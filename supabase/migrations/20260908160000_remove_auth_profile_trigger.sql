-- ============================================================================
-- M-TEK / data-api database bootstrap.
-- Executed by .github/workflows/deploy-edge.yml ("Remove and verify obsolete
-- Auth profile triggers") against the Management API BEFORE every function
-- deploy. Keep the auditable verification SELECT as the LAST statement: the
-- workflow's jq gate reads that result set to prove the repair succeeded.
--
-- 2026-11-04 owner directive: "Supabase alone is for our backend". The old
-- MongoDB/Atlas cluster (mfsl.w5ifd7x.mongodb.net) no longer resolves in
-- public DNS, so every data route returned `querySrv ENOTFOUND`. This file
-- now provisions the replacement storage in THIS project's Postgres:
--
--   public.mtek_docs            (collection, id, doc jsonb) — ALL records
--   public.mtek_next_serial()   — race-safe paper-book serial allocator
--
-- Serials deliberately live IN mtek_docs under collection 'serials', so
-- /api/bootstrap, /api/settings (reseed), health?deep=1 and the allocator all
-- read and write the SAME counter. There is no second serial table to drift.
--
-- Every statement is idempotent so re-running on each deploy is safe. RLS is
-- enabled, anon/authenticated are revoked, and only service_role (the key the
-- Edge Runtime injects) may touch the table.
-- ============================================================================

create table if not exists public.mtek_docs (
  collection text         not null,
  id          text        not null,
  doc         jsonb       not null default '{}'::jsonb,
  written_at  timestamptz not null default now(),
  primary key (collection, id)
);

create index if not exists mtek_docs_collection_idx on public.mtek_docs (collection);

alter table public.mtek_docs enable row level security;
drop policy if exists mtek_docs_service_role on public.mtek_docs;
create policy mtek_docs_service_role on public.mtek_docs
  for all to service_role using (true) with check (true);

revoke all on public.mtek_docs from anon, authenticated;
grant usage on schema public to service_role;
grant select, insert, update, delete on public.mtek_docs to service_role;

-- Paper-book serials must NEVER be issued from a device/local counter, and two
-- devices must never receive the same number. A single SQL statement with
-- INSERT ... ON CONFLICT DO UPDATE takes a row lock and returns the new value,
-- so concurrent document issuances cannot collide. The counter is stored in
-- the same document table that peekSerials()/reseed already use.
create or replace function public.mtek_next_serial(p_type text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v integer;
begin
  insert into public.mtek_docs (collection, id, doc)
  values (
    'serials',
    p_type,
    jsonb_build_object('_id', p_type, 'last_used', 1)
  )
  on conflict (collection, id) do update
    set doc = jsonb_set(
          mtek_docs.doc,
          '{last_used}',
          to_jsonb(
            coalesce((mtek_docs.doc ->> 'last_used')::numeric, 0)::integer + 1
          )
        ),
        written_at = now()
  returning (doc ->> 'last_used')::integer into v;
  return v;
end;
$$;

revoke all on function public.mtek_next_serial(text) from public, anon, authenticated;
grant execute on function public.mtek_next_serial(text) to service_role;

-- Compare-and-swap for document updates. The Edge Function reads a row,
-- applies $set/$inc/etc. in JS, then calls this function: the UPDATE only
-- lands if the stored document is STILL exactly the one it read. A null
-- result means a concurrent writer won the race and the caller retries.
-- This restores the atomicity MongoDB's $inc gave stock decrements.
create or replace function public.mtek_cas_update(
  p_collection text, p_id text, p_expected jsonb, p_next jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  update public.mtek_docs
     set doc = p_next, written_at = now()
   where collection = p_collection
     and id = p_id
     and doc = p_expected
  returning doc into v;
  return v;
end;
$$;
revoke all on function public.mtek_cas_update(text, text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.mtek_cas_update(text, text, jsonb, jsonb)
  to service_role;

-- Atomic upsert: INSERT ... ON CONFLICT DO UPDATE ... WHERE doc = expected.
-- `p_expected` is NULL when the caller saw no row; the conflict branch then
-- deliberately does nothing and returns NULL, so the caller re-reads and
-- retries. This makes $setOnInsert / $max / nextSerial()'s fallback safe
-- under concurrency instead of last-writer-wins.
create or replace function public.mtek_cas_upsert(
  p_collection text, p_id text, p_expected jsonb, p_next jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v jsonb;
begin
  insert into public.mtek_docs as d (collection, id, doc, written_at)
  values (p_collection, p_id, p_next, now())
  on conflict (collection, id) do update
     set doc = excluded.doc, written_at = now()
   where d.doc = p_expected
  returning doc into v;
  return v;
end;
$$;
revoke all on function public.mtek_cas_upsert(text, text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.mtek_cas_upsert(text, text, jsonb, jsonb)
  to service_role;

-- Point reads/deletes go through these two functions so no user-supplied id
-- is ever interpolated into a PostgREST `eq.` URL filter. Quoted filter values
-- were tried and failed against real PostgREST (the live health probe caught
-- it); JSON bodies have no grammar to escape.
create or replace function public.mtek_doc_get(p_collection text, p_id text)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select doc from public.mtek_docs
   where collection = p_collection and id = p_id;
$$;
revoke all on function public.mtek_doc_get(text, text)
  from public, anon, authenticated;
grant execute on function public.mtek_doc_get(text, text) to service_role;

-- NOTE: keep RETURNS void. This function was first deployed with void;
-- CREATE OR REPLACE cannot change a return type (PostgreSQL 42P13).
create or replace function public.mtek_doc_delete(p_collection text, p_id text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.mtek_docs
   where collection = p_collection and id = p_id;
$$;
revoke all on function public.mtek_doc_delete(text, text)
  from public, anon, authenticated;
grant execute on function public.mtek_doc_delete(text, text) to service_role;

-- Exact row counts for every public table. pg_class.reltuples is -1 until a
-- table has been ANALYZEd, so it cannot answer "does Supabase already hold
-- business data?". This read-only helper gives the deploy log real numbers.
create or replace function public.mtek_table_counts()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  n bigint;
  result jsonb := '[]'::jsonb;
begin
  for r in
    select c.relname as t
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace
    where ns.nspname = 'public' and c.relkind = 'r'
    order by 1
  loop
    execute format('select count(*) from public.%I', r.t) into n;
    result := result || jsonb_build_object('t', r.t, 'n', n);
  end loop;
  return result;
end;
$$;
revoke all on function public.mtek_table_counts() from public, anon, authenticated;

-- Ask PostgREST to pick up the new table / RPC immediately. Supabase also
-- installs a DDL-watch event trigger, so this is belt-and-braces.
-- A failed deploy can leave a scratch row behind; the probe collection is
-- not business data, so clear it on every bootstrap.
delete from public.mtek_docs where collection = '__health__';

notify pgrst, 'reload schema';

-- ---------------------------------------------------------------------------
-- Legacy repair: staff profiles are owned by the data-api (now Postgres),
-- NOT by an auth.users trigger. A leftover trigger mirrored new users into a
-- removed/incompatible Postgres profile table and made GoTrue fail with
-- "Database error creating new user". Drop every user-defined trigger.
-- Do not filter by function schema: legacy triggers may call public, auth or
-- extensions functions, and filtering by public previously left one behind.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  trigger_row record;
  remaining integer;
BEGIN
  FOR trigger_row IN
    SELECT t.tgname
    FROM pg_trigger t
    WHERE t.tgrelid = 'auth.users'::regclass
      AND NOT t.tgisinternal
  LOOP
    RAISE NOTICE 'Dropping user-defined auth.users trigger: %', trigger_row.tgname;
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON auth.users', trigger_row.tgname);
  END LOOP;

  SELECT count(*) INTO remaining
  FROM pg_trigger t
  WHERE t.tgrelid = 'auth.users'::regclass
    AND NOT t.tgisinternal;

  IF remaining <> 0 THEN
    RAISE EXCEPTION 'auth.users still has % user-defined trigger(s)', remaining;
  END IF;
END $$;

-- Return an auditable result to the Management API/GitHub Actions log.
-- The workflow requires `verified: true` and `auth_users_user_triggers: 0`.
SELECT json_build_object(
  'auth_users_user_triggers', count(*),
  'verified', count(*) = 0,
  'storage', 'supabase-postgres',
  'mtek_docs_ready',
    (select count(*) > 0 from pg_tables
     where schemaname = 'public' and tablename = 'mtek_docs'),
  'mtek_next_serial_ready',
    (select count(*) > 0 from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'mtek_next_serial'),
  'mtek_cas_ready',
    (select count(*) > 0 from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname = 'mtek_cas_update'),
  -- Exact signature checks (not a row count: an overload or a stale
  -- signature would make count(*) = 4 misleading).
  'mtek_rpc_ready',
    (to_regprocedure('public.mtek_next_serial(text)') is not null and
     to_regprocedure('public.mtek_cas_update(text,text,jsonb,jsonb)') is not null and
     to_regprocedure('public.mtek_doc_get(text,text)') is not null and
     to_regprocedure('public.mtek_doc_delete(text,text)') is not null and
     to_regprocedure('public.mtek_cas_upsert(text,text,jsonb,jsonb)') is not null),
  'mtek_rpc_list',
    (select coalesce(json_agg(p.proname || '(' ||
               pg_get_function_identity_arguments(p.oid) || ')' order by 1), '[]'::json)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'mtek%'),
  -- One-time inventory of this Supabase project. The deploy workflow writes
  -- the full SQL response into the rolling ci release log, so the team can
  -- see whether any business data already lives in Postgres (and in which
  -- collection) without guessing or touching any external database.
  'table_counts', public.mtek_table_counts(),
  'mtek_docs_by_collection', (
    select coalesce(
      json_agg(json_build_object('c', d.collection, 'n', d.n)
               order by d.collection), '[]'::json)
    from (select collection, count(*)::bigint as n
          from public.mtek_docs group by collection) d
  ),
  'auth_users', (select count(*) from auth.users)
) AS auth_trigger_repair
FROM pg_trigger t
WHERE t.tgrelid = 'auth.users'::regclass
  AND NOT t.tgisinternal;
