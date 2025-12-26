#!/usr/bin/env zx
/**
 * Clean up stale time tracking sessions
 * - Detects state file with dead tracker process
 * - Closes old sessions with NULL end_time
 */

import { fs } from 'zx';
import {
  ok,
  warn,
  info,
  validateNumeric,
  sqlite,
  fileExists,
  isProcessRunning,
  readSessionState,
  removeSessionState,
  now,
  TIME_DB,
} from '../lib/common.ts';

async function main(): Promise<void> {
  // Check if database exists
  if (!(await fileExists(TIME_DB))) {
    const state = await readSessionState();
    if (state) {
      await removeSessionState();
      ok('Removed orphaned state file');
    } else {
      info('No database to clean');
    }
    return;
  }

  let cleaned = 0;

  // Clean up state file if tracker is dead
  const state = await readSessionState();
  if (state) {
    const { CLIENT, SESSION_ID, TRACKER_PID } = state;

    // Validate session ID
    if (!validateNumeric(SESSION_ID)) {
      warn('Invalid session ID in state file, removing');
      await removeSessionState();
    } else if (SESSION_ID > 0 && TRACKER_PID && !(await isProcessRunning(TRACKER_PID))) {
      console.log(`🧹 Found stale session: ${CLIENT}`);

      // Estimate end time from last app usage activity
      let endTime: number;
      try {
        const result = await sqlite(
          TIME_DB,
          `SELECT COALESCE(MAX(last_seen), start_time + 3600) FROM app_usage WHERE session_id = ${SESSION_ID};`
        );
        endTime = parseInt(result, 10) || now();
      } catch {
        endTime = now();
      }

      // Update session
      try {
        await sqlite(
          TIME_DB,
          `UPDATE sessions SET end_time = ${endTime}, duration = ${endTime} - start_time WHERE id = ${SESSION_ID};`
        );
        await removeSessionState();
        ok(`Cleaned up session ${SESSION_ID}`);
        cleaned++;
      } catch {
        warn('Failed to update session in database');
      }
    }
  }

  // Find and clean sessions with NULL end_time older than 24 hours
  const oldThreshold = now() - 86400; // 24 hours ago

  try {
    const countResult = await sqlite(
      TIME_DB,
      `SELECT COUNT(*) FROM sessions WHERE end_time IS NULL AND start_time < ${oldThreshold};`
    );
    const oldSessions = parseInt(countResult, 10) || 0;

    if (oldSessions > 0) {
      console.log(`🧹 Found ${oldSessions} old unclosed session(s)`);

      // Close them with default 8 hour duration
      await sqlite(
        TIME_DB,
        `UPDATE sessions SET end_time = start_time + 28800, duration = 28800 WHERE end_time IS NULL AND start_time < ${oldThreshold};`
      );

      ok(`Closed ${oldSessions} old session(s) (estimated 8h duration)`);
      cleaned += oldSessions;
    }
  } catch (err) {
    warn('Failed to clean old sessions');
  }

  if (cleaned === 0) {
    ok('No cleanup needed');
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
