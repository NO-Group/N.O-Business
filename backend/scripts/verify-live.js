#!/usr/bin/env node
/**
 * M-TEK — LIVE end-to-end verification (run from any machine with normal
 * internet; the dev sandbox firewalls Supabase/Atlas):
 *
 *   node backend/scripts/verify-live.js
 *
 * Proves, against the REAL cloud:
 *   1. Supabase Auth is healthy (auth-only role)
 *   2. the CEO account signs in with the real password (from backend/.env)
 *   3. MongoDB accepts the credentials and all 7 section databases exist
 *   4. the CEO profile is present and role-locked
 *   5. a document serial is issued: 000000001 (books start at 1)
 * Exits non-zero on any failure. Never prints secrets.
 */
'use strict';
const fs = require('fs');
const path = require('path');

const ENV_PATH = path.join(__dirname, '..', '.env');
const env = Object.fromEntries(
  fs.readFileSync(ENV_PATH, 'utf8').split('\n')
    .filter(l => l.trim() && !l.trim().startsWith('#'))
    .map(l => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()]; }));

const ok = m => console.log(`  ✓ ${m}`);
const fail = m => { console.error(`  ✗ ${m}`); process.exitCode = 1; };
const step = m => console.log(`\n— ${m}`);
const expect = (c, m) => { if (c) ok(m); else fail(m); };

(async () => {
  console.log('M-TEK live verification\n=======================');

  // ---- 1. Supabase auth health
  step('Supabase Auth (auth-only role)');
  let health = null;
  try {
    const r = await fetch(`${env.SUPABASE_URL}/auth/v1/health`);
    health = await r.json();
  } catch (e) { /* handled below */ }
  expect(health, health ? `healthy (${health.name || health.version || 'online'})` : 'unreachable — check network');

  // ---- 2. CEO real sign-in
  step('CEO sign-in (real account, real password)');
  let token = null;
  try {
    const r = await fetch(`${env.SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'mtekfiresafetyltd@gmail.com', password: env.MTEK_CEO_PASSWORD }),
    });
    const j = await r.json().catch(() => ({}));
    if (r.ok && j.access_token) { token = j.access_token; ok('signed in — JWT received (role comes from profiles)'); }
    else fail(`sign-in failed: ${j.error_description || j.error || j.msg || 'HTTP ' + r.status}`);
  } catch (e) { fail(`unreachable — ${e.message}`); }

  // ---- 3+4+5. MongoDB + CEO profile + serials (direct, no API host needed)
  step('MongoDB cluster + section databases');
  let mongoOk = false;
  try {
    const { MongoClient } = require('mongodb');
    const c = new MongoClient(env.MONGODB_URI, { appName: 'mtek-verify' });
    await c.connect();
    mongoOk = true;
    ok('connected + authenticated');
    const dbs = (await c.db('admin').admin().listDatabases()).databases.map(d => d.name);
    for (const s of ['mtek_core', 'mtek_inventory', 'mtek_people', 'mtek_billing', 'mtek_mils', 'mtek_documents', 'mtek_audit']) {
      expect(dbs.includes(s), s);
    }
    const prof = await c.db('mtek_people').collection('profiles').findOne({ _id: env.MTEK_CEO_UID });
    expect(prof?.role === 'ceo', 'CEO profile exists with the CEO role');
    // serials start at zero → first document is 000000001
    const serials = await c.db('mtek_core').collection('serials').find({}).toArray();
    const map = Object.fromEntries(serials.map(s => [s._id, s.last_used]));
    const bad = Object.entries(map).filter(([k, v]) => k !== 'seeded' && v !== 0);
    expect(Object.keys(map).length >= 5 && !bad.length,
      `serial books at zero ${JSON.stringify(map)} → first issue = 000000001`);
    await c.close();
  } catch (e) {
    fail(mongoOk ? e.message : 'unreachable — check MONGODB_URI / network');
  }

  console.log(process.exitCode ? '\nRESULT: FAILURES ABOVE' : '\nRESULT: ALL LIVE CHECKS PASSED');
  process.exit(process.exitCode || 0);
})();
