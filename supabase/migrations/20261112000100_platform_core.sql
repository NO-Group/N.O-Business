-- ============================================================================
-- N.O Business — platform core (multi-tenant foundation)
--
-- Tenancy model
--   organization  = the tenant. Every business row carries organization_id.
--   workspace     = an operating unit inside an organization (branch, store,
--                   business line). Stock, sales and billing documents are
--                   scoped to a workspace; customers and the catalogue are
--                   organization-wide.
--   membership    = user <-> organization, carrying exactly one role.
--   role          = named permission set, owned by an organization.
--
-- Enforcement
--   * Row Level Security is enabled on every table. Policies call
--     app.has_permission(organization_id, '<permission>'), never trust
--     client-side filtering.
--   * Tables that decide *who may do what* (memberships, roles,
--     role_permissions, invitations, audit_logs, subscriptions) are READ-ONLY
--     for clients. They change only through the SECURITY DEFINER functions
--     in 20261112000400_rpc.sql, which run their own authorization checks.
--   * Child rows reference parents with composite (id, organization_id)
--     foreign keys, so a row can never point at another tenant's data even
--     if a policy were wrong.
--
-- All helper functions pin search_path to '' and schema-qualify every name.
-- ============================================================================

create schema if not exists app;
comment on schema app is
  'N.O Business internal helpers. Not exposed through the Data API.';

revoke all on schema app from public;
grant usage on schema app to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Generic triggers
-- ---------------------------------------------------------------------------
create or replace function app.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- A row never moves between tenants. Without this, a user who belongs to two
-- organizations could re-home a record by updating organization_id.
create or replace function app.prevent_tenant_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id is distinct from old.organization_id then
    raise exception 'organization_id is immutable'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profiles (one per auth user)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text not null,
  full_name   text not null default '' check (char_length(full_name) <= 120),
  phone       text check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'),
  avatar_path text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger profiles_touch before update on public.profiles
  for each row execute function app.touch_updated_at();

-- Mirrors auth.users into profiles. Deliberately defensive: a failure here
-- would block sign-up, so it only ever inserts/updates one narrow row.
create or replace function app.handle_auth_user_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    coalesce(new.email, ''),
    left(coalesce(new.raw_user_meta_data ->> 'full_name', ''), 120)
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists no_business_on_auth_user_created on auth.users;
create trigger no_business_on_auth_user_created
  after insert or update of email on auth.users
  for each row execute function app.handle_auth_user_change();

-- Accounts that existed before this migration.
insert into public.profiles (id, email, full_name)
select u.id, coalesce(u.email, ''),
       left(coalesce(u.raw_user_meta_data ->> 'full_name', ''), 120)
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Organizations and workspaces
-- ---------------------------------------------------------------------------
create table public.organizations (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (char_length(btrim(name)) between 2 and 120),
  slug             text not null unique
                     check (slug ~ '^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$'),
  legal_name       text check (legal_name is null or char_length(legal_name) <= 200),
  email            text check (email is null or email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone            text check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'),
  address          text check (address is null or char_length(address) <= 500),
  country_code     text check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  currency_code    text not null default 'USD' check (currency_code ~ '^[A-Z]{3}$'),
  timezone         text not null default 'UTC',
  tax_id           text check (tax_id is null or char_length(tax_id) <= 60),
  default_tax_rate numeric(5, 2) not null default 0
                     check (default_tax_rate >= 0 and default_tax_rate <= 100),
  brand_color      text check (brand_color is null or brand_color ~ '^#[0-9A-Fa-f]{6}$'),
  logo_path        text,
  document_footer  text check (document_footer is null or char_length(document_footer) <= 1000),
  created_by       uuid references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create trigger organizations_touch before update on public.organizations
  for each row execute function app.touch_updated_at();

create table public.workspaces (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (char_length(btrim(name)) between 2 and 80),
  address         text check (address is null or char_length(address) <= 500),
  is_default      boolean not null default false,
  is_archived     boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, organization_id),
  constraint workspaces_default_is_active check (not (is_default and is_archived))
);

create unique index workspaces_name_key
  on public.workspaces (organization_id, lower(btrim(name)));
create unique index workspaces_one_default
  on public.workspaces (organization_id) where is_default;

create trigger workspaces_touch before update on public.workspaces
  for each row execute function app.touch_updated_at();
create trigger workspaces_tenant_lock before update on public.workspaces
  for each row execute function app.prevent_tenant_change();

-- ---------------------------------------------------------------------------
-- Permissions, roles, memberships
-- ---------------------------------------------------------------------------
create table public.permissions (
  key         text primary key check (key ~ '^[a-z_]+\.[a-z_]+$'),
  module      text not null,
  description text not null
);

insert into public.permissions (key, module, description) values
  ('org.manage',        'Organization', 'Edit organization profile and settings'),
  ('workspaces.manage', 'Organization', 'Create, rename and archive workspaces'),
  ('members.read',      'Team',         'View members and pending invitations'),
  ('members.manage',    'Team',         'Invite, suspend and remove members; assign roles'),
  ('roles.manage',      'Team',         'Create and edit custom roles'),
  ('audit.read',        'Security',     'View the audit trail'),
  ('reports.view',      'Insights',     'View dashboards and business reports'),
  ('customers.read',    'Customers',    'View customers'),
  ('customers.write',   'Customers',    'Create and edit customers'),
  ('customers.delete',  'Customers',    'Delete customers'),
  ('catalog.read',      'Catalogue',    'View products and services'),
  ('catalog.write',     'Catalogue',    'Create and edit products and services'),
  ('catalog.delete',    'Catalogue',    'Delete products and services'),
  ('inventory.read',    'Inventory',    'View stock levels and movements'),
  ('inventory.adjust',  'Inventory',    'Adjust stock levels'),
  ('sales.read',        'Sales',        'View sales'),
  ('sales.create',      'Sales',        'Record sales'),
  ('sales.void',        'Sales',        'Void recorded sales'),
  ('quotations.read',   'Quotations',   'View quotations'),
  ('quotations.write',  'Quotations',   'Create, edit and progress quotations'),
  ('invoices.read',     'Invoices',     'View invoices and payments'),
  ('invoices.write',    'Invoices',     'Create, edit and issue invoices'),
  ('invoices.void',     'Invoices',     'Void issued invoices'),
  ('payments.record',   'Invoices',     'Record payments against invoices'),
  ('documents.read',    'Documents',    'View and download documents'),
  ('documents.write',   'Documents',    'Upload and edit documents'),
  ('documents.delete',  'Documents',    'Delete documents');

create table public.roles (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name            text not null check (char_length(btrim(name)) between 2 and 60),
  description     text not null default '' check (char_length(description) <= 300),
  is_system       boolean not null default false,
  is_owner        boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, organization_id)
);

