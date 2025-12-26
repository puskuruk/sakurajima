#!/usr/bin/env zx
/**
 * Start a time tracking session for a client
 */

import { $, argv, chalk, path } from 'zx';
import {
  ok,
  info,
  warn,
  die,
  bold,
  validateClientName,
  sqlEscape,
  sqlite,
  ensureDir,
  fileExists,
  dirExists,
  commandExists,
  isProcessRunning,
  killProcess,
  readSessionState,
  writeSessionState,
  removeSessionState,
  now,
  sleep,
  SAKURAJIMA_CONFIG,
  TIME_DB,
  SETUP_DIR,
  CLIENTS_DIR,
  WORKSPACE_DIR,
  SSH_KEYS_DIR,
  CONFIG_DIR,
} from '../lib/common.ts';

// Special "personal" workspace for non-client work
const PERSONAL_DIR = path.join(WORKSPACE_DIR, 'personal');

// Local zx path - NEVER rely on global zx
const ZX_BIN = path.join(SETUP_DIR, 'node_modules', '.bin', 'zx');

async function initDb(): Promise<void> {
  if (await fileExists(TIME_DB)) return;

  if (await commandExists('sakurajima-time-init')) {
    await $`sakurajima-time-init`.quiet();
  } else {
    // Try to run the init script directly
    const initScript = path.join(SETUP_DIR, 'src', 'time', 'init.ts');
    if (await fileExists(initScript)) {
      await $`${ZX_BIN} ${initScript}`.quiet();
    } else {
      die('Database not initialized and init script not found');
    }
  }
}

async function stopPreviousSession(): Promise<void> {
  if (await commandExists('sakurajima-unfocus')) {
    try {
      await $`sakurajima-unfocus`.quiet();
    } catch {
      // Ignore errors
    }
  }
}

async function switchToClientWorkspace(clientName: string): Promise<void> {
  // Switch to client's AeroSpace workspace if aerospace is available
  if (await commandExists('aerospace')) {
    try {
      await $`aerospace workspace ${clientName}`.quiet();
      info(`Switched to workspace: ${clientName}`);
    } catch {
      // Workspace might not exist in aerospace config yet
      // This is non-fatal - the client directory is what matters
    }
  }
}

async function showClientConfig(clientName: string): Promise<void> {
  const clientDir = path.join(CLIENTS_DIR, clientName);
  const sshKeyPath = path.join(SSH_KEYS_DIR, clientName, 'id_ed25519');
  const gitConfigPath = path.join(CONFIG_DIR, 'git', 'clients', `${clientName}.gitconfig`);

  console.log();
  console.log(bold(`🏗  CLIENT: ${clientName}`));
  console.log('─'.repeat(50));
  console.log(`   Workspace: ${clientDir}`);

  // SSH configuration
  if (await fileExists(sshKeyPath)) {
    console.log(`   SSH Key:   ${sshKeyPath}`);
    console.log(`   GitHub:    git@github.com-${clientName}:org/repo.git`);
    console.log(`   GitLab:    git@gitlab.com-${clientName}:org/repo.git`);
  }

  // Git identity
  if (await fileExists(gitConfigPath)) {
    try {
      const content = await $`cat ${gitConfigPath}`.quiet();
      const nameMatch = content.stdout.match(/name\s*=\s*(.+)/);
      const emailMatch = content.stdout.match(/email\s*=\s*(.+)/);
      if (nameMatch || emailMatch) {
        const name = nameMatch ? nameMatch[1].trim() : 'N/A';
        const email = emailMatch ? emailMatch[1].trim() : 'N/A';
        console.log(`   Git ID:    ${name} <${email}>`);
      }
    } catch {
      // Ignore errors reading git config
    }
  } else {
    console.log(`   Git ID:    (using personal identity)`);
  }

  console.log('─'.repeat(50));
}

async function main(): Promise<void> {
  const clientNameArg = argv._[0] as string | undefined;

  if (!clientNameArg) {
    die('Client name required. Usage: sakurajima-time-start <client>');
  }

  // Validate client name (safe to use: checked above, die() exits if undefined)
  if (!validateClientName(clientNameArg!)) {
    die(`Invalid client name: ${clientNameArg} (must be kebab-case)`);
  }

  const clientName = clientNameArg!;
  const isPersonal = clientName === 'personal';

  // Verify workspace exists
  if (isPersonal) {
    // "personal" is a special workspace at ~/workspace/personal (not a client)
    if (!(await dirExists(PERSONAL_DIR))) {
      await ensureDir(PERSONAL_DIR);
      info(`Created personal workspace: ${PERSONAL_DIR}`);
    }
    console.log();
    console.log(bold('🏠 PERSONAL WORKSPACE'));
    console.log('─'.repeat(50));
    console.log(`   Workspace: ${PERSONAL_DIR}`);
    console.log(`   Git ID:    (using personal identity)`);
    console.log('─'.repeat(50));
  } else {
    // Regular client workspace
    const clientDir = path.join(CLIENTS_DIR, clientName);
    if (!(await dirExists(clientDir))) {
      die(`Client not found: ${clientName}\nCreate it first with: skr new ${clientName}`);
    }

    // Show client configuration
    await showClientConfig(clientName);

    // Switch to client's AeroSpace workspace
    await switchToClientWorkspace(clientName);
  }

  // Initialize DB if needed
  await initDb();

  // Check for active session
  const state = await readSessionState();
  if (state) {
    if (await isProcessRunning(state.TRACKER_PID)) {
      if (clientName === state.CLIENT) {
        warn(`Already tracking: ${state.CLIENT}`);
        process.exit(0);
      } else {
        warn(`Stopping previous session: ${state.CLIENT}`);
        await stopPreviousSession();
      }
    } else {
      // Stale session - clean up
      if (await commandExists('sakurajima-time-cleanup')) {
        try {
          await $`sakurajima-time-cleanup`.quiet();
        } catch {
          await removeSessionState();
        }
      } else {
        await removeSessionState();
      }
    }
  }

  // Insert client if not exists
  const escapedClient = sqlEscape(clientName);
  await sqlite(TIME_DB, `INSERT OR IGNORE INTO clients (name) VALUES ('${escapedClient}');`);

  // Create new session
  const timestamp = now();
  const result = await sqlite(
    TIME_DB,
    `INSERT INTO sessions (client, start_time) VALUES ('${escapedClient}', ${timestamp}); SELECT last_insert_rowid();`
  );

  const sessionId = parseInt(result, 10);
  if (!sessionId || sessionId === 0) {
    die('Failed to create session');
  }

  // Start background tracker daemon
  const daemonScript = path.join(SETUP_DIR, 'src', 'time', 'daemon.ts');

  // Use nohup to run daemon in background
  const daemonProcess = $`nohup ${ZX_BIN} ${daemonScript} ${sessionId} > /dev/null 2>&1 &`.quiet();

  // Small delay to let the process start
  await sleep(200);

  // Get the daemon PID from state file or estimate
  const newState = await readSessionState();
  const trackerPid = newState?.TRACKER_PID ?? process.pid;

  // Write state file
  await writeSessionState({
    CLIENT: clientName,
    SESSION_ID: sessionId,
    PID: process.pid,
    TRACKER_PID: trackerPid,
  });

  ok(`Started tracking: ${clientName} (session ${sessionId})`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
