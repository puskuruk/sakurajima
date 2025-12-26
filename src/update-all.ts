#!/usr/bin/env zx
/**
 * Update Sakurajima system and all tools
 */

import { $, chalk, path, spinner } from 'zx';
import {
  ok,
  info,
  warn,
  bold,
  commandExists,
  SETUP_DIR,
} from './lib/common.ts';

// Local zx path - NEVER rely on global zx
const ZX_BIN = path.join(SETUP_DIR, 'node_modules', '.bin', 'zx');

async function updateHomebrew(): Promise<void> {
  if (!(await commandExists('brew'))) {
    warn('Homebrew not installed, skipping');
    return;
  }

  await spinner('Updating Homebrew...', async () => {
    await $`brew update`.quiet();
  });
  ok('Homebrew updated');

  await spinner('Upgrading packages...', async () => {
    await $`brew upgrade`.quiet();
  });
  ok('Packages upgraded');

  await spinner('Running brew bundle...', async () => {
    await $`brew bundle --file=${SETUP_DIR}/Brewfile`.quiet();
  });
  ok('Brewfile synced');

  await spinner('Cleaning up...', async () => {
    await $`brew cleanup`.quiet();
  });
  ok('Homebrew cleanup complete');
}

async function updateMise(): Promise<void> {
  if (!(await commandExists('mise'))) {
    warn('mise not installed, skipping');
    return;
  }

  await spinner('Updating mise...', async () => {
    await $`mise self-update -y`.quiet().catch(() => {});
    await $`mise upgrade`.quiet().catch(() => {});
  });
  ok('mise updated');
}

async function updateNpm(): Promise<void> {
  if (!(await commandExists('npm'))) {
    warn('npm not installed, skipping');
    return;
  }

  await spinner('Updating npm packages...', async () => {
    await $`npm update --prefix ${SETUP_DIR}`.quiet();
  });
  ok('npm packages updated');
}

async function updateGitRepo(): Promise<void> {
  await spinner('Pulling latest changes...', async () => {
    await $`git -C ${SETUP_DIR} pull --rebase`.quiet().catch(() => {});
  });
  ok('Repository updated');
}

async function regenerateConfigs(): Promise<void> {
  await spinner('Regenerating AeroSpace config...', async () => {
    const script = `${SETUP_DIR}/src/generate-aerospace-config.ts`;
    try {
      await $`${ZX_BIN} ${script}`.quiet();
    } catch {
      // Script might not exist yet
    }
  });

  await spinner('Regenerating Raycast commands...', async () => {
    const script = `${SETUP_DIR}/raycast/generate-sakurajima-commands.sh`;
    try {
      await $`bash ${script}`.quiet();
    } catch {
      // Script might not exist yet
    }
  });
}

async function main(): Promise<void> {
  console.log(bold('🔄 SAKURAJIMA SYSTEM UPDATE'));
  console.log('━'.repeat(40));
  console.log();

  info('Updating git repository...');
  await updateGitRepo();
  console.log();

  info('Updating Homebrew...');
  await updateHomebrew();
  console.log();

  info('Updating mise...');
  await updateMise();
  console.log();

  info('Updating npm packages...');
  await updateNpm();
  console.log();

  info('Regenerating configs...');
  await regenerateConfigs();
  console.log();

  console.log('━'.repeat(40));
  console.log(chalk.green(bold('✅ System update complete!')));
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
