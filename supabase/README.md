# M-TEK server — Supabase ONLY (free tier is enough)

The Android APK and Windows EXE talk to ONE backend: **Supabase Auth** for
sign-in, and the **`data-api` Edge Function** for all business data, stored in
**this project's own Postgres**. There is no MongoDB, no Atlas cluster, no
second database and no external DB secret.

> **2026-11-04:** MongoDB was retired. The Atlas SRV host
> `mfsl.w5ifd7x.mongodb.net` stopped resolving in public DNS (NXDOMAIN), so
> every data route returned `querySrv ENOTFOUND`, documents could not be
> issued and the app showed empty counters. `MONGODB_URI` is no longer read.

## Where the data lives

| Object | Purpose |
|---|---|
| `public.mtek_docs` | One row per record: `(collection, id, doc jsonb)`. All 20 logical collections (products, customers, sales, invoices, receipts, transactions, MILS, profiles, notifications, archive, settings, serials, …) |
| `public.mtek_next_serial(text)` | Atomic paper-book serial allocator (`INSERT … ON CONFLICT DO UPDATE … RETURNING`). Serials are only ever issued by the server — never from a device. |
| `public.mtek_cas_update(text,text,jsonb,jsonb)` | Compare-and-swap so concurrent stock decrements cannot lose each other (MongoDB `$inc` parity). |
| `public.mtek_doc_get(text,text)` / `mtek_doc_delete(text,text)` | Point reads/deletes by JSON body — no user-supplied id is ever put in a PostgREST URL filter. |
| `public.mtek_cas_upsert(text,text,jsonb,jsonb)` | Atomic insert-or-update so `$setOnInsert` / `$max` / the serial fallback are not last-writer-wins. |

Both are created **idempotently** by
`supabase/migrations/20260908160000_remove_auth_profile_trigger.sql`, which
`.github/workflows/deploy-edge.yml` runs against the Management API before
every function deploy. That file also removes any legacy `auth.users` trigger.

RLS is enabled, `anon` / `authenticated` are revoked, and only
`service_role` (automatically injected into the Edge Runtime as
`SUPABASE_SERVICE_ROLE_KEY`) can read or write the table. The apps never touch
Postgres directly — they go through `data-api` with their Supabase JWT.

The HTTP contract of every `/api/...` route is unchanged, so **the existing
APK does not need to be rebuilt** for this migration.

## Deploy / one-time setup

**1. GitHub → Settings → Secrets and variables → Actions** — two repository
secrets (already in place):

| Name | Value |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | Supabase dashboard → Account → Access Tokens |
| `SUPABASE_PROJECT_ID` | Project Settings → General → Reference ID (`kshuadjcflwlidupnqly`) |

**2. NO Edge Function secrets to add.** The runtime injects `SUPABASE_URL`
and `SUPABASE_SERVICE_ROLE_KEY`. Nothing else is required. `MTEK_CEO_UID` is
optional (the CEO is also locked by email).

**3. Push a change under `supabase/functions/**`.** The workflow:

1. runs 53 offline assertions over the Postgres storage shim
   (`tools/pg_shim_test.mjs`) and asserts no Mongo import / `MONGODB_URI`,
2. provisions `mtek_docs`, all five SQL RPCs (verified by exact signature),
   and removes obsolete Auth triggers,
3. deploys `data-api` in place (`--no-verify-jwt --yes`),
4. verifies `health?deep=1&full=1` returns `ok:true`, the expected bundle
   version, `"storage":"supabase-postgres"`, `"serial_rpc":"ok"` and
   `"storage_roundtrip":"ok"`,
5. runs an authenticated end-to-end smoke test with a real JWT (signup →
   bootstrap → product write/read → server-serial document issue →
   idempotent re-issue → history), then removes every test row and account.

Manual alternative: Supabase dashboard → Edge Functions → `data-api` → paste
the whole of `supabase/functions/data-api/index.ts` → Deploy. It has no side
files. Run the SQL migration once first (SQL Editor or Management API).

**4. Supabase → Authentication → Users → "Add user"** → email
`mtekfiresafetyltd@gmail.com` + the company password → tick "Auto-confirm
user". This is only for the CEO account — it is locked to this exact email and
always gets the `ceo` role.

Everyone else (Admin/Sales staff) creates their own account from the app's
"Create an account →" link. It calls `POST /api/auth/signup`, which uses the
Supabase Admin API to create a real Auth user and a matching profile (with
phone number and a ≥15-character recovery phrase). New accounts start as
`sales`; promotion to `admin` happens inside the app (CEO → **Staff**).

## First run — the new store starts EMPTY

STOCK IS NEVER SEEDED. `products` starts empty and is filled through the app
(Add product / Import TXT → `POST /api/products/upsert`). Serial books
self-provision from 000000001.

Because this is a brand-new Postgres store, **no historical MongoDB records
are carried over automatically**. Enter data in the app, import your product
file, or ask for a one-off import from a device cache / export. Never overwrite
existing data without confirming its source first.

> If a device still holds local cached records, do not let an empty first
> bootstrap replace them: confirm the import source before syncing that device.

## Check it's alive

```
https://kshuadjcflwlidupnqly.supabase.co/functions/v1/data-api/health
```

should return `"ok":true`, `"storage":"supabase-postgres"` and the bundle
version. Add `?deep=1` to also read the serial counters and exercise a real
Postgres insert/read/update/filter/delete round-trip
(`"storage_roundtrip":"ok"`) — including a hostile id and a multi-page
read past PostgREST's 1000-row cap — or `?deep=1&full=1` to exercise all nine
bootstrap collections (what CI does). See
`docs/SUPABASE_MIGRATION.md` §7 for the defects this scrutiny found.
`/api/bootstrap` without a bearer token must answer `Missing bearer token`,
which proves Supabase Auth is healthy. `/health` also publishes
`app_version`, `app_build` and installer URLs so installed APK/MSIX builds can
check for a newer release (the repo is private, so the Releases API is not
anonymously readable). Keep `APP_VERSION` in `index.ts` in sync with
`app/pubspec.yaml`; both build scripts fail on drift.

## The exhaustive contract gate

`tools/api_contract.json` lists the **complete** 50-route API surface.
`tools/contract_audit.py` cross-checks it against the Edge Function, the Dart
client, the SQL migration/RPC grants, the shim operators, all version markers
and both CI workflows — 41 checks, any failure stops the build. It runs as step
1 of `deploy-edge.yml` and step 0 of `ci/build-android.sh`. The deploy E2E also
dispatches 47 of the 50 routes live with a real JWT; the 3 skipped
routes are the only ones that would write on an empty body, each with a
reason recorded in the manifest. Every dispatched probe is proven read-only. See `docs/SUPABASE_MIGRATION.md` §9 for the exact coverage and the
explicit list of what is still unproven. Adding a route, renaming a response
key or bumping a version now requires updating the manifest — CI will tell you.

## Updating later

Edit `supabase/functions/data-api/index.ts` and push — the workflow handles
SQL provisioning, deployment and verification. Alternatively re-paste the one
file in the dashboard editor.
