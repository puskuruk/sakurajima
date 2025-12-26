#!/usr/bin/env zx
/**
 * Provision a new client workspace
 */

import { $, argv, chalk, fs, path, question } from 'zx';
import {
  ok,
  info,
  warn,
  die,
  bold,
  validateClientName,
  ensureDir,
  fileExists,
  CLIENTS_DIR,
  SSH_DIR,
  SSH_KEYS_DIR,
  HOME,
  CONFIG_DIR,
} from '../lib/common.ts';

interface ClientOptions {
  name: string;
  email?: string;
  userName?: string;
  githubOnly: boolean;
  gitlabOnly: boolean;
  noPassphrase: boolean;
  noClipboard: boolean;
  usePersonalGit: boolean;  // Use global git identity (no per-client config)
  yes: boolean;  // Skip confirmation prompts (for non-interactive use)
}

const SSH_CONFIG = path.join(SSH_DIR, 'config');
const GIT_CLIENTS_DIR = path.join(CONFIG_DIR, 'git', 'clients');

const MANAGED_BEGIN = '# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>';
const MANAGED_END = '# <<< SAKURAJIMA MANAGED CLIENT HOSTS <<<';

function showHelp(): void {
  console.log(`${bold('skr new')} <client-name> [options]

${bold('Options:')}
  --github-only          Create only GitHub host alias
  --gitlab-only          Create only GitLab host alias
  --email <email>        Per-client git user.email (implies custom git identity)
  --name <full-name>     Per-client git user.name (implies custom git identity)
  --personal             Use personal git identity (from ~/.gitconfig.local)
  --no-passphrase        Create SSH key WITHOUT passphrase (INSECURE)
  --no-clipboard         Don't copy public key to clipboard
  --yes, -y              Skip confirmation prompts (for automation)

${bold('Git Identity:')}
  By default, you'll be asked whether to use your personal git identity
  or create a custom one for this client.

  Use --personal to skip the prompt and use your personal identity.
  Use --email/--name to skip the prompt and create a custom identity.

${bold('Client name must be kebab-case:')}
  e.g. acme-corp, my-client

${bold('Examples:')}
  skr new acme                          # Interactive (asks about git identity)
  skr new acme --personal               # Use personal git identity
  skr new acme --email dev@acme.com     # Create custom identity for Acme

${bold('NOTE:')} SSH keys are created WITH passphrases by default for security.
`);
}

async function ensureSshPerms(): Promise<void> {
  await ensureDir(SSH_DIR, SSH_KEYS_DIR);
  await $`chmod 700 ${SSH_DIR} ${SSH_KEYS_DIR}`.quiet().catch(() => {});

  if (!(await fileExists(SSH_CONFIG))) {
    await fs.writeFile(SSH_CONFIG, '');
  }
  await $`chmod 600 ${SSH_CONFIG}`.quiet().catch(() => {});
}

async function ensureManagedBlock(): Promise<void> {
  let content = await fs.readFile(SSH_CONFIG, 'utf-8').catch(() => '');

  if (!content.includes(MANAGED_BEGIN)) {
    content = content.trimEnd() + `\n\n${MANAGED_BEGIN}\n${MANAGED_END}\n`;
    await fs.writeFile(SSH_CONFIG, content);
    ok('Initialized managed SSH block');
  }
}

async function insertSshBlock(unique: string, block: string): Promise<void> {
  await ensureManagedBlock();

  let content = await fs.readFile(SSH_CONFIG, 'utf-8');

  if (content.includes(unique)) {
    ok(`SSH entry exists: ${unique}`);
    return;
  }

  content = content.replace(MANAGED_END, `${block}\n${MANAGED_END}`);
  await fs.writeFile(SSH_CONFIG, content);
  await $`chmod 600 ${SSH_CONFIG}`.quiet().catch(() => {});
  ok(`Added SSH entry: ${unique}`);
}

