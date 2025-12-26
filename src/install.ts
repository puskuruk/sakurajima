#!/usr/bin/env zx
/**
 * Sakurajima Main Installer
 * Configures the macOS development environment
 *
 * NOTE: This script expects dependencies (zx, mise, node) to already be
 * installed by the bootstrap script (install.sh)
 */

import { $, chalk, fs, path, question, spinner } from 'zx';
import {
  ok,
  info,
  warn,
  die,
  bold,
  ensureDir,
  fileExists,
  dirExists,
  ensureSymlinkStrict,
  commandExists,
  HOME,
  SETUP_DIR,
  WORKSPACE_DIR,
  CLIENTS_DIR,
  CONFIG_DIR,
  SSH_DIR,
  LOCAL_BIN,
} from './lib/common.ts';

const VERSION = '0.2.0';

// Directory structure
const CONFIGS_DIR = path.join(SETUP_DIR, 'configs');
const RAYCAST_DIR = path.join(SETUP_DIR, 'raycast');
const INFRA_DIR = path.join(SETUP_DIR, 'infra');
const DOCS_DIR = path.join(SETUP_DIR, 'docs');

const SSH_CONFIG = path.join(SSH_DIR, 'config');
const SSH_KEYS_DIR = path.join(SSH_DIR, 'keys');
const ZPROFILE = path.join(HOME, '.zprofile');

// Übersicht widgets directory
const UBERSICHT_WIDGETS = path.join(HOME, 'Library', 'Application Support', 'Übersicht', 'widgets');
const SIMPLE_BAR_DIR = path.join(UBERSICHT_WIDGETS, 'simple-bar');

// Workspace directories
const CLIENTS_ARCHIVE = path.join(CLIENTS_DIR, '_archive');
const PERSONAL_DIR = path.join(WORKSPACE_DIR, 'personal');
const SHARED_DIR = path.join(WORKSPACE_DIR, 'shared');
const SCRATCH_DIR = path.join(WORKSPACE_DIR, 'scratch');
const DATA_DIR = path.join(WORKSPACE_DIR, 'data');

// Required files for installation verification
const REQUIRED_FILES = [
  'package.json',
  'Brewfile',
  'configs/.zshrc',
  'configs/.gitconfig.template',
  'configs/starship.toml',
  'configs/aerospace.base.toml',
  'configs/lazygit/config.yml',
  'configs/rectangle.json',
  'configs/simplebarrc.json',
  'configs/apps-catalog.json',
  'raycast/workflows.json',
  'raycast/generate-sakurajima-commands.sh',
  'infra/docker-compose.yml',
];

// Logo script path
const LOGO_SCRIPT = path.join(SETUP_DIR, 'scripts', 'sakurajima-logo');

async function showLogo(): Promise<void> {
  // Show the full ASCII art logo
  if (await fileExists(LOGO_SCRIPT)) {
    try {
      await $`bash ${LOGO_SCRIPT}`;
    } catch {
      // Fallback to simple banner if logo fails
      console.log();
      console.log(chalk.bold.magentaBright('SAKURAJIMA'));
      console.log(chalk.dim('My mind is a mountain'));
      console.log();
    }
  }
  console.log(chalk.dim(`Installer v${VERSION}`));
  console.log();
}

async function verifyRepoIntegrity(): Promise<void> {
  info('Verifying repository integrity...');

  // Check that we're at ~/setup
  if (SETUP_DIR !== path.join(HOME, 'setup')) {
    die(`Path inconsistency: Repo MUST be at ~/setup. Current: ${SETUP_DIR}`);
  }

  // Check required files
  for (const file of REQUIRED_FILES) {
    const fullPath = path.join(SETUP_DIR, file);
    if (!(await fileExists(fullPath))) {
      die(`Missing required file: ${file}`);
    }
  }

  ok('Repository integrity verified');
}