create unique index roles_name_key
  on public.roles (organization_id, lower(btrim(name)));
create unique index roles_one_owner_role
  on public.roles (organization_id) where is_owner;

create trigger roles_touch before update on public.roles
  for each row execute function app.touch_updated_at();
create trigger roles_tenant_lock before update on public.roles
  for each row execute function app.prevent_tenant_change();

create table public.role_permissions (
  role_id         uuid not null,
  organization_id uuid not null,
  permission_key  text not null references public.permissions (key) on delete cascade,
  primary key (role_id, permission_key),
  foreign key (role_id, organization_id)
    references public.roles (id, organization_id) on delete cascade
);

create index role_permissions_org_idx on public.role_permissions (organization_id);

create table public.memberships (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id         uuid not null references auth.users (id) on delete cascade,
  role_id         uuid not null,
  status          text not null default 'active' check (status in ('active', 'suspended')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (organization_id, user_id),
  constraint memberships_role_fk foreign key (role_id, organization_id)
    references public.roles (id, organization_id),
  constraint memberships_profile_fk foreign key (user_id)
    references public.profiles (id) on delete cascade
);

create index memberships_user_idx on public.memberships (user_id) where status = 'active';
create index memberships_role_idx on public.memberships (role_id);

create trigger memberships_touch before update on public.memberships
  for each row execute function app.touch_updated_at();
create trigger memberships_tenant_lock before update on public.memberships
  for each row execute function app.prevent_tenant_change();

-- Invariant: an organization always keeps at least one active owner.
-- Deferred so ownership can be handed over inside one transaction, and
-- skipped when the organization itself is being removed.
create or replace function app.ensure_owner_remains()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.organizations o where o.id = old.organization_id) then
    return null;
  end if;
  if not exists (
    select 1
    from public.memberships m
    join public.roles r on r.id = m.role_id
    where m.organization_id = old.organization_id
      and m.status = 'active'
      and r.is_owner
  ) then
    raise exception 'An organization must keep at least one active owner'
      using errcode = 'P0001';
  end if;
  return null;
end;
$$;

create constraint trigger memberships_owner_remains
  after update or delete on public.memberships
  deferrable initially deferred
  for each row execute function app.ensure_owner_remains();

-- ---------------------------------------------------------------------------
-- Authorization helpers used by every policy
-- ---------------------------------------------------------------------------
create or replace function app.is_org_member(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
  );
$$;

create or replace function app.is_org_owner(p_org uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    join public.roles r on r.id = m.role_id
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and r.is_owner
  );
$$;

