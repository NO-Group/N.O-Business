#!/usr/bin/env python3
"""Exhaustive MFSL Office contract audit.

This is the "no more surprises" gate. Instead of spot-checking a few paths,
it enumerates the whole finite surface of the app and cross-checks every
element against its counterpart:

  * tools/api_contract.json  <-  the 50 HTTP routes declared in data-api
  * every /api literal in the Dart client  <-  that contract
  * every response key a client relies on  <-  the server's json({...})
  * every coll.X() / collection('X')  <-  the coll map and STORAGE_COLLECTIONS
  * every rpc/mtek_* call  <-  a SQL function with the right GRANT/REVOKE
  * every $operator used  <-  the operators the Postgres shim implements
  * every version string  <-  pubspec / AppInfo / Edge APP_VERSION / MSIX
  * every dart-define  <-  both build scripts
  * every POST that writes  <-  a 4xx validation guard (or an explicit skip)
  * health probe + workflow gates  <-  required live verification markers

It is dependency-free (stdlib only) and runs in BOTH CI workflows plus the
existing local gate suite. A mismatch fails the build rather than shipping.

    python3 tools/contract_audit.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ERRORS = []
PASSED = 0


def check(name, condition, detail=''):
    global PASSED
    if condition:
        PASSED += 1
        print(f'  PASS  {name}')
    else:
        ERRORS.append(name)
        print(f'  FAIL  {name}' + (f'\n        {detail}' if detail else ''))


def read(rel):
    p = ROOT / rel
    return p.read_text(encoding='utf8') if p.exists() else ''


IDX = 'supabase/functions/data-api/index.ts'
SQL = 'supabase/migrations/20260908160000_remove_auth_profile_trigger.sql'
WORKFLOW = '.github/workflows/deploy-edge.yml'
CONTRACT = 'tools/api_contract.json'

idx = read(IDX)
sql = read(SQL)
wf = read(WORKFLOW)
pubspec = read('app/pubspec.yaml')
app_info = read('app/lib/core/app_info.dart')
android_sh = read('ci/build-android.sh')
windows_ps = read('ci/build-windows.ps1')
shim_test = read('tools/pg_shim_test.mjs')
verify_js = read('backend/scripts/verify-supabase.js')

# ---------------------------------------------------------------- 1. contract
try:
    contract = json.loads(read(CONTRACT))
    routes = contract['routes']
except Exception as e:
    print(f'  FAIL  contract file is readable: {e}')
    sys.exit(1)

check('contract file is readable and has schema v1',
      contract.get('schema') == 'mtek-api-contract-v1', contract.get('schema'))
check('contract declares exactly 50 routes', len(routes) == 50, f'got {len(routes)}')
route_names = [r['route'] for r in routes]
check('contract has no duplicate routes', len(set(route_names)) == len(route_names))
check('every contract route is a real GET/POST /api path',
      all(re.fullmatch(r'(GET|POST|PUT|DELETE|PATCH) /api/[A-Za-z0-9_/\-]+', r) for r in route_names))
check('every contract route has an auth, role and probe classification',
      all(r.get('auth') in ('public', 'jwt') and r.get('role') and r.get('probe') in ('get', 'empty', 'skip')
          for r in routes))
check('probes cover all 16 GET routes and skip exactly the 3 documented writers',
      sum(1 for r in routes if r['probe'] == 'get') == 16 and
      sum(1 for r in routes if r['probe'] == 'skip') == 3 and
      all(r.get('reason') for r in routes if r['probe'] == 'skip'))

# ------------------------------------------------------- 2. server route set
server_routes = {f'{m} {p}' for m, p in re.findall(
    r"^\s*(?:case\s+|if \(route === )'(GET|POST|PUT|DELETE|PATCH) (/api/[^']+)'", idx, re.M)}
check('server declares exactly the 50 contract routes',
      server_routes == set(route_names),
      f'only-in-code={sorted(server_routes - set(route_names))} '
      f'only-in-contract={sorted(set(route_names) - server_routes)}')

# Brace-aware first-level keys of `return json({...})` inside a handler.
def first_level_keys(src):
    out = set()
    for m in re.finditer(r'return json\(\s*\{', src):
        i, depth, j = m.end(), 1, m.end()
        while j < len(src) and depth:
            if src[j] == '{':
                depth += 1
            elif src[j] == '}':
                depth -= 1
            j += 1
        chunk, depth, last, parts = src[i:j - 1], 0, 0, []
        for k, c in enumerate(chunk):
            if c in '{([':
                depth += 1
            elif c in '})]':
                depth -= 1
            elif c == ',' and depth == 0:
                parts.append(chunk[last:k])
                last = k + 1
        parts.append(chunk[last:])
        for p in parts:
            p = p.strip()
            m1 = re.match(r'^(\w+)\s*:', p) or re.match(r'^(\w+)$', p)
            if m1:
                out.add(m1.group(1))
    return sorted(out)


hits = list(re.finditer(
    r"^\s*(?:case\s+|if \(route === )'(GET|POST|PUT|DELETE|PATCH) (/api/[^']+)'", idx, re.M))
bodies = {}
for n, h in enumerate(hits):
    end = hits[n + 1].start() if n + 1 < len(hits) else len(idx)
    bodies[f'{h.group(1)} {h.group(2)}'] = idx[h.end():end]

# A live probe with {} must be strictly read-only. Count EVERY state-changing
# call, including helpers (ins/audit/notify/nextSerial) that wrap collection
# writes - the first version of this gate only looked for coll.X() methods and
# let POST /api/mils consume a real document serial.
STATE_CALL = re.compile(
    r'\.(?:insertOne|updateOne|updateMany|deleteOne|deleteMany|findOneAndUpdate)\s*\('
    r'|(?<![\w.])(?:ins|audit|notify|nextSerial|pgPut|pgCasUpsert)\s*\(')
GUARD_CALL = re.compile(r'(?:throw new HttpErr\(|return err\(|err\()4\d\d')
unsafe_probes = []
for r in routes:
    if r['probe'] != 'empty':
        continue
    body = bodies.get(r['route'], '')
    first_write = STATE_CALL.search(body)
    first_guard = GUARD_CALL.search(body)
    if first_write and not (first_guard and first_guard.start() < first_write.start()):
        unsafe_probes.append(r['route'])
check('every live {} POST probe is read-only (guard precedes ANY state change)',
      not unsafe_probes, f'would write: {unsafe_probes}')

bad_keys = [r['route'] for r in routes if r['probe'] == 'get'
            and set(r['keys']) != set(first_level_keys(bodies.get(r['route'], '')))]
check('contract response keys match the server json({...}) for every GET route',
      not bad_keys, f'mismatched: {bad_keys}')

# ------------------------------------------------------------- 3. client paths
client_paths = set()
for f in (ROOT / 'app/lib').rglob('*.dart'):
    client_paths.update(re.findall(r"'(/api/[^'\"?\s]*)'", f.read_text(encoding='utf8')))
missing = sorted(p for p in client_paths if not any(r.endswith(' ' + p) for r in route_names))
check(f'all {len(client_paths)} client /api literals exist on the server',
      not missing, f'unknown: {missing}')

# --------------------------------------------------------- 4. collections/RPCs
start = idx.index('const coll = {')
coll_block = idx[start:idx.index('\n};', start)]
coll_defined = set(re.findall(r'^\s*(\w+):\s*\(\)\s*=>', coll_block, re.M))
coll_used = set(re.findall(r'\bcoll\.(\w+)\(\)', idx))
check(f'all {len(coll_used)} coll.X() calls resolve to one of {len(coll_defined)} definitions',
      coll_used == coll_defined,
      f'undefined={sorted(coll_used - coll_defined)} unused={sorted(coll_defined - coll_used)}')

block = idx[idx.index('const STORAGE_COLLECTIONS = ['):]
declared_collections = set(re.findall(r"'([^']+)'", block[:block.index('];')]))
physical = set(re.findall(r"collection\('([^']+)'\)", idx))
check(f'all {len(physical)} physical collections are declared in STORAGE_COLLECTIONS',
      physical == declared_collections and len(declared_collections) == 20,
      f'undeclared={sorted(physical - declared_collections)}')
check("the only undeclared collection is the reserved __health__ probe",
      set(re.findall(r"new PgCollection\('([^']+)'\)", idx)) == {'__health__'})

rpcs = set(re.findall(r'rpc/(mtek_\w+)', idx))
sql_funcs = set(re.findall(r'create or replace function public\.(mtek_\w+)\s*\(', sql))
check(f'all {len(rpcs)} RPC calls have a SQL function', rpcs <= sql_funcs,
      f'missing={sorted(rpcs - sql_funcs)}')
check('every SQL RPC is revoked from anon/authenticated and granted to service_role',
      all(re.search(r'revoke all on function public\.' + re.escape(fn) + r'\([^)]*\)[\s\S]{0,160}?from public, anon, authenticated', sql)
          and re.search(r'grant execute on function public\.' + re.escape(fn), sql)
          for fn in rpcs),
      f'checked: {sorted(rpcs)}')
check('mtek_rpc_ready verifies every RPC by exact signature',
      all(f"to_regprocedure('public.{fn}(" in sql for fn in rpcs))

# -------------------------------------------------------------- 5. operators
IMPLEMENTED = {
    '$eq', '$ne', '$in', '$nin', '$gt', '$gte', '$lt', '$lte', '$exists',
    '$regex', '$options', '$expr', '$add', '$and', '$or',
    '$set', '$setOnInsert', '$inc', '$max', '$unset', '$push', '$each', '$slice',
}
operator_keys = {'$' + k for k in re.findall(r'\$(\w+)\s*:', idx)}
check(f'all {len(operator_keys)} operators used have shim implementations',
      operator_keys <= IMPLEMENTED, f'unimplemented={sorted(operator_keys - IMPLEMENTED)}')
check('shim harness asserts the no-URL-filter invariant and CAS/upsert/paging',
      all(s in shim_test for s in ['unsafeFilterCount', 'mtek_cas_update', 'mtek_cas_upsert',
                                   'mtek_doc_get', 'mtek_doc_delete',
                                   'find({}) pages past the 1000-row PostgREST cap',
                                   'updateMany reaches every page']))
check('every GET probe that needs a query parameter declares one',
      all(not r.get('query') or (r['probe'] == 'get' and r['query'].startswith('?'))
          for r in routes)
      and sum(1 for r in routes if r.get('query')) >= 2)
check('live health probe covers hostile ids, paging and atomic upsert',
      all(s in idx for s in ['__roundtrip__,filter.(probe)', "pgRows('__health__', undefined, 2)",
                             '__upsert_probe__', 'pagination failed']))
check('deep-health probe is concurrency-safe (per-invocation nonce)',
      all(s in idx for s in ['const nonce = crypto.randomUUID()',
                             'const pageLabel = `page-${nonce}`',
                             'pageIds.filter(pid => paged.some(',
                             'deleteMany({ label: pageLabel })']))

# --------------------------------------------------------------- 6. versions
ver = re.search(r'^version:\s*(\S+)', pubspec, re.M)
app_version = ver.group(1) if ver else ''
edge_version = re.search(r"const APP_VERSION = '([^']+)'", idx)
edge_build = re.search(r'const APP_BUILD = (\d+)', idx)
default_version = re.search(r"defaultValue: '([^']+)'", app_info)
msix = re.search(r'msix_version:\s*([\d.]+)', pubspec)
check(f'version strings all agree ({app_version})',
      bool(ver and edge_version and edge_build and default_version)
      and app_version == edge_version.group(1) == default_version.group(1)
      and int(edge_build.group(1)) == int(app_version.split('+')[-1]),
      f'pubspec={app_version} edge={edge_version.group(1) if edge_version else None} '
      f'default={default_version.group(1) if default_version else None}')
check('MSIX version build segment matches the logical build number',
      bool(msix) and msix.group(1).split('.')[2] == app_version.split('+')[-1],
      msix.group(1) if msix else 'missing')
check('both build scripts read pubspec and assert APP_VERSION drift',
      'PUB_VERSION' in android_sh and 'EDGE_VERSION' in android_sh
      and '$versionMatch' in windows_ps and '$edgeMatch' in windows_ps)
check('both build scripts bake APP_VERSION into the Dart build',
      '--dart-define="APP_VERSION=${PUB_VERSION}"' in android_sh
      and '$dartDefineArg' in windows_ps)

# ------------------------------------------------------------- 7. config/secrets
defines = set()
for f in (ROOT / 'app/lib').rglob('*.dart'):
    t = f.read_text(encoding='utf8')
    defines.update(re.findall(r"(?:String|bool|int)\.fromEnvironment\(\s*'([^']+)'", t))
check(f'all {len(defines)} dart-define keys have a baked default',
      all(f"'{d}'" in read('app/lib/data/env.dart') or f"'{d}'" in app_info for d in defines),
      f'checked: {sorted(defines)}')
denv = set(re.findall(r"Deno\.env\.get\('([^']+)'\)", idx))
check('no MongoDB env var survives and all runtime secrets are documented',
      'MONGODB_URI' not in denv and denv <= {
          'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY',
          'SUPABASE_SECRET_KEY', 'MTEK_CEO_UID'},
      f'found: {sorted(denv)}')
check('data-api imports no Mongo driver',
      'npm:mongodb' not in idx and 'MONGODB_URI' not in idx)

# ------------------------------------------------- 7b. client write ordering
store = read('app/lib/data/store.dart')
fire_and_forget = re.findall(r'unawaited\(\(\) async \{([\s\S]*?)\}\(\)\)', store)
check('no fire-and-forget server write remains in store.dart',
      not any('_api' in block or '.post(' in block for block in fire_and_forget),
      f'{len(fire_and_forget)} immediate async block(s), '
      f'{sum(1 for b in fire_and_forget if "_api" in b)} touch the API')
check('addCustomer is server-first, awaitable and returns the stored record',
      'Future<Customer> addCustomer(Customer c) async' in store
      and 'customers.add(saved);' in store
      and "await _api!.post('/api/customers'" in store)
bare_add_customer = [f'{f.name}:{i}' for f in (ROOT / 'app/lib').rglob('*.dart')
                     for i, line in enumerate(f.read_text(encoding='utf8').splitlines(), 1)
                     if 'addCustomer(' in line and 'Future<Customer>' not in line
                     and 'await ' not in line]
check('every addCustomer call site awaits the server result',
      not bare_add_customer, f'unawaited: {bare_add_customer}')
check('payInvoice still refuses local mutation before server confirmation',
      'SERVER-AUTHORITATIVE, exactly like recordSale()' in store
      and "'issue_key': issueKey," in store
      and 'Cloud server is unreachable. Payment was not recorded' in store)

# --------------------------------------------------------- 8. POST write guards
unguarded = [r['route'] for r in routes
             if r.get('writes') and not r.get('guarded') and r['probe'] != 'skip']
check('every writing POST route validates input before writing (or is documented skip)',
      not unguarded, f'unguarded: {unguarded}')
check('all 5 public auth routes are classified public',
      sum(1 for r in routes if r['auth'] == 'public') == 5)

# -------------------------------------------------------------- 9. CI gates
required_markers = [
    '"ok":true', 'storage":"supabase-postgres', 'serial_rpc":"ok',
    'storage_roundtrip":"ok', 'app_version', 'mtek_rpc_ready',
    'tools/contract_audit.py', 'POST /api/docs/issue',
]
check('deploy workflow contains every mandatory live gate',
      all(m in wf for m in required_markers),
      f'missing: {[m for m in required_markers if m not in wf]}')
docs_snapshot = read('docs/ci/deploy-edge.yml')
snapshot_header = ('# SNAPSHOT of .github/workflows/deploy-edge.yml (the authoritative file).\n'
                   '# Kept byte-for-byte in sync apart from the branch filter. Do NOT copy only\n'
                   '# part of this file: the SQL bootstrap step is REQUIRED — without it the\n'
                   '# function has no mtek_docs table and every data route fails.\n#\n')
normalised = (docs_snapshot
              .replace(snapshot_header, '', 1)
              .replace('#   1. Use .github/workflows/deploy-edge.yml (authoritative) as-is.',
                       '#   1. Copy this file into .github/workflows/deploy-edge.yml', 1)
              .replace('branches: [main]', 'branches: [main, arena/**]', 1))
check('docs/ci/deploy-edge.yml is byte-for-byte in sync (3 documented differences only)',
      bool(docs_snapshot) and normalised == wf,
      f'live={len(wf)}B snapshot-normalised={len(normalised)}B')
check('verify-supabase.js requires all four health markers',
      all(s in verify_js for s in ['storage_roundtrip', 'serial_rpc', 'bootstrap_bytes', 'app_version']))
check('build workflow is triggered by app/ and ci/ changes',
      "paths: ['app/**', 'ci/**', '.github/workflows/build-mfsl.yml']" in read('.github/workflows/build-mfsl.yml'))

# --------------------------------------------------------------- 10. book types
books = re.search(r'const BOOK_TYPES = \[([^\]]+)\]', idx)
book_names = set(re.findall(r"'([^']+)'", books.group(1))) if books else set()
migration_doc = read('docs/SUPABASE_MIGRATION.md')
readme_doc = read('supabase/README.md')
_dispatched = sum(1 for r in routes if r['probe'] in ('get', 'empty'))
check(f'documentation states the exact live-sweep coverage ({_dispatched}/{len(routes)})',
      f'**{_dispatched} of the {len(routes)} manifest routes**' in migration_doc
      and f'{_dispatched} of {len(routes)} routes execute against real Supabase' in migration_doc
      and f'{_dispatched} of the {len(routes)} routes live' in readme_doc,
      'docs disagree with tools/api_contract.json')

check('exactly 8 authoritative serial books are provisioned',
      len(book_names) == 8 and 'receipt' in book_names and 'invoice' in book_names,
      sorted(book_names))
sync_body = bodies.get('POST /api/sync/import', '')
check('POST /api/sync/import cannot write counters — serials are server-owned',
      bool(sync_body) and 'coll.serials()' not in sync_body
      and 'Serials are SERVER-OWNED' in sync_body
      and 'peekSerials()' in sync_body)

print(f'\n{PASSED} contract checks passed, {len(ERRORS)} failed')
if ERRORS:
    print('FAILED: ' + ', '.join(ERRORS))
    sys.exit(1)
print('CONTRACT AUDIT PASSED — every enumerated cross-reference agrees.')
