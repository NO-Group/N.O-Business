#!/usr/bin/env node
/**
 * M-TEK — seed MongoDB (run once from any machine with normal internet):
 *   cd backend && npm install
 *   node scripts/seed-mongo.js
 *
 * Creates the seven section databases, zeroes the serial books (000000001
 * series), writes settings and the CEO profile.
 *
 * STOCK IS DELIBERATELY NOT SEEDED (owner directive 2026-08-30): the
 * products collection stays EMPTY and is filled through the apps' own
 * fields (Add product / Import TXT).
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { MongoClient } = require('mongodb');

const ENV_PATH = path.join(__dirname, '..', '.env');
const env = Object.fromEntries(
  fs.readFileSync(ENV_PATH, 'utf8').split('\n')
    .filter(l => l.trim() && !l.trim().startsWith('#'))
    .map(l => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()]; }));

const CEO_UID = env.MTEK_CEO_UID;
if (!env.MONGODB_URI) { console.error('✗ MONGODB_URI missing in backend/.env'); process.exit(1); }
if (!CEO_UID) { console.error('✗ MTEK_CEO_UID missing in backend/.env'); process.exit(1); }

(async () => {
  const c = new MongoClient(env.MONGODB_URI, { appName: 'mtek-seed' });
  await c.connect();
  console.log('✓ connected to cluster');

  // core: serials all ZERO — every book starts at 000000001 (owner directive)
  const core = c.db('mtek_core');
  for (const t of ['receiptIssue', 'receipt', 'invoice', 'mils', 'waybill', 'deliverynote']) {
    await core.collection('serials').updateOne({ _id: t }, { $setOnInsert: { last_used: 0 } }, { upsert: true });
  }
  await core.collection('settings').updateOne({ _id: 'settings' },
    { $setOnInsert: { vat_enabled: false, vat_rate: 0.075, watermark: true } }, { upsert: true });
  console.log('✓ mtek_core — serials at 0 (books start 000000001), settings written');

  // people: CEO profile (role locked)
  await c.db('mtek_people').collection('profiles').updateOne({ _id: CEO_UID }, {
    $set: {
      email: 'mtekfiresafetyltd@gmail.com', full_name: 'CEO', role: 'ceo',
      updated_at: new Date().toISOString(),
    },
  }, { upsert: true });
  console.log('✓ mtek_people — CEO profile seeded (role=ceo)');

  // inventory: left EMPTY by design — products are entered in the app
  await c.db('mtek_inventory').collection('products').createIndex({ name: 1 });
  console.log('✓ mtek_inventory — empty (stock is entered in the app, never seeded)');

  // billing/mils/documents/audit: ensure indexes so the DBs exist
  await c.db('mtek_billing').collection('sales').createIndex({ created_at: -1 });
  await c.db('mtek_billing').collection('receipts').createIndex({ no: 1 }, { unique: true });
  await c.db('mtek_billing').collection('invoices').createIndex({ no: 1 }, { unique: true });
  await c.db('mtek_mils').collection('logs').createIndex({ created_at: -1 });
  await c.db('mtek_documents').collection('archive').createIndex({ issued_at: -1 });
  await c.db('mtek_audit').collection('events').createIndex({ at: -1 });
  console.log('✓ mtek_billing / mtek_mils / mtek_documents / mtek_audit ready (indexed)');

  await c.close();
  console.log('\nALL SEEDED — every document book starts from 000000001');
})().catch(e => { console.error('✗ seed failed:', e.message); process.exit(1); });
