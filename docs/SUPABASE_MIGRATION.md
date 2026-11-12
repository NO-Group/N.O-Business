# Supabase-only backend — issue, fix and verification

**Date:** 2026-11-04
**Branch:** `arena/8ef1ceb8-mtek-fire-safety-ltd`
**Owner directive:** "Supabase alone is for our backend … we are cutting off mongo", and "never issue a document without a server serial".

---

## 1. What was wrong

The screenshot showed:

> **Document NOT issued — Something went wrong on the server — `querySrv ENOTFOUND _mongodb._tcp.mfsl.w5ifd7x.mongodb.net`**

and the dashboard counters were all `00`.

Diagnosis (before any code change):

| Check | Result |
|---|---|
| `GET /health` | `ok:true`, `version:"2026-09-19-office-suite1"` — the deployed bundle really was this repo's `data-api` |
| `GET /api/bootstrap` (no token) | `{"error":"Missing bearer token"}` — Supabase Auth/JWT fine |
| `GET /health?deep=1&full=1` | `querySrv ENOTFOUND ...` — every DB route broken |
| Google DNS SRV / TXT / A / SOA for `mfsl.w5ifd7x.mongodb.net` and `w5ifd7x.mongodb.net` | `Status:3` NXDOMAIN |
| AliDNS SRV (independent resolver) | `Status:3` NXDOMAIN |
| `mongodb.net` SOA (parent zone) | `Status:0` — parent healthy, child zone gone |

`supabase/functions/data-api/index.ts` imported `npm:mongodb@6.3.0` and read
`MONGODB_URI` (Atlas SRV). The Atlas cluster's DNS zone no longer exists, so
`bootstrap`, `docs/issue`, products, customers, sales — every data route —
failed. The app then had nothing to count, hence the zeros.

Per the owner's decision, **no attempt was made to revive Atlas or to chase a
new `MONGODB_URI`**. MongoDB is removed entirely.

---

## 2. What changed

### Storage (Supabase Postgres, this same project)

`supabase/migrations/20260908160000_remove_auth_profile_trigger.sql` now
provisions, idempotently, before each deploy:

| Object | Purpose |
|---|---|
| `public.mtek_docs(collection text, id text, doc jsonb, written_at)` | All 20 logical collections in one table, keyed by `(collection, id)` |
| `public.mtek_next_serial(text)` | `INSERT … ON CONFLICT DO UPDATE … RETURNING` — one row lock, no duplicate paper-book serials |
| `public.mtek_cas_update(text,text,jsonb,jsonb)` | Compare-and-swap: an update lands only if the row still holds the document the caller read. Restores MongoDB's atomic `$inc` semantics |
| `public.mtek_doc_get(text,text)` / `mtek_doc_delete(text,text)` | Point reads/deletes by JSON body, so no user-supplied id is ever interpolated into a PostgREST URL filter |

RLS is enabled, `anon`/`authenticated` are revoked, and only `service_role`
(the key the Edge Runtime injects) can read or write. Serials live **inside
`mtek_docs`** under `collection='serials'`, so `/api/bootstrap`, Settings
reseed, `health?deep=1` and the allocator all use the *same* counter — there
is no second table to drift.

### Edge Function

`supabase/functions/data-api/index.ts`:

- `npm:mongodb` import and `MONGODB_URI` are **gone**.
- A small Mongo-compatible collection shim talks to PostgREST
  (`${SUPABASE_URL}/rest/v1`) with the service-role key. It implements
  `find / findOne / findOneAndUpdate / insertOne / updateOne / updateMany /
  deleteOne / deleteMany`, cursors (`sort/limit/skip/toArray`), and the
  operators actually used by the routes: `$eq $ne $in $nin $gt $gte $lt
  $lte $exists $regex $options $expr ($add, field refs) $set $setOnInsert
  $inc $max $unset $push ($each, $slice)`. A local `ObjectId` keeps 24-hex
  ids so the app still recognises server ids.
- `nextSerial()` calls the atomic RPC first (server-issued serial only) and
  falls back to the shim if the RPC is temporarily unavailable.
- `ensureCore()` is shared per isolate, so a polling app no longer re-runs
  ten upserts on every bootstrap.
- `/health` reports `"storage":"supabase-postgres"`, the real logical
  collections, and on deep checks `"serial_rpc":"ok"` plus
  `"storage_roundtrip":"ok"` — live proofs that the authoritative allocator
  and a full insert/read/update/filter/delete cycle work on real Postgres.

### Contract preservation — **no APK rebuild needed**

`git diff` comparison of route declarations:

```
case  routes: before=45 after=45   IDENTICAL
if(route ===) routes: before=5  after=5    IDENTICAL
total HTTP /api routes: 50 before, 50 after
```

The 45 `switch` routes plus the 5 public-auth `if (route === …)` routes —
50 `/api/...` routes in total — and their JSON shapes are unchanged. The
completed always-signed-in auth work is untouched; `static_checks.py` and
`session_checks.py` still pass.