async function generateSshKey(
  keyPath: string,
  comment: string,
  usePassphrase: boolean,
  skipConfirmation: boolean
): Promise<void> {
  if ((await fileExists(keyPath)) && (await fileExists(`${keyPath}.pub`))) {
    ok(`SSH key exists: ${keyPath}`);
    return;
  }

  if (usePassphrase) {
    info('Creating SSH key with passphrase (secure default)');
    await $`ssh-keygen -t ed25519 -C ${comment} -f ${keyPath}`;
  } else {
    warn('Creating SSH key WITHOUT passphrase (INSECURE)');
    warn('If your machine is compromised, all client SSH access will be exposed!');

    if (!skipConfirmation) {
      const confirm = await question('Are you sure you want to proceed? (yes/N) ');
      if (confirm.toLowerCase() !== 'yes') {
        die('Aborted. Remove --no-passphrase flag for secure key generation.');
      }
    }

    await $`ssh-keygen -t ed25519 -C ${comment} -f ${keyPath} -N ""`;
  }

  await $`chmod 600 ${keyPath}`.quiet().catch(() => {});
  await $`chmod 644 ${keyPath}.pub`.quiet().catch(() => {});
  ok(`Generated SSH key: ${keyPath}`);
}

async function setupGitConfig(
  client: string,
  email: string,
  userName?: string
): Promise<void> {
  await ensureDir(GIT_CLIENTS_DIR);

  const configPath = path.join(GIT_CLIENTS_DIR, `${client}.gitconfig`);

  // Use provided values (userName defaults to client name if not specified)
  const finalName = userName || client;
  const finalEmail = email;

  const content = `# Sakurajima per-client git identity
# Client: ${client}
[user]
    name = ${finalName}
    email = ${finalEmail}
`;

  await fs.writeFile(configPath, content);
  ok(`Created git config: ${configPath}`);

  // Add includeIf to main gitconfig if not present
  const mainGitconfig = path.join(HOME, '.gitconfig');
  if (await fileExists(mainGitconfig)) {
    let mainContent = await fs.readFile(mainGitconfig, 'utf-8');
    const includeIf = `[includeIf "gitdir:~/workspace/clients/${client}/"]`;

    if (!mainContent.includes(includeIf)) {
      mainContent += `\n${includeIf}\n    path = ~/.config/git/clients/${client}.gitconfig\n`;
      await fs.writeFile(mainGitconfig, mainContent);
      ok(`Added includeIf to ~/.gitconfig for ${client}`);
    }
  }
}

async function getPersonalGitIdentity(): Promise<{ name: string; email: string } | null> {
  try {
    const name = (await $`git config --global user.name`.quiet()).stdout.trim();
    const email = (await $`git config --global user.email`.quiet()).stdout.trim();
    if (name && email) {
      return { name, email };
    }
  } catch {
    // Git config not set
  }
  return null;
}

