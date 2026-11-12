-- Document metadata + storage object policies, and the audit trail.
\set QUIET on
select tests.superuser();
select tests.create_user('owner@e.test') as owner \gset
select tests.create_user('viewer@e.test') as viewer \gset
select tests.create_user('rival@f.test') as rival \gset

select tests.login(:'rival');
select public.create_organization('Foxtrot Ltd') as org_f \gset
select tests.login(:'owner');
select public.create_organization('Echo Ltd') as org \gset
select public.invite_member(:'org', 'viewer@e.test', (select id from public.roles where organization_id = :'org' and name = 'Viewer')) as inv \gset
select tests.login(:'viewer');
select public.accept_invitation(:'inv');

-- ---- storage objects: authorized by the first path segment --------------------
select tests.login(:'owner');
select gen_random_uuid() as doc \gset
insert into storage.objects (bucket_id, name) values ('documents', :'org' || '/' || :'doc' || '/contract.pdf');
insert into public.documents (id, organization_id, name, storage_path, mime_type, size_bytes)
  values (:'doc', :'org', 'Contract', :'org' || '/' || :'doc' || '/contract.pdf', 'application/pdf', 2048);
select tests.ok(tests.count('select 1 from storage.objects') = 1, 'owner can upload into the tenant folder');
select tests.throws(format($$insert into storage.objects (bucket_id, name) values ('documents', %L)$$, :'org_f' || '/x/steal.pdf'),
  '42501', 'cannot upload into another tenant folder');
select tests.throws($$insert into storage.objects (bucket_id, name) values ('documents', 'not-a-uuid/x/file.pdf')$$,
  '42501', 'a malformed path is denied, not an error');
select tests.throws($$insert into storage.objects (bucket_id, name) values ('documents', 'loose.pdf')$$,
  '42501', 'an object outside any tenant folder is denied');
select tests.throws(format($$insert into public.documents (id, organization_id, name, storage_path, mime_type, size_bytes)
    values (gen_random_uuid(), %L, 'Fake', %L, 'application/pdf', 10)$$, :'org', :'org_f' || '/x/steal.pdf'),
  '23514', 'metadata cannot point outside its own tenant folder');
select tests.throws(format($$insert into public.documents (id, organization_id, name, storage_path, mime_type, size_bytes)
    values (%L, %L, 'Exe', %L, 'application/x-msdownload', 10)$$, gen_random_uuid(), :'org', :'org' || '/y/a.exe'),
  '23514', 'disallowed file types are rejected');
select tests.throws(format($$insert into public.documents (id, organization_id, name, storage_path, mime_type, size_bytes)
    values (%L, %L, 'Huge', %L, 'application/pdf', 20971521)$$, :'doc', :'org', :'org' || '/' || :'doc' || '/huge.pdf'),
  '23514', 'files above 20 MB are rejected');

select tests.login(:'viewer');
select tests.ok(tests.count('select 1 from storage.objects') = 1, 'viewer can read tenant objects');
select tests.ok(tests.count('select 1 from public.documents') = 1, 'viewer can read document metadata');
select tests.throws(format($$insert into storage.objects (bucket_id, name) values ('documents', %L)$$, :'org' || '/z/new.pdf'),
  '42501', 'viewer cannot upload');
select tests.affects_none('delete from storage.objects', 'viewer cannot delete objects');
select tests.affects_none('delete from public.documents', 'viewer cannot delete document metadata');
select tests.affects_none($$update public.documents set name = 'Renamed'$$, 'viewer cannot rename documents');

select tests.login(:'rival');
select tests.ok(tests.count('select 1 from storage.objects') = 0, 'another tenant sees no objects');
select tests.ok(tests.count('select 1 from public.documents') = 0, 'another tenant sees no document metadata');
select tests.affects_none('delete from storage.objects', 'another tenant cannot delete objects');

select tests.anonymous();
select tests.throws('select * from public.documents', '42501', 'anon cannot read documents');

-- ---- audit trail ----------------------------------------------------------------
select tests.login(:'owner');
update public.organizations set name = 'Echo Limited' where id = :'org';
select tests.ok(tests.count($$select 1 from public.audit_logs where entity_type = 'organizations' and action = 'create'$$) = 1, 'organization creation is audited');
select tests.ok(tests.count($$select 1 from public.audit_logs where entity_type = 'organizations' and action = 'update'
  and details -> 'changed' -> 'name' ->> 'to' = 'Echo Limited'$$) = 1, 'organization edits record old and new values');
select tests.ok(tests.count($$select 1 from public.audit_logs where entity_type = 'memberships' and action = 'insert'$$) = 2, 'membership grants are audited');
select tests.ok(tests.count($$select 1 from public.audit_logs where entity_type = 'invitations'$$) >= 2, 'invitation lifecycle is audited');
select tests.ok(tests.count($$select 1 from public.audit_logs where entity_type = 'documents' and action = 'insert'$$) = 1, 'document uploads are audited');
select tests.ok((select bool_and(actor_id is not null) from public.audit_logs), 'every entry names its actor');
select tests.ok(tests.count(format('select 1 from public.audit_logs where organization_id <> %L', :'org')) = 0, 'audit entries are tenant-scoped');
select tests.throws($$update public.audit_logs set action = 'tampered'$$, '42501', 'audit entries cannot be updated by a client');
select tests.throws('delete from public.audit_logs', '42501', 'audit entries cannot be deleted by a client');

-- Append-only holds for privileged roles too.
select tests.superuser();
select tests.ok((select file_size_limit from storage.buckets where id = 'documents') = 20971520, 'bucket enforces the same size limit');
select tests.ok(not (select public from storage.buckets where id = 'documents'), 'bucket is private');
select tests.throws($$update public.audit_logs set action = 'tampered'$$, '42501', 'audit entries cannot be updated even by a privileged role');
select tests.throws('delete from public.audit_logs', '42501', 'audit entries cannot be deleted even by a privileged role');

-- ---- tenant teardown is clean ----------------------------------------------------
delete from public.organizations where id = :'org';
select tests.ok(tests.count(format('select 1 from public.audit_logs where organization_id = %L', :'org')) = 0, 'deleting a tenant removes its audit trail');
select tests.ok(tests.count(format('select 1 from public.memberships where organization_id = %L', :'org')) = 0, 'and its memberships');
select tests.ok(tests.count(format('select 1 from public.documents where organization_id = %L', :'org')) = 0, 'and its documents');
select tests.ok(tests.count(format('select 1 from public.organizations where id = %L', :'org_f')) = 1, 'other tenants are unaffected');
delete from auth.users where id = :'viewer';
select tests.ok(tests.count(format('select 1 from public.profiles where id = %L', :'viewer')) = 0, 'deleting a user removes the profile');

-- ---- every public table has RLS enabled -------------------------------------------
select tests.ok(
  (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity) = 0,
  'RLS is enabled on every table in public');
select tests.ok(
  (select count(*) from information_schema.role_table_grants
   where table_schema = 'public' and grantee in ('anon', 'PUBLIC')) = 0,
  'anon holds no table privileges in public');
select tests.ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'app') and has_function_privilege('anon', p.oid, 'execute')) = 0,
  'anon can execute no function in public or app');
select tests.ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('public', 'app') and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')) = 0,
  'every SECURITY DEFINER function pins search_path');
