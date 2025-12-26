#!/usr/bin/env zx
/**
 * Sakurajima Common Library
 * Shared utilities for all scripts
 */

import { $, chalk, fs, path, os, within, spinner } from 'zx';

// Configure zx defaults
$.verbose = false;

// ============================================================================
// ANSI Colors & Output Helpers
// ============================================================================

export const ok = (msg: string): void => {
  console.log(`${chalk.green('✓')} ${msg}`);
};

export const info = (msg: string): void => {
  console.log(`${chalk.bold('→')} ${msg}`);
};

export const warn = (msg: string): void => {
  console.error(`${chalk.yellow('⚠')} ${msg}`);
};

export const error = (msg: string): void => {
  console.error(`${chalk.red('✗')} ${msg}`);
};

export const die = (msg: string, code = 1): never => {
  error(msg);
  process.exit(code);
};

export const bold = (msg: string): string => chalk.bold(msg);

// ============================================================================
// Path Constants
// ============================================================================

export const HOME = os.homedir();
export const SETUP_DIR = path.join(HOME, 'setup');
export const WORKSPACE_DIR = path.join(HOME, 'workspace');
export const CLIENTS_DIR = path.join(WORKSPACE_DIR, 'clients');
export const CONFIG_DIR = path.join(HOME, '.config');
export const SAKURAJIMA_CONFIG = path.join(CONFIG_DIR, 'sakurajima');
export const SSH_DIR = path.join(HOME, '.ssh');
export const SSH_KEYS_DIR = path.join(SSH_DIR, 'keys');
export const LOCAL_BIN = path.join(HOME, '.local', 'bin');
export const SAKURAJIMA_DATA = path.join(HOME, '.local', 'share', 'sakurajima');

// Time tracking paths
export const TIME_DB = path.join(SAKURAJIMA_CONFIG, 'time-tracking.db');
export const STATE_FILE = path.join(SAKURAJIMA_CONFIG, 'active-session.state');

// ============================================================================
// Validation Functions
// ============================================================================

/**
 * Validate client name (kebab-case only)
 * Prevents path traversal and SQL injection through strict validation
 */
export const validateClientName = (name: string): boolean => {
  return /^[a-z0-9]+(-[a-z0-9]+)*$/.test(name);
};

/**
 * Validate numeric value (for session IDs, timestamps, etc.)
 */
export const validateNumeric = (value: string | number): boolean => {
  return /^\d+$/.test(String(value));
};

/**
 * SQL escape for sqlite3 (escapes single quotes by doubling them)
 */
