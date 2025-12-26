#!/usr/bin/env zx
/**
 * Sakurajima AeroSpace Config Generator
 * Version: 0.2.0
 *
 * Reads base template: ~/.config/aerospace.base.toml
 * Writes generated:    ~/.config/aerospace.toml
 *
 * Injects generated client workspace bindings between markers.
 * Also refreshes simple-bar to reflect current clients.
 */

import { $, chalk, fs, path } from 'zx';
import type { Dirent } from 'fs';
import {
  ok,
  info,
  warn,
  die,
  bold,
  ensureDir,
  fileExists,
  dirExists,
  commandExists,
  HOME,
  CLIENTS_DIR,
  CONFIG_DIR,
} from './lib/common.ts';

const BASE_CONFIG = path.join(CONFIG_DIR, 'aerospace.base.toml');
const OUT_CONFIG = path.join(CONFIG_DIR, 'aerospace.toml');

const BEGIN_MARKER = '# >>> SAKURAJIMA GENERATED CLIENTS >>>';
const END_MARKER = '# <<< SAKURAJIMA GENERATED CLIENTS <<<';

// Maximum number of client workspaces (keys 1-9)
const MAX_CLIENTS = 9;

async function getClients(): Promise<string[]> {
  if (!(await dirExists(CLIENTS_DIR))) {
    return [];
  }

  const entries = await fs.readdir(CLIENTS_DIR, { withFileTypes: true });
  const clients = entries
    .filter((e: Dirent) => e.isDirectory() && !e.name.startsWith('_') && !e.name.startsWith('.'))
    .map((e: Dirent) => e.name)
    .sort();

  // Limit to MAX_CLIENTS for stable key mapping (1-9)
  return clients.slice(0, MAX_CLIENTS);
}

// Reserved alt keys (used by core bindings)
const RESERVED_KEYS = new Set(['h', 'j', 'k', 'l', 'f', 'r', 't', 'i', 'w', 'm', '1', '2', '3', '4']);

function generateBindingsBlock(clients: string[]): string {
  if (clients.length === 0) {
    return '# No client workspaces configured yet.\n# Run: skr new <client-name> to create one.';
  }

  const lines: string[] = [];
  const usedLetters = new Set<string>();

  // Header
  lines.push('# Client Workspaces (auto-generated)');
  lines.push('');

  // Generate letter-based bindings (alt-<first-letter>)
  clients.forEach((client) => {
    const letter = client[0].toLowerCase();
    if (!RESERVED_KEYS.has(letter) && !usedLetters.has(letter)) {
      usedLetters.add(letter);
      lines.push(`alt-${letter} = 'workspace ${client}'`);
      lines.push(`alt-shift-${letter} = 'move-node-to-workspace ${client}'`);
    }
  });

  if (usedLetters.size > 0) {
    lines.push('');
  }

  // Mapping reference
  lines.push('# Mapping: alt-<letter> = workspace');
  clients.forEach((client) => {
    const letter = client[0].toLowerCase();
    const mapped = !RESERVED_KEYS.has(letter) && [...usedLetters][0] !== letter || usedLetters.has(letter);
    if (!RESERVED_KEYS.has(letter)) {
      lines.push(`#   ${letter} → ${client}`);
    }
  });

  return lines.join('\n');
}

async function refreshSimpleBar(): Promise<void> {
  try {
    // Refresh simple-bar via Übersicht
    await $`osascript -e 'tell application id "tracesOf.Uebersicht" to refresh widget id "simple-bar-index-jsx"'`.quiet();
  } catch {
    // Übersicht might not be running
  }
}

async function main(): Promise<void> {
  console.log(bold('AeroSpace Config Generator'));
  console.log();

  // Check base template exists
  if (!(await fileExists(BASE_CONFIG))) {
    die(`Missing base template: ${BASE_CONFIG}`);
  }

  await ensureDir(CONFIG_DIR);

  // Get client list
  const clients = await getClients();
  info(`Found ${clients.length} client workspace(s)`);

  // Read base template
  let baseContent = await fs.readFile(BASE_CONFIG, 'utf-8');

  // Check if template has markers
  if (!baseContent.includes(BEGIN_MARKER) || !baseContent.includes(END_MARKER)) {
    warn('Base template missing markers. This should not happen.');
    die('Please restore the base template from the repository.');
  }

  // Generate bindings block
  const bindingsBlock = generateBindingsBlock(clients);

  // Replace content between markers
  const lines = baseContent.split('\n');
  const output: string[] = [];
  let inside = false;

  for (const line of lines) {
    if (line === BEGIN_MARKER) {
      output.push(line);
      output.push(bindingsBlock);
      inside = true;
      continue;
    }

    if (line === END_MARKER) {
      inside = false;
      output.push(line);
      continue;
    }

    if (!inside) {
      output.push(line);
    }
  }

  // If OUT_CONFIG is a symlink (legacy), remove it
  try {
    const stat = await fs.lstat(OUT_CONFIG);
    if (stat.isSymbolicLink()) {
      await fs.remove(OUT_CONFIG);
    }
  } catch {
    // File doesn't exist, that's fine
  }

  // Write generated config
  await fs.writeFile(OUT_CONFIG, output.join('\n'));
  ok(`Generated: ${OUT_CONFIG}`);

  // Refresh simple-bar
  await refreshSimpleBar();

  // Reload AeroSpace if running
  if (await commandExists('aerospace')) {
    try {
      await $`aerospace reload-config`.quiet();
      ok('AeroSpace config reloaded');
    } catch {
      warn('Could not reload AeroSpace (may not be running)');
    }
  }

  // Summary
  console.log();
  if (clients.length > 0) {
    const mapped = new Set<string>();
    info('Client workspaces:');
    clients.forEach((client) => {
      const letter = client[0].toLowerCase();
      if (!RESERVED_KEYS.has(letter) && !mapped.has(letter)) {
        mapped.add(letter);
        console.log(`  ⌥${letter} → ${client}`);
      } else {
        console.log(`       ${client} (no shortcut)`);
      }
    });
  } else {
    info('No client workspaces. Run: skr new <client-name>');
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
