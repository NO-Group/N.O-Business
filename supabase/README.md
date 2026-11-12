# N.O Business backend

Everything the backend is lives in SQL migrations: tables, constraints,
row-level security, the functions the app calls, and the storage bucket with
its policies. There are no edge functions and no server process to deploy.

```
supabase/
  config.toml      Supabase CLI configuration (no project ref, no secrets)
  migrations/      the schema, applied in file-name order
  tests/           SQL test suite and its runner
```

| Migration | Contents |
| --- | --- |
| `…000100_platform_core.sql` | Profiles, organizations, workspaces, permissions, roles, memberships, invitations, subscription state, audit trail, and the row-level security for them |
| `…000200_business_core.sql` | Customers, catalogue, stock, sales, quotations, invoices, payments |
| `…000300_documents.sql` | Document records, the private `documents` bucket and its object policies |
| `…000400_rpc.sql` | Every function the app calls (`create_organization`, `record_sale`, `issue_invoice`, …) |

## Apply it to a project

Use a **new, empty** Supabase project. The migrations create their tables
from scratch and are not written to coexist with another schema in `public`.

```sh
supabase link --project-ref <project-ref>
supabase db push          # applies supabase/migrations
supabase config push      # optional: applies the auth settings in config.toml
```

Then, in the dashboard:

1. **Authentication → Sign In / Providers → Email**: keep "Confirm email" on.
   The app confirms addresses with a six-digit code, so edit the *Confirm
   signup* and *Reset password* templates to include `{{ .Token }}`. With the
   default templates users receive a link the desktop app cannot open.
2. **Authentication → SMTP**: configure a mail provider. The built-in sender
   is rate-limited to a handful of messages per hour and is not meant for
   production.
3. **Project Settings → API keys**: copy the project URL and the
   *publishable* (or legacy *anon*) key. Those two values are what the app is
   built with. Never give the app a secret or service-role key; it refuses
   to start with one.

`config.toml` asks for passwords of at least 10 characters with letters and
digits, refresh-token rotation and confirmed emails. The app's own validation
matches those rules.

## Test it

```sh
bash ci/check-db.sh
```

The script creates a Python virtual environment, starts a throwaway
PostgreSQL through the `pgserver` package, applies every migration and runs
the four suites in `tests/` (334 assertions). To use a PostgreSQL you already
have, point it at an **empty scratch database**:

```sh
python supabase/tests/run.py --psql-url postgresql://postgres@localhost/scratch
```

Never run the suite against a real project. It installs
`tests/support/supabase_shim.sql`, a stand-in for the parts of Supabase the
migrations depend on (the `anon`, `authenticated` and `service_role` roles,
`auth.users`, `auth.uid()`, `storage.buckets`, `storage.objects`).

What the suites cover:

| Suite | Proves |
| --- | --- |
| `01_tenant_isolation` | A member of one organization cannot read, write, move or reference another organization's rows, through tables or functions; anonymous callers get nothing; a suspended member loses access at once |
| `02_roles_and_members` | Permissions gate each table; the authorization tables are read-only to clients; a role cannot grant what its author lacks; an organization always keeps an owner |
| `03_business_flows` | Totals are computed by the database; stock moves atomically and cannot go negative; only legal status transitions happen; every function checks its permission |
| `04_documents_and_audit` | Document rows and storage objects are authorized by organization; the audit trail is append-only, also for privileged roles; every `public` table has row-level security enabled |

Because the suite runs on plain PostgreSQL with a stand-in, it proves the SQL
is correct, not that a hosted project behaves identically. See
[`docs/status.md`](../docs/status.md).

## Changing the schema

Add a new migration file with a later timestamp; do not edit one that has
been applied to a real project. Add or extend a test in `tests/` in the same
change, and run `bash ci/check-db.sh`.

The security model, the data model and the plan for moving data from the
previous system are described in [`docs/backend.md`](../docs/backend.md).
