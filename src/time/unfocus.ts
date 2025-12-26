#!/usr/bin/env zx
/**
 * Stop the current time tracking session
 */

import { fs } from 'zx';
import {
  ok,
  warn,
  die,
  validateNumeric,
  sqlite,
  fileExists,
  isProcessRunning,
  killProcess,
  readSessionState,
  removeSessionState,
  formatDuration,
  now,
  sleep,
  TIME_DB,
} from '../lib/common.ts';

async function main(): Promise<void> {
  // Check if there's an active session
  const state = await readSessionState();
  if (!state) {
    console.log('ℹ️  No active session');
    process.exit(0);
  }

  // Verify database exists
  if (!(await fileExists(TIME_DB))) {
    warn('Database not found, removing state file');
    await removeSessionState();
    process.exit(1);
  }

  const { CLIENT, SESSION_ID, TRACKER_PID } = state;

  // Validate session ID
  if (!validateNumeric(SESSION_ID)) {
    warn('Invalid session ID in state file');
    await removeSessionState();
    process.exit(1);
  }

  // Stop tracker process
  if (TRACKER_PID && (await isProcessRunning(TRACKER_PID))) {
    await killProcess(TRACKER_PID, 'SIGTERM');
    await sleep(500);

    // Force kill if still alive
    if (await isProcessRunning(TRACKER_PID)) {
      await killProcess(TRACKER_PID, 'SIGKILL');
    }
  }

  // Update session end time and duration
  const timestamp = now();
  try {
    await sqlite(
      TIME_DB,
      `UPDATE sessions SET end_time = ${timestamp}, duration = ${timestamp} - start_time WHERE id = ${SESSION_ID};`
    );

    // Get session duration for display
    const durationStr = await sqlite(
      TIME_DB,
      `SELECT COALESCE(duration, 0) FROM sessions WHERE id = ${SESSION_ID};`
    );
    const duration = parseInt(durationStr, 10) || 0;

    await removeSessionState();
    ok(`Stopped tracking: ${CLIENT} (${formatDuration(duration)})`);
  } catch (err) {
    warn('Failed to update session in database');
    await removeSessionState();
    process.exit(1);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