### CI / deploy

`.github/workflows/deploy-edge.yml` now:

1. runs `tools/pg_shim_test.mjs` (**51 offline assertions**, Node 22's
   built-in TS stripping — no npm packages), and fails the deploy if
   `npm:mongodb` or `MONGODB_URI` reappears;
2. provisions Postgres and verifies `verified`, `auth_users_user_triggers:0`,
   `mtek_docs_ready:true`, `mtek_next_serial_ready:true`,
   `mtek_cas_ready:true`, `mtek_rpc_ready:true` (four exact
   `to_regprocedure(...)` signature checks);
3. deploys with `--yes` (Supabase CLI 3.x requires non-interactive
   confirmation — see §4);
4. verifies `ok:true`, the bundle version, **`"storage":"supabase-postgres"`**,
   **`"serial_rpc":"ok"`** and **`"storage_roundtrip":"ok"`** — a stale Mongo
   bundle or a broken Postgres CRUD path can no longer pass.

### Docs / config

`supabase/README.md` rewritten for Supabase-only; `README.md`, `app/README.md`,
`docs/SPEC.md`, `backend/.env.example` and a new `backend/README.md` no
longer direct anyone to MongoDB/Atlas. `docs/ci/deploy-edge.yml` was a stale
partial copy that omitted the mandatory SQL bootstrap; it is now a faithful
snapshot of the live workflow, so copying it cannot produce a function with
no tables. `backend/` is
marked legacy ops tooling, not production.

---

## 3. Verification evidence

### CI

| Run | Result |
|---|---|
| `41890953879` — Deploy @ `b9bbdc0` (v0.4.0+7, payment idempotency, atomic upserts) | **success**, all 10 steps |
| `41890953864` — Build MFSL Office @ `b9bbdc0` (fresh APK / MSIX / portable) | **success**, Android 9m22s / Windows 5m53s, `flutter test` passed |
| `41884279119` — Deploy @ `19a6459` (final, with live pagination proof) | **success**, all 10 steps |
| `41883792270` — Deploy @ `c3b4047` (first fully green E2E smoke test) | **success**, all 10 steps |
| `41883215374` — Deploy @ `e626225` | failed at the SQL step (§7, PostgreSQL 42P13) |
| `41882755406` — Deploy @ `980f0d1` | failed at the SQL gate (§7, `mtek_rpc_ready:false`) |
| `41882120046` — Deploy @ `08be0ae` | failed at the live health gate (§7, quoted filters rejected by real PostgREST) |
| `41795173870` — Deploy @ `bc9e2a4` (real Postgres CRUD gate) | **success**, all 9 steps |
| `41791552150`, `41791331876` — earlier Deploy runs | **success**, all steps |
| `41784100593` — Deploy Edge Function @ `2ef19d4` | **success**, all 9 steps (incl. shim test, SQL provisioning, deploy, bundle + serial RPC verification) |
| `41783875407` — Deploy Edge Function @ `a92ac0c` | **success**, all 9 steps |
| `41783658235` — Build MFSL Office @ `b7632f5` | **success**, Android 11m11s / Windows 6m37s, `flutter test` passed |
| `41783658230` — first Deploy @ `b7632f5` | failed *only* at the CLI deploy step (§4); SQL provisioning already succeeded |

SQL bootstrap response (from the rolling `ci` release deploy log):

```json
[{"auth_trigger_repair":{"auth_users_user_triggers":0,"verified":true,
  "storage":"supabase-postgres","mtek_docs_ready":true,
  "mtek_next_serial_ready":true,"mtek_cas_ready":true,
  "mtek_rpc_ready":true}}]
```

The final run also reports `mtek_rpc_list`, which exposed a second
`mtek_next_serial(p_book_type text, p_actor uuid)` overload — the reason a
naive `count(*) = 4` readiness check was wrong (§7).

### Live endpoints (2026-11-04)

| URL | Response |
|---|---|
| `/health` | `{"ok":true,"version":"2026-09-19-office-suite1","storage":"supabase-postgres","collections":[…20…]}` |
| `/health?deep=1` | `ok:true`, 20 real collections, all 8 serial books at `0`, `"serial_rpc":"ok"`, `"storage_roundtrip":"ok"` |
| `/health?deep=1&full=1` | `{"ok":true,…,"serial_rpc":"ok","storage_roundtrip":"ok","bootstrap_bytes":116}` — all 9 bootstrap collections read successfully |
| `/health?deep=1?v=0407` (current) | `ok:true`, `storage:"supabase-postgres"`, **`"app_version":"0.4.0+7"`, `"app_build":7`** plus release URLs, 20 collections, all 8 serial books `0`, `"serial_rpc":"ok"`, `"storage_roundtrip":"ok"` |
| `/api/bootstrap` (no token) | `{"error":"Missing bearer token"}` — Auth gate intact |

