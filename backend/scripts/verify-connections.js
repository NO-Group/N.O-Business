#!/usr/bin/env node
/**
 * M-Tek app — backend connection verifier (ops tooling, not app code).
 *
 * Run from a machine with normal internet access (NOT needed in CI yet):
 *   cd backend && npm install mongodb && node scripts/verify-connections.js
 *
 * Reads credentials from backend/.env (gitignored). Never prints secrets.
 */
const fs = require('fs');
const path = require('path');

const ENV_PATH = path.join(__dirname, '..', '.env');
if (!fs.existsSync(ENV_PATH)) {
  console.error('✗ backend/.env not found. Copy .env.example to .env and fill it in.');
  process.exit(1);
}
const env = Object.fromEntries(
  fs.readFileSync(ENV_PATH, 'utf8')
    .split('\n').filter(l => l.trim() && !l.trim().startsWith('#'))
    .map(l => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()]; })
);

const ok = (name, msg) => console.log(`✓ ${name}: ${msg}`);
const fail = (name, msg) => { console.error(`✗ ${name}: ${msg}`); process.exitCode = 1; };

async function checkSupabase() {
  const base = env.SUPABASE_URL;
  if (!base) return fail('Supabase', 'SUPABASE_URL missing in .env');
  try {
    const health = await fetch(`${base}/auth/v1/health`).then(r => r.json());
    ok('Supabase', `auth healthy (${health.name || health.version || 'online'})`);
  } catch (e) { return fail('Supabase', `unreachable — ${e.message}`); }
  try {
    const res = await fetch(`${base}/rest/v1/`, {
      headers: { apikey: env.SUPABASE_PUBLISHABLE_KEY, Authorization: `Bearer ${env.SUPABASE_PUBLISHABLE_KEY}` },
    });
    if (res.ok) ok('Supabase publishable key', `accepted by REST (HTTP ${res.status})`);
    else fail('Supabase publishable key', `HTTP ${res.status}`);
  } catch (e) { fail('Supabase publishable key', e.message); }
  try {
    // Server-side operation — proves the secret key without exposing anything.
    const res = await fetch(`${base}/auth/v1/admin/users?page=1&per_page=1`, {
      headers: { Authorization: `Bearer ${env.SUPABASE_SECRET_KEY}`, apikey: env.SUPABASE_SECRET_KEY },
    });
    if (res.ok) ok('Supabase secret key', `admin API OK (HTTP ${res.status})`);
    else fail('Supabase secret key', `HTTP ${res.status} — check/recreate the key`);
  } catch (e) { fail('Supabase secret key', e.message); }
}

async function checkMongo() {
  if (!env.MONGODB_URI) return fail('MongoDB', 'MONGODB_URI missing in .env');
  let MongoClient;
  try { ({ MongoClient } = require('mongodb')); }
  catch { return fail('MongoDB', 'driver not installed — run: npm install mongodb'); }
  const client = new MongoClient(env.MONGODB_URI, {
    serverSelectionTimeoutMS: 15000,
  });
  try {
    await client.connect();
    await client.db('admin').command({ ping: 1 });
    const dbs = await client.db().admin().listDatabases();
    ok('MongoDB', `ping OK — cluster reachable, databases: ${dbs.databases.map(d => d.name).join(', ') || '(none yet)'}`);
  } catch (e) { fail('MongoDB', `${e.name || 'Error'} — ${e.message}`); }
  finally { await client.close().catch(() => {}); }
}

(async () => {
  console.log('Verifying backend connections (credentials stay hidden)…\n');
  await checkSupabase();
  await checkMongo();
  console.log(process.exitCode ? '\nOne or more checks failed.' : '\nAll backend connections verified.');
})();
