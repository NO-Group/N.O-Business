// Local verification for the Supabase-Postgres collection shim in
// supabase/functions/data-api/index.ts. Deno is not installed in every
// environment, so this harness extracts the shim block, imports it with
// Node's built-in TypeScript stripping, and drives it against a mock
// PostgREST — asserting every Mongo operator the ~50 route handlers use,
// plus pagination, quoted filter values and compare-and-swap retries.
//
// Run:  node --experimental-strip-types tools/pg_shim_test.mjs
// No npm packages required.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

// Extract exactly the storage layer from the Edge Function, inject the two
// runtime constants, and export the internals we want to exercise. Keeping
// the extraction in the test means it can never drift from production code.
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const src = fs.readFileSync(path.join(repo, 'supabase/functions/data-api/index.ts'), 'utf8');
const start = src.indexOf('/// 24-hex id');
const marker = "  notifications: () => collection('notifications'),\n};\n";
const end = src.indexOf(marker) + marker.length;
if (start < 0 || end < marker.length) throw new Error('Could not find the Postgres shim in index.ts');
const block = src.slice(start, end);
const header = "const SUPABASE_URL = 'http://pg.mock';\nconst SERVICE_ROLE = 'test-service-key';\n";
const exports = "\nexport { ObjectId, PgCollection, coll, collection, pgRequest, pgRows, pgCas, matchDoc, applyUpdate };\n";
const shimPath = path.join(os.tmpdir(), 'mtek_pg_shim.ts');
fs.writeFileSync(shimPath, header + block + exports);

const store = new Map();          // `${collection}|${id}` -> doc
const serials = new Map();        // type -> last_used
const key = (c, id) => `${c}|${id}`;