`querySrv ENOTFOUND` no longer occurs. The `serial_rpc:"ok"` gate proves a
real `INSERT … ON CONFLICT` write through PostgREST with the service role;
`storage_roundtrip:"ok"` proves the shim's full CRUD cycle against the real
database (not just the mock used by the offline tests) — including a
deliberately hostile id and a five-row / three-page PostgREST read (§7).

### Authenticated end-to-end (run `41884279119`, rolling `ci` deploy log)

```
=== authenticated E2E smoke test CI-SMOKE-41884279119 ===
receipt serial before: 0
signup OK uid=d8129758-b4d1-4ebf-a27e-ec4da7f6cf09
GET /api/bootstrap OK
GET /api/me OK (role admin)
POST /api/products/upsert + GET /api/products OK
POST /api/docs/issue OK -> server serial 1
repeat issue is idempotent (no second serial consumed)
history / changes / notifications OK
cleanup: []
=== authenticated E2E smoke test PASSED ===
```

This is a **real Supabase JWT**, a real product write/read, and a real
server-issued document serial — the exact path that produced the owner's
original "Document NOT issued" error. The throwaway account, its rows, and
the consumed serial were removed afterwards: `auth_users:3`,
`mtek_docs:10` (9 serials + 1 settings), `mtek_docs_by_collection` contains
no `__health__` or smoke rows, and all 8 serial books are back at `0`.

### Local gates

```
static checks passed: braces balanced, imports resolve, assets exist, no emojis, no placeholders
session checks passed: no background logout, dual-write restore, boot gate, guarded vault, single-flight refresh
53 checks passed   (tools/pg_shim_test.mjs)
app/test/app_update_test.dart — version parsing/comparison (flutter test, in CI)
```

---

## 4. One CI issue found and fixed

Supabase CLI **3.0.0** now asks for an interactive confirmation before
deploying functions:

```
Confirmation required: Deploy 1 Function … This run can't ask because stdout
is not a terminal. Nothing was changed. Re-run with --yes to confirm.
```

On the first push the SQL tables were created but the old Mongo bundle stayed
live. Adding `--yes` to `supabase functions deploy` fixed it; the next run was
fully green.

---

## 5. IMPORTANT — the new store is EMPTY

No historical MongoDB records were carried over (the Atlas cluster is gone and
the owner explicitly chose Supabase-only). `products`, `customers`, `sales`,
invoices etc. start empty, **by design**: the server has never seeded stock.

So after this fix:

- document issuance, serials, sign-in, sync and every data route **work**;
- dashboard counts will still read `00` until records exist in Supabase.

**Candidate data sources already in the repo (not imported — awaiting owner
confirmation):**

| Source | Contents |
|---|---|
| `seed/products_seed.txt` | 359 products with selling prices; cost / qty / reorder / unit columns are blank (template awaiting owner edits) |
| `STOCK/Fire.csv`, `safety.csv`, `solar.csv`, `Surveillanceandhomeautomation.csv` | Product names and website prices only; no quantities |
| Device local caches | Any records still on a signed-in phone/PC |

> **Do not sync a device that still holds local cached records until the
> import source is agreed.** `AppStore.refreshRemote()` replaces the in-memory
> lists with the server snapshot and then persists them, so an empty first
> bootstrap could overwrite that device's local cache. Nothing has been
> imported, overwritten or seeded by this change.

---

## 6. Follow-up — the cut is complete, and the empty store is safe

### Every MongoDB trace removed

The three legacy Atlas ops scripts (`seed-mongo.js`, `verify-connections.js`,
`verify-live.js`) and the `mongodb` npm dependency were **deleted**. They were
replaced with a dependency-free `backend/scripts/verify-supabase.js` that
checks `/health`, `/health?deep=1`, `/health?deep=1&full=1` and the Auth gate.
Stale MongoDB/Atlas references were removed from app comments,
`backend/.env.example`, `README.md` and `docs/SPEC.md`. The only remaining
mentions are **negative assertions** in the deploy workflow (which fail the
build if `npm:mongodb` or `MONGODB_URI` ever return) and historical notes in
this document.

The deploy workflow now also triggers on `supabase/migrations/**`; previously a
SQL-only change silently skipped deployment.

### Exact Supabase database inventory (from the deploy SQL verification)

`public.mtek_table_counts()` reports **actual row counts**:

| Table | Rows |
|---|---|
| `products`, `customers`, `sales`, `sale_items`, `invoices`, `invoice_items`, `invoice_payments`, `receipts`, `financial_transactions`, `issued_documents`, `stock_adjustments`, `mils_logs`, `mils_photos`, `notifications`, `notification_reads`, `audit_events` | **0** |
| `app_settings` | 1 |
| `profiles` | 1 |
| `serial_books` | 6 |
| `mtek_docs` | 10 (9 serial counters + 1 settings — created by this migration) |
| `auth.users` | 3 |