create or replace function app.has_permission(p_org uuid, p_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships m
    join public.roles r on r.id = m.role_id
    where m.organization_id = p_org
      and m.user_id = (select auth.uid())
      and m.status = 'active'
      and (
        r.is_owner
        or exists (
          select 1
          from public.role_permissions rp
          where rp.role_id = r.id
            and rp.permission_key = p_permission
        )
      )
  );
$$;

-- Raises instead of returning false; used at the top of every RPC.
create or replace function app.require_permission(p_org uuid, p_permission text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  if not app.has_permission(p_org, p_permission) then
    raise exception 'Permission denied: %', p_permission using errcode = '42501';
  end if;
end;
$$;

create or replace function app.shares_org_with(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.memberships mine
    join public.memberships theirs
      on theirs.organization_id = mine.organization_id
    where mine.user_id = (select auth.uid())
      and mine.status = 'active'
      and theirs.user_id = p_user
  );
$$;

-- ---------------------------------------------------------------------------
-- Invitations
-- ---------------------------------------------------------------------------
create table public.invitations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  email           text not null check (email = lower(email) and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role_id         uuid not null,
  status          text not null default 'pending'
                    check (status in ('pending', 'accepted', 'revoked')),
  invited_by      uuid references auth.users (id) on delete set null,
  accepted_by     uuid references auth.users (id) on delete set null,
  accepted_at     timestamptz,
  expires_at      timestamptz not null default now() + interval '14 days',
  created_at      timestamptz not null default now(),
  foreign key (role_id, organization_id)
    references public.roles (id, organization_id) on delete cascade
);

create unique index invitations_one_pending
  on public.invitations (organization_id, email) where status = 'pending';
create index invitations_email_idx on public.invitations (email) where status = 'pending';

-- ---------------------------------------------------------------------------
-- Subscription state (billing readiness). Written by the service role only,
-- i.e. by a future billing webhook — never by a client.
-- ---------------------------------------------------------------------------
create table public.organization_subscriptions (
  organization_id          uuid primary key references public.organizations (id) on delete cascade,
  plan                     text not null default 'free',
  status                   text not null default 'active'
                             check (status in ('trialing', 'active', 'past_due', 'canceled')),
  seat_limit               integer check (seat_limit is null or seat_limit > 0),
  current_period_end       timestamptz,
  provider                 text,
  provider_customer_id     text,
  provider_subscription_id text,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create trigger organization_subscriptions_touch before update on public.organization_subscriptions
  for each row execute function app.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Audit trail (append-only)
-- ---------------------------------------------------------------------------
create table public.audit_logs (
  id              bigint generated always as identity primary key,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  actor_id        uuid references auth.users (id) on delete set null,
  action          text not null,
  entity_type     text not null,
  entity_id       text,
  details         jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create index audit_logs_org_time_idx on public.audit_logs (organization_id, created_at desc);

-- Append-only, for every role including service_role. The only tolerated
-- changes are the referential actions of deleting a whole organization
-- (cascade) or an auth user (actor_id -> null), which arrive nested inside a
-- foreign-key trigger.
create or replace function app.audit_logs_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 1 then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;
  raise exception 'audit_logs is append-only' using errcode = '42501';
end;
$$;

create trigger audit_logs_immutable
  before update or delete on public.audit_logs
  for each row execute function app.audit_logs_immutable();

create or replace function app.write_audit(
  p_org uuid,
  p_action text,
  p_entity_type text,
  p_entity_id text,
  p_details jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, details)
  values (p_org, (select auth.uid()), p_action, p_entity_type, p_entity_id, coalesce(p_details, '{}'::jsonb));
$$;

-- Generic row-change audit for sensitive tables. Records which columns
-- changed (old -> new) on UPDATE and the removed row on DELETE.
create or replace function app.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_id text;
  v_details jsonb := '{}'::jsonb;
  v_old jsonb;
  v_new jsonb;
begin
  if tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_org := coalesce((v_old ->> 'organization_id')::uuid, (v_old ->> 'id')::uuid);
    v_id := v_old ->> 'id';
    v_details := jsonb_build_object('removed', v_old - 'created_at' - 'updated_at');
    -- The organization may already be gone (cascade); nothing to attach to.
    if not exists (select 1 from public.organizations o where o.id = v_org) then
      return old;
    end if;
  else
    v_new := to_jsonb(new);
    v_org := coalesce((v_new ->> 'organization_id')::uuid, (v_new ->> 'id')::uuid);
    v_id := v_new ->> 'id';
    if tg_op = 'UPDATE' then
      v_old := to_jsonb(old);
      select coalesce(jsonb_object_agg(n.key, jsonb_build_object('from', v_old -> n.key, 'to', n.value)), '{}'::jsonb)
        into v_details
      from jsonb_each(v_new) n
      where n.key <> 'updated_at'
        and n.value is distinct from v_old -> n.key;
      if v_details = '{}'::jsonb then
        return new;
      end if;
      v_details := jsonb_build_object('changed', v_details);
    end if;
  end if;

  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, details)
  values (v_org, (select auth.uid()), lower(tg_op), tg_table_name, v_id, v_details);

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger organizations_audit after update on public.organizations
  for each row execute function app.audit_row_change();
create trigger workspaces_audit after insert or update or delete on public.workspaces
  for each row execute function app.audit_row_change();
create trigger roles_audit after insert or update or delete on public.roles
  for each row execute function app.audit_row_change();
create trigger memberships_audit after insert or update or delete on public.memberships
  for each row execute function app.audit_row_change();
create trigger invitations_audit after insert or update on public.invitations
  for each row execute function app.audit_row_change();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles                   enable row level security;
alter table public.organizations              enable row level security;
alter table public.workspaces                 enable row level security;
alter table public.permissions                enable row level security;
alter table public.roles                      enable row level security;
alter table public.role_permissions           enable row level security;
alter table public.memberships                enable row level security;
alter table public.invitations                enable row level security;
alter table public.organization_subscriptions enable row level security;
alter table public.audit_logs                 enable row level security;

-- Start from zero: nothing for anon, explicit grants for authenticated.
revoke all on
  public.profiles, public.organizations, public.workspaces, public.permissions,
  public.roles, public.role_permissions, public.memberships, public.invitations,
  public.organization_subscriptions, public.audit_logs
from public, anon, authenticated;

grant all on
  public.profiles, public.organizations, public.workspaces, public.permissions,
  public.roles, public.role_permissions, public.memberships, public.invitations,
  public.organization_subscriptions, public.audit_logs
to service_role;

-- profiles: read yourself and colleagues; edit only your own display fields.
grant select on public.profiles to authenticated;
grant update (full_name, phone, avatar_path) on public.profiles to authenticated;

create policy profiles_select on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or app.shares_org_with(id));

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- organizations: created via create_organization(); editable columns are an
-- explicit allow-list so slug / created_by can never be rewritten.
grant select on public.organizations to authenticated;
grant update (
  name, legal_name, email, phone, address, country_code, currency_code,
  timezone, tax_id, default_tax_rate, brand_color, logo_path, document_footer
) on public.organizations to authenticated;

create policy organizations_select on public.organizations
  for select to authenticated
  using (app.is_org_member(id));

create policy organizations_update on public.organizations
  for update to authenticated
  using (app.has_permission(id, 'org.manage'))
  with check (app.has_permission(id, 'org.manage'));

-- workspaces: never deleted from a client (archive instead).
grant select, insert on public.workspaces to authenticated;
grant update (name, address, is_archived) on public.workspaces to authenticated;

create policy workspaces_select on public.workspaces
  for select to authenticated
  using (app.is_org_member(organization_id));

create policy workspaces_insert on public.workspaces
  for insert to authenticated
  with check (app.has_permission(organization_id, 'workspaces.manage') and not is_default);

create policy workspaces_update on public.workspaces
  for update to authenticated
  using (app.has_permission(organization_id, 'workspaces.manage'))
  with check (app.has_permission(organization_id, 'workspaces.manage'));

-- Read-only authorization tables.
grant select on
  public.permissions, public.roles, public.role_permissions, public.memberships,
  public.invitations, public.organization_subscriptions, public.audit_logs
to authenticated;

create policy permissions_select on public.permissions
  for select to authenticated using (true);

create policy roles_select on public.roles
  for select to authenticated
  using (app.is_org_member(organization_id));

create policy role_permissions_select on public.role_permissions
  for select to authenticated
  using (app.is_org_member(organization_id));

create policy memberships_select on public.memberships
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or app.has_permission(organization_id, 'members.read')
  );

create policy invitations_select on public.invitations
  for select to authenticated
  using (app.has_permission(organization_id, 'members.read'));

create policy organization_subscriptions_select on public.organization_subscriptions
  for select to authenticated
  using (app.has_permission(organization_id, 'org.manage'));

create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (app.has_permission(organization_id, 'audit.read'));

-- Function privileges. Only the predicates that policies evaluate are
-- executable by signed-in users; everything else in `app` runs exclusively
-- inside SECURITY DEFINER functions and triggers.
revoke all on all functions in schema app from public, anon, authenticated;
grant execute on all functions in schema app to service_role;
grant execute on function
  app.is_org_member(uuid),
  app.is_org_owner(uuid),
  app.has_permission(uuid, text),
  app.shares_org_with(uuid)
to authenticated;
