#!/usr/bin/env zx
/**
 * Verify Sakurajima system state
 * Runs aggressive checks to ensure everything is properly configured
 */

import { $, chalk, fs, path } from 'zx';
import {
  ok,
  warn,
  die,
  bold,
  fileExists,
  dirExists,
  commandExists,
  ensureSymlink,
  HOME,
  SETUP_DIR,
  WORKSPACE_DIR,
  CLIENTS_DIR,
  CONFIG_DIR,
  SSH_DIR,
  LOCAL_BIN,
} from './lib/common.ts';

let errors = 0;
let warnings = 0;

function check(condition: boolean, msg: string, fatal = false): void {
  if (condition) {
    ok(msg);
  } else if (fatal) {
    die(msg);
  } else {
    warn(msg);
    warnings++;
  }
}

async function checkCommand(cmd: string, name?: string): Promise<void> {
  const displayName = name || cmd;
  if (await commandExists(cmd)) {
    ok(`${displayName} installed`);
  } else {
    warn(`${displayName} not found`);
    warnings++;
  }
}

async function checkFile(filepath: string, name?: string): Promise<void> {
  const displayName = name || filepath;
  if (await fileExists(filepath)) {
    ok(`${displayName} exists`);
  } else {
    warn(`${displayName} missing`);
    warnings++;
  }
}

async function checkDir(dirpath: string, name?: string): Promise<void> {
  const displayName = name || dirpath;
  if (await dirExists(dirpath)) {
    ok(`${displayName} exists`);
  } else {
    warn(`${displayName} missing`);
    warnings++;
  }
}

async function checkSymlink(link: string, expectedTarget: string): Promise<void> {
  try {
    const stat = await fs.lstat(link);
    if (stat.isSymbolicLink()) {
      const target = await fs.readlink(link);
      if (target === expectedTarget) {
        ok(`Symlink OK: ${link}`);
      } else {
        warn(`Symlink points to wrong target: ${link} -> ${target} (expected: ${expectedTarget})`);
        warnings++;
      }
    } else {
      warn(`Not a symlink: ${link}`);
      warnings++;
    }
  } catch {
    warn(`Symlink missing: ${link}`);
    warnings++;
  }
}

async function main(): Promise<void> {
  console.log(bold('🔍 SAKURAJIMA SYSTEM VERIFICATION'));
  console.log('━'.repeat(50));
  console.log();

  // Check Sakurajima is at correct path
  console.log(bold('📁 Directory Layout'));
  check(
    SETUP_DIR === path.join(HOME, 'setup'),
    'Sakurajima at ~/setup',
    true
  );
  await checkDir(SETUP_DIR, '~/setup');
  await checkDir(WORKSPACE_DIR, '~/workspace');
  await checkDir(CLIENTS_DIR, '~/workspace/clients');
  await checkDir(LOCAL_BIN, '~/.local/bin');
  console.log();

  // Check repo files
  console.log(bold('📄 Repository Files'));
  await checkFile(path.join(SETUP_DIR, 'package.json'), 'package.json');
  await checkFile(path.join(SETUP_DIR, 'Brewfile'), 'Brewfile');
  await checkFile(path.join(SETUP_DIR, 'src', 'lib', 'common.ts'), 'src/lib/common.ts');
  await checkFile(path.join(SETUP_DIR, 'src', 'cli', 'skr.ts'), 'src/cli/skr.ts');
  console.log();

  // Check node_modules
  console.log(bold('📦 Node Dependencies'));
  await checkDir(path.join(SETUP_DIR, 'node_modules'), 'node_modules');
  await checkDir(path.join(SETUP_DIR, 'node_modules', 'zx'), 'zx package');
  console.log();

  // Check essential commands
  console.log(bold('🔧 Essential Commands'));
  await checkCommand('brew', 'Homebrew');
  await checkCommand('git', 'Git');
  await checkCommand('node', 'Node.js');
  await checkCommand('mise', 'mise');
  // Check local zx (not global)
  await checkFile(
    path.join(SETUP_DIR, 'node_modules', '.bin', 'zx'),
    'zx (local)'
  );
  console.log();

  // Check symlinks
  console.log(bold('🔗 Configuration Symlinks'));
  await checkSymlink(
    path.join(HOME, '.zshrc'),
    path.join(SETUP_DIR, 'configs', '.zshrc')
  );
  await checkSymlink(
    path.join(CONFIG_DIR, 'starship.toml'),
    path.join(SETUP_DIR, 'configs', 'starship.toml')
  );
  console.log();

  // Check AeroSpace and simple-bar
  console.log(bold('🪟 Window Management'));
  await checkCommand('aerospace', 'AeroSpace');
  await checkFile(path.join(CONFIG_DIR, 'aerospace.toml'), '~/.config/aerospace.toml');
  await checkSymlink(
    path.join(CONFIG_DIR, 'aerospace.base.toml'),
    path.join(SETUP_DIR, 'configs', 'aerospace.base.toml')
  );
  await checkFile(path.join(HOME, '.simplebarrc'), '~/.simplebarrc');
  await checkDir(
    path.join(HOME, 'Library', 'Application Support', 'Übersicht', 'widgets', 'simple-bar'),
    'simple-bar widget'
  );
  console.log();

  // Check git config
  console.log(bold('⚙️ Git Configuration'));
  await checkFile(path.join(HOME, '.gitconfig'), '~/.gitconfig');
  await checkFile(path.join(HOME, '.gitconfig.local'), '~/.gitconfig.local');
  console.log();

  // Check SSH
  console.log(bold('🔐 SSH Configuration'));
  await checkDir(SSH_DIR, '~/.ssh');
  await checkFile(path.join(SSH_DIR, 'config'), '~/.ssh/config');

  try {
    const stat = await fs.stat(SSH_DIR);
    const mode = stat.mode & 0o777;
    check(mode === 0o700, `~/.ssh permissions (${mode.toString(8)} should be 700)`);
  } catch {
    warn('Could not check ~/.ssh permissions');
    warnings++;
  }
  console.log();

  // Summary
  console.log('━'.repeat(50));
  if (warnings === 0 && errors === 0) {
    console.log(chalk.green(bold('✅ All checks passed!')));
  } else {
    if (warnings > 0) {
      console.log(chalk.yellow(`⚠️  ${warnings} warning(s)`));
    }
    if (errors > 0) {
      console.log(chalk.red(`❌ ${errors} error(s)`));
      process.exit(1);
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