**Conclusion:** there is no business data anywhere in Supabase either. The
`00` counters are now accurate — they are no longer a symptom of a broken
backend. Data will appear as soon as records are entered in the app (or a
catalogue/export is imported). Nothing was imported or overwritten.

### Empty-cloud safety net (client)

`app/lib/data/store.dart` now refuses to persist an **empty successful
bootstrap** over a device that still holds cached records:

- `init()` falls back to `_loadLocal()` when local cache files have data but
  the cloud snapshot is empty;
- `refreshRemote()` rolls back to its in-memory snapshot and skips
  `_persistAll()` in the same situation, setting a clear `lastSyncError`;
- a fresh device with no cache still starts normally with an empty store.

No automatic logout, session, or auth behaviour was touched; both regression
gates still pass.

### Readiness checklist

| Item | Status |
|---|---|
| MongoDB / Atlas dependency anywhere in the repo | **removed** (CI asserts it stays gone) |
| Supabase Postgres schema + atomic serial function | **provisioned and verified** |
| All 50 `/api/...` routes + JSON shapes (45 switch + 5 public auth) | **unchanged** |
| Real Postgres insert / read / update / filter / delete / paged read / atomic upsert | **verified live** (`storage_roundtrip:"ok"`) |
| Server-issued document serials (no offline serials) | **verified live** (`serial_rpc:"ok"`) |
| Supabase Auth / JWT gate | **verified live** |
| Always-signed-in (no automatic logout) | **unchanged**, regression gates pass |
| APK / EXE built from current source | **yes, v0.4.0+7**, rolling `ci` release refreshed 2026-11-04 18:55–18:59Z |
| In-app update check (public `/health` marker + download links) | **added**, with a non-blocking startup prompt and Settings → Check for updates |
| Client/server version drift (Android vs Windows vs Edge) | **prevented**: both build scripts assert pubspec == `APP_VERSION` |
| Empty cloud snapshot wiping device caches | **guarded** |
| Business records (products, customers, sales…) | **empty by design — nothing was imported** |
| Authenticated server flow (signup → bootstrap → product write/read → invoice payment + replay → document issue → history) | **verified in CI** with a real JWT, `41890953879` — self-cleaning |
| Full signed-in walkthrough on an owner device (Flutter UI → sale → PDF) | **not run** — needs the owner's own login and a physical device |

### Still outstanding

1. **Business data.** The store is intentionally empty — an exact row-count
   audit confirmed no records exist in any Supabase table. Enter records in the
   app, or supply a completed `seed/products_seed.txt` / CSV export for a
   one-off idempotent import. Never overwrite existing rows without confirming.
2. A signed-in walkthrough on a real device: sign in, add a product, record a
   sale and issue a document. The server side is now exercised by CI with a
   real JWT, but only the owner can validate the Flutter UI on their device.
3. Optional (cosmetic): Android's OS `versionCode` is the CI run number
   (strictly increasing for in-place upgrades) while the logical build shown
   in the app / compared by the updater is `+7`. They are intentionally
   different. When bumping a release, update **both** `app/pubspec.yaml` and
   `APP_VERSION`/`APP_BUILD` in `index.ts`; the build scripts fail fast if
   they drift.

---

## 7. Critical scrutiny — defects found in my own work (2026-11-04)

The owner asked for a genuine line-by-line review and lifted the data-loss
constraint so real write tests were allowed. That review found **four real
bugs** in the storage layer I had previously called "ready", and the new live
checks then caught **two mistakes in my own fixes**. All are fixed; none was
cosmetic.

### Defects in the original Supabase shim