async function ensureDirectories(): Promise<void> {
  info('Creating directory structure...');

  await ensureDir(
    WORKSPACE_DIR,
    CLIENTS_DIR,
    CLIENTS_ARCHIVE,
    PERSONAL_DIR,
    SHARED_DIR,
    SCRATCH_DIR,
    DATA_DIR,
    CONFIG_DIR,
    LOCAL_BIN,
    path.join(CONFIG_DIR, 'git', 'clients')
  );

  // Create global gitignore
  await fs.ensureFile(path.join(CONFIG_DIR, 'git', 'ignore'));

  ok('Directory structure created');
}

async function ensureSsh(): Promise<void> {
  info('Configuring SSH...');

  await ensureDir(SSH_DIR, SSH_KEYS_DIR);

  // Set permissions
  await $`chmod 700 ${SSH_DIR} ${SSH_KEYS_DIR}`.quiet().catch(() => {});

  // Ensure SSH config exists
  if (!(await fileExists(SSH_CONFIG))) {
    await fs.writeFile(SSH_CONFIG, '');
  }
  await $`chmod 600 ${SSH_CONFIG}`.quiet().catch(() => {});

  // Add managed block if not present
  let config = await fs.readFile(SSH_CONFIG, 'utf-8').catch(() => '');
  if (!config.includes('# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>')) {
    config += `
# >>> SAKURAJIMA MANAGED CLIENT HOSTS >>>
# (managed by new-client)
# <<< SAKURAJIMA MANAGED CLIENT HOSTS <<<

Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityAgent none
`;
    await fs.writeFile(SSH_CONFIG, config);
  }

  ok('SSH configured');
}

async function setupSymlinks(): Promise<void> {
  info('Setting up configuration symlinks...');

  // .zshrc
  await ensureSymlinkStrict(
    path.join(CONFIGS_DIR, '.zshrc'),
    path.join(HOME, '.zshrc')
  );

  // Starship
  await ensureSymlinkStrict(
    path.join(CONFIGS_DIR, 'starship.toml'),
    path.join(CONFIG_DIR, 'starship.toml')
  );

  // AeroSpace base template
  await ensureSymlinkStrict(
    path.join(CONFIGS_DIR, 'aerospace.base.toml'),
    path.join(CONFIG_DIR, 'aerospace.base.toml')
  );

  // Rectangle
  await ensureSymlinkStrict(
    path.join(CONFIGS_DIR, 'rectangle.json'),
    path.join(CONFIG_DIR, 'rectangle.json')
  );

  // Lazygit
  await ensureDir(path.join(CONFIG_DIR, 'lazygit'));
  await ensureSymlinkStrict(
    path.join(CONFIGS_DIR, 'lazygit', 'config.yml'),
    path.join(CONFIG_DIR, 'lazygit', 'config.yml')
  );

  // Zsh completions
  const zshCompletionsDir = path.join(CONFIG_DIR, 'zsh', 'completions');
  await ensureDir(zshCompletionsDir);
  await ensureSymlinkStrict(
    path.join(CONFIGS_DIR, 'completions', '_sakurajima-apps'),
    path.join(zshCompletionsDir, '_sakurajima-apps')
  );

  ok('Symlinks configured');
}

async function setupSimpleBar(): Promise<void> {
  info('Setting up simple-bar for Übersicht...');

  // Create Übersicht widgets directory
  await ensureDir(UBERSICHT_WIDGETS);

  // Clone simple-bar if not exists
  if (!(await dirExists(SIMPLE_BAR_DIR))) {
    await spinner('Cloning simple-bar...', async () => {
      await $`git clone --depth 1 https://github.com/Jean-Tinland/simple-bar ${SIMPLE_BAR_DIR}`.quiet();
    });
    ok('simple-bar cloned');
  } else {
    // Update simple-bar
    await spinner('Updating simple-bar...', async () => {
      await $`git -C ${SIMPLE_BAR_DIR} pull --rebase`.quiet().catch(() => {});
    });
    ok('simple-bar updated');
  }

  // Copy simplebarrc configuration
  const simplebarrc = path.join(HOME, '.simplebarrc');
  const srcConfig = path.join(CONFIGS_DIR, 'simplebarrc.json');

  if (!(await fileExists(simplebarrc))) {
    await fs.copy(srcConfig, simplebarrc);
    ok('Created ~/.simplebarrc');
  } else {
    ok('~/.simplebarrc already exists');
  }

  ok('simple-bar configured');
}

