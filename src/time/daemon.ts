#!/usr/bin/env zx
/**
 * Background daemon for tracking active application usage during a focus session
 */

import { argv, fs } from 'zx';
import {
  die,
  validateNumeric,
  sqlEscape,
  sqlite,
  fileExists,
  getActiveApp,
  getActiveAppBundle,
  now,
  sleep,
  writeSessionState,
  readSessionState,
  TIME_DB,
  SAKURAJIMA_CONFIG,
} from '../lib/common.ts';

const POLL_INTERVAL = 5000; // 5 seconds

async function updateAppUsage(
  sessionId: number,
  appName: string,
  bundleId: string,
  pollSeconds: number
): Promise<void> {
  const timestamp = now();
  const escapedApp = sqlEscape(appName);
  const escapedBundle = sqlEscape(bundleId);

  const query = `
BEGIN TRANSACTION;

-- Insert or update application with bundle_id
INSERT INTO applications (name, bundle_id) VALUES ('${escapedApp}', '${escapedBundle}')
ON CONFLICT(name) DO UPDATE SET bundle_id = COALESCE(bundle_id, '${escapedBundle}');

-- Update app_usage
INSERT INTO app_usage (session_id, application_id, total_seconds, last_seen)
SELECT ${sessionId}, id, ${pollSeconds}, ${timestamp}
FROM applications WHERE name = '${escapedApp}'
ON CONFLICT(session_id, application_id) DO UPDATE SET
    total_seconds = total_seconds + ${pollSeconds},
    last_seen = ${timestamp};

COMMIT;
`;

  try {
    await sqlite(TIME_DB, query);
  } catch {
    // Database might be locked - continue tracking
  }
}

async function main(): Promise<void> {
  const sessionIdArg = argv._[0] as string | undefined;
  const pollIntervalArg = argv._[1] as string | undefined;

  if (!sessionIdArg) {
    die('Session ID required');
  }

  // Safe to use non-null assertion: die() exits if undefined
  if (!validateNumeric(sessionIdArg!)) {
    die(`Invalid session ID: ${sessionIdArg} (must be numeric)`);
  }

  const sessionId = parseInt(sessionIdArg!, 10);
  const pollMs = pollIntervalArg ? parseInt(pollIntervalArg, 10) * 1000 : POLL_INTERVAL;
  const pollSeconds = Math.floor(pollMs / 1000);

  // Verify database exists
  if (!(await fileExists(TIME_DB))) {
    die(`Database not found: ${TIME_DB}`);
  }

  // Update state file with daemon PID
  const state = await readSessionState();
  if (state) {
    await writeSessionState({
      ...state,
      TRACKER_PID: process.pid,
    });
  }

  // Main tracking loop
  while (true) {
    const appName = await getActiveApp();
    const bundleId = await getActiveAppBundle();

    await updateAppUsage(sessionId, appName, bundleId, pollSeconds);
    await sleep(pollMs);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