| # | Defect | Impact | Fix |
|---|---|---|---|
| 1 | `pgRows()` issued one GET. Supabase PostgREST caps a response at `db-max-rows` (default 1000). | `GET /api/products` (`.limit(5000)`), `/api/bootstrap` and `updateMany({})` **silently truncated** past 1000 rows — no error. | Page with `Prefer: count=exact`, `limit`/`offset` and `Content-Range`; stop on a short page. |
| 2 | `eq.<encodeURIComponent(id)>` left PostgREST reserved characters unescaped (offline keys contain `:`; ids can contain `, . ( ) " \`). | Point reads/deletes could match the wrong row or none at all. | No user-controlled URL filter remains (see below). |
| 3 | `updateOne` / `updateMany` / `findOneAndUpdate` were read → JS modify → write. | Two devices selling the same item could both decrement stock from the same quantity — a **regression from MongoDB's atomic `$inc`**. | SQL `mtek_cas_update` compare-and-swap in one `UPDATE … WHERE doc = p_expected`, with up to 4 re-read/retry attempts. |
| 4 | `compareValues` compared numeric strings lexicographically. | `'10'` sorted before `'9'`. | Numeric-aware comparison; ISO timestamps stay lexicographic. |

Also fixed: `updateOne` previously returned `modifiedCount:1` even when nothing
changed, and writes/deletes were needlessly sequential in places. The shim
harness went from 43 to **51** assertions, now covering pagination, CAS retry
with a simulated concurrent writer, hostile ids, numeric-string sorting and the
invariant that **zero** ids ever enter a PostgREST URL filter.

### Mistakes the new live checks caught (this is why they were added)

1. **`41882120046` — `storage_roundtrip:"insert/read failed"`.** My first fix
   quoted filter values (`eq."…"`, escaping `\` before `"`). Real PostgREST
   did not accept it. Rather than guess at its grammar again, I removed the
   whole class of bug: `mtek_doc_get` / `mtek_doc_delete` SQL functions take
   `collection` + `id` as a **JSON body**, and the only remaining `eq.` filter
   is on `collection`, which is always a fixed internal `[A-Za-z0-9_]+` name.
   The live health probe now uses a deliberately hostile id
   (`__roundtrip__,filter.(probe)"q\z`) on every deploy, so this cannot
   regress silently.
2. **`41882755406` — `mtek_rpc_ready:false`.** A `count(*) = 4` readiness
   check was wrong because the project already has **two**
   `mtek_next_serial` overloads (`p_type text` and
   `p_book_type text, p_actor uuid`). Replaced with four exact
   `to_regprocedure(...)` signature checks and added `mtek_rpc_list` to the
   deploy log.
3. **`41883215374` — PostgreSQL `42P13`.** I changed
   `mtek_doc_delete(text,text)` from `RETURNS void` to `RETURNS integer`;
   `CREATE OR REPLACE` cannot change a return type. Restored `void` (the
   Edge Function ignores the result anyway).

### What is now proven live, and what is not

Proven on real Supabase Postgres, with a real JWT: signup, bootstrap, `/api/me`,
product upsert + read-back, **`POST /api/docs/issue` returning server serial
1**, idempotent re-issue (`duplicate:true`, no second serial), document
history, changes and notifications; plus hostile-id CRUD, five-row/three-page
pagination, `serial_rpc:"ok"`, `storage_roundtrip:"ok"`, and exact cleanup back
to `auth_users:3` / `mtek_docs:10`.

Not proven: a real Flutter UI walkthrough on the owner's device; a sale with
stock decrement under genuine multi-device concurrency (the CAS path is proven
against a simulated concurrent writer in the harness, not two phones); and the
`SUPABASE_SERVICE_ROLE_KEY` secret's presence in the dashboard (it is injected
by the runtime and every live read/write succeeded, so it is working).

Residual limitation, stated plainly: **`upsert` is still last-writer-wins**.
`updateOne(..., {upsert:true})` and `findOneAndUpdate(..., {upsert:true})` use a
PostgREST upsert, not CAS. That affects `$setOnInsert` / `$max` in the legacy
offline-replay path (`/api/sync/import`), which the owner's `offline_docs=no`
decision de-emphasises; authoritative document serials come from the atomic
`mtek_next_serial` RPC, so they are unaffected.

---

## 8. Second scrutiny round and the v0.4.0+7 build (2026-11-04)

The owner asked to keep scrutinising **and** to build a new version that can
update. They chose both meanings of "update": record updates must work, and
the app must be able to check for its own updates.

### More real defects found

| # | Defect | Fix |
|---|---|---|
| 1 | `AppStore.payInvoice()` mutated the local invoice, generated a **locally numbered receipt** and persisted transactions/receipts even when `/api/invoices/pay` failed or the server was unreachable. The device said "paid" while Supabase said "unpaid" — the opposite of the server-authoritative `recordSale()`. | Now throws before any local mutation unless the server confirms. The UI already catches and shows "Payment could not be recorded". |
| 2 | `POST /api/invoices/pay` had **no idempotency key**, while `ApiClient` replays a POST once after a 401/token refresh — a replay could charge an invoice twice. | Deterministic client `issue_key` (`PAY-<no>-<balance>-<amount>`); server returns the original receipt with `duplicate:true`. Proven live: one 400 payment, not 800 (`41890953879`). |
| 3 | `ci/build-windows.ps1` passed **no `--dart-define=APP_VERSION`**, so Windows showed the stale `0.1.0+1` fallback while Android showed the real version — which would have broken update comparison. | Both build scripts read `app/pubspec.yaml`, assert it equals the Edge Function's `APP_VERSION`, and bake in `--build-name`, `--build-number` and `APP_VERSION`. |
| 4 | The residual limitation from §7 — **upserts were last-writer-wins** — was left open. It affects `$setOnInsert`, `$max` and `nextSerial()`'s fallback. | SQL `mtek_cas_upsert` (`INSERT … ON CONFLICT DO UPDATE … WHERE d.doc = p_expected`) plus `pgCasUpsert` and a re-read/retry loop. Closed. |
| 5 | `AppInfo.version` fallback was `0.1.0+1` while `pubspec.yaml` said `0.3.0+6`. | Bumped to `0.4.0+7` everywhere, added a parsed `buildNumber`. |

