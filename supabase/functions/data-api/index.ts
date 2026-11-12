// ============================================================================
// M-TEK DATA API — Supabase Edge Function (Deno). THE production backend.
//
//   Supabase  = AUTH ONLY (GoTrue + JWT verification)
//   Postgres = ALL storage — public.mtek_docs on THIS Supabase project
//
// STOCK IS NEVER SEEDED: the products collection starts EMPTY and is filled
// through the app's own fields (Add product / Import TXT → /api/products/upsert).
// Serial books still self-provision from 000000001 on first call.
//
// Deploy (owner preference — ONE file, no local imports):
//   Supabase dashboard → Edge Functions → Create a new function → name it
//   `data-api` → replace index.ts with THIS file → Deploy. That's all.
//
// No external secrets: the Edge Runtime injects SUPABASE_URL and
// SUPABASE_SERVICE_ROLE_KEY automatically. No external DB secret is read.
//
// The apps call:  https://kshuadjcflwlidupnqly.supabase.co/functions/v1/data-api/...
//                 Authorization: Bearer <Supabase JWT>
// ============================================================================

// Storage is Supabase Postgres via PostgREST — no external DB driver.
// The MongoDB driver is GONE. Atlas SRV DNS for mfsl.w5ifd7x.mongodb.net
// stopped resolving (NXDOMAIN globally), which broke every data route. All
// reads/writes now go to the project's own Postgres through PostgREST — the
// same Supabase project that already provides Auth. Nothing else to configure.

// ---- environment (Function secrets — see header comment above) --------------
// SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY are auto-injected by the Supabase
// Edge Runtime for every function; SUPABASE_SECRET_KEY is kept as a fallback
// name since older projects expose the service key under that key instead.
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ??
  Deno.env.get('SUPABASE_SECRET_KEY') ??
  '';
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
// The CEO identity is locked to this email (owner directive) and, optionally,
// a specific Supabase Auth UID if MTEK_CEO_UID is set as a secret.
const CEO_EMAIL = 'mtekfiresafetyltd@gmail.com';
const CEO_PHONE = '+2348033498452';
const CEO_UID = Deno.env.get('MTEK_CEO_UID') ?? '';
// Bundle marker returned by GET /health so a deploy can be VERIFIED from
// the outside (bump whenever index.ts changes).
const BUNDLE_VERSION = '2026-09-19-office-suite1';
const STORAGE = 'supabase-postgres';

// App release marker. The repo is PRIVATE, so devices cannot query the GitHub
// Releases API without a token. /health (public, no JWT) carries this instead,
// letting installed APK/MSIX builds check whether a newer one exists.
// MUST equal `version:` in app/pubspec.yaml — ci/build-android.sh fails the
// build when they drift, and the deploy gate asserts it on the live response.
const APP_VERSION = '0.4.0+7';
const APP_BUILD = 7;
const APP_INFO = {
  app_version: APP_VERSION,
  app_build: APP_BUILD,
  app_release_url: 'https://github.com/NO-Group/mtek_fire_safety_ltd/releases/tag/ci',
  app_apk_url: 'https://github.com/NO-Group/mtek_fire_safety_ltd/releases/download/ci/MFSL.Inventory.apk',
  app_windows_url: 'https://github.com/NO-Group/mtek_fire_safety_ltd/releases/download/ci/MFSL.Inventory.Setup.msix',
};
// True when this GoTrue user is the locked CEO identity (by UID or email).
const isCeoUser = (id: unknown, email: unknown) =>
  String(id ?? '') === CEO_UID || String(email ?? '').toLowerCase() === CEO_EMAIL;

// CORS: the Android/Windows apps call this function directly (no browser
// origin to restrict to), so allow any origin but only the methods/headers
// this API actually uses.
const CORS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type, apikey',
};

// ---- logical collections inside public.mtek_docs ----------------------------
// ONE Supabase Postgres table, not seven MongoDB databases. /health reports
// this for deploy diagnostics; no app reads the field.
const STORAGE_COLLECTIONS = [
  'products', 'customers', 'sales', 'transactions', 'invoices', 'receipts',
  'invoice_payments', 'payment_vouchers', 'stock_adjustments', 'stock_receipts',
  'logs', 'archive', 'profiles', 'settings', 'serials', 'events',
  'notifications', 'cloud_files', 'office_documents', 'office_files',
];

// ============================================================================
// STORAGE — Supabase Postgres (PostgREST) ONLY. MongoDB/Atlas is RETIRED.
//
// Owner directive 2026-11-04: "Supabase alone is for our backend". The old
// Atlas SRV host (mfsl.w5ifd7x.mongodb.net) no longer exists in public DNS,
// so every data route failed with `querySrv ENOTFOUND` and the app showed
// empty counters / "Document NOT issued".
//
// All records live in ONE table, public.mtek_docs(collection, id, doc jsonb),
// created by supabase/migrations/20260908160000_remove_auth_profile_trigger.sql
// which the deploy workflow executes before each function deploy. The Edge
// Runtime injects SUPABASE_SERVICE_ROLE_KEY; it is the ONLY identity granted
// access (anon/authenticated are explicitly revoked, RLS is on).
//
// The small Mongo-compatible collection API below exists so the ~50 route
// handlers keep their exact behaviour AND their exact HTTP contract. No APK
// change is required for this migration.
// ============================================================================

/// 24-hex id, matching the shape the Flutter app already treats as a
/// server id (`_isServerId`). Constructing with no argument generates one.
class ObjectId {
  readonly hex: string;
  constructor(value?: string) {
    if (value === undefined || value === '') {
      const bytes = new Uint8Array(12);
      crypto.getRandomValues(bytes);
      this.hex = [...bytes].map(b => b.toString(16).padStart(2, '0')).join('');
    } else if (/^[0-9a-f]{24}$/i.test(value)) {
      this.hex = value.toLowerCase();
    } else {
      throw new Error('Invalid ObjectId');
    }
  }
  toString() { return this.hex; }
  toHexString() { return this.hex; }
  toJSON() { return this.hex; }
}

// deno-lint-ignore no-explicit-any
type AnyDoc = Record<string, any>;

const PG_TABLE = 'mtek_docs';
const PG_URL = `${SUPABASE_URL}/rest/v1`;
const newId = () => new ObjectId().toString();
const enc = (v: string) => encodeURIComponent(v);

function idOf(v: unknown): string | null {
  if (typeof v === 'string' && v) return v;
  if (v instanceof ObjectId) return v.toString();
  if (v && typeof v === 'object' && typeof (v as AnyDoc).toHexString === 'function') {
    return String((v as AnyDoc).toHexString());
  }
  return null;
}

/// Fast path: a filter of exactly `{ _id: <id> }` becomes one indexed
/// PostgREST lookup instead of scanning the whole collection.
function directId(filter?: AnyDoc): string | null {
  if (!filter) return null;
  const keys = Object.keys(filter);
  return keys.length === 1 && keys[0] === '_id' ? idOf(filter._id) : null;
}