export const sqlEscape = (value: string): string => {
  return value.replace(/'/g, "''");
};

// ============================================================================
// File System Helpers
// ============================================================================

/**
 * Ensure directory exists
 */
export const ensureDir = async (...dirs: string[]): Promise<void> => {
  for (const dir of dirs) {
    await fs.ensureDir(dir);
  }
};

/**
 * Check if file exists
 */
export const fileExists = async (filepath: string): Promise<boolean> => {
  try {
    await fs.access(filepath);
    return true;
  } catch {
    return false;
  }
};

/**
 * Check if directory exists
 */
export const dirExists = async (dirpath: string): Promise<boolean> => {
  try {
    const stat = await fs.stat(dirpath);
    return stat.isDirectory();
  } catch {
    return false;
  }
};

/**
 * Require file exists or die
 */
export const requireFile = async (filepath: string): Promise<void> => {
  if (!(await fileExists(filepath))) {
    die(`Required file not found: ${filepath}`);
  }
};

/**
 * Require directory exists or die
 */
export const requireDir = async (dirpath: string): Promise<void> => {
  if (!(await dirExists(dirpath))) {
    die(`Required directory not found: ${dirpath}`);
  }
};

/**
 * Create symlink safely (won't overwrite existing files)
 */
export const ensureSymlink = async (
  target: string,
  link: string
): Promise<boolean> => {
  try {
    const linkStat = await fs.lstat(link).catch(() => null);

    if (linkStat?.isSymbolicLink()) {
      const currentTarget = await fs.readlink(link);
      if (currentTarget === target) {
        return true; // Already correct
      }
      warn(`Symlink exists but points to wrong target: ${link} -> ${currentTarget}`);
      return false;
    }

    if (linkStat) {
      warn(`File exists and is not a symlink: ${link}`);
      return false;
    }

    await fs.symlink(target, link);
    ok(`Created symlink: ${link} -> ${target}`);
    return true;
  } catch (err) {
    error(`Failed to create symlink: ${link} -> ${target}`);
    return false;
  }
};

/**
 * Strict symlink creation (dies if target exists incorrectly)
 */
export const ensureSymlinkStrict = async (
  target: string,
  link: string
): Promise<void> => {
  const result = await ensureSymlink(target, link);
  if (!result) {
    const linkStat = await fs.lstat(link).catch(() => null);
    if (linkStat?.isSymbolicLink()) {
      die(`Symlink exists but points to wrong target: ${link}`);
    } else if (linkStat) {
      die(`File exists and is not a symlink: ${link}`);
    }
  }
};

// ============================================================================
// Command Helpers
// ============================================================================

/**
 * Check if command exists
 */
export const commandExists = async (cmd: string): Promise<boolean> => {
  try {
    await $`which ${cmd}`.quiet();
    return true;
  } catch {
    return false;
  }
};

/**
 * Require command exists or die
 */
export const requireCmd = async (cmd: string): Promise<void> => {
  if (!(await commandExists(cmd))) {
    die(`Required command not found: ${cmd}`);
  }
};

// ============================================================================
// SQLite Helpers
// ============================================================================

/**
 * Execute SQLite query safely
 */
export const sqlite = async (
  db: string,
  query: string
): Promise<string> => {
  const result = await $`sqlite3 ${db} ${query}`.quiet();
  return result.stdout.trim();
};

/**
 * Execute SQLite query and return rows
 */
export const sqliteRows = async (
  db: string,
  query: string,
  separator = '|'
): Promise<string[][]> => {
  const result = await $`sqlite3 -separator ${separator} ${db} ${query}`.quiet();
  const output = result.stdout.trim();
  if (!output) return [];
  return output.split('\n').map(row => row.split(separator));
};

// ============================================================================
// Process Helpers
// ============================================================================

/**
 * Check if a process is running by PID
 */
export const isProcessRunning = async (pid: number): Promise<boolean> => {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
};

/**
 * Kill a process safely
 */
export const killProcess = async (
  pid: number,
  signal: NodeJS.Signals = 'SIGTERM'
): Promise<boolean> => {
  try {
    process.kill(pid, signal);
    return true;
  } catch {
    return false;
  }
};

// ============================================================================
// macOS Helpers
// ============================================================================

/**
 * Get active application name (macOS only)
 */
export const getActiveApp = async (): Promise<string> => {
  try {
    const result = await $`osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true'`.quiet();
    return result.stdout.trim();
  } catch {
    return 'Unknown';
  }
};

/**
 * Get active application bundle ID (macOS only)
 */
export const getActiveAppBundle = async (): Promise<string> => {
  try {
    const result = await $`osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true'`.quiet();
    return result.stdout.trim();
  } catch {
    return '';
  }
};

/**
 * Get macOS version
 */
export const getMacOSVersion = async (): Promise<string> => {
  try {
    const result = await $`sw_vers -productVersion`.quiet();
    return result.stdout.trim();
  } catch {
    return 'unknown';
  }
};

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Format duration in seconds to "Xh Ym" format
 */
export const formatDuration = (seconds: number): string => {
  const hours = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  return `${hours}h ${mins}m`;
};

/**
 * Get current Unix timestamp
 */
export const now = (): number => Math.floor(Date.now() / 1000);

/**
 * Sleep for milliseconds
 */
export const sleep = (ms: number): Promise<void> =>
  new Promise(resolve => setTimeout(resolve, ms));

/**
 * Run with spinner
 */
export { spinner, within };

// ============================================================================
// State File Helpers
// ============================================================================

export interface SessionState {
  CLIENT: string;
  SESSION_ID: number;
  PID: number;
  TRACKER_PID: number;
}

/**
 * Read session state file
 */
export const readSessionState = async (): Promise<SessionState | null> => {
  try {
    if (!(await fileExists(STATE_FILE))) {
      return null;
    }
    const content = await fs.readFile(STATE_FILE, 'utf-8');
    const state: Partial<SessionState> = {};

    for (const line of content.split('\n')) {
      const match = line.match(/^(\w+)='?([^']*)'?$/);
      if (match) {
        const [, key, value] = match;
        if (key === 'CLIENT') state.CLIENT = value;
        if (key === 'SESSION_ID') state.SESSION_ID = parseInt(value, 10);
        if (key === 'PID') state.PID = parseInt(value, 10);
        if (key === 'TRACKER_PID') state.TRACKER_PID = parseInt(value, 10);
      }
    }

    if (state.CLIENT && state.SESSION_ID && state.TRACKER_PID) {
      return state as SessionState;
    }
    return null;
  } catch {
    return null;
  }
};

/**
 * Write session state file
 */
export const writeSessionState = async (state: SessionState): Promise<void> => {
  await ensureDir(SAKURAJIMA_CONFIG);
  const content = `CLIENT='${state.CLIENT}'
SESSION_ID=${state.SESSION_ID}
PID=${state.PID}
TRACKER_PID=${state.TRACKER_PID}
`;
  await fs.writeFile(STATE_FILE, content);
};

/**
 * Remove session state file
 */
export const removeSessionState = async (): Promise<void> => {
  try {
    await fs.remove(STATE_FILE);
  } catch {
    // Ignore if doesn't exist
  }
};
