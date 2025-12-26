#!/usr/bin/env zx
/**
 * Display time tracking statistics
 */

import { argv, chalk } from 'zx';
import {
  die,
  info,
  validateClientName,
  sqlEscape,
  sqliteRows,
  fileExists,
  formatDuration,
  TIME_DB,
} from '../lib/common.ts';

function formatDate(timestamp: number): string {
  try {
    return new Date(timestamp * 1000).toISOString().replace('T', ' ').slice(0, 16);
  } catch {
    return 'N/A';
  }
}

async function main(): Promise<void> {
  const clientArg = argv._[0] as string | undefined;

  // Check if database exists
  if (!(await fileExists(TIME_DB))) {
    info('No time tracking data');
    process.exit(0);
  }

  // Validate client name if provided
  if (clientArg && !validateClientName(clientArg)) {
    die(`Invalid client name: ${clientArg}`);
  }

  console.log(chalk.bold('📊 SAKURAJIMA TIME TRACKING STATISTICS'));
  console.log('━'.repeat(60));
  console.log();

  // Per-client summary
  let query: string;
  if (clientArg) {
    const escaped = sqlEscape(clientArg);
    query = `SELECT client, COUNT(*) as sessions, COALESCE(SUM(duration), 0) as total_seconds, CAST(COALESCE(AVG(duration), 0) AS INTEGER) as avg_seconds, MAX(start_time) as last_focused FROM sessions WHERE client = '${escaped}' GROUP BY client ORDER BY total_seconds DESC;`;
  } else {
    query = `SELECT client, COUNT(*) as sessions, COALESCE(SUM(duration), 0) as total_seconds, CAST(COALESCE(AVG(duration), 0) AS INTEGER) as avg_seconds, MAX(start_time) as last_focused FROM sessions GROUP BY client ORDER BY total_seconds DESC;`;
  }

  const rows = await sqliteRows(TIME_DB, query);

  if (rows.length === 0) {
    info('No sessions recorded yet');
    process.exit(0);
  }

  // Print header
  console.log(
    chalk.bold(
      `${'CLIENT'.padEnd(15)} ${'SESSIONS'.padStart(10)} ${'TOTAL TIME'.padStart(15)} ${'AVG SESSION'.padStart(15)} ${'LAST FOCUSED'.padStart(20)}`
    )
  );
  console.log('─'.repeat(80));

  // Print rows
  for (const [client, sessions, totalSeconds, avgSeconds, lastFocused] of rows) {
    const total = parseInt(totalSeconds, 10);
    const avg = parseInt(avgSeconds, 10);
    const last = parseInt(lastFocused, 10);

    console.log(
      `${client.padEnd(15)} ${sessions.padStart(10)} ${formatDuration(total).padStart(15)} ${formatDuration(avg).padStart(15)} ${formatDate(last).padStart(20)}`
    );
  }

  // Application usage breakdown (only if specific client requested)
  if (clientArg) {
    console.log();
    console.log(chalk.bold(`📱 APPLICATION USAGE: ${clientArg}`));
    console.log('─'.repeat(80));

    const escaped = sqlEscape(clientArg);
    const appQuery = `SELECT a.name, SUM(au.total_seconds) as total_seconds FROM app_usage au JOIN applications a ON au.application_id = a.id JOIN sessions s ON au.session_id = s.id WHERE s.client = '${escaped}' GROUP BY a.name ORDER BY total_seconds DESC LIMIT 10;`;

    const appRows = await sqliteRows(TIME_DB, appQuery);

    if (appRows.length > 0) {
      console.log(
        chalk.bold(`${'APPLICATION'.padEnd(50)} ${'TIME'.padStart(15)}`)
      );
      console.log('─'.repeat(70));

      for (const [appName, seconds] of appRows) {
        const sec = parseInt(seconds, 10);
        console.log(`${appName.padEnd(50)} ${formatDuration(sec).padStart(15)}`);
      }
    } else {
      info(`No application usage data for ${clientArg}`);
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