async function pgRaw(method: string, path: string, body?: unknown,
                     prefer = ''): Promise<Response> {
  if (!SERVICE_ROLE) throw new Error('data-api has no service-role key — cannot reach Supabase Postgres');
  const headers: Record<string, string> = {
    apikey: SERVICE_ROLE,
    Authorization: `Bearer ${SERVICE_ROLE}`,
    'Content-Type': 'application/json',
  };
  if (prefer) headers.Prefer = prefer;
  const res = await fetch(`${PG_URL}/${path}`, {
    method, headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Supabase Postgres ${method} ${path.split('?')[0]} → ${res.status}: ${text.slice(0, 240)}`);
  }
  return res;
}

async function pgRequest(method: string, path: string, body?: unknown,
                         prefer = ''): Promise<any> {
  const res = await pgRaw(method, path, body, prefer);
  const text = await res.text();
  if (!text.trim()) return null;
  try { return JSON.parse(text); } catch { return null; }
}

// deno-lint-ignore no-explicit-any
const docsOf = (rows: unknown): AnyDoc[] => Array.isArray(rows)
  ? rows.map((r: any) => r?.doc as AnyDoc).filter(Boolean) : [];

async function pgRows(collection: string, filter?: AnyDoc,
                      pageSize = 500): Promise<AnyDoc[]> {
  const id = directId(filter);
  if (id != null) {
    // Point reads use a SQL function with a JSON body, NEVER a URL filter.
    // Ids are user-supplied and PostgREST treats ',', '.', '(', ')', '"' and
    // '\\' specially inside eq. values (offline keys contain ':'). Quoting
    // those values was tried and FAILED against real PostgREST — the live
    // health probe caught it — so no user-controlled value ever enters a URL.
    const doc = await pgRequest('POST', 'rpc/mtek_doc_get',
      { p_collection: collection, p_id: id });
    return doc && typeof doc === 'object' ? [doc as AnyDoc] : [];
  }
  // `collection` is always one of the fixed internal names in
  // STORAGE_COLLECTIONS (or __health__), i.e. [A-Za-z0-9_]+; plain eq. is safe.
  const base = `${PG_TABLE}?collection=eq.${enc(collection)}&select=doc`;
  // Supabase PostgREST caps one response at db-max-rows (default 1000). A
  // single GET silently truncated find({}).limit(5000) and updateMany({}).
  // Page with count=exact and stop on Content-Range / a short page.
  const PAGE = pageSize;
  const out: AnyDoc[] = [];
  for (let offset = 0; offset < 100000; offset += PAGE) {
    const res = await pgRaw('GET', `${base}&limit=${PAGE}&offset=${offset}`,
                            undefined, 'count=exact');
    const text = await res.text();
    let parsed: unknown = null;
    try { parsed = JSON.parse(text); } catch { /* empty body */ }
    const page = docsOf(parsed);
    out.push(...page);
    const range = res.headers.get('content-range') ?? '';
    const total = Number(range.split('/')[1] ?? '');
    if (page.length < PAGE) break;
    if (Number.isFinite(total) && out.length >= total) break;
  }
  return out;
}

async function pgPut(collection: string, id: string, doc: AnyDoc) {
  // Upsert on the (collection, id) primary key. Used for inserts and upserts;
  // updates go through pgCas() so concurrent writers cannot lose each other.
  await pgRequest('POST', PG_TABLE,
    { collection, id, doc }, 'resolution=merge-duplicates,return=minimal');
}

async function pgCas(collection: string, id: string,
                     expected: AnyDoc, next: AnyDoc): Promise<boolean> {
  // Compare-and-swap in ONE SQL statement: the UPDATE only lands if the row
  // still holds exactly the document we read. A null result means another
  // device won the race, so the caller re-reads and retries. This restores
  // the atomicity Mongo's $inc gave stock decrements and serial counters.
  try {
    const r = await pgRequest('POST', 'rpc/mtek_cas_update',
      { p_collection: collection, p_id: id, p_expected: expected, p_next: next });
    const v = Array.isArray(r) ? r[0] : r;
    return !(v === null || v === undefined || v === false);
  } catch (e) {
    // Only degrade when the RPC genuinely does not exist (SQL not applied
    // yet). A real DB/network error must surface — silently downgrading to a
    // plain write would hide lost updates.
    const msg = e instanceof Error ? e.message : String(e);
    if (!/mtek_cas_update|could not find the function|does not exist|PGRST202|\b404\b/i.test(msg)) throw e;
    console.error('mtek_cas_update not installed, using non-atomic write:', msg);
    await pgPut(collection, id, next);
    return true;
  }
}

async function pgCasUpsert(collection: string, id: string,
                           expected: AnyDoc | null, next: AnyDoc): Promise<boolean> {
  // Atomic insert-or-update. `expected` is null when we read no row, so the
  // ON CONFLICT branch only fires if another writer created it first — in
  // that case the WHERE fails, no row is returned, and the caller re-reads
  // and retries through the normal CAS path. Closes the last-writer-wins gap
  // that $setOnInsert / $max / nextSerial()'s fallback used to have.
  try {
    const r = await pgRequest('POST', 'rpc/mtek_cas_upsert',
      { p_collection: collection, p_id: id, p_expected: expected, p_next: next });
    const v = Array.isArray(r) ? r[0] : r;
    return !(v === null || v === undefined || v === false);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    if (!/mtek_cas_upsert|could not find the function|does not exist|PGRST202|\b404\b/i.test(msg)) throw e;
    console.error('mtek_cas_upsert not installed, using non-atomic upsert:', msg);
    await pgPut(collection, id, next);
    return true;
  }
}

async function pgDelete(collection: string, id: string) {
  // JSON body RPC for the same reason as pgRows: no id ever reaches a URL.
  await pgRequest('POST', 'rpc/mtek_doc_delete',
    { p_collection: collection, p_id: id });
}

// ---- Mongo query emulation --------------------------------------------------
function valuesAt(value: unknown, parts: string[]): unknown[] {
  if (parts.length === 0) return [value];
  if (Array.isArray(value)) return value.flatMap(e => valuesAt(e, parts));
  if (value == null || typeof value !== 'object') return [undefined];
  const [head, ...rest] = parts;
  return valuesAt((value as AnyDoc)[head], rest);
}
function scalarAt(doc: AnyDoc, path: string): unknown {
  return valuesAt(doc, path.split('.'))[0];
}
const same = (a: unknown, b: unknown) => {
  const norm = (v: unknown) => v instanceof ObjectId ? v.toString() : v;
  const x = norm(a), y = norm(b);
  if (x === y) return true;
  if (x != null && y != null && typeof x === 'object' && typeof y === 'object') {
    return JSON.stringify(x) === JSON.stringify(y);
  }
  return false;
};
function num(v: unknown) { return Number(v ?? 0) || 0; }

function exprValue(doc: AnyDoc, e: unknown): unknown {
  if (typeof e === 'string' && e.startsWith('$')) return num(scalarAt(doc, e.slice(1)));
  if (e && typeof e === 'object' && !Array.isArray(e)) {
    const o = e as AnyDoc;
    if ('$add' in o) return (o.$add as unknown[]).reduce<number>((a, x) => a + num(exprValue(doc, x)), 0);
  }
  return e;
}
function matchExpr(doc: AnyDoc, e: AnyDoc): boolean {
  if ('$gte' in e) return num(exprValue(doc, e.$gte[0])) >= num(exprValue(doc, e.$gte[1]));
  if ('$lte' in e) return num(exprValue(doc, e.$lte[0])) <= num(exprValue(doc, e.$lte[1]));
  if ('$gt' in e) return num(exprValue(doc, e.$gt[0])) > num(exprValue(doc, e.$gt[1]));
  if ('$lt' in e) return num(exprValue(doc, e.$lt[0])) < num(exprValue(doc, e.$lt[1]));
  return true;
}
function matchField(values: unknown[], cond: unknown): boolean {
  const c: AnyDoc = (cond && typeof cond === 'object' && !(cond instanceof ObjectId) &&
    Object.keys(cond as AnyDoc).some(k => k.startsWith('$')))
    ? cond as AnyDoc : { $eq: cond };
  for (const [op, expected] of Object.entries(c)) {
    switch (op) {
      case '$eq':   if (!values.some(v => same(v, expected))) return false; break;
      case '$ne':   if (values.some(v => same(v, expected))) return false; break;
      case '$in':   if (!(expected as unknown[]).some(x => values.some(v => same(v, x)))) return false; break;
      case '$nin':  if ((expected as unknown[]).some(x => values.some(v => same(v, x)))) return false; break;
      // Mongo compares numbers numerically and strings lexicographically.
      // History pagination uses `$lt: <ISO timestamp>`, so blindly coercing
      // to Number() would make every date comparison false.
      case '$gt':
      case '$gte':
      case '$lt':
      case '$lte': {
        const numeric = typeof expected === 'number' ||
          (typeof expected === 'string' && expected.trim() !== '' && Number.isFinite(Number(expected)));
        const hits = values.some(v => {
          if (v == null) return false;
          const c = numeric
            ? (typeof v === 'number' || (typeof v === 'string' && Number.isFinite(Number(v)))
                ? num(v) - Number(expected)
                : -1)
            : compareValues(v, expected);
          return op === '$gt' ? c > 0 : op === '$gte' ? c >= 0 : op === '$lt' ? c < 0 : c <= 0;
        });
        if (!hits) return false;
        break;
      }
      case '$exists': {
        const found = values.some(v => v !== undefined);
        if (found !== Boolean(expected)) return false;
        break;
      }
      case '$regex': {
        const flags = String(c.$options ?? '');
        let re: RegExp;
        try { re = new RegExp(String(expected), flags); } catch { return false; }
        if (!values.some(v => v != null && re.test(String(v)))) return false;
        break;
      }
      case '$options': break; // consumed by $regex
      default: break;
    }
  }
  return true;
}
function matchDoc(doc: AnyDoc, filter: AnyDoc = {}): boolean {
  for (const [key, cond] of Object.entries(filter)) {
    if (key === '$expr') { if (!matchExpr(doc, cond as AnyDoc)) return false; continue; }
    if (key === '$or') {
      if (!(cond as AnyDoc[]).some(sub => matchDoc(doc, sub))) return false;
      continue;
    }
    if (key === '$and') {
      if (!(cond as AnyDoc[]).every(sub => matchDoc(doc, sub))) return false;
      continue;
    }
    if (!matchField(valuesAt(doc, key.split('.')), cond)) return false;
  }
  return true;
}
function compareValues(a: unknown, b: unknown): number {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  // A number imported as a JSON string must still sort numerically
  // ('10' after '9', not before it). ISO timestamps stay lexicographic.
  if (typeof a === 'string' && typeof b === 'string' &&
      a.trim() !== '' && b.trim() !== '' &&
      Number.isFinite(Number(a)) && Number.isFinite(Number(b))) {
    return Number(a) - Number(b);
  }
  const x = a instanceof ObjectId ? a.toString() : String(a);
  const y = b instanceof ObjectId ? b.toString() : String(b);
  return x < y ? -1 : x > y ? 1 : 0;
}

// ---- Mongo update emulation -------------------------------------------------
function setPath(doc: AnyDoc, path: string, value: unknown) {
  const parts = path.split('.');
  let cur = doc;
  for (let i = 0; i < parts.length - 1; i++) {
    const p = parts[i];
    if (cur[p] == null || typeof cur[p] !== 'object') cur[p] = {};
    cur = cur[p];
  }
  cur[parts[parts.length - 1]] = value;
}
function applyUpdate(doc: AnyDoc, update: AnyDoc, isInsert: boolean) {
  const hasOps = Object.keys(update).some(k => k.startsWith('$'));
  if (!hasOps) {
    const id = doc._id;
    for (const k of Object.keys(doc)) delete doc[k];
    doc._id = id;
    Object.assign(doc, update);
    doc._id = id;
    return;
  }
  for (const [op, spec] of Object.entries(update)) {
    const fields = (spec ?? {}) as AnyDoc;
    switch (op) {
      case '$set':
        for (const [k, v] of Object.entries(fields)) setPath(doc, k, v);
        break;
      case '$setOnInsert':
        if (isInsert) for (const [k, v] of Object.entries(fields)) setPath(doc, k, v);
        break;
      case '$inc':
        for (const [k, v] of Object.entries(fields)) setPath(doc, k, num(scalarAt(doc, k)) + num(v));
        break;
      case '$max':
        for (const [k, v] of Object.entries(fields)) {
          const cur = num(scalarAt(doc, k));
          if (num(v) > cur) setPath(doc, k, num(v));
        }
        break;
      case '$unset':
        for (const k of Object.keys(fields)) {
          const parts = k.split('.');
          let cur: AnyDoc = doc;
          for (let i = 0; i < parts.length - 1; i++) {
            if (cur[parts[i]] == null) { cur = {}; break; }
            cur = cur[parts[i]];
          }
          if (cur && typeof cur === 'object') delete cur[parts[parts.length - 1]];
        }
        break;
      case '$push':
        for (const [k, v] of Object.entries(fields)) {
          const current = scalarAt(doc, k);
          const arr: unknown[] = Array.isArray(current) ? [...current] : [];
          let additions: unknown[] = [v];
          let slice: number | null = null;
          if (v && typeof v === 'object' && '$each' in (v as AnyDoc)) {
            const spec = v as AnyDoc;
            additions = Array.isArray(spec.$each) ? spec.$each : [spec.$each];
            if (typeof spec.$slice === 'number') slice = spec.$slice;
          }
          arr.push(...additions);
          setPath(doc, k, slice == null ? arr : (slice < 0 ? arr.slice(slice) : arr.slice(0, slice)));
        }
        break;
      default: break;
    }
  }
}

class Cursor {
  private sortSpec: AnyDoc = {};
  private take = Number.MAX_SAFE_INTEGER;
  private skipCount = 0;
  private pending: Promise<AnyDoc[]>;
  private filter: AnyDoc;
  constructor(pending: Promise<AnyDoc[]>, filter: AnyDoc) {
    this.pending = pending;
    this.filter = filter;
  }
  sort(spec: AnyDoc) { this.sortSpec = spec; return this; }
  limit(n: number) { this.take = n; return this; }
  skip(n: number) { this.skipCount = n; return this; }
  async toArray(): Promise<AnyDoc[]> {
    const rows = (await this.pending).filter(r => matchDoc(r, this.filter));
    const keys = Object.entries(this.sortSpec);
    if (keys.length) rows.sort((a, b) => {
      for (const [k, dir] of keys) {
        const c = compareValues(scalarAt(a, k), scalarAt(b, k));
        if (c) return Number(dir) < 0 ? -c : c;
      }
      return 0;
    });
    return rows.slice(this.skipCount, this.skipCount + this.take);
  }
}

class PgCollection {
  readonly name: string;
  constructor(name: string) { this.name = name; }
  find(filter: AnyDoc = {}) { return new Cursor(pgRows(this.name, filter), filter); }
  async findOne(filter: AnyDoc = {}): Promise<AnyDoc | null> {
    const rows = await pgRows(this.name, filter);
    return rows.find(r => matchDoc(r, filter)) ?? null;
  }
  async insertOne(doc: AnyDoc) {
    const raw = doc._id;
    const id = raw == null ? newId() : (idOf(raw) ?? String(raw));
    const full: AnyDoc = { ...doc, _id: id };
    await pgPut(this.name, id, full);
    return { acknowledged: true, insertedId: id };
  }
  private async casWrite(existing: AnyDoc, update: AnyDoc): Promise<AnyDoc | null> {
    const id = idOf(existing._id) ?? String(existing._id);
    const next: AnyDoc = structuredClone(existing);
    applyUpdate(next, update, false);
    next._id = id;
    return await pgCas(this.name, id, existing, next) ? next : null;
  }
  async updateOne(filter: AnyDoc, update: AnyDoc,
                  options: { upsert?: boolean } = {}) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const rows = await pgRows(this.name, filter);
      const existing = rows.find(r => matchDoc(r, filter));
      if (!existing) {
        if (!options.upsert) return { matchedCount: 0, modifiedCount: 0, upsertedCount: 0 };
        const id = directId(filter) ?? newId();
        const doc: AnyDoc = { _id: id };
        applyUpdate(doc, update, true);
        doc._id = id;
        if (await pgCasUpsert(this.name, id, null, doc)) {
          return { matchedCount: 0, modifiedCount: 0, upsertedCount: 1, upsertedId: id };
        }
        // Someone inserted first. Re-read; the next pass treats it as an
        // existing row and applies the update through the CAS path.
        continue;
      }
      if (await this.casWrite(existing, update)) {
        return { matchedCount: 1, modifiedCount: 1, upsertedCount: 0 };
      }
    }
    throw new Error('Concurrent update conflict — please retry');
  }
  async updateMany(filter: AnyDoc, update: AnyDoc) {
    const rows = (await pgRows(this.name, filter)).filter(r => matchDoc(r, filter));
    for (const row of rows) {
      await this.updateOne({ _id: row._id }, update);
    }
    return { matchedCount: rows.length, modifiedCount: rows.length };
  }
  async deleteOne(filter: AnyDoc) {
    const rows = await pgRows(this.name, filter);
    const existing = rows.find(r => matchDoc(r, filter));
    if (!existing) return { acknowledged: true, deletedCount: 0 };
    await pgDelete(this.name, idOf(existing._id) ?? String(existing._id));
    return { acknowledged: true, deletedCount: 1 };
  }
  async deleteMany(filter: AnyDoc) {
    const rows = (await pgRows(this.name, filter)).filter(r => matchDoc(r, filter));
    for (const row of rows) await pgDelete(this.name, idOf(row._id) ?? String(row._id));
    return { acknowledged: true, deletedCount: rows.length };
  }
  async findOneAndUpdate(filter: AnyDoc, update: AnyDoc,
                         options: { returnDocument?: string; upsert?: boolean } = {}) {
    for (let attempt = 0; attempt < 4; attempt++) {
      const rows = await pgRows(this.name, filter);
      const existing = rows.find(r => matchDoc(r, filter));
      if (!existing) {
        if (!options.upsert) return null;
        const id = directId(filter) ?? newId();
        const doc: AnyDoc = { _id: id };
        applyUpdate(doc, update, true);
        doc._id = id;
        if (await pgCasUpsert(this.name, id, null, doc)) {
          return options.returnDocument === 'before' ? null : doc;
        }
        continue;
      }
      const next = await this.casWrite(existing, update);
      if (next) return options.returnDocument === 'before' ? existing : next;
    }
    throw new Error('Concurrent update conflict — please retry');
  }
}

const collectionCache = new Map<string, PgCollection>();
const collection = (name: string): Promise<PgCollection> => {
  let c = collectionCache.get(name);
  if (!c) { c = new PgCollection(name); collectionCache.set(name, c); }
  return Promise.resolve(c);
};

const coll = {
  serials: () => collection('serials'),
  settings: () => collection('settings'),
  products: () => collection('products'),
  adjustments: () => collection('stock_adjustments'),
  stockReceipts: () => collection('stock_receipts'),
  profiles: () => collection('profiles'),
  customers: () => collection('customers'),
  sales: () => collection('sales'),
  txns: () => collection('transactions'),
  invoices: () => collection('invoices'),
  receipts: () => collection('receipts'),
  payments: () => collection('invoice_payments'),
  vouchers: () => collection('payment_vouchers'),
  mils: () => collection('logs'),
  archive: () => collection('archive'),
  cloudDocs: () => collection('cloud_files'),
  officeDocs: () => collection('office_documents'),
  officeFiles: () => collection('office_files'),
  audit: () => collection('events'),
  notifications: () => collection('notifications'),
};

// ---- helpers ----------------------------------------------------------------
const pad9 = (n: number) => String(n).padStart(9, '0');
// insertOne helper (npm driver resolves to { insertedId }).
// deno-lint-ignore no-explicit-any
const ins = async (c: Promise<any>, doc: Record<string, unknown>) => (await c).insertOne(doc);
const fmtN = (n: number) => '₦' + Math.round(n).toLocaleString('en-NG');
const BOOK_TYPES = ['receiptIssue', 'receipt', 'invoice', 'mils', 'waybill', 'deliverynote', 'stockreceipt', 'paymentvoucher'];
const now = () => new Date().toISOString();

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status, headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}
const err = (status: number, message: string) => json({ error: message }, status);

async function audit(section: string, action: string, ref: string, user: Profile) {
  try {
    (await coll.audit()).insertOne({ section, action, ref: String(ref), by: user.uid, by_name: user.name, at: now() });
  } catch { /* never break a request on audit failure */ }
}

// ---- notifications: every significant write fires one of these, visible
// to EVERY signed-in user (CEO, Admin, Sales) — owner directive 2026-09-01
// ("the CEO admin and any user should receive a notification ... when any
// transaction happens"). Announcements (CEO/Admin → all staff) reuse the
// same collection with kind='announcement' and track exactly who has read
// them so the sender can see a read count + reader list.
async function notify(kind: string, title: string, message: string, ref: string, user: Profile) {
  try {
    await (await coll.notifications()).insertOne({
      kind, title, message, ref: String(ref),
      created_by: user.uid, created_by_name: user.name, created_at: now(),
      read_by: [] as Array<{ uid: string; name: string; at: string }>,
    });
  } catch { /* never break a request because a notification failed to save */ }
}

// ---- auth: Supabase JWT → Postgres profile -----------------------------------
interface Profile {
  uid: string; email: string; name: string; role: string;
}
const hashRecovery = (secret: string, salt: string) => hmacHex(`${salt}${secret}`, 'mtek-recovery-salt');
async function hmacHex(message: string, key: string): Promise<string> {
  const enc = new TextEncoder();
  const k = await crypto.subtle.importKey('raw', enc.encode(key), { name: 'HMAC', hash: 'SHA-512' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', k, enc.encode(message));
  return [...new Uint8Array(sig)].map(b => b.toString(16).padStart(2, '0')).join('');
}

const profileCache = new Map<string, { value: Profile; expires: number }>();

/// Passport photos belong in the database, never Supabase Auth metadata. Auth
/// metadata is embedded in every JWT; a base64 passport photo made the
/// Authorization header exceed the Edge gateway limit and produced HTTP 520.
async function removePhotoFromAuthMetadata(user: Record<string, unknown>): Promise<boolean> {
  const metadata = (user.user_metadata ?? {}) as Record<string, unknown>;
  if (typeof metadata.passport_photo !== 'string' || !metadata.passport_photo) return false;
  const r = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${String(user.id ?? '')}`, {
    method: 'PUT',
    headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ user_metadata: { ...metadata, passport_photo: null } }),
  });
  if (!r.ok) throw new Error(`Could not repair oversized Auth metadata (${r.status})`);
  return true;
}

