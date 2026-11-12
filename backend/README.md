# Supabase-only ops tooling

This folder is **not** the production backend. The shipped apps talk to
[`supabase/functions/data-api/index.ts`](../supabase/functions/data-api/index.ts),
which stores everything in **Supabase Postgres** (`public.mtek_docs`).

MongoDB was removed completely on 2026-11-04. The three legacy scripts that
talked to the retired Atlas cluster (`seed-mongo.js`, `verify-connections.js`,
`verify-live.js`) and the `mongodb` npm dependency were deleted — there is no
Mongo code left in this repository.

## Live check (no dependencies)

```bash
cd backend
npm run verify
# or:  SUPABASE_URL=https://<ref>.supabase.co npm run verify
```

`scripts/verify-supabase.js` uses Node's built-in `fetch` and checks:

| Check | Expects |
|---|---|
| `GET /health` | `ok:true`, `storage:"supabase-postgres"` |
| `GET /health?deep=1` | serial books present, `serial_rpc:"ok"` |
| `GET /health?deep=1&full=1` | all nine bootstrap collections readable |
| `GET /api/bootstrap` (no token) | `{"error":"Missing bearer token"}` |

`.env.example` is a reference template only. Production needs **no** secrets
in this folder and no `MONGODB_URI`: the Edge Runtime injects `SUPABASE_URL`
and `SUPABASE_SERVICE_ROLE_KEY` automatically. See
[`supabase/README.md`](../supabase/README.md) for deployment.