// PostgREST percent-decodes the query once, so eq.%22a%2Cb%22 arrives as
// eq."a,b" — strip the quotes and unescape embedded \" and \\.
const eq = (v) => {
  if (!v) return v;
  let x = v.startsWith('eq.') ? v.slice(3) : v;
  if (x.startsWith('"') && x.endsWith('"')) {
    x = x.slice(1, -1).replace(/\\"/g, '"').replace(/\\\\/g, '\\');
  }
  return x;
};
const canon = (v) => JSON.stringify(v);

// When set, the next CAS call simulates a concurrent writer winning the
// race before our UPDATE lands.
let raceOnce = false;
// Invariant: no user-supplied id may ever appear in a PostgREST URL filter.
let unsafeFilterCount = 0;
let upsertRaceOnce = false;

globalThis.fetch = async (url, opts = {}) => {
  const u = new URL(url);
  const empty = (status = 200) => new Response('', { status });
  if (u.pathname.endsWith('/rpc/mtek_next_serial')) {
    // Mirror the real SQL function: it upserts into mtek_docs('serials'),
    // so peekSerials()/reseed/health all see the same counter.
    const { p_type } = JSON.parse(opts.body);
    const k = key('serials', p_type);
    const prev = store.get(k);
    const n = Number(prev?.last_used ?? 0) + 1;
    store.set(k, { _id: p_type, last_used: n });
    serials.set(p_type, n);
    return new Response(JSON.stringify(n), { status: 200 });
  }
  if (u.pathname.endsWith('/rpc/mtek_doc_get')) {
    const b = JSON.parse(opts.body);
    const doc = store.get(key(b.p_collection, b.p_id));
    return new Response(doc ? JSON.stringify(doc) : 'null', { status: 200 });
  }
  if (u.pathname.endsWith('/rpc/mtek_doc_delete')) {
    const b = JSON.parse(opts.body);
    store.delete(key(b.p_collection, b.p_id));
    return new Response('', { status: 200 });
  }
  if (u.pathname.endsWith('/rpc/mtek_cas_upsert')) {
    const b = JSON.parse(opts.body);
    const k = key(b.p_collection, b.p_id);
    if (upsertRaceOnce) {
      // Another writer created the row between our read and our insert.
      upsertRaceOnce = false;
      store.set(k, { _id: b.p_id, from: 'other', v: 1 });
      return new Response('null', { status: 200 });
    }
    const cur = store.get(k);
    if (cur && canon(cur) !== canon(b.p_expected)) {
      return new Response('null', { status: 200 });
    }
    store.set(k, b.p_next);
    return new Response(JSON.stringify(b.p_next), { status: 200 });
  }
  if (u.pathname.endsWith('/rpc/mtek_cas_update')) {
    const b = JSON.parse(opts.body);
    const k = key(b.p_collection, b.p_id);
    const cur = store.get(k);
    if (raceOnce) {
      const r = raceOnce; raceOnce = null;
      // Another device committed an increment first.
      const patched = { ...cur };
      patched[r.field] = Number(cur?.[r.field] ?? 0) + r.delta;
      store.set(k, patched);
      return new Response('null', { status: 200 });
    }
    if (!cur || canon(cur) !== canon(b.p_expected)) {
      return new Response('null', { status: 200 });
    }
    store.set(k, b.p_next);
    return new Response(JSON.stringify(b.p_next), { status: 200 });
  }
  if (!u.pathname.endsWith('/mtek_docs')) throw new Error('unexpected URL ' + url);
  const collection = eq(u.searchParams.get('collection'));
  if (u.searchParams.has('id')) unsafeFilterCount++;
  const id = u.searchParams.has('id') ? eq(u.searchParams.get('id')) : null;
  if (opts.method === 'GET') {
    let rows = [...store.entries()]
      .filter(([k]) => k.startsWith(collection + '|') && (id == null || k.endsWith('|' + id)))
      .map(([, doc]) => ({ doc }));
    const total = rows.length;
    const limit = Number(u.searchParams.get('limit') ?? '0');
    const offset = Number(u.searchParams.get('offset') ?? '0');
    if (limit) rows = rows.slice(offset, offset + limit);
    // PostgREST returns Content-Range when Prefer: count=exact is used.
    return new Response(JSON.stringify(rows), {
      status: 200,
      headers: { 'Content-Range': `${offset}-${offset + rows.length - 1}/${total}` },
    });
  }
  if (opts.method === 'POST') {
    const body = JSON.parse(opts.body);
    store.set(key(body.collection, body.id), body.doc);
    return empty(201);
  }
  if (opts.method === 'DELETE') {
    store.delete(key(collection, id));
    return empty(200);
  }
  throw new Error('unexpected method ' + opts.method);
};

const {
  ObjectId, coll, pgRequest,
} = await import(pathToFileURL(shimPath).href);

let passed = 0;
const check = (label, fn) => {
  try { fn(); passed++; console.log('  PASS  ' + label); }
  catch (e) { console.error('  FAIL  ' + label + '\n        ' + e.message); process.exitCode = 1; }
};
const ok = (label, v) => check(label, () => assert.ok(v));

(async () => {
  console.log('Supabase-Postgres shim contract tests');

  // --- ids ---------------------------------------------------------------
  const oid = new ObjectId();
  ok('ObjectId generates a 24-hex server id', /^[0-9a-f]{24}$/.test(oid.toString()));
  ok('ObjectId parses an existing hex', new ObjectId('A'.repeat(24)).toString() === 'a'.repeat(24));
  ok('ObjectId rejects junk', (() => { try { new ObjectId('nope'); return false; } catch { return true; } })());

  // --- insert / findOne / find / sort / limit -----------------------------
  const products = await coll.products();
  const ins = await products.insertOne({ _id: 'p1', name: 'Zebra nozzle', qty_on_hand: 5, updated_at: '2026-01-01' });
  await products.insertOne({ _id: 'p2', name: 'abc extinguisher', qty_on_hand: 2, updated_at: '2026-01-02' });
  await products.insertOne({ _id: 'p3', name: 'Beta hose', qty_on_hand: 9, updated_at: '2026-01-03' });
  ok('insertOne echoes the chosen _id', ins.insertedId === 'p1');
  const auto = await products.insertOne({ name: 'auto id' });
  ok('insertOne generates a server-shaped _id', /^[0-9a-f]{24}$/.test(auto.insertedId));
  ok('findOne({_id}) finds it', (await products.findOne({ _id: 'p1' }))?.name === 'Zebra nozzle');
  ok('findOne(ObjectId) matches a hex id',
    (await products.findOne({ _id: new ObjectId(auto.insertedId) }))?.name === 'auto id');
  const sorted = await products.find({}).sort({ name: 1 }).limit(3).toArray();
  // Mongo's default binary collation sorts uppercase before lowercase (B<Z<a).
  ok('sort ascending + limit', sorted.length === 3 && sorted[0].name === 'Beta hose'
    && sorted[1].name === 'Zebra nozzle' && sorted[2].name === 'abc extinguisher');
  const desc = await products.find({}).sort({ updated_at: -1 }).limit(1).toArray();
  ok('sort descending', desc[0].updated_at === '2026-01-03');
  ok('find({}).toArray() returns every row', (await products.find({}).toArray()).length === 4);

  // --- numeric strings must sort numerically, not lexicographically -------
  const nums = await coll.adjustments();
  await nums.insertOne({ _id: 'n1', n: '9' });
  await nums.insertOne({ _id: 'n2', n: '10' });
  const numSorted = await nums.find({}).sort({ n: 1 }).toArray();
  ok('numeric strings sort 9 before 10', numSorted[0].n === '9' && numSorted[1].n === '10');
  await nums.deleteMany({});

  // --- ids with PostgREST-reserved characters -----------------------------
  const tricky = 'dev:c:F,001.a("q")\\z';
  const weird = await coll.customers();
  await weird.insertOne({ _id: tricky, name: 'Reserved chars' });
  ok('hostile id survives a targeted lookup via JSON-body RPC',
    (await weird.findOne({ _id: tricky }))?.name === 'Reserved chars');
  ok('and survives updateOne + deleteOne',
    (await weird.updateOne({ _id: tricky }, { $set: { name: 'Renamed' } })).modifiedCount === 1
    && (await weird.findOne({ _id: tricky }))?.name === 'Renamed'
    && (await weird.deleteOne({ _id: tricky })).deletedCount === 1);

  // --- pagination past PostgREST's db-max-rows ---------------------------
  const big = await coll.audit();
  for (let i = 0; i < 1203; i++) await big.insertOne({ _id: 'e' + i, at: String(i) });
  ok('find({}) pages past the 1000-row PostgREST cap',
    (await big.find({}).toArray()).length === 1203);
  ok('find({}).limit(5000) is not silently truncated',
    (await big.find({}).limit(5000).toArray()).length === 1203);
  ok('updateMany reaches every page',
    (await big.updateMany({}, { $set: { seen: true } })).matchedCount === 1203);
  await big.deleteMany({});

  // --- $regex / $options / $ne / $lt / $gte / $exists ---------------------
  const rx = await products.find({
    name: { $regex: '^ABC EXTINGUISHER$', $options: 'i' },
  }).limit(20).toArray();
  ok('$regex + case-insensitive $options', rx.length === 1 && rx[0]._id === 'p2');
  ok('_id $ne', (await products.find({ _id: { $ne: 'p1' } }).toArray()).length === 3);
  ok('$gte on a number', (await products.find({ qty_on_hand: { $gte: 5 } }).toArray()).length === 2);
  // Mongo's $lt does not match documents missing the field; 'auto id' has no
  // updated_at, so only p1 (01-01) and p2 (01-02) are before 01-03.
  ok('$lt on a date string (history pagination)',
    (await products.find({ updated_at: { $lt: '2026-01-03' } }).toArray()).length === 2);
  ok('$exists:false hides soft-deleted rows',
    (await products.find({ deleted_at: { $exists: false } }).toArray()).length === 4);
  await products.updateOne({ _id: 'p3' }, { $set: { deleted_at: '2026-02-01' } });
  ok('$exists:false after a soft delete',
    (await products.find({ deleted_at: { $exists: false } }).toArray()).length === 3);

  // --- $inc / $set / matchedCount / modifiedCount -------------------------
  const inc = await products.updateOne({ _id: 'p1' }, { $inc: { qty_on_hand: 3 }, $set: { updated_at: 'x' } });
  ok('$inc and $set together', (await products.findOne({ _id: 'p1' })).qty_on_hand === 8
    && (await products.findOne({ _id: 'p1' })).updated_at === 'x');
  ok('updateOne reports matchedCount/modifiedCount', inc.matchedCount === 1 && inc.modifiedCount === 1);
  ok('updateOne on a miss reports 0', (await products.updateOne({ _id: 'ghost' }, { $set: { a: 1 } })).matchedCount === 0);
  // CAS: a concurrent writer wins once; the shim must re-read and retry so
  // neither increment is lost (1 -> 2 by the other writer -> 3 by us).
  raceOnce = { field: 'qty_on_hand', delta: 1 };
  await products.updateOne({ _id: 'p1' }, { $inc: { qty_on_hand: 1 } });
  ok('compare-and-swap retry prevents a lost concurrent $inc',
    (await products.findOne({ _id: 'p1' })).qty_on_hand === 10);

  // --- $expr with $add/$gte and with $lte field comparison ----------------
  const stockGuard = await products.updateOne(
    { _id: 'p2', $expr: { $gte: [{ $add: ['$qty_on_hand', -2] }, 0] } },
    { $inc: { qty_on_hand: -2 } });
  ok('$expr $add/$gte guard allows a valid adjustment', stockGuard.matchedCount === 1);
  const stockGuard2 = await products.updateOne(
    { _id: 'p2', $expr: { $gte: [{ $add: ['$qty_on_hand', -99] }, 0] } },
    { $inc: { qty_on_hand: -99 } });
  ok('$expr guard blocks a negative-stock adjustment', stockGuard2.matchedCount === 0);
  const invoices = await coll.invoices();
  await invoices.insertOne({ _id: 'i1', no: 'INV-1', total: 100, amount_paid: 40 });
  const payGuard = await invoices.updateOne(
    { no: 'INV-1', $expr: { $lte: ['$amount_paid', '$total'] } },
    { $inc: { amount_paid: 10 } });
  ok('$expr $lte field-vs-field comparison', payGuard.modifiedCount === 1);
  ok('$lte payment raced guard still updates the balance',
    (await invoices.findOne({ _id: 'i1' })).amount_paid === 50);

  // --- upsert / $setOnInsert / $max ---------------------------------------
  const settings = await coll.settings();
  await settings.updateOne({ _id: 'settings' }, { $setOnInsert: { vat_enabled: false, vat_rate: 0.075 } }, { upsert: true });
  ok('upsert with $setOnInsert creates the row', (await settings.findOne({ _id: 'settings' })).vat_rate === 0.075);
  await settings.updateOne({ _id: 'settings' }, { $setOnInsert: { vat_rate: 99 } }, { upsert: true });
  ok('$setOnInsert does not overwrite an existing row', (await settings.findOne({ _id: 'settings' })).vat_rate === 0.075);
  const serialCol = await coll.serials();
  await serialCol.updateOne({ _id: 'receiptIssue' }, { $max: { last_used: 12 } }, { upsert: true });
  await serialCol.updateOne({ _id: 'receiptIssue' }, { $max: { last_used: 4 } }, { upsert: true });
  ok('$max upsert raises counters but never lowers them',
    (await serialCol.findOne({ _id: 'receiptIssue' })).last_used === 12);
  const made = await settings.updateOne({ _id: 'atomic-upsert' },
    { $setOnInsert: { vat_enabled: true } }, { upsert: true });
  ok('atomic upsert creates a row with $setOnInsert',
    made.upsertedCount === 1 &&
    (await settings.findOne({ _id: 'atomic-upsert' }))?.vat_enabled === true);
  upsertRaceOnce = true;
  const raced = await settings.updateOne({ _id: 'raced-upsert' },
    { $setOnInsert: { vat_rate: 0.075 } }, { upsert: true });
  const racedDoc = await settings.findOne({ _id: 'raced-upsert' });
  ok('lost upsert race re-reads instead of overwriting the winner',
    racedDoc?.from === 'other' && racedDoc?.v === 1 && raced.upsertedCount === 0);
  const peek = {};
  for (const r of await serialCol.find({}).toArray()) if (r._id !== 'seeded') peek[String(r._id)] = Number(r.last_used ?? 0);
  ok('peekSerials-style read', peek.receiptIssue === 12);

  // --- $unset / updateMany ------------------------------------------------
  const profiles = await coll.profiles();
  await profiles.insertOne({ _id: 'u1', role: 'ceo', sig_salt: 's', sig_hash: 'h' });
  await profiles.insertOne({ _id: 'u2', role: 'sales', sig_salt: 's2', sig_hash: 'h2' });
  const many = await profiles.updateMany({}, { $unset: { sig_salt: '', sig_hash: '' } });
  ok('updateMany({},$unset) purges both profiles', many.matchedCount === 2
    && (await profiles.findOne({ _id: 'u1' })).sig_salt === undefined
    && (await profiles.findOne({ _id: 'u2' })).role === 'sales');

  // --- $push (single, dotted $ne, and $each/$slice) -----------------------
  const notes = await coll.notifications();
  const nid = new ObjectId().toString();
  await notes.insertOne({ _id: nid, kind: 'voucherApproval', read_by: [], created_at: '2026-01-01' });
  await notes.updateOne({ _id: new ObjectId(nid), 'read_by.uid': { $ne: 'u1' } },
    { $push: { read_by: { uid: 'u1', name: 'Ada', at: 'now' } } });
  ok('$push + dotted-array $ne appends once', (await notes.findOne({ _id: nid })).read_by.length === 1);
  await notes.updateOne({ _id: nid, 'read_by.uid': { $ne: 'u1' } },
    { $push: { read_by: { uid: 'u1', name: 'Ada', at: 'now' } } });
  ok('dotted-array $ne prevents duplicate reads', (await notes.findOne({ _id: nid })).read_by.length === 1);
  const docs = await coll.officeDocs();
  await docs.insertOne({ _id: 'd1', title: 'Doc', blocks: [], revision: 1, versions: [] });
  for (let i = 1; i <= 25; i++) {
    await docs.updateOne({ _id: 'd1' }, {
      $set: { title: 'Doc ' + i, revision: i + 1 },
      $push: { versions: { $each: [{ revision: i }], $slice: -20 } },
    });
  }
  const d1 = await docs.findOne({ _id: 'd1' });
  ok('$push $each $slice:-20 keeps only the newest 20 versions',
    d1.versions.length === 20 && d1.versions[0].revision === 6 && d1.versions[19].revision === 25);
  ok('$set alongside $push still applies', d1.title === 'Doc 25' && d1.revision === 26);

  // --- findOneAndUpdate before/after --------------------------------------
  const vouchers = await coll.vouchers();
  const vid = new ObjectId().toString();
  await vouchers.insertOne({ _id: vid, status: 'pending', amount: 500, method: 'transfer', serial: 7 });
  const before = await vouchers.findOneAndUpdate({ _id: new ObjectId(vid), status: 'pending' },
    { $set: { status: 'processing' } }, { returnDocument: 'before' });
  ok('findOneAndUpdate returnDocument:before', before.status === 'pending' && before.amount === 500);
  ok('findOneAndUpdate persisted the new status', (await vouchers.findOne({ _id: vid })).status === 'processing');
  const after = await vouchers.findOneAndUpdate({ _id: vid }, { $inc: { serial: 1 } }, { returnDocument: 'after' });
  ok('findOneAndUpdate returnDocument:after', after.serial === 8);
  const missing = await vouchers.findOneAndUpdate({ _id: 'ghost', status: 'pending' }, { $set: { status: 'processing' } }, { returnDocument: 'before' });
  ok('findOneAndUpdate returns null when nothing matched', missing === null);

  // --- deleteOne ----------------------------------------------------------
  ok('deleteOne by ObjectId', (await products.deleteOne({ _id: new ObjectId(auto.insertedId) })).deletedCount === 1);
  ok('deleteOne on a miss', (await products.deleteOne({ _id: 'ghost' })).deletedCount === 0);
  ok('deleted row is gone', (await products.findOne({ _id: auto.insertedId })) === null);

  // --- atomic serial RPC --------------------------------------------------
  const nextSerial = async (type) => {
    const v = await pgRequest('POST', 'rpc/mtek_next_serial', { p_type: type });
    return Number(Array.isArray(v) ? v[0] : v);
  };
  ok('serial RPC starts at 1', await nextSerial('invoice') === 1);
  ok('serial RPC increments', await nextSerial('invoice') === 2);
  const concurrent = await Promise.all(Array.from({ length: 20 }, () => nextSerial('invoice')));
  ok('20 parallel serial requests are all unique',
    new Set(concurrent).size === 20 && Math.min(...concurrent) === 3 && Math.max(...concurrent) === 22);
  const liveSerials = await (await coll.serials()).find({}).toArray();
  const liveMap = Object.fromEntries(liveSerials.map(r => [String(r._id), Number(r.last_used ?? 0)]));
  ok('peekSerials / bootstrap sees the RPC-issued counter (single source of truth)',
    liveMap.invoice === 22 && liveMap.receiptIssue === 12);

  ok('no user-supplied id ever entered a PostgREST URL filter',
    unsafeFilterCount === 0);

  console.log(`\n${passed} checks passed, exitCode=${process.exitCode ?? 0}`);
})().catch(e => { console.error(e); process.exitCode = 1; });