async function setupGitConfig(): Promise<void> {
  info('Setting up Git configuration...');

  const gitconfig = path.join(HOME, '.gitconfig');
  const gitconfigLocal = path.join(HOME, '.gitconfig.local');

  // Copy .gitconfig template (not symlinked to allow personal changes)
  if (!(await fileExists(gitconfig))) {
    await fs.copy(
      path.join(CONFIGS_DIR, '.gitconfig.template'),
      gitconfig
    );
    ok('Created ~/.gitconfig from template');
  } else {
    ok('~/.gitconfig already exists');
  }

  // Setup global gitignore at ~/.config/git/ignore
  const gitConfigDir = path.join(CONFIG_DIR, 'git');
  const gitIgnore = path.join(gitConfigDir, 'ignore');
  const gitIgnoreSource = path.join(CONFIGS_DIR, 'git', 'ignore');

  await ensureDir(gitConfigDir);

  if (await fileExists(gitIgnoreSource)) {
    // Remove existing file if it's not a symlink
    try {
      const stat = await fs.lstat(gitIgnore);
      if (!stat.isSymbolicLink()) {
        await fs.remove(gitIgnore);
      }
    } catch {
      // File doesn't exist, that's fine
    }
    await ensureSymlinkStrict(gitIgnoreSource, gitIgnore);
    ok('Linked ~/.config/git/ignore');
  }

  // Create directory for per-client git configs
  const gitClientsDir = path.join(gitConfigDir, 'clients');
  await ensureDir(gitClientsDir);
  ok('Created ~/.config/git/clients/');

  // Create .gitconfig.local for personal identity
  if (!(await fileExists(gitconfigLocal))) {
    console.log();
    info('Setting up personal Git identity...');
    const gitName = await question('Enter your full name: ');
    const gitEmail = await question('Enter your email: ');

    const content = `# Personal Git Identity (not version controlled)
[user]
    name = ${gitName}
    email = ${gitEmail}
`;
    await fs.writeFile(gitconfigLocal, content);
    ok('Created ~/.gitconfig.local');
  } else {
    ok('~/.gitconfig.local already exists');
  }
}