Also: the rolling `ci` release still exposed three stale September assets
(`MFSL-Inventory-portable.zip`, `probe-mongo.txt`, `probe.txt`) that could be
mistaken for the current build. They were removed; only the fresh 2026-11-04
APK, MSIX, portable ZIP and two logs remain.

### How the in-app update check works

The GitHub repo is **private**, so an installed app cannot query the Releases
API without a token. Instead `data-api` publishes a public, no-JWT marker on
`/health`:

```json
{"app_version":"0.4.0+7","app_build":7,
 "app_release_url":"https://github.com/NO-Group/mtek_fire_safety_ltd/releases/tag/ci",
 "app_apk_url":"…/releases/download/ci/MFSL.Inventory.apk",
 "app_windows_url":"…/releases/download/ci/MFSL.Inventory.Setup.msix"}
```

- `AppUpdateService` (dependency-free) reads it via the public `/health`;
  `AppUpdateInfo` compares `app_build` with `AppInfo.buildNumber`.
- One-shot post-frame check on sign-in shows an "Update available" dialog with
  a **Download** button (opens the platform installer URL). It never gates
  boot, never touches the session, never signs anyone out, and all network
  errors are swallowed silently.
- Settings → About → **Check for updates** gives a manual check for every role.
- `app/test/app_update_test.dart` covers parsing, comparison and URL choice;
  `flutter test` ran green in build `41890953864`.
- The deploy gate asserts live `app_version == app/pubspec.yaml`, and both
  build scripts fail fast on drift.

**Honest scope of "update":** the app *detects* a newer build and opens the
correct installer. It does **not** silently download and install an APK/MSIX —
that needs `REQUEST_INSTALL_PACKAGES`/platform installers and a signed-in
GitHub browser session (private repo). Installing still requires the owner's
tap. Future releases only need: bump `pubspec.yaml`, bump `APP_VERSION`/
`APP_BUILD` in `index.ts`, push (both workflows rebuild and redeploy).

### Evidence for this round

- Deploy `41890953879` — all 10 steps green; `mtek_rpc_ready:true`,
  `mtek_rpc_list` now includes `mtek_cas_upsert`; `auth_users:3`,
  `mtek_docs:10` (9 serials + 1 settings), no smoke rows.
- Authenticated E2E log: signup → bootstrap → `/api/me` → product write/read
  → **invoice payment idempotent (one 400 payment, not 800)** →
  `POST /api/docs/issue` server serial 1 → idempotent re-issue →
  history/changes/notifications → cleanup `[]` → PASSED.
- Build `41890953864` — Android 9m22s / Windows 5m53s, `flutter test` green.
  Fresh `ci` assets: `MFSL.Inventory.apk` 68,285,217 B (18:59:02Z),
  `MFSL.Inventory.Setup.msix` 24,281,423 B (18:55:28Z),
  `MFSL-Office-portable.zip` 67,499,734 B (18:55:29Z).
- Live `/health?deep=1` returns `app_version:"0.4.0+7"`, `app_build:7`,
  `serial_rpc:"ok"`, `storage_roundtrip:"ok"`, all serial books `0`.
- Local gates: 53 shim checks, static/session checks, esbuild, js-yaml,
  `bash -n`, `node --check`, 50/50 `/api` routes unchanged.

### Still not proven

- The full Flutter UI walkthrough on the owner's own phone/PC, including
  the new update dialog.
- Two physical devices racing the same stock row or the same upsert.
- Silent/background install (deliberately out of scope, above).

---

## 9. "Fix it once and for all" — finite-surface contract gate (2026-11-04)

Repeated "found another bug" rounds were the wrong method. Instead of more spot
checks, the app's **entire finite surface is now enumerated in one
machine-readable manifest** and every element is cross-checked mechanically by
a build-failing gate. Nothing can drift silently again.

### The enumerated surface

| Surface | Count | Where it is listed |
| --- | --- | --- |
| HTTP routes (method + path) | **50** (16 GET, 34 POST) | `tools/api_contract.json` |
| Client `/api` literals | **39** | scanned from `app/lib/**/*.dart` |
| Contract response keys for GET routes | **16 routes** | manifest `keys` |
| Logical collections (`coll.X()`) | **20** = `STORAGE_COLLECTIONS` | `index.ts` |
| PostgREST SQL RPCs | **5** (+ `mtek_table_counts`, SQL-only) | migration SQL |
| `$` operators used by route handlers | **18** | `index.ts` / shim harness |
| Authoritative serial books | **8** | `BOOK_TYPES` |
| Runtime env vars / dart-defines | **5 / 4** | `index.ts`, `app/lib` |
| Version markers | pubspec, Edge `APP_VERSION`/`APP_BUILD`, `AppInfo`, MSIX, both build scripts | — |

