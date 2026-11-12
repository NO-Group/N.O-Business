-- ============================================================================
-- N.O Business — documents (foundation for DocuMind)
--
-- Files live in the private `documents` storage bucket. The object key is
--   <organization_id>/<document_id>/<file name>
-- and storage policies authorize on that first path segment, so tenant
-- isolation holds for the bytes as well as for the metadata row.
--
-- Extraction / OCR / classification columns are intentionally NOT added yet:
-- they arrive with the DocuMind processing pipeline, in their own migration.
-- ============================================================================

create table public.documents (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  workspace_id    uuid,
  name            text not null check (char_length(btrim(name)) between 1 and 200),
  category        text not null default 'general' check (category in (
                    'general', 'contract', 'invoice', 'receipt', 'quotation',
                    'identity', 'report', 'other')),
  storage_path    text not null unique,
  mime_type       text not null check (mime_type in (
                    'application/pdf', 'image/png', 'image/jpeg', 'image/webp',
                    'text/plain', 'text/csv',
                    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
  size_bytes      bigint not null check (size_bytes > 0 and size_bytes <= 20971520),
  customer_id     uuid,
  notes           text check (notes is null or char_length(notes) <= 1000),
  uploaded_by     uuid default auth.uid() references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, organization_id),
  -- The metadata row may only describe an object inside its own tenant folder.
  constraint documents_path_in_tenant
    check (storage_path like organization_id::text || '/' || id::text || '/%'),
  foreign key (workspace_id, organization_id)
    references public.workspaces (id, organization_id),
  foreign key (customer_id, organization_id)
    references public.customers (id, organization_id) on delete set null (customer_id)
);

create index documents_org_time_idx on public.documents (organization_id, created_at desc);
create index documents_customer_idx on public.documents (customer_id);
create index documents_workspace_idx on public.documents (workspace_id);

create trigger documents_touch before update on public.documents
  for each row execute function app.touch_updated_at();
create trigger documents_tenant_lock before update on public.documents
  for each row execute function app.prevent_tenant_change();
create trigger documents_audit after insert or delete on public.documents
  for each row execute function app.audit_row_change();

alter table public.documents enable row level security;

revoke all on public.documents from public, anon, authenticated;
grant all on public.documents to service_role;
grant select, delete on public.documents to authenticated;
grant insert (
  id, organization_id, workspace_id, name, category, storage_path, mime_type,
  size_bytes, customer_id, notes
) on public.documents to authenticated;
grant update (name, category, customer_id, notes) on public.documents to authenticated;

create policy documents_select on public.documents
  for select to authenticated
  using (app.has_permission(organization_id, 'documents.read'));
create policy documents_insert on public.documents
  for insert to authenticated
  with check (app.has_permission(organization_id, 'documents.write'));
create policy documents_update on public.documents
  for update to authenticated
  using (app.has_permission(organization_id, 'documents.write'))
  with check (app.has_permission(organization_id, 'documents.write'));
create policy documents_delete on public.documents
  for delete to authenticated
  using (app.has_permission(organization_id, 'documents.delete'));

-- ---------------------------------------------------------------------------
-- Storage bucket + object policies
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documents', 'documents', false, 20971520,
  array[
    'application/pdf', 'image/png', 'image/jpeg', 'image/webp',
    'text/plain', 'text/csv',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- A malformed first path segment must evaluate to "no access", not an error.
create or replace function app.try_uuid(p_value text)
returns uuid
language plpgsql
immutable
set search_path = ''
as $$
begin
  return p_value::uuid;
exception when others then
  return null;
end;
$$;

revoke all on function app.try_uuid(text) from public, anon;
grant execute on function app.try_uuid(text) to authenticated, service_role;

drop policy if exists no_business_documents_select on storage.objects;
create policy no_business_documents_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and app.has_permission(app.try_uuid(split_part(name, '/', 1)), 'documents.read')
  );

drop policy if exists no_business_documents_insert on storage.objects;
create policy no_business_documents_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'documents'
    and app.has_permission(app.try_uuid(split_part(name, '/', 1)), 'documents.write')
  );

drop policy if exists no_business_documents_delete on storage.objects;
create policy no_business_documents_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'documents'
    and app.has_permission(app.try_uuid(split_part(name, '/', 1)), 'documents.delete')
  );