async function main(): Promise<void> {
  const clientName = argv._[0] as string | undefined;

  if (argv.help || argv.h || !clientName) {
    showHelp();
    if (!clientName) process.exit(1);
    return;
  }

  // Parse options
  const hasCustomGitArgs = !!(argv.email || argv.name);
  const usePersonalFlag = !!argv.personal;

  const options: ClientOptions = {
    name: clientName,
    email: argv.email as string | undefined,
    userName: argv.name as string | undefined,
    githubOnly: !!argv['github-only'],
    gitlabOnly: !!argv['gitlab-only'],
    noPassphrase: !!argv['no-passphrase'],
    noClipboard: !!argv['no-clipboard'],
    usePersonalGit: usePersonalFlag,
    yes: !!(argv.yes || argv.y),
  };

  // Validate client name
  if (!validateClientName(clientName)) {
    die(`Invalid client name: ${clientName} (must be kebab-case, e.g., acme-corp)`);
  }

  console.log(bold(`🏗  Provisioning client: ${clientName}`));

  // Determine git identity strategy
  if (!hasCustomGitArgs && !usePersonalFlag) {
    // Interactive mode: ask user what they want
    const personalId = await getPersonalGitIdentity();

    if (personalId) {
      console.log();
      info(`Your personal git identity: ${personalId.name} <${personalId.email}>`);
      console.log();
      const choice = await question(`Git identity for '${clientName}'? [P]ersonal / [C]ustom (P): `);

      if (choice.toLowerCase() === 'c' || choice.toLowerCase() === 'custom') {
        // User wants custom identity
        const customName = await question(`Git name for ${clientName}: `);
        const customEmail = await question(`Git email for ${clientName}: `);

        if (!customEmail.trim()) {
          die('Email is required for custom git identity');
        }

        options.email = customEmail.trim();
        options.userName = customName.trim() || clientName;
        options.usePersonalGit = false;
      } else {
        // Use personal identity (default)
        options.usePersonalGit = true;
      }
    } else {
      warn('No personal git identity found (run: git config --global user.name/email)');
      info('Creating custom git identity for this client...');

      const customName = await question(`Git name for ${clientName}: `);
      const customEmail = await question(`Git email for ${clientName}: `);

      if (!customEmail.trim()) {
        die('Email is required');
      }

      options.email = customEmail.trim();
      options.userName = customName.trim() || clientName;
      options.usePersonalGit = false;
    }
  } else if (hasCustomGitArgs) {
    // User provided --email or --name, so they want custom identity
    options.usePersonalGit = false;
  }
  // else: usePersonalFlag is true, so usePersonalGit stays true

  // Create workspace directory
  const workspaceDir = path.join(CLIENTS_DIR, clientName);
  await ensureDir(workspaceDir);
  ok(`Workspace ready: ${workspaceDir}`);

  // Setup SSH
  await ensureSshPerms();

  const keyDir = path.join(SSH_KEYS_DIR, clientName);
  await ensureDir(keyDir);

  const keyPath = path.join(keyDir, 'id_ed25519');
  const comment = `sakurajima-${clientName}@${require('os').hostname()}`;

  await generateSshKey(keyPath, comment, !options.noPassphrase, options.yes);

  // Create SSH host aliases
  const useGithub = !options.gitlabOnly;
  const useGitlab = !options.githubOnly;

  if (useGithub) {
    const block = `
Host github.com-${clientName}
    HostName github.com
    User git
    IdentityFile ${keyPath}
    IdentitiesOnly yes
`;
    await insertSshBlock(`github.com-${clientName}`, block);
  }

  if (useGitlab) {
    const block = `
Host gitlab.com-${clientName}
    HostName gitlab.com
    User git
    IdentityFile ${keyPath}
    IdentitiesOnly yes
`;
    await insertSshBlock(`gitlab.com-${clientName}`, block);
  }

  // Setup git config (only if using custom identity)
  if (!options.usePersonalGit) {
    await setupGitConfig(clientName, options.email!, options.userName);
    ok(`Custom git identity: ${options.userName || clientName} <${options.email}>`);
  } else {
    ok('Using personal git identity (no per-client config)');
  }

  // Copy public key to clipboard
  if (!options.noClipboard) {
    try {
      const pubKey = await fs.readFile(`${keyPath}.pub`, 'utf-8');
      await $`echo ${pubKey.trim()} | pbcopy`;
      ok('Public key copied to clipboard');
    } catch {
      warn('Failed to copy public key to clipboard');
    }
  }

  // Summary
  console.log();
  console.log(bold('✅ Client provisioned successfully!'));
  console.log();
  console.log(`Workspace:  ${workspaceDir}`);
  console.log(`SSH Key:    ${keyPath}`);

  if (!options.usePersonalGit) {
    console.log(`Git Config: ${path.join(GIT_CLIENTS_DIR, `${clientName}.gitconfig`)}`);
    console.log(`Git User:   ${options.userName || clientName} <${options.email}>`);
  } else {
    console.log('Git Config: Using personal identity from ~/.gitconfig.local');
  }

  if (useGithub) {
    console.log(`GitHub:     git clone git@github.com-${clientName}:org/repo.git`);
  }
  if (useGitlab) {
    console.log(`GitLab:     git clone git@gitlab.com-${clientName}:org/repo.git`);
  }

  console.log();
  info('Add the public key to your Git hosting service.');
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