async function installWrapperScripts(): Promise<void> {
  info('Installing wrapper scripts...');

  await ensureDir(LOCAL_BIN);

  // Generate wrapper scripts that call zx scripts
  const wrappers = [
    { name: 'skr', script: 'src/cli/skr.ts' },
    { name: 'sakurajima-time-start', script: 'src/time/start.ts' },
    { name: 'sakurajima-time-init', script: 'src/time/init.ts' },
    { name: 'sakurajima-unfocus', script: 'src/time/unfocus.ts' },
    { name: 'sakurajima-stats', script: 'src/time/stats.ts' },
    { name: 'sakurajima-time-cleanup', script: 'src/time/cleanup.ts' },
    { name: 'verify-system', script: 'src/verify-system.ts' },
    { name: 'update-all', script: 'src/update-all.ts' },
    { name: 'new-client', script: 'src/client/new.ts' },
    { name: 'generate-aerospace-config', script: 'src/generate-aerospace-config.ts' },
  ];

  // Use the local zx from node_modules
  const zxPath = path.join(SETUP_DIR, 'node_modules', '.bin', 'zx');

  for (const { name, script } of wrappers) {
    const wrapperPath = path.join(LOCAL_BIN, name);
    const content = `#!/usr/bin/env bash
# Sakurajima wrapper for ${name}
exec "${zxPath}" "${path.join(SETUP_DIR, script)}" "$@"
`;
    await fs.writeFile(wrapperPath, content);
    await $`chmod +x ${wrapperPath}`.quiet();
    ok(`Installed: ${name}`);
  }

  // Install static scripts (non-zx)
  const staticScripts = [
    'sakurajima-confirm',
    'kubectl-guard',
    'terraform-guard',
    'sakurajima-infra-up.sh',
    'sakurajima-infra-down.sh',
    'sakurajima-infra-backup.sh',
    'sakurajima-apps.sh',
    'sakurajima-logo',
    'macos-defaults.sh',
    'setup-local-ai.sh',
    'update-aerospace.sh',
    'install-aerospace-native-shortcuts.sh',
    'update-aerospace-native-shortcuts.sh',
  ];

  const scriptsDir = path.join(SETUP_DIR, 'scripts');

  for (const script of staticScripts) {
    const src = path.join(scriptsDir, script);
    if (await fileExists(src)) {
      const name = script.replace(/\.sh$/, '');
      const dest = path.join(LOCAL_BIN, name);
      await fs.copy(src, dest);
      await $`chmod +x ${dest}`.quiet();
      ok(`Installed: ${name}`);
    }
  }

  // Install raycast generator
  const raycastGen = path.join(RAYCAST_DIR, 'generate-sakurajima-commands.sh');
  if (await fileExists(raycastGen)) {
    const dest = path.join(LOCAL_BIN, 'generate-sakurajima-commands');
    await fs.copy(raycastGen, dest);
    await $`chmod +x ${dest}`.quiet();
    ok('Installed: generate-sakurajima-commands');
  }
}

async function generateConfigs(): Promise<void> {
  info('Generating dynamic configurations...');

  // Local zx path - NEVER rely on global zx
  const zxBin = path.join(SETUP_DIR, 'node_modules', '.bin', 'zx');

  // Generate AeroSpace config using zx script
  const genAerospace = path.join(SETUP_DIR, 'src', 'generate-aerospace-config.ts');
  if (await fileExists(genAerospace)) {
    await spinner('Generating AeroSpace config...', async () => {
      await $`${zxBin} ${genAerospace}`.quiet().catch(() => {});
    });
    ok('AeroSpace config generated');
  }

  // Generate Raycast commands
  if (await commandExists('generate-sakurajima-commands')) {
    await spinner('Generating Raycast commands...', async () => {
      await $`generate-sakurajima-commands`.quiet().catch(() => {});
    });
    ok('Raycast commands generated');
  }
}

async function applyMacOSDefaults(): Promise<void> {
  info('Applying macOS defaults...');

  if (await commandExists('macos-defaults')) {
    try {
      await $`macos-defaults`.quiet();
      ok('macOS defaults applied');
    } catch {
      warn('macos-defaults had warnings (non-fatal)');
    }
  }
}

async function setupLocalAI(): Promise<void> {
  if (await commandExists('setup-local-ai')) {
    info('Setting up Local AI...');
    try {
      await $`setup-local-ai`.quiet();
      ok('Local AI configured');
    } catch {
      warn('Local AI setup had warnings (non-fatal)');
    }
  }
}

async function startServices(): Promise<void> {
  info('Starting services...');

  // Start Übersicht (if installed)
  try {
    await $`open -a Übersicht`.quiet();
    ok('Übersicht started');
  } catch {
    warn('Could not start Übersicht (may not be installed yet)');
  }

  // Refresh simple-bar
  try {
    await $`osascript -e 'tell application id "tracesOf.Uebersicht" to refresh'`.quiet();
    ok('simple-bar refreshed');
  } catch {
    // Übersicht may not be running
  }

  // AeroSpace
  if (await commandExists('aerospace')) {
    await $`aerospace reload-config`.quiet().catch(() => {});
    ok('AeroSpace config reloaded');
  }

  // Native shortcuts
  if (await commandExists('install-aerospace-native-shortcuts')) {
    try {
      await $`install-aerospace-native-shortcuts`.quiet();
      ok('Native shortcuts configured');
    } catch {
      warn('Native shortcuts installer had warnings');
    }
  }
}