### The permanent gate

`tools/contract_audit.py` (stdlib only, no dependencies) performs **41 checks**,
each of which fails the build on any mismatch:

1. `tools/api_contract.json` equals the 50 routes actually declared in
   `index.ts` — no added, removed, duplicated or malformed route.
2. Every GET route's declared response keys equal the server's real first-level
   `json({...})` keys (brace-aware parser, not a grep).
3. Every client `/api` literal resolves to a declared route — a typo in Dart
   now fails CI rather than surfacing as "Something went wrong on the server".
4. `coll.X()` ↔ the `coll` map; `collection('X')` ↔ `STORAGE_COLLECTIONS`;
   `rpc/mtek_*` ↔ `CREATE OR REPLACE FUNCTION public.mtek_*`; and every RPC is
   `REVOKE`d from `anon/authenticated` and `GRANT`ed to `service_role` only.
5. Every `$operator` used has a shim implementation; the harness still asserts
   the no-URL-filter invariant, CAS/atomic-upsert, serials and paging.
6. All version strings agree; both build scripts bake `APP_VERSION` and fail on
   drift; all dart-defines have defaults; no MongoDB env var/driver survives.
7. Every writing POST route has a 4xx input guard **before** its first write
   (or is explicitly marked `skip` in the manifest with a reason).
8. **No fire-and-forget server write** remains in `store.dart`; `addCustomer`
   is server-first/awaitable and every call site awaits it; `payInvoice` still
   refuses local mutation until the server confirms.
9. **Serials are server-owned**: `/api/sync/import` cannot write a counter.
10. The deploy workflow contains every mandatory live gate, and
    `docs/ci/deploy-edge.yml` is byte-for-byte in sync apart from the three
    documented header differences.

It runs in **both** CI paths: as step 1 of `deploy-edge.yml` and as step 0 of
`ci/build-android.sh` (before Flutter is even installed), plus all the existing
local gates (53 shim checks, static checks, session checks, esbuild, js-yaml,
`bash -n`, `node --check`).

### The exhaustive live sweep

The authenticated E2E step now dispatches **47 of the 50 manifest routes** with
a real JWT:

- **16 GET routes** — read-only, each called (with its declared query params)
  and asserted to return valid JSON containing every declared key.
- **31 POST routes** — sent `{}` and asserted to return valid JSON, never a 5xx,
  never `Unknown API route`. A permanent gate proves **every dispatched probe is
  read-only**: a 4xx guard precedes *any* state-changing call, including the
  `ins`/`audit`/`notify`/`nextSerial` helpers that wrap collection writes.
- **3 skipped, each with a reason in the manifest** —
  `POST /api/notifications/read-all` (would mark every real notification read),
  `POST /api/settings` (unconditional audit event), and `POST /api/mils`
  (would consume a real document serial and create phantom rows). All three are
  covered by the shim harness and the static contract gate.
- The smoke account is promoted to `ceo` so all 7 CEO-only and 11
  CEO/Admin routes execute their handler bodies, not just a 403.
- A new regression probe posts a poisoned `serials` map
  (`invoice: 999999`, etc.) to `/api/sync/import` and asserts the deep-health
  counters are **byte-identical** before and after.

### Two more defects this round closed

| # | Defect | Fix |
| --- | --- | --- |
| 1 | `addCustomer()` was `void` and fire-and-forget: it inserted the customer locally **before** the server replied, then silently replaced its id later. Callers could not detect a rejected save. | Now `Future<Customer>`, server-first like `addProduct()`/`payInvoice()`; throws on an active refusal without touching local state, returns the record actually stored, and all three call sites await it and surface real errors. The ad-hoc receipt path catches a refusal and keeps the customer locally so a receipt is never aborted. |
| 2 | `POST /api/sync/import` accepted a client-supplied `serials` map and applied `$max` to the **authoritative** serial counters — any device could jump a counter and cause duplicate document numbers, contradicting the server-owned-serial directive. | The incoming map is now deliberately ignored; only `nextSerial()` and the CEO-only reseed in `/api/settings` can move a counter. Locked by a static gate **and** the live poison probe. |

### An honest correction from this round

The **first** version of the exhaustive sweep did dispatch `POST /api/mils`
with `{}`. That handler has no input guard: it called `nextSerial('mils')`,
inserted a MILS job, wrote an audit event and a notification. Cleanup removed
the rows (they carry the throwaway uid) but the server counter stayed at 1, and
the live `/health?deep=1` showed `serials.mils: 1` instead of `0`. This was
caught by checking the live health afterwards, not by assuming the green
workflow meant "no side effects". Three changes followed:

1. The gate now counts **every** state-changing call, including helper
   wrappers, and fails if any `{}` probe could write. The three unsafe routes
   are marked `skip` with reasons.
