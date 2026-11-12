#!/usr/bin/env node
/**
 * M-TEK — Supabase-only live backend check. No npm dependencies, no MongoDB.
 *
 *   cd backend && npm run verify
 *   SUPABASE_URL=https://<ref>.supabase.co npm run verify
 *
 * Confirms the deployed data-api bundle is the Postgres build, that EVERY
 * bootstrap collection can be read, that the authoritative server serial
 * allocator works, and that the Supabase Auth/JWT gate is still in place.
 * This replaces the old seed-mongo.js / verify-connections.js /
 * verify-live.js scripts, which targeted the retired Atlas cluster.
 */

const BASE = (process.env.SUPABASE_URL || 'https://kshuadjcflwlidupnqly.supabase.co')
  .replace(/\/+$/, '');
const API = `${BASE}/functions/v1/data-api`;

const hasAppVersion = (b) => b && typeof b.app_version === 'string' &&
  b.app_version.length > 0 && Number.isInteger(b.app_build) && b.app_build > 0;

const checks = [
  {
    name: 'shallow health / bundle',
    path: '/health',
    ok: (b) => b && b.ok === true && b.storage === 'supabase-postgres' && hasAppVersion(b),
    why: 'ok:true, storage:supabase-postgres and the published app version marker',
  },
  {
    name: 'serial books + allocator',
    path: '/health?deep=1',
    ok: (b) => b && b.ok === true && b.serial_rpc === 'ok' &&
      b.storage_roundtrip === 'ok' &&
      b.serials && typeof b.serials === 'object' && Object.keys(b.serials).length > 0 &&
      hasAppVersion(b),
    why: 'deep DB read, server serials and a real Postgres CRUD round-trip',
  },
  {
    name: 'full bootstrap reads',
    path: '/health?deep=1&full=1',
    ok: (b) => b && b.ok === true && Number.isFinite(b.bootstrap_bytes) &&
      b.storage_roundtrip === 'ok' && hasAppVersion(b),
    why: 'all nine bootstrap collections readable from Supabase Postgres',
  },
  {
    name: 'Auth / JWT gate',
    path: '/api/bootstrap',
    ok: (b) => b && b.error === 'Missing bearer token',
    why: 'unauthenticated requests are rejected by Supabase Auth',
  },
];

async function main() {
  let failed = 0;
  for (const c of checks) {
    try {
      const r = await fetch(`${API}${c.path}`, {
        headers: { 'User-Agent': 'mtek-verify-supabase' },
      });
      const text = await r.text();
      let body;
      try { body = JSON.parse(text); } catch { body = null; }
      const pass = r.ok && c.ok(body);
      if (!pass) failed++;
      console.log(`${pass ? 'OK  ' : 'FAIL'} ${c.name.padEnd(26)} HTTP ${r.status}  ${text.slice(0, 220)}`);
      if (!pass) console.log(`     expected: ${c.why}`);
    } catch (e) {
      failed++;
      console.log(`FAIL ${c.name.padEnd(26)} ${e.message}`);
    }
  }
  console.log(`\n${failed ? failed + ' check(s) FAILED' : 'All Supabase backend checks passed'}`);
  process.exitCode = failed ? 1 : 0;
}

main();
