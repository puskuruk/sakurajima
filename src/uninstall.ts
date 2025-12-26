#!/usr/bin/env zx
/**
 * Uninstall Sakurajima environment
 * Cleans up everything so ./install.sh can start fresh
 */

import { $, chalk, fs, path, question } from 'zx';
import {
  ok,
  info,
  warn,
  bold,
  fileExists,
  dirExists,
  HOME,
  CONFIG_DIR,
  WORKSPACE_DIR,
  CLIENTS_DIR,
  SAKURAJIMA_DATA,
  SSH_DIR,
  SSH_KEYS_DIR,
  SETUP_DIR,
} from './lib/common.ts';

const LOCAL_BIN = path.join(HOME, '.local', 'bin');

// Symlinks created by installer
const SYMLINKS = [
  path.join(HOME, '.zshrc'),
  path.join(CONFIG_DIR, 'starship.toml'),
  path.join(CONFIG_DIR, 'aerospace.base.toml'),
  path.join(CONFIG_DIR, 'rectangle.json'),
  path.join(CONFIG_DIR, 'lazygit', 'config.yml'),
  path.join(CONFIG_DIR, 'git', 'ignore'),
];

// Generated files (not symlinks)
const GENERATED_FILES = [
  path.join(CONFIG_DIR, 'aerospace.toml'),
  path.join(HOME, '.simplebarrc'),
];

// Directories to remove
const DIRECTORIES_TO_REMOVE = [
  path.join(CONFIG_DIR, 'git', 'clients'),  // Per-client git configs
  SAKURAJIMA_DATA,                           // Time tracking DB, session state, aerospace actions
];

// Übersicht widgets
const UBERSICHT_WIDGETS = path.join(HOME, 'Library', 'Application Support', 'Übersicht', 'widgets');
const SIMPLE_BAR_DIR = path.join(UBERSICHT_WIDGETS, 'simple-bar');

// Raycast scripts
const RAYCAST_DIR = path.join(HOME, 'raycast', 'scripts', 'sakurajima');

// All binaries installed to ~/.local/bin
const BINARIES = [
  'skr',
  'sakurajima-time-start',
  'sakurajima-time-init',
  'sakurajima-unfocus',
  'sakurajima-stats',
  'sakurajima-time-cleanup',
  'verify-system',
  'new-client',
  'update-all',
  'generate-aerospace-config',
  'generate-sakurajima-commands',
  'macos-defaults',
  'setup-local-ai',
  'install-aerospace-native-shortcuts',
  'update-aerospace-native-shortcuts',
  'sakurajima-confirm',
  'kubectl-guard',
  'terraform-guard',
  'sakurajima-infra-up',
  'sakurajima-infra-down',
  'sakurajima-infra-backup',
  'sakurajima-logo',
  'update-aerospace',
];

// SSH config managed block markers
const SSH_MANAGED_BEGIN = '# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>';
const SSH_MANAGED_END = '# <<< SAKURAJIMA MANAGED CLIENT HOSTS <<<';

async function stopTimeTracking(): Promise<void> {
  info('Stopping any running time tracking...');

  // Read session state and kill daemon if running
  const sessionFile = path.join(SAKURAJIMA_DATA, 'session');
  if (await fileExists(sessionFile)) {
    try {
      const content = await fs.readFile(sessionFile, 'utf-8');
      const pidMatch = content.match(/TRACKER_PID=(\d+)/);
      if (pidMatch) {
        const pid = parseInt(pidMatch[1], 10);
        try {
          await $`kill ${pid}`.quiet();
          ok('Stopped time tracking daemon');
        } catch {
          // Process might not exist
        }
      }
    } catch {
      // Ignore errors
    }
  }
}

async function cleanSshConfig(): Promise<void> {
  info('Cleaning SSH config...');

  const sshConfig = path.join(SSH_DIR, 'config');
  if (!(await fileExists(sshConfig))) {
    return;
  }

  try {
    let content = await fs.readFile(sshConfig, 'utf-8');

    // Remove managed block
    const beginIdx = content.indexOf(SSH_MANAGED_BEGIN);
    const endIdx = content.indexOf(SSH_MANAGED_END);

    if (beginIdx !== -1 && endIdx !== -1) {
      const before = content.substring(0, beginIdx).trimEnd();
      const after = content.substring(endIdx + SSH_MANAGED_END.length).trimStart();
      content = before + (after ? '\n\n' + after : '\n');
      await fs.writeFile(sshConfig, content);
      ok('Removed managed SSH host entries');
    }
  } catch (err) {
    warn(`Failed to clean SSH config: ${err}`);
  }
}