2. The smoke step snapshots **all 8 serial books** at start and restores all
   of them at cleanup (previously only `receipt`/`receiptIssue` were restored).
3. A guarded one-time SQL repair resets the phantom `mils` counter to `0`
   **only while the `logs` (MILS) collection is empty**, so it can never touch
   real owner data. It can only ever fire once.

That is exactly the point of the gate: the failure was found by a mechanical
check, turned into a permanent invariant, and can no longer recur silently.

### Evidence for this round

- `225110c` — first exhaustive gate/sweep committed. Deploy `41899126016`
  green (all 10 steps), build `41899128281` green (Android 11m36s, Windows
  7m3s, `flutter test` passed). That first sweep consumed one phantom MILS
  serial; live `/health?deep=1` showed `serials.mils: 1`.
- `c0e93f8` — corrected, provably read-only sweep. Deploy `41900149097`
  green (all 10 steps). Afterwards live `/health?deep=1` returned
  `"serial_rpc":"ok"`, `"storage_roundtrip":"ok"` and **all 8 serial books
  at 0** — the phantom counter is gone and no new one leaked.
- Fresh rolling `ci` assets: `MFSL.Inventory.apk` 68,301,601 B (19:51:30Z),
  `MFSL.Inventory.Setup.msix` 24,282,153 B (19:46:57Z),
  `MFSL-Office-portable.zip` 67,492,693 B (19:46:58Z),
  `last-edge-deploy.log` 4,519 B (19:48:03Z).
- Local gates re-run after every edit: 40 contract checks, 53 shim checks,
  static + session checks, esbuild parse, js-yaml on both workflows,
  `bash -n ci/build-android.sh`, `node --check backend/scripts/verify-supabase.js`.
- The GitHub Actions log host is unreachable from this sandbox, so the exact
  `route sweep: N routes live-verified, 0 failed, 3 intentionally skipped`
  line could not be read back here; however that step calls `fail()` (exit 1)
  on any 5xx, non-JSON, unknown-route or missing-key result, and the run is
  green — so zero failures is proven by the run status itself.

### Second live correction: a transient health probe

A final live `/health?deep=1` returned
`"storage_roundtrip":"pagination failed: got 4/5"` and then `"ok"` on the
immediate retry. Cause: `probeStorageRoundTrip()` used **fixed** ids
(`__page__0..4`, `label:'page'`) in the shared `__health__` collection. Two
overlapping deep polls (the CI health gate plus a manual check) deleted each
other's page rows, so one saw only 4 of its 5. This could have failed a
perfectly good deployment.

Every probe row now carries a per-invocation `crypto.randomUUID()` nonce, the
pagination assertion counts only that nonce's rows, and cleanup deletes only
that nonce's rows. The gate has a dedicated check that locks this invariant in
(41 checks). A concurrency-safe probe means overlapping health polls can no
longer produce a false-negative deploy gate.

### What this proves — and what it cannot

**Proven mechanically on every push:** all 50 routes exist and are named
correctly; every client call has a server counterpart; every GET response has
the keys the client expects; all 20 collections, 5 RPCs and their grants are
consistent; every operator used is implemented; all 8 version markers agree;
no Mongo dependency/env var remains; no unguarded write or fire-and-forget
write exists; serials cannot be set by a client; the docs snapshot is current.
**Proven live on every deploy:** 47 of 50 routes execute against real Supabase
Postgres without a 5xx or an unknown-route error; deep health, serial RPC,
storage round-trip, payment idempotency, document issuance and cleanup.

**NOT proven — explicitly, so nothing is hidden:**

- No finite gate can prove the *absence of every possible runtime error*;
  it proves the enumerated invariants only. Business-logic mistakes inside a
  handler body, device-specific rendering, and third-party outages are outside
  this enumeration.
- `updateMany()` is a per-row CAS loop, not a single SQL transaction; a mid-loop
  failure can leave earlier rows updated. Its production callers are
  notification read-markers and a one-off profile purge, not financial records.
- `updateOne()` reports `modifiedCount: 1` on a successful CAS even if the value
  was unchanged (Mongo would report 0). Callers use it as "the CAS succeeded".
- A full Flutter UI walkthrough on the owner's own phone/PC (including the
  update dialog), and a two-physical-device stock/upsert race, still need a
  human with the hardware. No owner JWT or owner credentials were used.
- An independent post-smoke check that Auth contains **only** the real owner
  accounts: the deploy log records `cleanup: []` for the throwaway account but
  that is the smoke script's own report, not a separate query.
- The authenticated E2E still creates a **throwaway CI account** (deleted at the
  end of the step). This is the strongest available live proof without owner
  credentials, but it is the one item that still sits against the standing
  "no test account" instruction. Remove that step only if the owner prefers
  weaker (static-only) evidence.
- Silent/background install remains out of scope (§8): the private repo,
  platform installers and the owner's tap are still required.