async function auth(req: Request): Promise<Profile> {
  const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!jwt) throw new HttpErr(401, 'Missing bearer token');
  // NOTE: Supabase's GET /auth/v1/user returns the user id under `id`, NOT
  // `sub` (`sub` only exists inside a raw JWT payload). Keying everything on
  // `user.sub` made every profile lookup/cache key resolve to `undefined`,
  // so accounts could collide and pick up the WRONG cached role — the
  // reported "CEO signs in and shows as Sales" bug. Everything here now keys
  // on the real `user.id`.
  let user: { id: string; email?: string; user_metadata?: Record<string, unknown> };
  try {
    const r = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${jwt}` },
    });
    if (!r.ok) throw new HttpErr(401, 'Invalid or expired token');
    user = await r.json();
  } catch (e) {
    if (e instanceof HttpErr) throw e;
    throw new HttpErr(503, 'Auth service unreachable — try again shortly');
  }
  if (!user.id) throw new HttpErr(401, 'Invalid or expired token');
  const cached = profileCache.get(user.id);
  if (cached && Date.now() < cached.expires) return cached.value;

  const profiles = await coll.profiles();
  let p = await profiles.findOne({ _id: user.id }) as Record<string, unknown> | null;
  const isCeo = user.id === CEO_UID || String(user.email ?? '').toLowerCase() === CEO_EMAIL;
  if (!p) {
    p = {
      _id: user.id,
      email: String(user.email ?? '').toLowerCase(),
      full_name: (user.user_metadata?.full_name as string) || (isCeo ? 'CEO' : String(user.email ?? 'staff').split('@')[0]),
      role: isCeo ? 'ceo' : 'sales', // the CEO identity is locked by hardcode
      created_at: now(),
    };
    await profiles.insertOne(p as Record<string, unknown>);
  } else if (isCeo && p.role !== 'ceo') {
    await profiles.updateOne({ _id: user.id }, { $set: { role: 'ceo' } });
    p.role = 'ceo';
  }
  if (isCeo && String((p as Record<string, unknown>).phone ?? '') !== CEO_PHONE) {
    await profiles.updateOne({ _id: user.id }, { $set: { phone: CEO_PHONE } });
    (p as Record<string, unknown>).phone = CEO_PHONE;
  }
  const value: Profile = {
    uid: user.id, email: String(p.email), name: String(p.full_name),
    role: String(p.role),
  };
  profileCache.set(user.id, { value, expires: Date.now() + 60_000 });
  return value;
}

class HttpErr extends Error { constructor(public status: number, message: string) { super(message); } }

function requireRole(user: Profile, roles: string[], what: string) {
  if (!roles.includes(user.role)) {
    throw new HttpErr(403, roles.length === 1 && roles[0] === 'ceo'
      ? `Only the CEO can ${what}` : `Only CEO or Admin can ${what}`);
  }
}

const normName = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const internationalPhone = (s: string) => /^\+[1-9]\d{7,14}$/.test(s.replace(/[\s()\-]/g, ''));
const normPhone = (s: string) => s.replace(/\D/g, '').replace(/^234/, '0');
/// Same customer entered twice (two devices offline, or a typo-free re-entry):
/// identical normalised name, and identical phone when both sides have one.
async function findDuplicateCustomer(name: string, phone: string) {
  const n = normName(name); if (!n) return null;
  const ph = normPhone(phone);
  const cands = await (await coll.customers()).find({ name: { $regex: `^${name.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' } }).limit(20).toArray();
  for (const c of cands) {
    if (normName(String(c.name ?? '')) !== n) continue;
    const cp = normPhone(String(c.phone ?? ''));
    if (!ph || !cp || ph === cp) return c;
  }
  return null;
}

// ---- core provisioning (serials from 000000001, REAL owner catalogue) -------
// Runs once per Edge isolate. Each upsert used to be a read + write on every
// /api/bootstrap poll (the app polls frequently); sharing a single in-flight
// promise keeps that cost to one cold start without changing the result.
let coreReady: Promise<void> | null = null;
function ensureCore(): Promise<void> {
  if (!coreReady) {
    coreReady = provisionCore().catch(e => { coreReady = null; throw e; });
  }
  return coreReady;
}
async function provisionCore() {
  const s = await coll.serials();
  for (const t of BOOK_TYPES) {
    await s.updateOne({ _id: t }, { $setOnInsert: { last_used: 0 } }, { upsert: true });
  }
  await coll.settings().then(async c => {
    await c.updateOne({ _id: 'settings' }, { $setOnInsert: {
      vat_enabled: false, vat_rate: 0.075, watermark: true,
    } }, { upsert: true });
  });
  // Purge obsolete secondary-signing credentials from all staff profiles.
  // No-op on a fresh store: there are no profiles to scan yet.
  const existing = await (await coll.profiles()).find({}).toArray();
  if (existing.some(p => p.sig_salt !== undefined || p.sig_hash !== undefined)) {
    await (await coll.profiles()).updateMany({}, { $unset: { sig_salt: '', sig_hash: '' } });
  }
}
async function nextSerial(type: string): Promise<number> {
  // Atomic: INSERT ... ON CONFLICT DO UPDATE SET last_used = last_used + 1.
  // A read-then-write shim could hand the same paper-book number to two
  // devices, which the owner explicitly forbids (no offline-issued serials).
  try {
    const v = await pgRequest('POST', 'rpc/mtek_next_serial', { p_type: type });
    const n = Number(Array.isArray(v) ? v[0] : v);
    if (Number.isFinite(n) && n > 0) return n;
  } catch (e) {
    console.error('mtek_next_serial RPC unavailable, using fallback:', e);
  }
  const out = await (await coll.serials()).findOneAndUpdate(
    { _id: type } as Record<string, unknown>, { $inc: { last_used: 1 } },
    { upsert: true, returnDocument: 'after' });
  return Number(out?.last_used ?? 1);
}
async function peekSerials(): Promise<Record<string, number>> {
  const rows = await (await coll.serials()).find({}).toArray();
  const out: Record<string, number> = {};
  // '__health_probe__' is a reserved throwaway counter used only to prove
  // the atomic allocator is reachable; never expose it to the apps.
  for (const r of rows) {
    const k = String(r._id);
    if (k !== 'seeded' && !k.startsWith('__')) out[k] = Number(r.last_used ?? 0);
  }
  return out;
}

/// Live proof that POST /api/docs/issue can obtain a SERVER-assigned serial.
/// Uses a reserved counter so it never consumes a real paper-book number.
/// nextSerial() also has a non-atomic fallback, so this makes a broken RPC
/// visible instead of silently downgrading serial uniqueness.
async function probeSerialRpc(): Promise<string> {
  try {
    const v = await pgRequest('POST', 'rpc/mtek_next_serial', { p_type: '__health_probe__' });
    const n = Number(Array.isArray(v) ? v[0] : v);
    return Number.isFinite(n) && n > 0 ? 'ok' : 'unexpected response';
  } catch (e) {
    return `unavailable: ${String((e as Error)?.message ?? e).slice(0, 120)}`;
  }
}

/// Full CRUD round-trip against REAL Supabase Postgres (not the mock used by
/// tools/pg_shim_test.mjs). Uses a reserved throwaway collection and cleans
/// up after itself, so it is safe on every deep health poll. Proves insert,
/// filter/read, $inc+$set update, sort/limit and delete all work in production.
async function probeStorageRoundTrip(): Promise<string> {
  const c = new PgCollection('__health__');
  // Every deep-health poll gets its OWN nonce. Two overlapping polls (CI's
  // health gate plus a manual check) previously shared these fixed ids: one
  // poll's finally/deleteMany removed the other's page rows and produced a
  // spurious "pagination failed: got 4/5", which could fail a good deploy.
  const nonce = crypto.randomUUID().replace(/-/g, '').slice(0, 12);
  const probeLabel = `probe-${nonce}`;
  const upLabel = `updated-${nonce}`;
  const upsertLabel = `upsert-${nonce}`;
  const pageLabel = `page-${nonce}`;
  // Deliberately hostile id: comma, dot, parentheses, quotes and a backslash.
  // These are exactly the characters that broke `eq.` URL filters. Proves on
  // every deploy that point reads/deletes travel through JSON-body RPCs and
  // survive arbitrary ids; if that ever regresses the deploy gate fails.
  const id = `__roundtrip__,filter.(probe)"q\\z-${nonce}`;
  const upId = `__upsert_probe__-${nonce}`;
  const pageIds = Array.from({ length: 5 }, (_, i) => `__page__${nonce}-${i}`);
  try {
    await c.insertOne({ _id: id, label: probeLabel, n: 1 });
    const found = await c.findOne({ _id: id });
    if (!found || found.label !== probeLabel) return 'insert/read failed';
    const upd = await c.updateOne(
      { _id: id, n: { $gte: 1 } },
      { $inc: { n: 2 }, $set: { label: upLabel } });
    const after = await c.findOne({ _id: id });
    if (!upd.modifiedCount || Number(after?.n) !== 3 || after?.label !== upLabel) {
      return 'update failed';
    }
    const listed = await c.find({ label: upLabel }).sort({ n: -1 }).limit(5).toArray();
    if (listed.length !== 1) return 'filter/sort failed';
    const del = await c.deleteOne({ _id: id });
    if (del.deletedCount !== 1 || await c.findOne({ _id: id })) return 'delete failed';

    // Prove the atomic upsert RPC (used by $setOnInsert, $max and the
    // nextSerial() fallback) works on real Postgres — not just the mock.
    const up = await c.updateOne({ _id: upId },
      { $setOnInsert: { v: 1, label: upsertLabel } }, { upsert: true });
    if (up.upsertedCount !== 1) return 'atomic upsert failed';
    const upDoc = await c.findOne({ _id: upId });
    if (Number(upDoc?.v) !== 1) return 'atomic upsert readback failed';
    await c.deleteOne({ _id: upId });

    // Prove real PostgREST pagination (count=exact / limit / offset /
    // Content-Range), not just the mocked shim. Five rows with pageSize=2
    // forces three GETs and catches the 1000-row cap silently truncating.
    // Only OUR nonce-tagged rows are counted, so a concurrent poll's rows
    // cannot change the result; pgRows still fetches every page.
    for (let i = 0; i < pageIds.length; i++) {
      await c.insertOne({ _id: pageIds[i], label: pageLabel, n: i });
    }
    const paged = await pgRows('__health__', undefined, 2);
    const mine = pageIds.filter(pid => paged.some(r => String(r._id) === pid));
    if (mine.length !== 5) return `pagination failed: got ${mine.length}/5`;
    await c.deleteMany({ label: pageLabel });
    return 'ok';
  } catch (e) {
    return `unavailable: ${String((e as Error)?.message ?? e).slice(0, 140)}`;
  } finally {
    try { await c.deleteOne({ _id: id }); } catch { /* best-effort cleanup */ }
    try { await c.deleteOne({ _id: upId }); } catch { /* best-effort */ }
    try { await c.deleteMany({ label: pageLabel }); } catch { /* best-effort */ }
  }
}

// ---- router -----------------------------------------------------------------
Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  const url = new URL(req.url);
  // Gateway path forms vary across function versions/regions (full
  // '/functions/v1/<name>/...', '/<name>/...', or the bare route) — guessing
  // prefixes routed live traffic into auth() (the 'Unknown API route' class
  // of failures). Anchor on the LAST '/api/' marker or trailing '/health'
  // instead: immune to whatever prefix the gateway keeps.
  const rawPath = url.pathname;
  const cut = Math.max(rawPath.lastIndexOf('/api/'), rawPath.lastIndexOf('/health'));
  const path = cut === -1 ? '/' : rawPath.slice(cut);
  const route = `${req.method} ${path}`;

  try {
    // Boot/activation probe — responds to ANY method (GET/HEAD/POST alike)
    // so HEAD-only fetchers can read the live bundle version. Deliberately NO
    // DB work; deep (DB-touching) check: GET /?deep=1
    if (path === '/' || path === '/health') {
      if (url.searchParams.get('deep') === '1') {
        await ensureCore();
        if (url.searchParams.get('full') === '1') {
          const [products, customers, txns, receipts, invoices, docs, sales, mils, adjustments] = await Promise.all([
            (await coll.products()).find({}).limit(1000).toArray(),
            (await coll.customers()).find({}).limit(1000).toArray(),
            (await coll.txns()).find({}).limit(300).toArray(),
            (await coll.receipts()).find({}).limit(300).toArray(),
            (await coll.invoices()).find({}).limit(300).toArray(),
            (await coll.archive()).find({}).limit(100).toArray(),
            (await coll.sales()).find({}).limit(300).toArray(),
            (await coll.mils()).find({}).limit(300).toArray(),
            (await coll.adjustments()).find({}).limit(300).toArray(),
          ]);
          const payload = { products, customers, txns,
            receipts: receipts.map(({ customer_signature: _s, ...r }) => r), invoices, docs,
            sales: sales.map(({ customer_signature: _s, ...r }) => r), mils, adjustments };
          return json({ ok: true, version: BUNDLE_VERSION, storage: STORAGE, ...APP_INFO,
            serial_rpc: await probeSerialRpc(),
            storage_roundtrip: await probeStorageRoundTrip(),
            bootstrap_bytes: new TextEncoder().encode(JSON.stringify(payload)).length });
        }
        return json({ ok: true, version: BUNDLE_VERSION, storage: STORAGE, ...APP_INFO,
          collections: STORAGE_COLLECTIONS, serials: await peekSerials(),
          serial_rpc: await probeSerialRpc(),
          storage_roundtrip: await probeStorageRoundTrip() });
      }
      return json({ ok: true, version: BUNDLE_VERSION, storage: STORAGE, ...APP_INFO, collections: STORAGE_COLLECTIONS });
    }

    // ---- public auth: email + password sign-in (Supabase GoTrue proxy) ----
    if (route === 'POST /api/auth/login') {
      const b = await req.json().catch(() => ({} as Record<string, unknown>));
      let gr: Response;
      try {
        gr = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: String(b.email ?? ''), password: String(b.password ?? '') }),
        });
      } catch {
        return err(503, 'Auth service unreachable — try again shortly');
      }
      let j = await gr.json().catch(() => ({} as Record<string, unknown>));
      if (!gr.ok) {
        return err(401, String(j.error_description ?? j.msg ?? 'Wrong email or password'));
      }
      let u = (j.user ?? {}) as Record<string, unknown>;
      // Repair accounts created by older builds, then obtain a fresh slim JWT.
      if (await removePhotoFromAuthMetadata(u)) {
        gr = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: String(b.email ?? ''), password: String(b.password ?? '') }),
        });
        j = await gr.json().catch(() => ({} as Record<string, unknown>));
        if (!gr.ok) return err(401, 'Account metadata repaired; please sign in again');
        u = (j.user ?? {}) as Record<string, unknown>;
      }
      const token = String(j.access_token ?? '');
      let profile: Profile | null = null;
      try {
        profile = await auth(new Request('https://internal/', { headers: { authorization: `Bearer ${token}` } }));
      } catch { /* profile warming is best-effort */ }
      const loginCeo = isCeoUser(u.id, u.email);
      return json({
        access_token: token,
        refresh_token: String(j.refresh_token ?? ''),
        user: {
          uid: String(u.id ?? ''), email: String(u.email ?? ''),
          name: profile?.name ?? String((u.user_metadata as Record<string, unknown> | undefined)?.full_name ?? String(u.email ?? '').split('@')[0]),
          // The CEO identity is locked by email — a failed/best-effort
          // profile warm-up must NEVER downgrade the boss to 'sales'.
          role: profile?.role ?? (loginCeo ? 'ceo' : 'sales'),
        },
      });
    }
    // ---- public auth: silent session restore from a stored refresh token
    // (owner directive 2026-09-01 — exiting the app must not sign you out).
    if (route === 'POST /api/auth/refresh') {
      const b = await req.json().catch(() => ({} as Record<string, unknown>));
      const refreshToken = String(b.refresh_token ?? '');
      if (!refreshToken) return err(400, 'Missing refresh token');
      let gr: Response;
      try {
        gr = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: refreshToken }),
        });
      } catch {
        return err(503, 'Auth service unreachable — try again shortly');
      }
      let j = await gr.json().catch(() => ({} as Record<string, unknown>));
      if (!gr.ok) {
        return err(401, String(j.error_description ?? j.msg ?? 'Session expired — please sign in again'));
      }
      let u = (j.user ?? {}) as Record<string, unknown>;
      if (await removePhotoFromAuthMetadata(u)) {
        const nextRefresh = String(j.refresh_token ?? refreshToken);
        gr = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ refresh_token: nextRefresh }),
        });
        j = await gr.json().catch(() => ({} as Record<string, unknown>));
        if (!gr.ok) return err(401, 'Account metadata repaired; please sign in again');
        u = (j.user ?? {}) as Record<string, unknown>;
      }
      const token = String(j.access_token ?? '');
      let profile: Profile | null = null;
      try {
        profile = await auth(new Request('https://internal/', { headers: { authorization: `Bearer ${token}` } }));
      } catch { /* profile warming is best-effort */ }
      const refreshCeo = isCeoUser(u.id, u.email);
      return json({
        access_token: token,
        refresh_token: String(j.refresh_token ?? refreshToken),
        user: {
          uid: String(u.id ?? ''), email: String(u.email ?? ''),
          name: profile?.name ?? String((u.user_metadata as Record<string, unknown> | undefined)?.full_name ?? String(u.email ?? '').split('@')[0]),
          // Same CEO lock as /api/auth/login — session restore must not
          // downgrade the boss either.
          role: profile?.role ?? (refreshCeo ? 'ceo' : 'sales'),
        },
      });
    }
    // ---- public auth: real self sign-up (owner directive 2026-09-01) ----
    // Creates an ACTUAL Supabase Auth user via the Admin API (service-role
    // key, never exposed to the client) and seeds its Postgres profile with
    // role='sales' — self-signup can never grant admin/CEO authority; an
    // hash is bound immediately (there is no other first-bind path for
    // non-CEO accounts), so a brand-new account can sign documents right away.
    // Also collects a phone number (stored on the real Supabase auth.users
    // row so it shows in the dashboard, AND mirrored into the Postgres
    // profile) and a RECOVERY STRING (≥15 chars, hashed with its own HMAC
    // POST /api/auth/reset-password for a mail/OTP-free password reset
    // (owner directive 2026-09-01).
    if (route === 'POST /api/auth/signup') {
      if (!SERVICE_ROLE) return err(503, 'Account registration is temporarily unavailable');
      const b = await req.json().catch(() => ({} as Record<string, unknown>));
      const name = String(b.name ?? '').trim().slice(0, 120);
      const email = String(b.email ?? '').trim().toLowerCase();
      const phone = String(b.phone ?? '').trim().slice(0, 32);
      const password = String(b.password ?? '');
      const recovery = String(b.recovery_string ?? '');
      const passportPhoto = String(b.passport_photo ?? '');
      if (!name) return err(400, 'Enter your full name');
      if (!email.includes('@')) return err(400, 'Enter a valid email');
      if (!/^\+[1-9]\d{7,14}$/.test(phone.replace(/[\s()\-]/g, '')))
        return err(400, 'Phone number must include country code, e.g. +2348033498452');
      if (!passportPhoto.startsWith('data:image/') || passportPhoto.length > 2_100_000)
        return err(400, 'A valid passport photograph under 1.5 MB is required');
      if (password.length < 6) return err(400, 'Password must be at least 6 characters');
      if (recovery.length < 15) return err(400, 'Recovery string must be at least 15 characters');
      if (recovery === password) return err(400, 'Recovery string must be different from your password');
      if (email === CEO_EMAIL) return err(400, 'The CEO account is pre-provisioned — sign in directly');

      // phone_confirm:true marks it pre-verified so GoTrue stores it on
      // auth.users WITHOUT dispatching an SMS/needing an SMS provider —
      // it just shows up in Authentication → Users like the owner wants.
      let createRes: Response;
      try {
        createRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
          method: 'POST',
          headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password, phone, phone_confirm: true, email_confirm: true, user_metadata: { full_name: name, name, phone, role: 'sales' } }),
        });
      } catch {
        return err(503, 'Auth service unreachable — try again shortly');
      }
      let created = await createRes.json().catch(() => ({} as Record<string, unknown>));
      if (!createRes.ok) {
        const msg = String((created as Record<string, unknown>).msg ?? (created as Record<string, unknown>).error_description ?? (created as Record<string, unknown>).error ?? '');
        const duplicate = createRes.status === 422 || /already.*(registered|exists)/i.test(msg);
        if (duplicate) {
          // Recover an orphaned Auth user left by an earlier profile
          // failure: prove ownership with the supplied password, then finish
          // creating the missing profile instead of permanently blocking signup.
          const login = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
            method: 'POST', headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
            body: JSON.stringify({ email, password }),
          });
          const existing = await login.json().catch(() => ({} as Record<string, unknown>));
          if (!login.ok) return err(409, 'An account with that email already exists');
          const existingUid = String(((existing as Record<string, unknown>).user as Record<string, unknown> | undefined)?.id ?? '');
          // Recovery is allowed only for a genuinely orphaned Auth user. Never
          // overwrite an existing profile: doing so could demote an Admin and
          // rotate their signature/recovery credentials through the signup UI.
          if (!existingUid || await (await coll.profiles()).findOne({ _id: existingUid })) {
            return err(409, 'An account with that email already exists');
          }
          created = { id: existingUid };
        } else if (createRes.status === 401 || createRes.status === 403) {
          return err(500, 'Server is not configured for self sign-up (SUPABASE_SERVICE_ROLE_KEY secret missing) — ask the CEO to check Supabase → Edge Functions → Secrets');
        }
        // A phone-related rejection (e.g. an SMS provider strictly
        // required in this project) shouldn't block account creation —
        // retry once without the phone field so sign-up still succeeds;
        // the phone number is still recorded in the Postgres profile below.
        if (!duplicate && /phone/i.test(msg)) {
          let retryRes: Response;
          try {
            retryRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
              method: 'POST',
              headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
              body: JSON.stringify({ email, password, email_confirm: true, user_metadata: { full_name: name, name, phone, role: 'sales' } }),
            });
          } catch {
            return err(503, 'Auth service unreachable — try again shortly');
          }
          created = await retryRes.json().catch(() => ({} as Record<string, unknown>));
          if (!retryRes.ok) {
            const msg2 = String((created as Record<string, unknown>).msg ?? (created as Record<string, unknown>).error_description ?? (created as Record<string, unknown>).error ?? '');
            return err(400, msg2 || 'Could not create the account');
          }
        } else if (!duplicate) {
          return err(400, msg || 'Could not create the account');
        }
      }
      const createdUser = created as Record<string, unknown>;
      const uid = String(createdUser.id ?? (createdUser.user as Record<string, unknown> | undefined)?.id ?? '');
      if (!uid) return err(500, 'Account created but no id was returned — try signing in');

      const recoverySalt = crypto.randomUUID().replaceAll('-', '').slice(0, 16);
      const fullName = name || email.split('@')[0];
      await (await coll.profiles()).updateOne(
        { _id: uid },
        { $set: {
          email, phone, full_name: fullName, role: 'sales',
          staff_id: `MFSL-${uid.replaceAll('-', '').slice(0, 8).toUpperCase()}`,
          passport_photo: passportPhoto,
          recovery_salt: recoverySalt, recovery_hash: await hashRecovery(recovery, recoverySalt),
          created_at: now(),
        } },
        { upsert: true },
      );
      profileCache.delete(uid);

      // sign the brand-new account straight in so the app lands the user
      // directly in the workspace, same shape as /api/auth/login above.
      let signInRes: Response;
      try {
        signInRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password }),
        });
      } catch {
        return err(503, 'Account created — sign in manually with your new email and password');
      }
      const sj = await signInRes.json().catch(() => ({} as Record<string, unknown>));
      if (!signInRes.ok) {
        return err(503, 'Account created — sign in manually with your new email and password');
      }
      return json({
        access_token: String((sj as Record<string, unknown>).access_token ?? ''),
        refresh_token: String((sj as Record<string, unknown>).refresh_token ?? ''),
        user: { uid, email, name: fullName, role: 'sales' },
      });
    }

    // ---- public auth: reset password with the recovery string (owner
    // directive 2026-09-01) — NO email/OTP round-trip. The user proves
    // ownership by typing the ≥15-char recovery string they set at sign-up;
    // it is verified against a salted HMAC hash using its own key (never
    if (route === 'POST /api/auth/reset-password') {
      const b = await req.json().catch(() => ({} as Record<string, unknown>));
      const email = String(b.email ?? '').trim().toLowerCase();
      const recovery = String(b.recovery_string ?? '');
      const newPassword = String(b.new_password ?? '');
      if (!email.includes('@')) return err(400, 'Enter a valid email');
      if (!recovery) return err(400, 'Enter your recovery string');
      if (newPassword.length < 6) return err(400, 'New password must be at least 6 characters');

      const profile = await (await coll.profiles()).findOne({ email }) as Record<string, unknown> | null;
      if (!profile || !profile.recovery_hash || !profile.recovery_salt) {
        // Same generic message whether the email is unknown or has no
        // recovery string on file — never reveal which via the error text.
        return err(401, 'Recovery string does not match this account');
      }
      const hash = await hashRecovery(recovery, String(profile.recovery_salt));
      if (hash !== profile.recovery_hash) {
        return err(401, 'Recovery string does not match this account');
      }
      const uid = String(profile._id);
      let updRes: Response;
      try {
        updRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${uid}`, {
          method: 'PUT',
          headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ password: newPassword }),
        });
      } catch {
        return err(503, 'Auth service unreachable — try again shortly');
      }
      if (!updRes.ok) {
        const j = await updRes.json().catch(() => ({} as Record<string, unknown>));
        return err(400, String((j as Record<string, unknown>).msg ?? (j as Record<string, unknown>).error_description ?? 'Could not reset the password'));
      }
      profileCache.delete(uid);
      return json({ ok: true });
    }

    // ---- public auth: reset the RECOVERY STRING (owner directive
    // required together — either alone is rejected. Verifies the password
    // salted hash, then rotates the recovery salt+hash.
    if (route === 'POST /api/auth/reset-recovery') {
      const b = await req.json().catch(() => ({} as Record<string, unknown>));
      const email = String(b.email ?? '').trim().toLowerCase();
      const password = String(b.password ?? '');
      const newRecovery = String(b.new_recovery_string ?? '');
      if (!email.includes('@')) return err(400, 'Enter a valid email');
      if (!password) return err(400, 'Enter your account password');
      if (newRecovery.length < 15) return err(400, 'Recovery string must be at least 15 characters');
      if (newRecovery === password) return err(400, 'Recovery string must be different from your password');

      let gr: Response;
      try {
        gr = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
          method: 'POST',
          headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ email, password }),
        });
      } catch {
        return err(503, 'Auth service unreachable — try again shortly');
      }
      if (!gr.ok) return err(401, 'Account password is incorrect');

      const profile = await (await coll.profiles()).findOne({ email }) as Record<string, unknown> | null;
      if (!profile) return err(404, 'No account found for that email');
      const uid = String(profile._id);

      const recoverySalt = crypto.randomUUID().replaceAll('-', '').slice(0, 16);
      await (await coll.profiles()).updateOne(
        { _id: uid },
        { $set: { recovery_salt: recoverySalt, recovery_hash: await hashRecovery(newRecovery, recoverySalt) } },
      );
      profileCache.delete(uid);
      return json({ ok: true });
    }

    const user = await auth(req);

    switch (route) {
      case 'GET /api/me':
        return json({ user: { uid: user.uid, email: user.email, name: user.name, role: user.role } });

      // cheap "did anything change?" poll: the newest audit event id/time
      case 'GET /api/changes': {
        const last = await (await coll.audit()).find({}).sort({ at: -1 }).limit(1).toArray();
        return json({ stamp: last[0] ? `${last[0].at}|${last[0]._id}` : '' });
      }
      case 'GET /api/bootstrap': {
        await ensureCore();
        const [products, customers, settings, serials, txns, receipts, invoices, docs, sales, mils, adjustments] = await Promise.all([
          (await coll.products()).find({}).sort({ name: 1 }).limit(1000).toArray(),
          (await coll.customers()).find({}).sort({ name: 1 }).limit(1000).toArray(),
          (await coll.settings()).findOne({ _id: 'settings' }),
          peekSerials(),
          (await coll.txns()).find({}).sort({ txn_date: -1 }).limit(300).toArray(),
          (await coll.receipts()).find({}).sort({ created_at: -1 }).limit(300).toArray(),
          (await coll.invoices()).find({}).sort({ created_at: -1 }).limit(300).toArray(),
          (await coll.archive()).find({}).sort({ issued_at: -1 }).limit(100).toArray(),
          (await coll.sales()).find({}).sort({ created_at: -1 }).limit(300).toArray(),
          (await coll.mils()).find({}).sort({ created_at: -1 }).limit(300).toArray(),
          (await coll.adjustments()).find({}).sort({ created_at: -1 }).limit(300).toArray(),
        ]);
        // Hand-drawn signatures are large base64 PNGs and were duplicated in
        // both sale and receipt rows. Returning hundreds of them made the
        // authenticated bootstrap exceed the Edge gateway response limit,
        // which Cloudflare reported as HTTP 520. Lists only need metadata;
        // generated PDFs retain signatures in their authoritative records.
        const lightSales = sales.map(({ customer_signature: _signature, ...row }) => row);
        const lightReceipts = receipts.map(({ customer_signature: _signature, ...row }) => row);
        return json({
          user: { uid: user.uid, email: user.email, name: user.name, role: user.role },
          products, customers, transactions: txns, receipts: lightReceipts, invoices, docs, sales: lightSales, mils, adjustments,
          settings: {
            vat_enabled: settings?.vat_enabled ?? false,
            vat_rate: settings?.vat_rate ?? 0.075,
            watermark: settings?.watermark ?? true,
          },
          serials,
        });
      }

      // ---- signed-in: change the account password (Settings → Account).
      // Verifies the current password via a GoTrue token exchange, then the
      // Admin API sets the new one. No email/OTP round-trip.
      case 'POST /api/auth/change-password': {
        const b = await req.json();
        const current = String(b.current_password ?? '');
        const next = String(b.new_password ?? '');
        if (!current) throw new HttpErr(400, 'Enter your current password');
        if (next.length < 6) throw new HttpErr(400, 'New password must be at least 6 characters');
        if (next === current) throw new HttpErr(400, 'New password must be different from your current password');
        let gr: Response;
        try {
          gr = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
            method: 'POST',
            headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: user.email, password: current }),
          });
        } catch {
          throw new HttpErr(503, 'Auth service unreachable — try again shortly');
        }
        if (!gr.ok) throw new HttpErr(401, 'Current password is incorrect');
        const upd = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${user.uid}`, {
          method: 'PUT',
          headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ password: next }),
        });
        if (!upd.ok) throw new HttpErr(400, 'Could not update the password right now — please try again shortly');
        profileCache.delete(user.uid);
        await audit('core', 'change-password', user.uid, user);
        return json({ ok: true });
      }

      case 'GET /api/customers': {
        const rows = await (await coll.customers()).find({}).sort({ name: 1 }).limit(2000).toArray();
        return json({ customers: rows });
      }
      case 'GET /api/products': {
        const rows = await (await coll.products()).find({}).sort({ name: 1 }).limit(5000).toArray();
        return json({ products: rows });
      }
      // ---- older history, paged (the bootstrap only carries the latest
      // 300 of each; the app asks here for anything before a given date).
      case 'GET /api/history': {
        const kind = url.searchParams.get('kind') ?? '';
        const before = url.searchParams.get('before') ?? '';
        const limit = Math.min(500, Math.max(1, Number(url.searchParams.get('limit')) || 300));
        const sources: Record<string, [() => Promise<any>, string]> = {
          sales: [coll.sales, 'created_at'], receipts: [coll.receipts, 'created_at'],
          invoices: [coll.invoices, 'created_at'], transactions: [coll.txns, 'txn_date'],
          mils: [coll.mils, 'created_at'], adjustments: [coll.adjustments, 'created_at'],
          docs: [coll.archive, 'issued_at'],
        };
        const src = sources[kind];
        if (!src) throw new HttpErr(400, 'Unknown history kind');
        const q = before ? { [src[1]]: { $lt: before } } : {};
        const rows = await (await src[0]()).find(q).sort({ [src[1]]: -1 }).limit(limit).toArray();
        return json({ rows, more: rows.length === limit });
      }
      case 'POST /api/customers': {
        const b = await req.json();
        if (!b.name || String(b.name).trim().length < 2) throw new HttpErr(400, 'Customer name required');
        if (String(b.phone ?? '') && !internationalPhone(String(b.phone)))
          throw new HttpErr(400, 'Phone number must include country code, e.g. +2348033498452');
        // de-duplicate: same normalised name (+ same phone when both given)
        // returns the existing record instead of creating a twin
        const existing = await findDuplicateCustomer(String(b.name), String(b.phone ?? ''));
        if (existing) return json({ customer: existing, duplicate: true }, 200);
        const doc = {
          name: String(b.name).trim().slice(0, 120),
          kind: b.corp || b.kind === 'corporate' ? 'corporate' : 'individual',
          phone: String(b.phone ?? ''), email: String(b.email ?? ''), address: String(b.address ?? ''),
          credit_balance: 0, created_by: user.uid, created_at: now(),
        };
        const out = await ins(coll.customers(), doc);
        await audit('customers', 'create', String(out.insertedId), user);
        await notify('customer', 'New customer added', `${user.name} added ${doc.name} as a customer`, String(out.insertedId), user);
        return json({ customer: { ...doc, _id: out.insertedId } }, 201);
      }

      case 'POST /api/products/upsert': {
        requireRole(user, ['ceo', 'admin'], 'edit stock / import products');
        const b = await req.json();
        const rows = Array.isArray(b.products) ? b.products : [b];
        let upserted = 0;
        for (const r of rows) {
          if (!r.id || !r.name) continue;
          const productCollection = await coll.products();
          const normalizedName = String(r.name).trim().replace(/\s+/g, ' ');
          const duplicate = await productCollection.findOne({
            _id: { $ne: String(r.id) },
            name: { $regex: `^${normalizedName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, $options: 'i' },
          });
          if (duplicate) throw new HttpErr(409, `Stock item "${normalizedName}" already exists`);
          await productCollection.updateOne({ _id: String(r.id) }, { $set: {
            name: normalizedName, brand: String(r.brand ?? '').trim().slice(0, 100), category: r.category ?? 'Fire',
            cost_price: Number(r.cost_price) || 0, selling_price: Number(r.selling_price) || 0,
            qty_on_hand: Math.max(0, Math.trunc(Number(r.qty_on_hand) || 0)),
            reorder_level: Math.max(0, Math.trunc(Number(r.reorder_level) || 0)),
            unit: r.unit ?? 'unit',
            length: Number.isFinite(Number(r.length)) ? Number(r.length) : null,
            length_unit: String(r.length_unit ?? ''),
            width: Number.isFinite(Number(r.width)) ? Number(r.width) : null,
            width_unit: String(r.width_unit ?? ''),
            size: Number.isFinite(Number(r.size)) ? Number(r.size) : null,
            size_unit: String(r.size_unit ?? ''),
            weight: Number.isFinite(Number(r.weight)) ? Math.max(0, Number(r.weight)) : null,
            weight_unit: ['mg', 'g', 'kg', 'tonne', 'oz', 'lb'].includes(String(r.weight_unit))
              ? String(r.weight_unit) : '',
            image_urls: Array.isArray(r.image_urls) ? r.image_urls.map(String).slice(0, 10) : [],
            is_service: !!r.is_service, updated_at: now(),
          } }, { upsert: true });
          upserted++;
        }
        await audit('inventory', 'upsert', `${upserted} products`, user);
        await notify('product', 'Stock catalogue updated', `${user.name} added/updated ${upserted} product${upserted === 1 ? '' : 's'}`, `${upserted}`, user);
        return json({ ok: true, upserted });
      }

      case 'POST /api/products/images': {
        requireRole(user, ['ceo', 'admin'], 'upload stock images');
        const b = await req.json();
        const productId = String(b.product_id ?? '').trim();
        const images = Array.isArray(b.images) ? b.images.slice(0, 10) : [];
        if (!productId || !images.length) throw new HttpErr(400, 'Product and image required');
        // Images alone live in Supabase Storage. Product and transaction data
        // remain in the database. Ensure the dedicated public bucket exists.
        await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
          method: 'POST', headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ id: 'stock-images', name: 'stock-images', public: true, file_size_limit: 5242880, allowed_mime_types: ['image/jpeg','image/png','image/webp'] }),
        });
        const urls: string[] = [];
        for (let i = 0; i < images.length; i++) {
          const match = String(images[i]).match(/^data:(image\/(?:jpeg|png|webp));base64,(.+)$/);
          if (!match) throw new HttpErr(400, 'Only JPEG, PNG or WebP images are accepted');
          const binary = Uint8Array.from(atob(match[2]), c => c.charCodeAt(0));
          if (binary.length > 5 * 1024 * 1024) throw new HttpErr(400, 'Each stock image must be under 5 MB');
          const ext = match[1].split('/')[1].replace('jpeg', 'jpg');
          const path = `${productId}/${crypto.randomUUID()}.${ext}`;
          const uploaded = await fetch(`${SUPABASE_URL}/storage/v1/object/stock-images/${path}`, {
            method: 'POST', headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': match[1], 'x-upsert': 'false' }, body: binary,
          });
          if (!uploaded.ok) throw new HttpErr(502, `Stock image upload failed: ${await uploaded.text()}`);
          urls.push(`${SUPABASE_URL}/storage/v1/object/public/stock-images/${path}`);
        }
        return json({ urls }, 201);
      }

      case 'POST /api/products/delete': {
        requireRole(user, ['ceo'], 'delete products');
        const b = await req.json();
        const id = String(b.id ?? '').trim();
        if (!id) throw new HttpErr(400, 'Product id required');
        const result = await (await coll.products()).deleteOne({ _id: id });
        if (!result.deletedCount) throw new HttpErr(404, 'Product not found');
        await audit('inventory', 'delete-product', id, user);
        await notify('product', 'Product deleted', `${user.name} removed product ${id} from the active catalogue`, id, user);
        return json({ ok: true });
      }

      case 'POST /api/customers/delete': {
        requireRole(user, ['ceo'], 'delete customers');
        const b = await req.json();
        const id = String(b.id ?? '').trim();
        if (!id) throw new HttpErr(400, 'Customer id required');
        const customerCollection = await coll.customers();
        let result = await customerCollection.deleteOne({ _id: id });
        if (!result.deletedCount && /^[0-9a-f]{24}$/i.test(id)) {
          result = await customerCollection.deleteOne({ _id: new ObjectId(id) });
        }
        if (!result.deletedCount) throw new HttpErr(404, 'Customer not found');
        await audit('customers', 'delete', id, user);
        await notify('customer', 'Customer deleted', `${user.name} removed a customer from the active directory`, id, user);
        return json({ ok: true });
      }

      case 'POST /api/stock/adjust': {
        requireRole(user, ['ceo', 'admin'], 'edit stock');
        const b = await req.json();
        const delta = Math.trunc(Number(b.delta) || 0);
        if (!delta) throw new HttpErr(400, 'Quantity change required');
        const guarded = await (await coll.products()).updateOne(
          { _id: String(b.id), $expr: { $gte: [{ $add: ['$qty_on_hand', delta] }, 0] } },
          { $inc: { qty_on_hand: delta }, $set: { updated_at: now() } });
        if (!guarded.matchedCount) throw new HttpErr(400, 'Unknown product or adjustment would drive stock negative');
        const adj = { product_id: String(b.id), delta, reason: String(b.reason ?? 'CORRECTION'), note: String(b.note ?? ''), by: user.uid, by_name: user.name, created_at: now() };
        await (await coll.adjustments()).insertOne(adj);
        await audit('inventory', 'adjust', `${b.id} ${delta > 0 ? '+' : ''}${delta}`, user);
        await notify('stock', 'Stock adjusted', `${user.name} ${delta > 0 ? 'added' : 'removed'} ${Math.abs(delta)} unit${Math.abs(delta) === 1 ? '' : 's'} (${adj.reason})`, String(b.id), user);
        return json({ ok: true, adjustment: adj });
      }

      case 'POST /api/sales': {
        const b = await req.json();
        const issueKey = String(b.issue_key ?? '').trim().slice(0, 180);
        if (!issueKey) throw new HttpErr(400, 'Sale issue key required');
        // Every role uses this same endpoint. A retry after a timeout returns
        // the original cloud sale instead of decrementing stock or creating
        // another transaction/receipt.
        const existingSale = await (await coll.sales()).findOne({ issue_key: issueKey, signed_by: user.uid }) as Record<string, unknown> | null;
        if (existingSale) return json({
          ok: true, server_applied: true, duplicate: true,
          sale_id: String(existingSale._id), total: Number(existingSale.total) || 0,
          receipt_no: existingSale.receipt_no ?? null,
          invoice_no: existingSale.invoice_no ?? null,
        });
        const items = Array.isArray(b.items) ? b.items : [];
        if (!items.length) throw new HttpErr(400, 'Cart is empty');
        const method = ['cash', 'transfer', 'pos', 'credit'].includes(b.method) ? b.method : 'cash';
        const products = await coll.products();
        const lines: Array<Record<string, unknown>> = [];
        let subtotal = 0;
        for (const it of items) {
          const p = await products.findOne({ _id: String(it.product_id) }) as Record<string, unknown> | null;
          if (!p) throw new HttpErr(400, `Unknown product ${it.product_id}`);
          const qty = Math.trunc(Number(it.qty) || 0);
          if (qty <= 0) throw new HttpErr(400, 'Invalid quantity');
          if (!p.is_service) {
            const g = await products.updateOne(
              { _id: p._id, qty_on_hand: { $gte: qty } },
              { $inc: { qty_on_hand: -qty }, $set: { updated_at: now() } });
            if (!g.modifiedCount) throw new HttpErr(400, `Only ${p.qty_on_hand} ${p.unit} of ${p.name} in stock`);
          }
          subtotal += Number(p.selling_price) * qty;
          lines.push({ product_id: p._id, name: p.name, qty, unit_price: p.selling_price });
        }
        const discount = Math.max(0, Math.trunc(Number(b.discount) || 0));
        const total = Math.max(subtotal - discount, 0);

        let customerId: string | null = b.customerId ?? null;
        let customerName = 'Walk-in customer';
        const customers = await coll.customers();
        if (customerId) {
          const c = await customers.findOne({ _id: customerId }) as Record<string, unknown> | null;
          if (!c) throw new HttpErr(400, 'Unknown customer');
          customerName = String(c.name);
        } else if (b.customer && String(b.customer.name ?? '').trim().length > 1) {
          if (String(b.customer.phone ?? '') && !internationalPhone(String(b.customer.phone)))
            throw new HttpErr(400, 'Phone number must include country code, e.g. +2348033498452');
          const doc = { name: String(b.customer.name).trim(), kind: 'individual', phone: String(b.customer.phone ?? ''), email: String(b.customer.email ?? ''), address: '', credit_balance: 0, created_by: user.uid, created_at: now() };
          const r = await customers.insertOne(doc);
          customerId = String(r.insertedId);
          customerName = doc.name;
        }

        const t = now();
        const sale = { issue_key: issueKey, customer_id: customerId, customer_name: customerName, customer_contact: String(b.customer_contact ?? ''), method, discount, total, items: lines, signed_by: user.uid, signed_name: user.name, customer_signature: String(b.customer_signature ?? ''), created_at: t };
        const saleOut = await ins(coll.sales(), sale);
        // Credit is an accounts-receivable event, not cash received. Keep it
        // in the unified ledger but do not issue a payment receipt or count it
        // as revenue until an invoice payment arrives.
        const txnType = method === 'credit' ? 'creditSale' : 'salePayment';
        const txnOut = await ins(coll.txns(), { txn_type: txnType, method, amount: total, reference: String(saleOut.insertedId), txn_date: t, created_by: user.uid });
        let recNo: string | null = null;
        if (method !== 'credit') {
          recNo = 'MTK-REC-' + pad9(await nextSerial('receiptIssue'));
          await (await coll.receipts()).insertOne({ no: recNo, amount: total, method, source: 'sale', customer_id: customerId, customer_name: customerName, customer_contact: String(b.customer_contact ?? ''), issued_by: user.uid, issued_name: user.name, customer_signature: String(b.customer_signature ?? ''), txn_id: String(txnOut.insertedId), sale_id: String(saleOut.insertedId), created_at: t });
        }
        let invoiceNo: string | null = null;
        if (method === 'credit' && customerId) {
          await customers.updateOne({ _id: customerId }, { $inc: { credit_balance: total } });
          invoiceNo = 'MTK-INV-' + pad9(await nextSerial('invoice'));
          await (await coll.invoices()).insertOne({ no: invoiceNo, customer_id: customerId, customer_name: customerName, status: 'sent', subtotal, vat: 0, total, amount_paid: 0, items: lines, issued_by: user.uid, created_at: t, updated_at: t });
        }
        await (await coll.sales()).updateOne({ _id: saleOut.insertedId }, {
          $set: { receipt_no: recNo, invoice_no: invoiceNo },
        });
        const reference = invoiceNo ?? recNo ?? String(saleOut.insertedId);
        await audit('billing', method === 'credit' ? 'credit-sale' : 'sale', reference, user);
        await notify(
          'transaction',
          method === 'credit' ? 'New credit sale recorded' : 'New sale recorded',
          `${user.name} recorded a ${fmtN(total)} ${method === 'credit' ? 'credit ' : ''}sale for ${customerName} (${reference})`,
          reference,
          user,
        );
        return json({ ok: true, server_applied: true, sale_id: String(saleOut.insertedId), total, receipt_no: recNo, invoice_no: invoiceNo }, 201);
      }

      case 'POST /api/invoices/pay': {
        const b = await req.json();
        // Idempotency: ApiClient replays a POST once after a 401/token
        // refresh. Without a key that charged the invoice twice. The key is
        // deterministic on the client (invoice + balance + amount) so a
        // retried payment returns the SAME receipt instead of a second one.
        const issueKey = String(b.issue_key ?? '').slice(0, 180);
        if (issueKey) {
          const prior = await (await coll.payments()).findOne({
            issue_key: issueKey, invoice_no: String(b.no ?? ''),
          });
          if (prior) {
            return json({ ok: true, receipt_no: prior.receipt_no,
              status: prior.status ?? 'partial', duplicate: true });
          }
        }
        const invoices = await coll.invoices();
        const inv = await invoices.findOne({ no: String(b.no ?? '') }) as Record<string, unknown> | null;
        if (!inv) throw new HttpErr(404, 'Invoice not found');
        const amount = Math.trunc(Number(b.amount) || 0);
        const balance = Number(inv.total) - Number(inv.amount_paid ?? 0);
        if (balance <= 0) throw new HttpErr(400, `${inv.no} is fully paid`);
        const pay = Math.min(amount > 0 ? amount : balance, balance);
        const method = ['cash', 'transfer', 'pos'].includes(b.method) ? b.method : 'transfer';
        const t = now();
        const upd = await invoices.updateOne(
          { no: String(inv.no), $expr: { $lte: ['$amount_paid', '$total'] } },
          { $inc: { amount_paid: pay }, $set: { status: Number(inv.amount_paid ?? 0) + pay >= Number(inv.total) ? 'paid' : 'partial', updated_at: t } });
        if (!upd.modifiedCount) throw new HttpErr(409, 'Payment raced another update — retry');
        const txnOut = await ins(coll.txns(), { txn_type: 'invoicePayment', method, amount: pay, reference: String(inv.no), txn_date: t, created_by: user.uid });
        const recNo = 'MTK-REC-' + pad9(await nextSerial('receiptIssue'));
        await (await coll.receipts()).insertOne({ no: recNo, amount: pay, method, source: 'invoice', invoice_no: inv.no, customer_id: inv.customer_id ?? null, customer_name: inv.customer_name ?? '—', customer_contact: String(b.customer_contact ?? ''), issued_by: user.uid, issued_name: user.name, txn_id: String(txnOut.insertedId), created_at: t });
        await (await coll.payments()).insertOne({ invoice_no: inv.no, amount: pay, method,
          receipt_no: recNo, issue_key: issueKey || null,
          status: Number(inv.amount_paid ?? 0) + pay >= Number(inv.total) ? 'paid' : 'partial',
          created_by: user.uid, created_at: t });
        await audit('billing', 'invoice-payment', `${inv.no} ${pay}`, user);
        await notify('transaction', 'Invoice payment received', `${user.name} recorded a ${fmtN(pay)} payment against ${inv.no}`, String(inv.no), user);
        return json({ ok: true, receipt_no: recNo, status: Number(inv.amount_paid ?? 0) + pay >= Number(inv.total) ? 'paid' : 'partial' });
      }

      case 'GET /api/payment-vouchers': {
        requireRole(user, ['ceo', 'admin'], 'view payment vouchers');
        return json({ rows: await (await coll.vouchers()).find({}).sort({ created_at: -1 }).limit(300).toArray() });
      }
      case 'POST /api/payment-vouchers': {
        requireRole(user, ['ceo', 'admin'], 'prepare payment vouchers');
        const b = await req.json();
        const amount = Math.max(0, Math.trunc(Number(b.amount) || 0));
        if (!String(b.payee ?? '').trim() || !String(b.particulars ?? '').trim() || !amount)
          throw new HttpErr(400, 'Payee, particulars and amount are required');
        const serial = await nextSerial('paymentvoucher');
        const record = { serial, voucher_date: String(b.date ?? now()), payee: String(b.payee).slice(0, 120),
          particulars: String(b.particulars).slice(0, 1000), amount,
          method: ['cash','transfer','cheque','pos'].includes(String(b.method)) ? String(b.method) : 'cash',
          cheque_no: String(b.cheque_no ?? ''), debit_account: String(b.debit_account ?? ''),
          status: 'pending', prepared_by: user.uid, prepared_name: user.name,
          checked_by: user.uid, checked_name: user.name, created_at: now() };
        const out = await (await coll.vouchers()).insertOne(record);
        await notify('voucherApproval', 'Payment Voucher awaiting approval',
          `${user.name} submitted Payment Voucher ${pad9(serial)} for ${record.payee}.`, String(out.insertedId), user);
        await audit('billing', 'voucher-create', `Payment Voucher ${pad9(serial)}`, user);
        return json({ voucher: { _id: out.insertedId, ...record } }, 201);
      }
      case 'POST /api/payment-vouchers/approve': {
        requireRole(user, ['ceo'], 'approve payment vouchers');
        const b = await req.json();
        let id: InstanceType<typeof ObjectId>; try { id = new ObjectId(String(b.id ?? '')); } catch { throw new HttpErr(400, 'Invalid voucher'); }
        const vouchers = await coll.vouchers();
        const voucher = await vouchers.findOneAndUpdate({ _id: id, status: 'pending' },
          { $set: { status: 'processing' } }, { returnDocument: 'before' });
        if (!voucher) { const old = await vouchers.findOne({ _id: id }); if (old?.status === 'paid' || old?.status === 'processing') return json({ ok: true }); throw new HttpErr(404, 'Pending voucher not found'); }
        const t = now();
        await (await coll.txns()).insertOne({ txn_type: 'expense', method: voucher.method,
          amount: voucher.amount, reference: `PV-${pad9(Number(voucher.serial))}`, txn_date: t, created_by: user.uid });
        await vouchers.updateOne({ _id: id }, { $set: { status: 'paid', approved_by: user.uid,
          approved_name: user.name, paid_by: user.uid, paid_name: user.name, paid_at: t } });
        await (await coll.notifications()).updateMany({ kind: 'voucherApproval', ref: String(id) },
          { $set: { kind: 'transaction', title: 'Payment Voucher approved', message: `Payment Voucher ${pad9(Number(voucher.serial))} was paid.` } });
        await audit('billing', 'voucher-pay', `Payment Voucher ${pad9(Number(voucher.serial))}`, user);
        return json({ ok: true });
      }

      case 'GET /api/stock-receipts': {
        requireRole(user, ['ceo', 'admin'], 'view stock receipts');
        const rows = await (await coll.stockReceipts()).find({}).sort({ created_at: -1 }).limit(300).toArray();
        return json({ rows });
      }

      case 'POST /api/stock-receipts': {
        requireRole(user, ['ceo', 'admin'], 'prepare stock receipts');
        const b = await req.json();
        const input = Array.isArray(b.rows) ? b.rows : [];
        const rows = input.map((r: Record<string, unknown>, i: number) => ({
          sno: i + 1, product_id: String(r.product_id ?? ''),
          particulars: String(r.particulars ?? '').slice(0, 160),
          quantity: Math.max(0, Math.trunc(Number(r.quantity) || 0)),
          damaged: Math.max(0, Math.trunc(Number(r.damaged) || 0)),
          missing: Math.max(0, Math.trunc(Number(r.missing) || 0)),
        })).filter((r: Record<string, unknown>) => r.product_id && Number(r.quantity) > 0);
        if (!rows.length) throw new HttpErr(400, 'Add at least one stock item');
        for (const r of rows) {
          if (Number(r.damaged) + Number(r.missing) > Number(r.quantity))
            throw new HttpErr(400, `Deficits exceed quantity on row ${r.sno}`);
          if (!await (await coll.products()).findOne({ _id: r.product_id }))
            throw new HttpErr(400, `Unknown stock item on row ${r.sno}`);
        }
        const serial = await nextSerial('stockreceipt');
        const record = { serial, receipt_date: String(b.date ?? now()), rows,
          status: 'pending', receiver_id: user.uid, receiver_name: user.name,
          receiver_signature: String(b.receiver_signature ?? ''), created_at: now() };
        const out = await (await coll.stockReceipts()).insertOne(record);
        await audit('inventory', 'stock-receipt-create', `Stock Receipt ${pad9(serial)}`, user);
        await notify('stockApproval', 'Stock Receipt awaiting approval',
          `${user.name} submitted Stock Receipt ${pad9(serial)} for your approval.`,
          String(out.insertedId), user);
        return json({ receipt: { _id: out.insertedId, ...record } }, 201);
      }

      case 'POST /api/stock-receipts/approve': {
        requireRole(user, ['ceo'], 'approve stock receipts');
        const b = await req.json();
        // general document signature prompt is disabled in Settings.
        let id: InstanceType<typeof ObjectId>;
        try { id = new ObjectId(String(b.id ?? '')); } catch { throw new HttpErr(400, 'Invalid stock receipt'); }
        const c = await coll.stockReceipts();
        // Atomically claim approval: repeated/double taps cannot add stock twice.
        const receipt = await c.findOneAndUpdate(
          { _id: id, status: 'pending' }, { $set: { status: 'processing' } },
          { returnDocument: 'before' });
        if (!receipt) {
          const existing = await c.findOne({ _id: id });
          if (!existing) throw new HttpErr(404, 'Stock receipt not found');
          if (existing.status === 'approved' || existing.status === 'processing') return json({ ok: true, receipt: existing });
          throw new HttpErr(409, 'Stock receipt cannot be approved');
        }
        for (const r of receipt.rows ?? []) {
          const net = Math.max(0, Number(r.quantity) - Number(r.damaged) - Number(r.missing));
          if (net) await (await coll.products()).updateOne({ _id: String(r.product_id) }, { $inc: { qty_on_hand: net }, $set: { updated_at: now() } });
          await (await coll.adjustments()).insertOne({ product_id: String(r.product_id), delta: net,
            reason: 'restock', note: `Stock Receipt ${pad9(Number(receipt.serial))}; damaged ${r.damaged}; missing ${r.missing}`,
            by: user.uid, by_name: user.name, created_at: now() });
        }
        await c.updateOne({ _id: id, status: 'pending' }, { $set: { status: 'approved', approved_at: now(),
          approver_id: user.uid, approver_name: user.name, approval_signature: String(b.approval_signature ?? '') } });
        await (await coll.notifications()).updateMany(
          { kind: 'stockApproval', ref: String(id) },
          { $set: { kind: 'stock', title: 'Stock Receipt approved',
            message: `Stock Receipt ${pad9(Number(receipt.serial))} was approved by ${user.name}.` } });
        await audit('inventory', 'stock-receipt-approve', `Stock Receipt ${pad9(Number(receipt.serial))}`, user);
        await notify('stock', 'Stock quantities updated',
          `Stock Receipt ${pad9(Number(receipt.serial))} was approved and net quantities were added.`,
          String(id), user);
        return json({ ok: true });
      }

      case 'POST /api/settings': {
        requireRole(user, ['ceo'], 'change settings or seed data');
        const b = await req.json();
        const set: Record<string, unknown> = {};
        if (typeof b.vatEnabled === 'boolean') set.vat_enabled = b.vatEnabled;
        if (typeof b.vatRate === 'number' && b.vatRate >= 0 && b.vatRate <= 0.5) set.vat_rate = b.vatRate;
        if (typeof b.watermark === 'boolean') set.watermark = b.watermark;
        const st = await coll.settings();
        if (Object.keys(set).length) await st.updateOne({ _id: 'settings' }, { $set: set });
        if (b.reseed && BOOK_TYPES.includes(b.reseed.type)) {
          const v = Math.trunc(Number(b.reseed.value));
          if (v < 0) throw new HttpErr(400, 'Invalid serial value');
          await (await coll.serials()).updateOne({ _id: b.reseed.type }, { $set: { last_used: v } }, { upsert: true });
        }
        await audit('core', 'settings', JSON.stringify({ ...set, reseed: b.reseed ?? null }), user);
        return json({ ok: true, settings: await st.findOne({ _id: 'settings' }), serials: await peekSerials() });
      }

      case 'GET /api/office-files': {
        const kind = String(url.searchParams.get('kind') ?? '');
        if (!['sheet', 'slide'].includes(kind)) throw new HttpErr(400, 'Invalid office file type');
        const rows = await (await coll.officeFiles()).find({ kind, deleted_at: { $exists: false } })
          .sort({ updated_at: -1 }).limit(200).toArray();
        return json({ files: rows.map((r: Record<string, unknown>) => ({
          id: String(r._id), kind: r.kind, title: r.title, content: r.content,
          owner: r.owner, owner_name: r.owner_name, revision: r.revision ?? 1,
          created_at: r.created_at, updated_at: r.updated_at,
        })) });
      }
      case 'POST /api/office-files/save': {
        const b = await req.json();
        const kind = String(b.kind ?? '');
        if (!['sheet', 'slide'].includes(kind)) throw new HttpErr(400, 'Invalid office file type');
        const id = String(b.id ?? crypto.randomUUID()).replace(/[^A-Za-z0-9_-]/g, '').slice(0, 80);
        const title = String(b.title ?? '').trim().slice(0, 180);
        if (!title) throw new HttpErr(400, 'A title is required');
        const content = b.content;
        const encoded = new TextEncoder().encode(JSON.stringify(content));
        if (encoded.length > 2_000_000) throw new HttpErr(413, 'Office file is too large');
        const collection = await coll.officeFiles();
        const existing = await collection.findOne({ _id: id }) as Record<string, unknown> | null;
        if (existing && existing.owner !== user.uid && !['ceo', 'admin'].includes(user.role))
          throw new HttpErr(403, 'Only the owner or management can edit this file');
        const baseRevision = Number(b.base_revision ?? 0);
        const currentRevision = Number(existing?.revision ?? 0);
        if (existing && baseRevision !== currentRevision)
          throw new HttpErr(409, 'This file changed on another device. Reload it before saving.');
        const timestamp = now();
        const unchanged = existing && existing.title === title && JSON.stringify(existing.content) === JSON.stringify(content);
        if (unchanged) return json({ ok: true, id, revision: currentRevision, unchanged: true });
        await collection.updateOne({ _id: id }, { $set: {
          kind, title, content, owner: existing?.owner ?? user.uid,
          owner_name: existing?.owner_name ?? user.name, updated_by: user.uid,
          updated_by_name: user.name, updated_at: timestamp,
          created_at: existing?.created_at ?? timestamp, revision: currentRevision + 1,
        } }, { upsert: true });
        await audit('documents', `save-office-${kind}`, title, user);
        return json({ ok: true, id, revision: currentRevision + 1 });
      }
      case 'POST /api/office-files/delete': {
        const b = await req.json();
        const id = String(b.id ?? '');
        const collection = await coll.officeFiles();
        const existing = await collection.findOne({ _id: id }) as Record<string, unknown> | null;
        if (!existing) throw new HttpErr(404, 'Office file not found');
        if (existing.owner !== user.uid && !['ceo', 'admin'].includes(user.role))
          throw new HttpErr(403, 'Only the owner or management can delete this file');
        await collection.updateOne({ _id: id }, { $set: { deleted_at: now(), deleted_by: user.uid } });
        await audit('documents', 'delete-office-file', String(existing.title ?? id), user);
        return json({ ok: true });
      }
      case 'GET /api/office-documents': {
        const rows = await (await coll.officeDocs()).find({ deleted_at: { $exists: false } })
          .sort({ updated_at: -1 }).limit(500).toArray();
        return json({ documents: rows.map((r: Record<string, unknown>) => ({
          id: String(r._id), title: r.title, blocks: r.blocks, owner: r.owner,
          owner_name: r.owner_name, created_at: r.created_at, updated_at: r.updated_at,
          revision: r.revision ?? 1,
          versions: Array.isArray(r.versions) ? (r.versions as Array<Record<string, unknown>>).map(v => ({
            revision: v.revision, saved_at: v.saved_at, saved_by_name: v.saved_by_name ?? '',
          })) : [],
        })) });
      }
      case 'POST /api/office-documents/save': {
        const b = await req.json();
        const id = String(b.id ?? crypto.randomUUID()).replace(/[^A-Za-z0-9_-]/g, '').slice(0, 80);
        const title = String(b.title ?? '').trim().slice(0, 160);
        const blocks = Array.isArray(b.blocks) ? b.blocks.slice(0, 300) : [];
        if (!id || !title) throw new HttpErr(400, 'Document title is required');
        const encodedSize = new TextEncoder().encode(JSON.stringify(blocks)).length;
        if (encodedSize > 2_000_000) throw new HttpErr(400, 'Editable document exceeds the 2 MB limit');
        const collection = await coll.officeDocs();
        const existing = await collection.findOne({ _id: id }) as Record<string, unknown> | null;
        if (existing && existing.owner !== user.uid && !['ceo', 'admin'].includes(user.role)) {
          throw new HttpErr(403, 'Only the owner or management can edit this document');
        }
        const currentRevision = Number(existing?.revision ?? 0);
        const baseRevision = Number(b.base_revision ?? currentRevision);
        if (existing && baseRevision !== currentRevision) {
          throw new HttpErr(409, 'This document changed on another device. Reopen it before editing further.');
        }
        if (existing && existing.title === title && JSON.stringify(existing.blocks ?? []) === JSON.stringify(blocks)) {
          return json({ ok: true, unchanged: true, id, revision: currentRevision, updated_at: existing.updated_at });
        }
        const timestamp = now();
        const revision = currentRevision + 1;
        if (existing) {
          const snapshot = { revision: existing.revision ?? 1, title: existing.title,
            blocks: existing.blocks, saved_at: existing.updated_at,
            saved_by: existing.updated_by ?? existing.owner,
            saved_by_name: existing.updated_by_name ?? existing.owner_name };
          await collection.updateOne({ _id: id }, {
            $set: { title, blocks, updated_at: timestamp, updated_by: user.uid,
              updated_by_name: user.name, revision },
            $push: { versions: { $each: [snapshot], $slice: -20 } },
          });
        } else {
          await collection.insertOne({ _id: id, title, blocks, owner: user.uid,
            owner_name: user.name, created_at: timestamp, updated_at: timestamp,
            updated_by: user.uid, updated_by_name: user.name, revision: 1, versions: [] });
        }
        await audit('documents', existing ? 'edit-office-document' : 'create-office-document', title, user);
        return json({ ok: true, id, revision, updated_at: timestamp }, existing ? 200 : 201);
      }
      case 'POST /api/office-documents/restore': {
        const b = await req.json();
        const id = String(b.id ?? '');
        const wanted = Number(b.revision);
        const collection = await coll.officeDocs();
        const existing = await collection.findOne({ _id: id }) as Record<string, unknown> | null;
        if (!existing) throw new HttpErr(404, 'Document not found');
        if (existing.owner !== user.uid && !['ceo', 'admin'].includes(user.role)) {
          throw new HttpErr(403, 'Only the owner or management can restore this document');
        }
        const versions = Array.isArray(existing.versions) ? existing.versions as Array<Record<string, unknown>> : [];
        const version = versions.find(v => Number(v.revision) === wanted);
        if (!version) throw new HttpErr(404, 'That document version is no longer available');
        const timestamp = now();
        const currentRevision = Number(existing.revision ?? 1);
        const snapshot = { revision: currentRevision, title: existing.title, blocks: existing.blocks,
          saved_at: existing.updated_at, saved_by: existing.updated_by ?? existing.owner,
          saved_by_name: existing.updated_by_name ?? existing.owner_name };
        await collection.updateOne({ _id: id }, {
          $set: { title: version.title, blocks: version.blocks, updated_at: timestamp,
            updated_by: user.uid, updated_by_name: user.name, revision: currentRevision + 1 },
          $push: { versions: { $each: [snapshot], $slice: -20 } },
        });
        await audit('documents', 'restore-office-document', `${existing.title} revision ${wanted}`, user);
        return json({ ok: true, revision: currentRevision + 1 });
      }
      case 'POST /api/office-documents/delete': {
        const b = await req.json();
        const id = String(b.id ?? '');
        const collection = await coll.officeDocs();
        const existing = await collection.findOne({ _id: id }) as Record<string, unknown> | null;
        if (!existing) throw new HttpErr(404, 'Document not found');
        if (existing.owner !== user.uid && !['ceo', 'admin'].includes(user.role)) {
          throw new HttpErr(403, 'Only the owner or management can delete this document');
        }
        await collection.updateOne({ _id: id }, { $set: { deleted_at: now(), deleted_by: user.uid } });
        await audit('documents', 'delete-office-document', String(existing.title ?? id), user);
        return json({ ok: true });
      }

      case 'GET /api/cloud-documents': {
        const rows = await (await coll.cloudDocs()).find({}).sort({ created_at: -1 }).limit(1000).toArray();
        return json({ documents: rows.map((r: Record<string, unknown>) => ({
          id: String(r._id), filename: r.filename, mime_type: r.mime_type,
          size: r.size, created_at: r.created_at, created_by_name: r.created_by_name,
          description: r.description ?? '',
        })) });
      }
      case 'POST /api/cloud-documents/upload': {
        if (!SERVICE_ROLE) throw new HttpErr(503, 'Cloud document storage is temporarily unavailable');
        const b = await req.json();
        const filename = String(b.filename ?? 'document.pdf').replace(/[^A-Za-z0-9._ -]/g, '_').slice(0, 160);
        const mime = String(b.mime_type ?? 'application/pdf').slice(0, 80);
        const encoded = String(b.base64 ?? '');
        if (!encoded || encoded.length > 16_000_000) throw new HttpErr(400, 'Document is empty or exceeds the 12 MB cloud limit');
        let bytes: Uint8Array;
        try { bytes = Uint8Array.from(atob(encoded), c => c.charCodeAt(0)); }
        catch { throw new HttpErr(400, 'Document data is invalid'); }
        if (!bytes.length || bytes.length > 12 * 1024 * 1024) throw new HttpErr(400, 'Document is empty or exceeds the 12 MB cloud limit');
        const digest = [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))]
          .map(x => x.toString(16).padStart(2, '0')).join('');
        const existing = await (await coll.cloudDocs()).findOne({ content_hash: digest });
        if (existing) return json({ ok: true, duplicate: true, document: existing });
        await fetch(`${SUPABASE_URL}/storage/v1/bucket`, {
          method: 'POST', headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ id: 'office-documents', name: 'office-documents', public: false, file_size_limit: 12582912 }),
        });
        const path = `${user.uid}/${digest}-${filename}`;
        const uploaded = await fetch(`${SUPABASE_URL}/storage/v1/object/office-documents/${encodeURIComponent(path).replaceAll('%2F', '/')}`, {
          method: 'POST', headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`,
            'Content-Type': mime, 'x-upsert': 'false' }, body: bytes,
        });
        if (!uploaded.ok && uploaded.status !== 409) throw new HttpErr(502, 'Cloud document upload failed');
        const record = { filename, mime_type: mime, size: bytes.length, storage_path: path,
          content_hash: digest, description: String(b.description ?? '').slice(0, 500),
          created_by: user.uid, created_by_name: user.name, created_at: now() };
        const out = await ins(coll.cloudDocs(), record);
        await audit('documents', 'cloud-upload', filename, user);
        return json({ ok: true, document: { ...record, _id: out.insertedId } }, 201);
      }
      case 'POST /api/cloud-documents/download': {
        const b = await req.json();
        const id = String(b.id ?? '');
        let doc = await (await coll.cloudDocs()).findOne({ _id: id }) as Record<string, unknown> | null;
        if (!doc && /^[0-9a-f]{24}$/i.test(id)) doc = await (await coll.cloudDocs()).findOne({ _id: new ObjectId(id) }) as Record<string, unknown> | null;
        if (!doc) throw new HttpErr(404, 'Cloud document not found');
        const signed = await fetch(`${SUPABASE_URL}/storage/v1/object/sign/office-documents/${encodeURIComponent(String(doc.storage_path)).replaceAll('%2F', '/')}`, {
          method: 'POST', headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({ expiresIn: 300 }),
        });
        const payload = await signed.json().catch(() => ({} as Record<string, unknown>)) as Record<string, unknown>;
        if (!signed.ok) throw new HttpErr(502, 'Could not prepare the cloud download');
        const signedPath = String(payload.signedURL ?? payload.signedUrl ?? '');
        const downloadUrl = signedPath.startsWith('http') ? signedPath
          : signedPath.startsWith('/storage/v1/') ? `${SUPABASE_URL}${signedPath}`
          : `${SUPABASE_URL}/storage/v1${signedPath.startsWith('/object/') ? signedPath : `/object/sign/office-documents/${signedPath}`}`;
        return json({ url: downloadUrl, filename: doc.filename, mime_type: doc.mime_type });
      }

      case 'POST /api/docs/issue': {
        requireRole(user, ['ceo', 'admin'], 'issue freehand documents');
        const b = await req.json();
        const type = ['receipt', 'invoice', 'mils', 'waybill', 'deliverynote'].includes(b.type) ? b.type : null;
        if (!type) throw new HttpErr(400, 'Unknown document type');
        const contact = String(b.contact ?? '');
        if (!contact && b.requireContact !== false) {
          throw new HttpErr(400, 'Customer phone or email is required on every document');
        }
        if (contact && !contact.includes('@') && !internationalPhone(contact)) {
          throw new HttpErr(400, 'Phone number must include country code, e.g. +2348033498452');
        }
        const issueKey = String(b.issue_key ?? '').slice(0, 180);
        if (issueKey) {
          const existing = await (await coll.archive()).findOne({ issue_key: issueKey, signed_by: user.uid });
          if (existing) return json({ serial: existing.serial, doc: existing, duplicate: true });
        }
        const serial = await nextSerial(type);
        const record = {
          doc_type: type, serial, customer: String(b.customer ?? '—').slice(0, 120) || '—',
          customer_contact: contact, total: Number(b.total) || 0,
          signed_by: user.uid, signed_name: user.name, issue_key: issueKey || null,
          verify_hash: String(b.hash ?? '').slice(0, 64),
          filename: `mtek_${type}_${serial}_${Date.now()}.pdf`, issued_at: now(),
        };
        await (await coll.archive()).insertOne(record);
        await audit('documents', 'issue', `${type} ${pad9(serial)}`, user);
        await notify('document', 'Document issued', `${user.name} issued ${type} No ${pad9(serial)} for ${record.customer}`, `${type} ${pad9(serial)}`, user);
        return json({ serial, doc: record, serials: await peekSerials() });
      }
      // ---- OFFLINE → SERVER replay -------------------------------------
      // The apps ran in offline-first mode (Env.offlineDataMode) for a while;
      // every record made on a device is replayed here IDEMPOTENTLY when the
      // API is reconnected. Each row carries `offline_key`
      // (<device>:<table>:<localId>); rows are inserted with $setOnInsert
      // upserts so a second upload is a no-op. Device-issued numbers
      // (receipt/invoice/MILS/document serials) are kept EXACTLY as printed,
      // and the serial counters are raised ($max) past anything a device
      // already used so future server-issued numbers never collide.
      case 'POST /api/sync/import': {
        const b = await req.json();
        const device = String(b.device ?? '').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 40);
        if (!device) throw new HttpErr(400, 'device id required');
        const canManage = user.role === 'ceo' || user.role === 'admin';
        const accepted: string[] = [];
        const skipped: string[] = [];
        const rowsOf = (k: string): Record<string, unknown>[] =>
          Array.isArray(b[k]) ? b[k].filter((r: unknown) => r && typeof r === 'object') : [];
        // deno-lint-ignore no-explicit-any
        const put = async (c: Promise<any>, key: string, doc: Record<string, unknown>, id?: string) => {
          const filter = id ? { _id: id } : { offline_key: key };
          await (await c).updateOne(filter as Record<string, unknown>,
            { $setOnInsert: { ...doc, offline_key: key, offline_device: device, synced_by: user.uid, synced_at: now() } },
            { upsert: true });
          accepted.push(key);
        };
        // customers: _id = offline key so sales/invoices/MILS can reference
        // them by the same string the device used.
        const remapped: Record<string, string> = {}; // offline key → existing server _id
        for (const r of rowsOf('customers')) {
          const key = String(r.offline_key ?? '');
          if (!key) continue;
          const dup = await findDuplicateCustomer(String(r.name ?? ''), String(r.phone ?? ''));
          if (dup && String(dup._id) !== key) { remapped[key] = String(dup._id); accepted.push(key); continue; }
          await put(coll.customers(), key, {
            name: String(r.name ?? '').slice(0, 120), kind: r.is_corporate ? 'corporate' : 'individual',
            phone: String(r.phone ?? ''), email: String(r.email ?? ''), address: String(r.address ?? ''),
            credit_balance: Number(r.credit_balance) || 0, created_by: user.uid, created_at: String(r.created_at ?? now()),
          }, key);
        }
        for (const r of rowsOf('products')) {
          const key = String(r.offline_key ?? '');
          if (!key || !r.id || !r.name) continue;
          if (!canManage) { skipped.push(key); continue; }
          // device stock levels are authoritative for the offline period
          await (await coll.products()).updateOne({ _id: String(r.id) }, { $set: {
            name: String(r.name), brand: String(r.brand ?? '').trim().slice(0, 100), category: r.category ?? 'Fire',
            cost_price: Number(r.cost_price) || 0, selling_price: Number(r.selling_price) || 0,
            qty_on_hand: Math.max(0, Math.trunc(Number(r.qty_on_hand) || 0)),
            reorder_level: Math.max(0, Math.trunc(Number(r.reorder_level) || 0)),
            unit: r.unit ?? 'unit',
            length: Number.isFinite(Number(r.length)) ? Number(r.length) : null,
            length_unit: String(r.length_unit ?? ''),
            width: Number.isFinite(Number(r.width)) ? Number(r.width) : null,
            width_unit: String(r.width_unit ?? ''),
            size: Number.isFinite(Number(r.size)) ? Number(r.size) : null,
            size_unit: String(r.size_unit ?? ''),
            weight: Number.isFinite(Number(r.weight)) ? Math.max(0, Number(r.weight)) : null,
            weight_unit: ['mg', 'g', 'kg', 'tonne', 'oz', 'lb'].includes(String(r.weight_unit))
              ? String(r.weight_unit) : '',
            image_urls: Array.isArray(r.image_urls) ? r.image_urls.map(String).slice(0, 10) : [],
            is_service: !!r.is_service, updated_at: now(),
          } }, { upsert: true });
          accepted.push(key);
        }
        const cref = (v: unknown) => { const k = v == null ? null : String(v); return k && remapped[k] ? remapped[k] : k; };
        for (const r of rowsOf('sales')) {
          const key = String(r.offline_key ?? ''); if (!key) continue;
          await put(coll.sales(), key, {
            customer_id: cref(r.customer_id), customer_name: String(r.customer_name ?? 'Walk-in customer'),
            customer_contact: String(r.customer_contact ?? ''), method: String(r.method ?? 'cash'),
            discount: Number(r.discount) || 0, total: Number(r.total) || 0,
            items: Array.isArray(r.items) ? r.items : [], signed_by: user.uid, signed_name: String(r.signed_name ?? user.name),
            customer_signature: String(r.customer_signature ?? ''), created_at: String(r.created_at ?? now()), offline_id: String(r.id ?? ''),
          });
        }
        for (const r of rowsOf('transactions')) {
          const key = String(r.offline_key ?? ''); if (!key) continue;
          await put(coll.txns(), key, {
            txn_type: String(r.txn_type ?? 'salePayment'), method: String(r.method ?? 'cash'), amount: Number(r.amount) || 0,
            reference: String(r.reference ?? ''), txn_date: String(r.txn_date ?? now()), created_by: user.uid,
          });
        }
        for (const r of rowsOf('receipts')) {
          const key = String(r.offline_key ?? ''); if (!key || !r.no) continue;
          await put(coll.receipts(), key, {
            no: String(r.no), amount: Number(r.amount) || 0, method: String(r.method ?? 'cash'),
            source: String(r.source ?? 'sale'), customer_id: r.customer_id ?? null, customer_name: String(r.customer_name ?? '—'),
            customer_contact: String(r.customer_contact ?? ''), issued_by: user.uid, issued_name: String(r.issued_name ?? user.name),
            customer_signature: String(r.customer_signature ?? ''), created_at: String(r.created_at ?? now()),
          });
        }
        for (const r of rowsOf('invoices')) {
          const key = String(r.offline_key ?? ''); if (!key || !r.no) continue;
          const total = Number(r.total) || 0, paid = Number(r.amount_paid) || 0;
          await put(coll.invoices(), key, {
            no: String(r.no), customer_id: cref(r.customer_id), customer_name: String(r.customer_name ?? '—'),
            status: paid >= total && total > 0 ? 'paid' : paid > 0 ? 'partial' : 'sent',
            subtotal: total, vat: 0, total, amount_paid: paid, items: Array.isArray(r.items) ? r.items : [],
            issued_by: user.uid, created_at: String(r.created_at ?? now()), updated_at: now(),
          });
        }
        for (const r of rowsOf('mils')) {
          const key = String(r.offline_key ?? ''); if (!key || !r.equipment) continue;
          if (!canManage) { skipped.push(key); continue; }
          const { offline_key: _k, ...rest } = r;
          await put(coll.mils(), key, { ...rest, customer_id: cref(r.customer_id), recorded_by: user.uid, recorded_name: String(r.technician ?? user.name), created_at: String(r.created_at ?? r.service_date ?? now()) });
        }
        for (const r of rowsOf('adjustments')) {
          const key = String(r.offline_key ?? ''); if (!key || !r.product_id) continue;
          if (!canManage) { skipped.push(key); continue; }
          await put(coll.adjustments(), key, {
            product_id: String(r.product_id), delta: Math.trunc(Number(r.delta) || 0), reason: String(r.reason ?? 'correction'),
            note: String(r.note ?? ''), by: user.uid, by_name: user.name, created_at: String(r.created_at ?? now()),
          });
        }
        for (const r of rowsOf('documents')) {
          const key = String(r.offline_key ?? ''); if (!key || !r.doc_type) continue;
          await put(coll.archive(), key, {
            doc_type: String(r.doc_type), serial: Number(r.serial) || 0, customer: String(r.customer ?? '—').slice(0, 120),
            customer_contact: String(r.customer_contact ?? ''), total: Number(r.total) || 0,
            signed_by: user.uid, signed_name: String(r.signed_name ?? user.name), verify_hash: String(r.verify_hash ?? '').slice(0, 64),
            filename: `mtek_${r.doc_type}_${r.serial}_offline.pdf`, issued_at: String(r.issued_at ?? now()),
          });
        }
        // Serials are SERVER-OWNED (owner directive: no offline/local issued
        // document numbers). The legacy `serials` map that old clients still
        // send is deliberately IGNORED: accepting it let any device raise the
        // authoritative counter with $max, which could re-issue a number and
        // produce duplicate receipts/invoices. Only nextSerial() (and the
        // CEO-only reseed in /api/settings) may ever change a counter. The
        // response below returns the real server counters via peekSerials().
        if (accepted.length) await audit('core', 'offline-sync', `${device}: ${accepted.length} records`, user);
        return json({ ok: true, accepted, skipped, remapped, serials: await peekSerials() });
      }
      case 'GET /api/docs/history': {
        const docs = await (await coll.archive()).find({}).sort({ issued_at: -1 }).limit(500).toArray();
        return json({ docs });
      }

      case 'GET /api/mils': {
        const q: Record<string, unknown> = {};
        for (const k of ['customer_id', 'customer_name', 'equipment']) {
          if (url.searchParams.get(k)) q[k] = url.searchParams.get(k);
        }
        const logs = await (await coll.mils()).find(q).sort({ created_at: -1 }).limit(500).toArray();
        return json({ logs });
      }
      case 'POST /api/mils': {
        requireRole(user, ['ceo', 'admin'], 'record MILS jobs');
        const b = await req.json();
        const doc = { ...b, mils_no: b.mils_no || 'MILS-' + pad9(await nextSerial('mils')), recorded_by: user.uid, recorded_name: user.name, created_at: now() };
        const out = await ins(coll.mils(), doc);
        await audit('mils', 'create', String(out.insertedId), user);
        await notify('mils', 'MILS job recorded', `${user.name} recorded MILS job ${doc.mils_no}`, doc.mils_no, user);
        return json({ ok: true, id: String(out.insertedId), mils_no: doc.mils_no, mils: doc }, 201);
      }

      case 'GET /api/audit': {
        if (user.role === 'sales') throw new HttpErr(403, 'Audit trail is management-only');
        const events = await (await coll.audit()).find({}).sort({ at: -1 }).limit(1000).toArray();
        return json({ events });
      }

      // ---- notifications: every signed-in user (CEO/Admin/Sales) sees
      // every transaction/document/stock/announcement notification (owner
      // directive 2026-09-01). read_by tracks who has read it so an
      // announcement's SENDER can see a read count + reader names.
      case 'GET /api/notifications': {
        const rows = await (await coll.notifications()).find({}).sort({ created_at: -1 }).limit(300).toArray();
        return json({ notifications: rows });
      }
      case 'POST /api/notifications/read': {
        const b = await req.json();
        const id = String(b.id ?? '');
        if (!id) throw new HttpErr(400, 'Notification id required');
        let oid: InstanceType<typeof ObjectId>;
        try {
          oid = new ObjectId(id);
        } catch {
          throw new HttpErr(400, 'Invalid notification id');
        }
        await (await coll.notifications()).updateOne(
          { _id: oid, 'read_by.uid': { $ne: user.uid } },
          { $push: { read_by: { uid: user.uid, name: user.name, at: now() } } });
        return json({ ok: true });
      }
      // ---- mark EVERY notification as read by the current user in one go
      // (Settings → Preferences). Idempotent: the $ne filter skips any
      // notification this uid has already read.
      case 'POST /api/notifications/read-all': {
        await (await coll.notifications()).updateMany(
          { 'read_by.uid': { $ne: user.uid } },
          { $push: { read_by: { uid: user.uid, name: user.name, at: now() } } });
        return json({ ok: true });
      }
      // ---- announcements: CEO/Admin broadcast a message that lands as a
      // notification for every signed-in user, same read-tracking as above.
      case 'POST /api/announcements': {
        requireRole(user, ['ceo', 'admin'], 'send announcements');
        const b = await req.json();
        const title = String(b.title ?? '').trim().slice(0, 160);
        const message = String(b.message ?? '').trim().slice(0, 2000);
        if (!title) throw new HttpErr(400, 'Announcement title is required');
        if (!message) throw new HttpErr(400, 'Announcement message is required');
        const doc = {
          kind: 'announcement', title, message, ref: '',
          created_by: user.uid, created_by_name: user.name, created_at: now(),
          read_by: [] as Array<{ uid: string; name: string; at: string }>,
        };
        const out = await ins(coll.notifications(), doc);
        await audit('core', 'announcement', title, user);
        return json({ ok: true, id: String(out.insertedId) }, 201);
      }

      // ---- staff directory: CEO/Admin see every staff member's name,
      // email and phone (owner directive 2026-09-01). Only the CEO can
      // promote a Sales staffer to Admin or demote an Admin back to Sales
      // (nobody can touch the CEO row — it is locked to CEO_EMAIL).
      case 'GET /api/staff': {
        requireRole(user, ['ceo', 'admin'], 'view the staff directory');
        const rows = await (await coll.profiles()).find({}).sort({ full_name: 1 }).toArray();
        const unique = new Map<string, Record<string, unknown>>();
        for (const row of rows as Array<Record<string, unknown>>) {
          const email = String(row.email ?? '').trim().toLowerCase();
          const key = email || `uid:${String(row._id)}`;
          const previous = unique.get(key);
          const previousAt = String(previous?.updated_at ?? previous?.created_at ?? '');
          const rowAt = String(row.updated_at ?? row.created_at ?? '');
          if (!previous || rowAt >= previousAt) unique.set(key, row);
        }
        return json({
          staff: Array.from(unique.values()).map((r: Record<string, unknown>) => {
            const email = String(r.email ?? '').trim().toLowerCase();
            return {
              uid: String(r._id), name: String(r.full_name ?? ''), email,
              phone: email === CEO_EMAIL ? CEO_PHONE : String(r.phone ?? ''),
              role: email === CEO_EMAIL ? 'ceo' : String(r.role ?? 'sales'),
              staff_id: String(r.staff_id ?? `MFSL-${String(r._id).replaceAll('-', '').slice(0, 8).toUpperCase()}`),
              passport_photo: String(r.passport_photo ?? ''),
              created_at: r.created_at ?? null,
            };
          }),
        });
      }
      case 'POST /api/staff/delete': {
        requireRole(user, ['ceo'], 'delete staff accounts');
        if (!SERVICE_ROLE) throw new HttpErr(503, 'Staff deletion is temporarily unavailable');
        const b = await req.json();
        const targetUid = String(b.uid ?? '').trim();
        if (!targetUid) throw new HttpErr(400, 'Staff member id required');
        if (targetUid === user.uid) throw new HttpErr(400, 'The signed-in CEO account cannot delete itself');
        const profiles = await coll.profiles();
        const target = await profiles.findOne({ _id: targetUid }) as Record<string, unknown> | null;
        if (!target) throw new HttpErr(404, 'Staff member not found');
        if (String(target.email ?? '').toLowerCase() === CEO_EMAIL || target.role === 'ceo') {
          throw new HttpErr(400, 'The CEO account cannot be deleted');
        }
        // Delete the real Supabase Auth identity first. A 404 is acceptable on
        // retry, allowing a previous partial attempt to finish profile cleanup.
        const authDelete = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${targetUid}`, {
          method: 'DELETE',
          headers: { apikey: SERVICE_ROLE, Authorization: `Bearer ${SERVICE_ROLE}` },
        });
        if (!authDelete.ok && authDelete.status !== 404) {
          throw new HttpErr(502, 'Supabase rejected the staff deletion; no local success was recorded');
        }
        await profiles.deleteOne({ _id: targetUid });
        profileCache.delete(targetUid);
        await audit('people', 'delete-staff', String(target.email ?? targetUid), user);
        await notify('staff', 'Staff account deleted',
          `${user.name} permanently removed ${target.full_name ?? target.email} from MFSL Office`, targetUid, user);
        return json({ ok: true, auth_deleted: true, profile_deleted: true });
      }
      case 'POST /api/staff/role': {
        requireRole(user, ['ceo'], 'promote or demote staff');
        const b = await req.json();
        const targetUid = String(b.uid ?? '');
        const newRole = String(b.role ?? '');
        if (!targetUid) throw new HttpErr(400, 'Staff member id required');
        if (!['admin', 'sales'].includes(newRole)) throw new HttpErr(400, 'Role must be admin or sales');
        const target = await (await coll.profiles()).findOne({ _id: targetUid }) as Record<string, unknown> | null;
        if (!target) throw new HttpErr(404, 'Staff member not found');
        if (String(target.email ?? '').toLowerCase() === CEO_EMAIL || target.role === 'ceo') {
          throw new HttpErr(400, 'The CEO role cannot be changed here');
        }
        await (await coll.profiles()).updateOne({ _id: targetUid }, { $set: { role: newRole } });
        profileCache.delete(targetUid);
        await audit('people', 'role-change', `${target.email} -> ${newRole}`, user);
        await notify('staff', newRole === 'admin' ? 'Staff promoted to Admin' : 'Staff moved to Sales',
          `${user.name} set ${target.full_name ?? target.email} to ${newRole}`, targetUid, user);
        return json({ ok: true });
      }

      default:
        return err(404, 'Unknown API route');
    }
  } catch (e) {
    if (e instanceof HttpErr) return err(e.status, e.message);
    // Log the full detail SERVER-SIDE only (visible in the function logs,
    // never to the app) and return one plain, user-safe message. Raw driver
    // errors / stack text must never reach a production screen.
    console.error('data-api unhandled error:', e);
    // TEMPORARY diagnostics (2026-09-03): the Supabase log viewer is not
    // reachable from the owner's tooling, so surface a short, sanitised
    // error detail to the app until the issue path is proven stable.
    const detail = String((e as Error)?.message ?? e).replace(/mongodb(\+srv)?:\/\/\S+/gi, '[uri]').slice(0, 160);
    return err(500, `Something went wrong on the server — ${detail}`);
  }
});