async function cleanGitConfig(): Promise<void> {
  info('Cleaning Git config includeIf entries...');

  const gitconfig = path.join(HOME, '.gitconfig');
  if (!(await fileExists(gitconfig))) {
    return;
  }

  try {
    let content = await fs.readFile(gitconfig, 'utf-8');

    // Remove all includeIf entries pointing to ~/.config/git/clients/
    const lines = content.split('\n');
    const filteredLines: string[] = [];
    let skipNext = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      if (line.includes('[includeIf "gitdir:~/workspace/clients/')) {
        // Skip this line and the next path = line
        skipNext = true;
        continue;
      }

      if (skipNext && line.trim().startsWith('path = ~/.config/git/clients/')) {
        skipNext = false;
        continue;
      }

      skipNext = false;
      filteredLines.push(line);
    }

    // Clean up multiple consecutive blank lines
    const cleanedContent = filteredLines.join('\n').replace(/\n{3,}/g, '\n\n');
    await fs.writeFile(gitconfig, cleanedContent);
    ok('Removed client includeIf entries from .gitconfig');
  } catch (err) {
    warn(`Failed to clean .gitconfig: ${err}`);
  }
}

async function removeSymlinks(): Promise<void> {
  info('Removing symlinks...');

  for (const link of SYMLINKS) {
    try {
      const stat = await fs.lstat(link);
      if (stat.isSymbolicLink()) {
        await fs.remove(link);
        ok(`Removed: ${link}`);
      }
    } catch {
      // Ignore if doesn't exist
    }
  }
}

async function removeBinaries(): Promise<void> {
  info('Removing binaries...');

  for (const bin of BINARIES) {
    const binPath = path.join(LOCAL_BIN, bin);
    try {
      await fs.remove(binPath);
      ok(`Removed: ${bin}`);
    } catch {
      // Ignore if doesn't exist
    }
  }
}

async function removeGeneratedFiles(): Promise<void> {
  info('Removing generated files...');

  for (const file of GENERATED_FILES) {
    try {
      await fs.remove(file);
      ok(`Removed: ${file}`);
    } catch {
      // Ignore if doesn't exist
    }
  }
}

async function removeDirectories(): Promise<void> {
  info('Removing Sakurajima directories...');

  for (const dir of DIRECTORIES_TO_REMOVE) {
    try {
      if (await dirExists(dir)) {
        await fs.remove(dir);
        ok(`Removed: ${dir}`);
      }
    } catch (err) {
      warn(`Failed to remove ${dir}: ${err}`);
    }
  }

  // Remove simple-bar widget
  try {
    if (await dirExists(SIMPLE_BAR_DIR)) {
      await fs.remove(SIMPLE_BAR_DIR);
      ok(`Removed: ${SIMPLE_BAR_DIR}`);
    }
  } catch {
    // Ignore
  }

  // Remove Raycast scripts
  try {
    if (await dirExists(RAYCAST_DIR)) {
      await fs.remove(RAYCAST_DIR);
      ok(`Removed: ${RAYCAST_DIR}`);
    }
  } catch {
    // Ignore
  }
}

async function removeSshKeys(): Promise<void> {
  info('Removing client SSH keys...');

  if (!(await dirExists(SSH_KEYS_DIR))) {
    return;
  }

  try {
    const entries = await fs.readdir(SSH_KEYS_DIR, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        const keyDir = path.join(SSH_KEYS_DIR, entry.name);
        await fs.remove(keyDir);
        ok(`Removed SSH keys: ${entry.name}`);
      }
    }

    // Remove keys directory if empty
    const remaining = await fs.readdir(SSH_KEYS_DIR);
    if (remaining.length === 0) {
      await fs.remove(SSH_KEYS_DIR);
      ok('Removed ~/.ssh/keys/');
    }
  } catch (err) {
    warn(`Failed to remove SSH keys: ${err}`);
  }
}


async function main(): Promise<void> {
  console.log();
  console.log(bold('🗑  SAKURAJIMA UNINSTALLER'));
  console.log();
  console.log('This will remove:');
  console.log('  • Binaries from ~/.local/bin');
  console.log('  • Config symlinks (.zshrc, starship.toml, etc.)');
  console.log('  • Generated configs (aerospace.toml, .simplebarrc)');
  console.log('  • SSH client keys and config entries');
  console.log('  • Per-client Git configs');
  console.log('  • Time tracking database');
  console.log('  • simple-bar widget and Raycast scripts');
  console.log();
  console.log(chalk.yellow('PRESERVED:'));
  console.log('  • ~/.gitconfig, ~/.gitconfig.local');
  console.log('  • ~/workspace/');
  console.log('  • ~/setup/');
  console.log();

  const confirm = await question(chalk.bold("Type 'uninstall' to continue: "));
  if (confirm !== 'uninstall') {
    console.log('Aborted.');
    process.exit(0);
  }

  console.log();

  // Stop any running processes first
  await stopTimeTracking();
  console.log();

  // Clean configs before removing symlinks
  await cleanSshConfig();
  await cleanGitConfig();
  console.log();

  // Remove installed files
  await removeBinaries();
  console.log();

  await removeSymlinks();
  console.log();

  await removeGeneratedFiles();
  console.log();

  await removeDirectories();
  console.log();

  await removeSshKeys();
  console.log();

  console.log(chalk.green(bold('✅ UNINSTALL COMPLETE')));
  console.log();
  console.log('To reinstall:');
  console.log(chalk.cyan('  cd ~/setup && ./install.sh'));
  console.log();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