async function setupDepotTools(): Promise<void> {
  const depotTools = path.join(WORKSPACE_DIR, 'depot_tools');

  if (!(await dirExists(depotTools))) {
    info('Cloning depot_tools (Chromium/WebKit prerequisite)...');
    await $`git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ${depotTools}`;
    ok('depot_tools installed');
  } else {
    ok('depot_tools already exists');
  }
}

async function provisionDefaultClients(): Promise<void> {
  info('Provisioning default clients...');

  // Get git identity
  let gitName = '';
  let gitEmail = '';

  try {
    gitName = (await $`git config --global user.name`.quiet()).stdout.trim();
    gitEmail = (await $`git config --global user.email`.quiet()).stdout.trim();
  } catch {
    // Use defaults
  }

  gitName = gitName || 'Chrome Dev';
  gitEmail = gitEmail || 'dev@chromium.local';

  const newClient = path.join(LOCAL_BIN, 'new-client');

  // Chromium
  // Note: --no-passphrase and --yes are required for non-interactive installation
  // Users can regenerate keys with passphrases later using: skr new <client>
  if (!(await dirExists(path.join(CLIENTS_DIR, 'chromium')))) {
    await $`${newClient} chromium --name ${gitName} --email ${gitEmail} --no-clipboard --no-passphrase --yes`;
    ok("Client 'chromium' provisioned");
  } else {
    ok("Client 'chromium' already exists");
  }

  // WebKit
  if (!(await dirExists(path.join(CLIENTS_DIR, 'webkit')))) {
    await $`${newClient} webkit --name ${gitName} --email ${gitEmail} --no-clipboard --no-passphrase --yes`;
    ok("Client 'webkit' provisioned");
  } else {
    ok("Client 'webkit' already exists");
  }
}

async function runVerification(): Promise<void> {
  info('Running system verification...');

  const verifySystem = path.join(LOCAL_BIN, 'verify-system');
  if (await fileExists(verifySystem)) {
    try {
      await $`${verifySystem}`;
    } catch {
      die('System verification failed');
    }
  }
}

async function main(): Promise<void> {
  await showLogo();

  console.log(bold('Starting Sakurajima installation...'));
  console.log();

  await verifyRepoIntegrity();
  console.log();

  await ensureDirectories();
  console.log();

  await ensureSsh();
  console.log();

  await setupSymlinks();
  console.log();

  await setupSimpleBar();
  console.log();

  await setupGitConfig();
  console.log();

  await installWrapperScripts();
  console.log();

  await generateConfigs();
  console.log();

  await applyMacOSDefaults();
  console.log();

  await setupLocalAI();
  console.log();

  await startServices();
  console.log();

  await setupDepotTools();
  console.log();

  await provisionDefaultClients();
  console.log();

  // Regenerate configs after clients are provisioned
  await generateConfigs();
  console.log();

  await runVerification();
  console.log();

  console.log('='.repeat(50));
  console.log(chalk.green(bold('INSTALLATION COMPLETE')));
  console.log('='.repeat(50));
  console.log();

  console.log(bold('Quick Start:'));
  console.log('  skr help              Show all available commands');
  console.log('  skr new <client>      Create a new client workspace');
  console.log('  skr focus <client>    Start time tracking for a client');
  console.log('  skr stats             View time tracking stats');
  console.log('  skr verify            Verify system is configured correctly');
  console.log();

  console.log(bold('Configuration:'));
  info('simple-bar: Open Übersicht → Cmd+, → Select "AeroSpace" in Global tab');
  info('Shortcuts: See ~/.local/share/sakurajima/aerospace-actions/SHORTCUTS_MAP.txt');
  console.log();

  console.log(chalk.dim('Use "skr" for all Sakurajima operations. Run "skr help" for full command list.'));
  console.log();
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
