#!/usr/bin/env zx
/**
 * Initialize the Sakurajima time tracking database
 * This script is idempotent - safe to run multiple times
 */

import { $, fs } from 'zx';
import {
  ok,
  info,
  ensureDir,
  fileExists,
  SAKURAJIMA_CONFIG,
  TIME_DB,
} from '../lib/common.ts';

const SCHEMA = `
-- Sessions: One record per focus session
CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client TEXT NOT NULL,
    start_time INTEGER NOT NULL,
    end_time INTEGER,
    duration INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_sessions_client ON sessions(client);
CREATE INDEX idx_sessions_start_time ON sessions(start_time);
CREATE INDEX idx_sessions_active ON sessions(end_time) WHERE end_time IS NULL;

-- Applications: Deduplicated app names
CREATE TABLE applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    bundle_id TEXT
);

-- Application usage per session
CREATE TABLE app_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL,
    application_id INTEGER NOT NULL,
    total_seconds INTEGER NOT NULL DEFAULT 0,
    last_seen INTEGER,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
    FOREIGN KEY (application_id) REFERENCES applications(id),
    UNIQUE(session_id, application_id)
);

CREATE INDEX idx_app_usage_session ON app_usage(session_id);

-- Client metadata
CREATE TABLE clients (
    name TEXT PRIMARY KEY,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
`;

async function main(): Promise<void> {
  // Create config directory
  await ensureDir(SAKURAJIMA_CONFIG);

  // Check if database already exists
  if (await fileExists(TIME_DB)) {
    ok(`Database already exists: ${TIME_DB}`);
    return;
  }

  info('Initializing time tracking database...');

  // Create database with schema
  await $`sqlite3 ${TIME_DB} ${SCHEMA}`;

  ok(`Time tracking database initialized: ${TIME_DB}`);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
