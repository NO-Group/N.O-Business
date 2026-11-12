-- ============================================================================
-- N.O Business — server-side operations (RPC)
--
-- Every function here:
--   * is SECURITY DEFINER with search_path = '' and fully qualified names;
--   * authenticates the caller (auth.uid()) and checks a named permission
--     against the target organization BEFORE touching data;
--   * derives organization_id from the row it loads, never from an unchecked
--     client argument;
--   * computes money server-side;
--   * runs in one transaction, so stock, totals, numbering and the audit
--     entry either all happen or none do.
--
-- Errors raised with SQLSTATE P0001 / 42501 / 28000 carry messages that are
-- safe to show to the user.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------
create or replace function app.current_user_id()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;
  return v_uid;
end;
$$;

create or replace function app.slugify(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    nullif(left(btrim(regexp_replace(lower(p_name), '[^a-z0-9]+', '-', 'g'), '-'), 40), ''),
    'org'
  );
$$;

-- Validates and prices a JSON array of line items for one organization.
-- Input item: { product_id?, description?, quantity, unit_price_minor?, tax_rate? }
-- Missing description / price / tax fall back to the product, then to the
-- organization default tax rate.
create or replace function app.normalize_items(p_org uuid, p_items jsonb)
returns table (
  "position"       integer,
  product_id       uuid,
  description      text,
  quantity         numeric,
  unit_price_minor bigint,
  tax_rate         numeric,
  line_total_minor bigint,
  track_inventory  boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_default_tax numeric;
  v_count integer;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Line items are required' using errcode = 'P0001';
  end if;
  v_count := jsonb_array_length(p_items);
  if v_count < 1 or v_count > 200 then
    raise exception 'A document needs between 1 and 200 line items' using errcode = 'P0001';
  end if;

  select o.default_tax_rate into v_default_tax
  from public.organizations o where o.id = p_org;

  -- Reject the whole call if any row is unusable.
  if exists (
    select 1
    from jsonb_array_elements(p_items) as t(item)
    left join public.products p
      on p.id = nullif(t.item ->> 'product_id', '')::uuid and p.organization_id = p_org
    where
      (nullif(t.item ->> 'product_id', '') is not null and p.id is null)
      or coalesce((t.item ->> 'quantity')::numeric, 0) <= 0
      or coalesce((t.item ->> 'unit_price_minor')::bigint, p.unit_price_minor, -1) < 0
      or coalesce((t.item ->> 'tax_rate')::numeric, 0) not between 0 and 100
      or coalesce(nullif(btrim(t.item ->> 'description'), ''), p.name) is null
  ) then
    raise exception 'One or more line items are invalid' using errcode = 'P0001';
  end if;

  return query
  with raw as (
    select
      (t.ord)::integer as pos,
      nullif(t.item ->> 'product_id', '')::uuid as pid,
      nullif(btrim(t.item ->> 'description'), '') as descr,
      (t.item ->> 'quantity')::numeric as qty,
      (t.item ->> 'unit_price_minor')::bigint as price,
      (t.item ->> 'tax_rate')::numeric as tax
    from jsonb_array_elements(p_items) with ordinality as t(item, ord)
  ),
  priced as (
    select
      r.pos,
      r.pid,
      p.id as found_id,
      coalesce(r.descr, p.name) as descr,
      r.qty,
      coalesce(r.price, p.unit_price_minor) as price,
      coalesce(r.tax, p.tax_rate, v_default_tax, 0) as tax,
      coalesce(p.track_inventory, false) as tracked
    from raw r
    left join public.products p
      on p.id = r.pid and p.organization_id = p_org
  )
  select
    pr.pos,
    pr.found_id,
    left(pr.descr, 300),
    round(pr.qty, 3),
    pr.price,
    round(pr.tax, 2),
    round(pr.qty * pr.price)::bigint,
    pr.tracked
  from priced pr
  order by pr.pos;
end;
$$;

-- subtotal, tax and total for a set of items and a document-level discount.
-- Tax is exclusive and is charged on the discounted amount.
create or replace function app.document_totals(
  p_org uuid,
  p_items jsonb,
  p_discount_minor bigint,
  out subtotal_minor bigint,
  out tax_minor bigint,
  out total_minor bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_raw_tax numeric;
  v_discount bigint := coalesce(p_discount_minor, 0);
begin
  select coalesce(sum(i.line_total_minor), 0),
         coalesce(sum(i.line_total_minor * i.tax_rate / 100), 0)
    into subtotal_minor, v_raw_tax
  from app.normalize_items(p_org, p_items) i;

  if v_discount < 0 or v_discount > subtotal_minor then
    raise exception 'Discount must be between zero and the subtotal' using errcode = 'P0001';
  end if;

  if subtotal_minor = 0 then
    tax_minor := 0;
  else
    tax_minor := round(v_raw_tax * (subtotal_minor - v_discount) / subtotal_minor)::bigint;
  end if;
  total_minor := subtotal_minor - v_discount + tax_minor;
end;
$$;

-- Fails the transaction if any tracked product in the workspace went negative.
create or replace function app.assert_stock_available(p_workspace uuid, p_products uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  select p.name into v_name
  from public.stock_levels l
  join public.products p on p.id = l.product_id
  where l.workspace_id = p_workspace
    and l.product_id = any (p_products)
    and l.quantity < 0
  limit 1;
  if v_name is not null then
    raise exception 'Insufficient stock for %', v_name using errcode = 'P0001';
  end if;
end;
$$;

create or replace function app.require_active_workspace(p_org uuid, p_workspace uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.workspaces w
    where w.id = p_workspace and w.organization_id = p_org and not w.is_archived
  ) then
    raise exception 'Workspace not found or archived' using errcode = 'P0001';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Session context: everything the app needs right after sign-in, one call.
-- ---------------------------------------------------------------------------
create or replace function public.get_my_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_email text;
  v_confirmed boolean;
begin
  select lower(u.email), u.email_confirmed_at is not null
    into v_email, v_confirmed
  from auth.users u where u.id = v_uid;

  return jsonb_build_object(
    'profile', (
      select jsonb_build_object(
        'id', p.id, 'email', p.email, 'full_name', p.full_name, 'phone', p.phone)
      from public.profiles p where p.id = v_uid
    ),
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'membership_id', m.id,
        'organization', to_jsonb(o) - 'created_by',
        'role', jsonb_build_object('id', r.id, 'name', r.name, 'is_owner', r.is_owner),
        'permissions', case when r.is_owner
          then (select coalesce(jsonb_agg(pm.key order by pm.key), '[]'::jsonb) from public.permissions pm)
          else (select coalesce(jsonb_agg(rp.permission_key order by rp.permission_key), '[]'::jsonb)
                from public.role_permissions rp where rp.role_id = r.id)
        end
      ) order by o.name)
      from public.memberships m
      join public.organizations o on o.id = m.organization_id
      join public.roles r on r.id = m.role_id
      where m.user_id = v_uid and m.status = 'active'
    ), '[]'::jsonb),
    'invitations', case when v_confirmed then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id,
        'organization_name', o.name,
        'role_name', r.name,
        'expires_at', i.expires_at
      ) order by i.created_at)
      from public.invitations i
      join public.organizations o on o.id = i.organization_id
      join public.roles r on r.id = i.role_id
      where i.email = v_email and i.status = 'pending' and i.expires_at > now()
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Organizations
-- ---------------------------------------------------------------------------
create or replace function public.create_organization(
  p_name text,
  p_currency_code text default 'USD',
  p_country_code text default null,
  p_timezone text default 'UTC',
  p_workspace_name text default 'Main'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_org uuid;
  v_owner uuid;
  v_admin uuid;
  v_manager uuid;
  v_staff uuid;
  v_viewer uuid;
begin
  if char_length(btrim(coalesce(p_name, ''))) not between 2 and 120 then
    raise exception 'Organization name must be 2 to 120 characters' using errcode = 'P0001';
  end if;
  if upper(coalesce(p_currency_code, 'USD')) !~ '^[A-Z]{3}$' then
    raise exception 'Currency must be a 3-letter ISO code' using errcode = 'P0001';
  end if;
  -- Abuse guard: a single account cannot mint unlimited tenants.
  if (select count(*) from public.organizations o where o.created_by = v_uid) >= 10 then
    raise exception 'Organization limit reached for this account' using errcode = 'P0001';
  end if;
  if not exists (select 1 from pg_catalog.pg_timezone_names tz where tz.name = coalesce(p_timezone, 'UTC')) then
    raise exception 'Unknown timezone' using errcode = 'P0001';
  end if;

  insert into public.profiles (id, email)
  select u.id, coalesce(u.email, '') from auth.users u where u.id = v_uid
  on conflict (id) do nothing;

  insert into public.organizations (name, slug, currency_code, country_code, timezone, created_by)
  values (
    btrim(p_name),
    app.slugify(p_name) || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8),
    upper(coalesce(p_currency_code, 'USD')),
    upper(nullif(btrim(p_country_code), '')),
    coalesce(p_timezone, 'UTC'),
    v_uid
  )
  returning id into v_org;

  insert into public.roles (organization_id, name, description, is_system, is_owner)
  values (v_org, 'Owner', 'Full control, including ownership and roles', true, true)
  returning id into v_owner;
  insert into public.roles (organization_id, name, description, is_system)
  values (v_org, 'Admin', 'Manages the organization, team and all records', true)
  returning id into v_admin;
  insert into public.roles (organization_id, name, description, is_system)
  values (v_org, 'Manager', 'Runs day-to-day operations and sees reports', true)
  returning id into v_manager;
  insert into public.roles (organization_id, name, description, is_system)
  values (v_org, 'Staff', 'Sells, quotes, invoices and serves customers', true)
  returning id into v_staff;
  insert into public.roles (organization_id, name, description, is_system)
  values (v_org, 'Viewer', 'Read-only access to business records', true)
  returning id into v_viewer;

  insert into public.role_permissions (role_id, organization_id, permission_key)
  select v_admin, v_org, p.key from public.permissions p;

  insert into public.role_permissions (role_id, organization_id, permission_key)
  select v_manager, v_org, p.key from public.permissions p
  where p.key not in ('org.manage', 'members.manage', 'roles.manage', 'audit.read');

  insert into public.role_permissions (role_id, organization_id, permission_key)
  select v_staff, v_org, p.key from public.permissions p
  where p.key in (
    'customers.read', 'customers.write', 'catalog.read', 'inventory.read',
    'sales.read', 'sales.create', 'quotations.read', 'quotations.write',
    'invoices.read', 'invoices.write', 'payments.record',
    'documents.read', 'documents.write');

  insert into public.role_permissions (role_id, organization_id, permission_key)
  select v_viewer, v_org, p.key from public.permissions p
  where p.key like '%.read' and p.key not in ('audit.read', 'members.read')
     or p.key = 'reports.view';

  insert into public.memberships (organization_id, user_id, role_id)
  values (v_org, v_uid, v_owner);

  insert into public.workspaces (organization_id, name, is_default)
  values (v_org, coalesce(nullif(btrim(p_workspace_name), ''), 'Main'), true);

  insert into public.organization_subscriptions (organization_id) values (v_org);

  perform app.write_audit(v_org, 'create', 'organizations', v_org::text,
    jsonb_build_object('name', btrim(p_name)));
  return v_org;
end;
$$;

-- ---------------------------------------------------------------------------
-- Workspaces
-- ---------------------------------------------------------------------------
create or replace function public.set_default_workspace(p_workspace_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ws public.workspaces%rowtype;
begin
  select * into v_ws from public.workspaces w where w.id = p_workspace_id for update;
  if not found then
    raise exception 'Workspace not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_ws.organization_id, 'workspaces.manage');
  if v_ws.is_archived then
    raise exception 'An archived workspace cannot be the default' using errcode = 'P0001';
  end if;
  if v_ws.is_default then
    return;
  end if;
  -- Two statements, in this order, so the one-default-per-organization index
  -- is never violated mid-way.
  update public.workspaces set is_default = false
   where organization_id = v_ws.organization_id and is_default;
  update public.workspaces set is_default = true where id = p_workspace_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------
create or replace function public.save_role(
  p_org uuid,
  p_role_id uuid,
  p_name text,
  p_description text,
  p_permissions text[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.roles%rowtype;
  v_id uuid;
  v_perms text[] := coalesce(p_permissions, '{}');
  v_denied text;
begin
  perform app.require_permission(p_org, 'roles.manage');

  if exists (
    select 1 from unnest(v_perms) k
    where not exists (select 1 from public.permissions p where p.key = k)
  ) then
    raise exception 'Unknown permission' using errcode = 'P0001';
  end if;

  -- No privilege escalation: you can only grant what you hold yourself.
  select k into v_denied from unnest(v_perms) k
  where not app.has_permission(p_org, k) limit 1;
  if v_denied is not null then
    raise exception 'You cannot grant a permission you do not hold: %', v_denied
      using errcode = '42501';
  end if;

  if p_role_id is null then
    insert into public.roles (organization_id, name, description)
    values (p_org, btrim(p_name), coalesce(p_description, ''))
    returning id into v_id;
  else
    select * into v_role from public.roles r
    where r.id = p_role_id and r.organization_id = p_org
    for update;
    if not found then
      raise exception 'Role not found' using errcode = 'P0001';
    end if;
    if v_role.is_system then
      raise exception 'Built-in roles cannot be edited' using errcode = 'P0001';
    end if;
    update public.roles
      set name = btrim(p_name), description = coalesce(p_description, '')
    where id = p_role_id;
    v_id := p_role_id;
    delete from public.role_permissions rp where rp.role_id = v_id;
  end if;

  insert into public.role_permissions (role_id, organization_id, permission_key)
  select v_id, p_org, k from (select distinct unnest(v_perms) as k) d;

  perform app.write_audit(p_org, 'set_permissions', 'roles', v_id::text,
    jsonb_build_object('permissions', to_jsonb(v_perms)));
  return v_id;
end;
$$;

create or replace function public.delete_role(p_role_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_role public.roles%rowtype;
begin
  select * into v_role from public.roles r where r.id = p_role_id for update;
  if not found then
    raise exception 'Role not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_role.organization_id, 'roles.manage');
  if v_role.is_system then
    raise exception 'Built-in roles cannot be deleted' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.memberships m where m.role_id = p_role_id) then
    raise exception 'Reassign the members holding this role first' using errcode = 'P0001';
  end if;
  delete from public.roles r where r.id = p_role_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Members
-- ---------------------------------------------------------------------------
-- Shared rule for anything that hands out a role: owners may assign anything;
-- everyone else may only assign roles that are a subset of their own access,
-- and never the owner role.
create or replace function app.assert_can_assign_role(p_org uuid, p_role_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role public.roles%rowtype;
begin
  select * into v_role from public.roles r
  where r.id = p_role_id and r.organization_id = p_org;
  if not found then
    raise exception 'Role not found' using errcode = 'P0001';
  end if;
  if app.is_org_owner(p_org) then
    return;
  end if;
  if v_role.is_owner then
    raise exception 'Only an owner can grant ownership' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.role_permissions rp
    where rp.role_id = p_role_id
      and not app.has_permission(p_org, rp.permission_key)
  ) then
    raise exception 'You cannot assign a role with more access than your own'
      using errcode = '42501';
  end if;
end;
$$;

create or replace function public.set_member_role(p_membership_id uuid, p_role_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_m public.memberships%rowtype;
  v_target_is_owner boolean;
begin
  select * into v_m from public.memberships m where m.id = p_membership_id for update;
  if not found then
    raise exception 'Member not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_m.organization_id, 'members.manage');
  if v_m.user_id = v_uid then
    raise exception 'You cannot change your own role' using errcode = 'P0001';
  end if;
  select r.is_owner into v_target_is_owner from public.roles r where r.id = v_m.role_id;
  if v_target_is_owner and not app.is_org_owner(v_m.organization_id) then
    raise exception 'Only an owner can change another owner' using errcode = '42501';
  end if;
  perform app.assert_can_assign_role(v_m.organization_id, p_role_id);
  update public.memberships set role_id = p_role_id where id = p_membership_id;
end;
$$;

create or replace function public.set_member_status(p_membership_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_m public.memberships%rowtype;
  v_target_is_owner boolean;
begin
  if p_status not in ('active', 'suspended') then
    raise exception 'Unknown status' using errcode = 'P0001';
  end if;
  select * into v_m from public.memberships m where m.id = p_membership_id for update;
  if not found then
    raise exception 'Member not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_m.organization_id, 'members.manage');
  if v_m.user_id = v_uid then
    raise exception 'You cannot change your own access' using errcode = 'P0001';
  end if;
  select r.is_owner into v_target_is_owner from public.roles r where r.id = v_m.role_id;
  if v_target_is_owner and not app.is_org_owner(v_m.organization_id) then
    raise exception 'Only an owner can change another owner' using errcode = '42501';
  end if;
  update public.memberships set status = p_status where id = p_membership_id;
end;
$$;

create or replace function public.remove_member(p_membership_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_m public.memberships%rowtype;
  v_target_is_owner boolean;
begin
  select * into v_m from public.memberships m where m.id = p_membership_id for update;
  if not found then
    raise exception 'Member not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_m.organization_id, 'members.manage');
  if v_m.user_id = v_uid then
    raise exception 'Use "Leave organization" to remove yourself' using errcode = 'P0001';
  end if;
  select r.is_owner into v_target_is_owner from public.roles r where r.id = v_m.role_id;
  if v_target_is_owner and not app.is_org_owner(v_m.organization_id) then
    raise exception 'Only an owner can remove another owner' using errcode = '42501';
  end if;
  delete from public.memberships m where m.id = p_membership_id;
end;
$$;

-- The deferred owner trigger rejects this if the caller is the last owner.
create or replace function public.leave_organization(p_org uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
begin
  delete from public.memberships m
  where m.organization_id = p_org and m.user_id = v_uid;
  if not found then
    raise exception 'You are not a member of this organization' using errcode = 'P0001';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Invitations (matched on the invitee's VERIFIED email; no shared secrets)
-- ---------------------------------------------------------------------------
create or replace function public.invite_member(p_org uuid, p_email text, p_role_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_email text := lower(btrim(p_email));
  v_seat_limit integer;
  v_id uuid;
begin
  perform app.require_permission(p_org, 'members.manage');
  perform app.assert_can_assign_role(p_org, p_role_id);

  if exists (
    select 1 from public.memberships m
    join public.profiles p on p.id = m.user_id
    where m.organization_id = p_org and lower(p.email) = v_email
  ) then
    raise exception 'That person is already a member' using errcode = 'P0001';
  end if;

  if (select count(*) from public.invitations i
      where i.organization_id = p_org and i.status = 'pending') >= 100 then
    raise exception 'Too many pending invitations' using errcode = 'P0001';
  end if;

  select s.seat_limit into v_seat_limit
  from public.organization_subscriptions s where s.organization_id = p_org;
  if v_seat_limit is not null and (
    (select count(*) from public.memberships m where m.organization_id = p_org)
    + (select count(*) from public.invitations i
       where i.organization_id = p_org and i.status = 'pending' and i.expires_at > now())
  ) >= v_seat_limit then
    raise exception 'Seat limit reached for the current plan' using errcode = 'P0001';
  end if;

  -- Re-inviting replaces a stale pending invitation.
  update public.invitations set status = 'revoked'
  where organization_id = p_org and email = v_email and status = 'pending';

  insert into public.invitations (organization_id, email, role_id, invited_by)
  values (p_org, v_email, p_role_id, v_uid)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.revoke_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  select i.organization_id into v_org from public.invitations i
  where i.id = p_invitation_id and i.status = 'pending' for update;
  if not found then
    raise exception 'Invitation not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_org, 'members.manage');
  update public.invitations set status = 'revoked' where id = p_invitation_id;
end;
$$;

create or replace function public.accept_invitation(p_invitation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_email text;
  v_confirmed boolean;
  v_inv public.invitations%rowtype;
begin
  select lower(u.email), u.email_confirmed_at is not null
    into v_email, v_confirmed
  from auth.users u where u.id = v_uid;
  -- An unverified address proves nothing about who is asking.
  if not coalesce(v_confirmed, false) then
    raise exception 'Verify your email address before accepting invitations'
      using errcode = '42501';
  end if;

  select * into v_inv from public.invitations i
  where i.id = p_invitation_id for update;
  if not found or v_inv.email <> v_email or v_inv.status <> 'pending' or v_inv.expires_at <= now() then
    raise exception 'Invitation not found or no longer valid' using errcode = 'P0001';
  end if;

  insert into public.profiles (id, email) values (v_uid, v_email)
  on conflict (id) do nothing;

  insert into public.memberships (organization_id, user_id, role_id)
  values (v_inv.organization_id, v_uid, v_inv.role_id)
  on conflict (organization_id, user_id) do nothing;

  update public.invitations
    set status = 'accepted', accepted_by = v_uid, accepted_at = now()
  where id = p_invitation_id;
  return v_inv.organization_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Inventory
-- ---------------------------------------------------------------------------
create or replace function public.adjust_stock(
  p_workspace_id uuid,
  p_product_id uuid,
  p_quantity_delta numeric,
  p_reason text,
  p_note text default null
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_product public.products%rowtype;
  v_qty numeric;
begin
  select * into v_product from public.products p where p.id = p_product_id;
  if not found then
    raise exception 'Product not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_product.organization_id, 'inventory.adjust');
  perform app.require_active_workspace(v_product.organization_id, p_workspace_id);

  if not v_product.track_inventory then
    raise exception 'Stock is not tracked for this item' using errcode = 'P0001';
  end if;
  if p_reason not in ('opening', 'purchase', 'adjustment', 'damage', 'return') then
    raise exception 'Unknown stock reason' using errcode = 'P0001';
  end if;
  if p_quantity_delta is null or p_quantity_delta = 0 then
    raise exception 'Quantity change cannot be zero' using errcode = 'P0001';
  end if;

  insert into public.stock_movements (
    organization_id, workspace_id, product_id, quantity_delta, reason, note, created_by)
  values (
    v_product.organization_id, p_workspace_id, p_product_id, round(p_quantity_delta, 3),
    p_reason, nullif(btrim(p_note), ''), v_uid);

  perform app.assert_stock_available(p_workspace_id, array[p_product_id]);

  select l.quantity into v_qty from public.stock_levels l
  where l.workspace_id = p_workspace_id and l.product_id = p_product_id;

  perform app.write_audit(v_product.organization_id, 'adjust_stock', 'products', p_product_id::text,
    jsonb_build_object('workspace_id', p_workspace_id, 'delta', p_quantity_delta,
                       'reason', p_reason, 'quantity', v_qty));
  return v_qty;
end;
$$;

-- ---------------------------------------------------------------------------
-- Sales
-- ---------------------------------------------------------------------------
create or replace function public.record_sale(
  p_org uuid,
  p_workspace_id uuid,
  p_customer_id uuid,
  p_payment_method text,
  p_items jsonb,
  p_discount_minor bigint default 0,
  p_note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_currency text;
  v_totals record;
  v_sale uuid;
  v_number text;
  v_products uuid[];
begin
  perform app.require_permission(p_org, 'sales.create');
  perform app.require_active_workspace(p_org, p_workspace_id);
  if p_payment_method is null or p_payment_method not in (
    'cash', 'bank_transfer', 'card', 'mobile_money', 'other') then
    raise exception 'Unknown payment method' using errcode = 'P0001';
  end if;

  if p_customer_id is not null and not exists (
    select 1 from public.customers c where c.id = p_customer_id and c.organization_id = p_org
  ) then
    raise exception 'Customer not found' using errcode = 'P0001';
  end if;

  select o.currency_code into v_currency from public.organizations o where o.id = p_org;
  select * into v_totals from app.document_totals(p_org, p_items, p_discount_minor);
  v_number := app.next_document_number(p_org, 'sale');

  insert into public.sales (
    organization_id, workspace_id, number, customer_id, payment_method, currency_code,
    subtotal_minor, discount_minor, tax_minor, total_minor, note, created_by)
  values (
    p_org, p_workspace_id, v_number, p_customer_id, p_payment_method, v_currency,
    v_totals.subtotal_minor, coalesce(p_discount_minor, 0), v_totals.tax_minor,
    v_totals.total_minor, nullif(btrim(p_note), ''), v_uid)
  returning id into v_sale;

  insert into public.sale_items (
    organization_id, sale_id, product_id, description, quantity, unit_price_minor,
    tax_rate, line_total_minor, position)
  select p_org, v_sale, i.product_id, i.description, i.quantity, i.unit_price_minor,
         i.tax_rate, i.line_total_minor, i."position"
  from app.normalize_items(p_org, p_items) i;

  with moved as (
    insert into public.stock_movements (
      organization_id, workspace_id, product_id, quantity_delta, reason,
      reference_type, reference_id, created_by)
    select p_org, p_workspace_id, i.product_id, -sum(i.quantity), 'sale', 'sale', v_sale, v_uid
    from app.normalize_items(p_org, p_items) i
    where i.track_inventory
    group by i.product_id
    returning product_id
  )
  select coalesce(array_agg(product_id), '{}') into v_products from moved;

  perform app.assert_stock_available(p_workspace_id, v_products);

  perform app.write_audit(p_org, 'record', 'sales', v_sale::text,
    jsonb_build_object('number', v_number, 'total_minor', v_totals.total_minor));
  return v_sale;
end;
$$;

create or replace function public.void_sale(p_sale_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_sale public.sales%rowtype;
begin
  select * into v_sale from public.sales s where s.id = p_sale_id for update;
  if not found then
    raise exception 'Sale not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_sale.organization_id, 'sales.void');
  if v_sale.status = 'voided' then
    raise exception 'This sale is already voided' using errcode = 'P0001';
  end if;

  update public.sales
    set status = 'voided', voided_at = now(), voided_by = v_uid
  where id = p_sale_id;

  -- Put the goods back, mirroring the original movements exactly.
  insert into public.stock_movements (
    organization_id, workspace_id, product_id, quantity_delta, reason,
    reference_type, reference_id, created_by)
  select m.organization_id, m.workspace_id, m.product_id, -m.quantity_delta, 'sale_void',
         'sale', p_sale_id, v_uid
  from public.stock_movements m
  where m.reference_type = 'sale' and m.reference_id = p_sale_id and m.reason = 'sale';

  perform app.write_audit(v_sale.organization_id, 'void', 'sales', p_sale_id::text,
    jsonb_build_object('number', v_sale.number, 'total_minor', v_sale.total_minor));
end;
$$;

-- ---------------------------------------------------------------------------
-- Quotations
-- ---------------------------------------------------------------------------
create or replace function public.save_quotation(
  p_org uuid,
  p_quotation_id uuid,
  p_workspace_id uuid,
  p_customer_id uuid,
  p_valid_until date,
  p_items jsonb,
  p_discount_minor bigint default 0,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_currency text;
  v_totals record;
  v_id uuid;
  v_status text;
begin
  perform app.require_permission(p_org, 'quotations.write');
  perform app.require_active_workspace(p_org, p_workspace_id);
  if not exists (
    select 1 from public.customers c where c.id = p_customer_id and c.organization_id = p_org
  ) then
    raise exception 'Customer not found' using errcode = 'P0001';
  end if;

  select * into v_totals from app.document_totals(p_org, p_items, p_discount_minor);

  if p_quotation_id is null then
    select o.currency_code into v_currency from public.organizations o where o.id = p_org;
    insert into public.quotations (
      organization_id, workspace_id, number, customer_id, valid_until, currency_code,
      subtotal_minor, discount_minor, tax_minor, total_minor, notes, created_by)
    values (
      p_org, p_workspace_id, app.next_document_number(p_org, 'quotation'), p_customer_id,
      p_valid_until, v_currency, v_totals.subtotal_minor, coalesce(p_discount_minor, 0),
      v_totals.tax_minor, v_totals.total_minor, nullif(btrim(p_notes), ''), v_uid)
    returning id into v_id;
  else
    select q.status into v_status from public.quotations q
    where q.id = p_quotation_id and q.organization_id = p_org for update;
    if not found then
      raise exception 'Quotation not found' using errcode = 'P0001';
    end if;
    if v_status not in ('draft', 'sent') then
      raise exception 'Only draft or sent quotations can be edited' using errcode = 'P0001';
    end if;
    update public.quotations set
      workspace_id = p_workspace_id,
      customer_id = p_customer_id,
      valid_until = p_valid_until,
      subtotal_minor = v_totals.subtotal_minor,
      discount_minor = coalesce(p_discount_minor, 0),
      tax_minor = v_totals.tax_minor,
      total_minor = v_totals.total_minor,
      notes = nullif(btrim(p_notes), '')
    where id = p_quotation_id;
    delete from public.quotation_items qi where qi.quotation_id = p_quotation_id;
    v_id := p_quotation_id;
  end if;

  insert into public.quotation_items (
    organization_id, quotation_id, product_id, description, quantity, unit_price_minor,
    tax_rate, line_total_minor, position)
  select p_org, v_id, i.product_id, i.description, i.quantity, i.unit_price_minor,
         i.tax_rate, i.line_total_minor, i."position"
  from app.normalize_items(p_org, p_items) i;
  return v_id;
end;
$$;

-- Allowed transitions: draft -> sent; sent -> accepted | declined | draft;
-- accepted | declined -> sent (reopen). 'converted' is set only by conversion.
create or replace function public.set_quotation_status(p_quotation_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q public.quotations%rowtype;
begin
  select * into v_q from public.quotations q where q.id = p_quotation_id for update;
  if not found then
    raise exception 'Quotation not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_q.organization_id, 'quotations.write');

  if not (
    (v_q.status = 'draft' and p_status = 'sent')
    or (v_q.status = 'sent' and p_status in ('accepted', 'declined', 'draft'))
    or (v_q.status in ('accepted', 'declined') and p_status = 'sent')
  ) then
    raise exception 'A % quotation cannot be marked %', v_q.status, p_status
      using errcode = 'P0001';
  end if;

  update public.quotations
    set status = p_status,
        sent_at = case when p_status = 'sent' then coalesce(sent_at, now()) else sent_at end
  where id = p_quotation_id;

  perform app.write_audit(v_q.organization_id, 'set_status', 'quotations', p_quotation_id::text,
    jsonb_build_object('number', v_q.number, 'from', v_q.status, 'to', p_status));
end;
$$;

create or replace function public.delete_quotation(p_quotation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q public.quotations%rowtype;
begin
  select * into v_q from public.quotations q where q.id = p_quotation_id for update;
  if not found then
    raise exception 'Quotation not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_q.organization_id, 'quotations.write');
  if v_q.status <> 'draft' then
    raise exception 'Only draft quotations can be deleted' using errcode = 'P0001';
  end if;
  delete from public.quotations q where q.id = p_quotation_id;
end;
$$;

-- Creates a DRAFT invoice from the quotation's lines. Requires the right to
-- write invoices as well as quotations.
create or replace function public.convert_quotation_to_invoice(p_quotation_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_q public.quotations%rowtype;
  v_invoice uuid;
begin
  select * into v_q from public.quotations q where q.id = p_quotation_id for update;
  if not found then
    raise exception 'Quotation not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_q.organization_id, 'quotations.write');
  perform app.require_permission(v_q.organization_id, 'invoices.write');
  if v_q.status not in ('sent', 'accepted') then
    raise exception 'Only sent or accepted quotations can be converted' using errcode = 'P0001';
  end if;

  insert into public.invoices (
    organization_id, workspace_id, customer_id, quotation_id, currency_code,
    subtotal_minor, discount_minor, tax_minor, total_minor, notes, created_by)
  values (
    v_q.organization_id, v_q.workspace_id, v_q.customer_id, v_q.id, v_q.currency_code,
    v_q.subtotal_minor, v_q.discount_minor, v_q.tax_minor, v_q.total_minor, v_q.notes, v_uid)
  returning id into v_invoice;

  insert into public.invoice_items (
    organization_id, invoice_id, product_id, description, quantity, unit_price_minor,
    tax_rate, line_total_minor, position)
  select qi.organization_id, v_invoice, qi.product_id, qi.description, qi.quantity,
         qi.unit_price_minor, qi.tax_rate, qi.line_total_minor, qi.position
  from public.quotation_items qi where qi.quotation_id = v_q.id;

  update public.quotations
    set status = 'converted', converted_invoice_id = v_invoice
  where id = v_q.id;

  perform app.write_audit(v_q.organization_id, 'convert', 'quotations', v_q.id::text,
    jsonb_build_object('number', v_q.number, 'invoice_id', v_invoice));
  return v_invoice;
end;
$$;

-- ---------------------------------------------------------------------------
-- Invoices and payments
-- ---------------------------------------------------------------------------
create or replace function public.save_invoice(
  p_org uuid,
  p_invoice_id uuid,
  p_workspace_id uuid,
  p_customer_id uuid,
  p_due_date date,
  p_items jsonb,
  p_discount_minor bigint default 0,
  p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_currency text;
  v_totals record;
  v_id uuid;
  v_status text;
begin
  perform app.require_permission(p_org, 'invoices.write');
  perform app.require_active_workspace(p_org, p_workspace_id);
  if not exists (
    select 1 from public.customers c where c.id = p_customer_id and c.organization_id = p_org
  ) then
    raise exception 'Customer not found' using errcode = 'P0001';
  end if;

  select * into v_totals from app.document_totals(p_org, p_items, p_discount_minor);

  if p_invoice_id is null then
    select o.currency_code into v_currency from public.organizations o where o.id = p_org;
    insert into public.invoices (
      organization_id, workspace_id, customer_id, due_date, currency_code,
      subtotal_minor, discount_minor, tax_minor, total_minor, notes, created_by)
    values (
      p_org, p_workspace_id, p_customer_id, p_due_date, v_currency,
      v_totals.subtotal_minor, coalesce(p_discount_minor, 0), v_totals.tax_minor,
      v_totals.total_minor, nullif(btrim(p_notes), ''), v_uid)
    returning id into v_id;
  else
    select i.status into v_status from public.invoices i
    where i.id = p_invoice_id and i.organization_id = p_org for update;
    if not found then
      raise exception 'Invoice not found' using errcode = 'P0001';
    end if;
    -- An issued invoice is a financial record: correct it by voiding.
    if v_status <> 'draft' then
      raise exception 'Only draft invoices can be edited' using errcode = 'P0001';
    end if;
    update public.invoices set
      workspace_id = p_workspace_id,
      customer_id = p_customer_id,
      due_date = p_due_date,
      subtotal_minor = v_totals.subtotal_minor,
      discount_minor = coalesce(p_discount_minor, 0),
      tax_minor = v_totals.tax_minor,
      total_minor = v_totals.total_minor,
      notes = nullif(btrim(p_notes), '')
    where id = p_invoice_id;
    delete from public.invoice_items ii where ii.invoice_id = p_invoice_id;
    v_id := p_invoice_id;
  end if;

  insert into public.invoice_items (
    organization_id, invoice_id, product_id, description, quantity, unit_price_minor,
    tax_rate, line_total_minor, position)
  select p_org, v_id, i.product_id, i.description, i.quantity, i.unit_price_minor,
         i.tax_rate, i.line_total_minor, i."position"
  from app.normalize_items(p_org, p_items) i;
  return v_id;
end;
$$;

create or replace function public.delete_invoice_draft(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_i public.invoices%rowtype;
begin
  select * into v_i from public.invoices i where i.id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_i.organization_id, 'invoices.write');
  if v_i.status <> 'draft' then
    raise exception 'Only draft invoices can be deleted' using errcode = 'P0001';
  end if;
  -- A quotation that produced this draft becomes convertible again.
  update public.quotations
    set status = 'accepted', converted_invoice_id = null
  where converted_invoice_id = p_invoice_id;
  delete from public.invoices i where i.id = p_invoice_id;
end;
$$;

-- Issuing numbers the invoice, fixes its date and releases the stock.
create or replace function public.issue_invoice(p_invoice_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_i public.invoices%rowtype;
  v_number text;
  v_today date;
  v_products uuid[];
begin
  select * into v_i from public.invoices i where i.id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_i.organization_id, 'invoices.write');
  if v_i.status <> 'draft' then
    raise exception 'This invoice has already been issued' using errcode = 'P0001';
  end if;
  if v_i.total_minor <= 0 then
    raise exception 'An invoice needs a total above zero to be issued' using errcode = 'P0001';
  end if;
  perform app.require_active_workspace(v_i.organization_id, v_i.workspace_id);

  select (now() at time zone o.timezone)::date into v_today
  from public.organizations o where o.id = v_i.organization_id;
  if v_i.due_date is not null and v_i.due_date < v_today then
    raise exception 'The due date is in the past' using errcode = 'P0001';
  end if;

  v_number := app.next_document_number(v_i.organization_id, 'invoice');
  update public.invoices
    set status = 'issued', number = v_number, issue_date = v_today, issued_at = now()
  where id = p_invoice_id;

  with moved as (
    insert into public.stock_movements (
      organization_id, workspace_id, product_id, quantity_delta, reason,
      reference_type, reference_id, created_by)
    select v_i.organization_id, v_i.workspace_id, ii.product_id, -sum(ii.quantity),
           'invoice', 'invoice', p_invoice_id, v_uid
    from public.invoice_items ii
    join public.products p on p.id = ii.product_id
    where ii.invoice_id = p_invoice_id and p.track_inventory
    group by ii.product_id
    returning product_id
  )
  select coalesce(array_agg(product_id), '{}') into v_products from moved;

  perform app.assert_stock_available(v_i.workspace_id, v_products);

  perform app.write_audit(v_i.organization_id, 'issue', 'invoices', p_invoice_id::text,
    jsonb_build_object('number', v_number, 'total_minor', v_i.total_minor));
  return v_number;
end;
$$;

create or replace function public.record_invoice_payment(
  p_invoice_id uuid,
  p_amount_minor bigint,
  p_method text,
  p_reference text default null,
  p_paid_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_i public.invoices%rowtype;
  v_balance bigint;
  v_payment uuid;
  v_paid bigint;
begin
  -- The row lock serializes concurrent payments against the same invoice.
  select * into v_i from public.invoices i where i.id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_i.organization_id, 'payments.record');
  if v_i.status not in ('issued', 'partially_paid') then
    raise exception 'Payments can only be recorded against an open invoice' using errcode = 'P0001';
  end if;

  if p_method is null or p_method not in (
    'cash', 'bank_transfer', 'card', 'mobile_money', 'other') then
    raise exception 'Unknown payment method' using errcode = 'P0001';
  end if;

  v_balance := v_i.total_minor - v_i.amount_paid_minor;
  if p_amount_minor is null or p_amount_minor <= 0 or p_amount_minor > v_balance then
    raise exception 'Payment must be above zero and no more than the balance due'
      using errcode = 'P0001';
  end if;
  if p_paid_at is not null and p_paid_at > now() + interval '1 day' then
    raise exception 'Payment date cannot be in the future' using errcode = 'P0001';
  end if;

  insert into public.payments (
    organization_id, invoice_id, amount_minor, method, reference, paid_at, received_by)
  values (
    v_i.organization_id, p_invoice_id, p_amount_minor, p_method,
    nullif(btrim(p_reference), ''), coalesce(p_paid_at, now()), v_uid)
  returning id into v_payment;

  v_paid := v_i.amount_paid_minor + p_amount_minor;
  update public.invoices
    set amount_paid_minor = v_paid,
        status = case when v_paid >= v_i.total_minor then 'paid' else 'partially_paid' end
  where id = p_invoice_id;

  perform app.write_audit(v_i.organization_id, 'record_payment', 'invoices', p_invoice_id::text,
    jsonb_build_object('number', v_i.number, 'amount_minor', p_amount_minor,
                       'method', p_method, 'payment_id', v_payment));
  return v_payment;
end;
$$;

-- Voiding is limited to invoices with no money received. Refunds and credit
-- notes are a separate, later capability.
create or replace function public.void_invoice(p_invoice_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := app.current_user_id();
  v_i public.invoices%rowtype;
begin
  select * into v_i from public.invoices i where i.id = p_invoice_id for update;
  if not found then
    raise exception 'Invoice not found' using errcode = 'P0001';
  end if;
  perform app.require_permission(v_i.organization_id, 'invoices.void');
  if v_i.status <> 'issued' or v_i.amount_paid_minor > 0 then
    raise exception 'Only issued invoices with no payments can be voided' using errcode = 'P0001';
  end if;

  update public.invoices set status = 'void', voided_at = now() where id = p_invoice_id;

  insert into public.stock_movements (
    organization_id, workspace_id, product_id, quantity_delta, reason,
    reference_type, reference_id, created_by)
  select m.organization_id, m.workspace_id, m.product_id, -m.quantity_delta, 'invoice_void',
         'invoice', p_invoice_id, v_uid
  from public.stock_movements m
  where m.reference_type = 'invoice' and m.reference_id = p_invoice_id and m.reason = 'invoice';

  perform app.write_audit(v_i.organization_id, 'void', 'invoices', p_invoice_id::text,
    jsonb_build_object('number', v_i.number, 'total_minor', v_i.total_minor));
end;
$$;

-- ---------------------------------------------------------------------------
-- Dashboard: one aggregate read, computed from real rows only.
-- ---------------------------------------------------------------------------
create or replace function public.dashboard_summary(
  p_org uuid,
  p_workspace_id uuid default null,
  p_days integer default 30
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_days integer := least(greatest(coalesce(p_days, 30), 1), 366);
  v_tz text;
  v_currency text;
  v_today date;
  v_from date;
  v_prev_from date;
  v_result jsonb;
begin
  perform app.require_permission(p_org, 'reports.view');

  select o.timezone, o.currency_code into v_tz, v_currency
  from public.organizations o where o.id = p_org;
  v_today := (now() at time zone v_tz)::date;
  v_from := v_today - (v_days - 1);
  v_prev_from := v_from - v_days;

  with sales_in as (
    select s.id, s.total_minor, s.payment_method,
           (s.sold_at at time zone v_tz)::date as day
    from public.sales s
    where s.organization_id = p_org
      and s.status = 'completed'
      and (p_workspace_id is null or s.workspace_id = p_workspace_id)
      and (s.sold_at at time zone v_tz)::date >= v_prev_from
  ),
  payments_in as (
    select p.amount_minor, p.method,
           (p.paid_at at time zone v_tz)::date as day
    from public.payments p
    join public.invoices i on i.id = p.invoice_id
    where p.organization_id = p_org
      and (p_workspace_id is null or i.workspace_id = p_workspace_id)
      and (p.paid_at at time zone v_tz)::date >= v_prev_from
  ),
  open_invoices as (
    select i.total_minor - i.amount_paid_minor as balance, i.due_date
    from public.invoices i
    where i.organization_id = p_org
      and i.status in ('issued', 'partially_paid')
      and (p_workspace_id is null or i.workspace_id = p_workspace_id)
  ),
  days as (
    select d::date as day from generate_series(v_from, v_today, interval '1 day') d
  ),
  daily as (
    select d.day,
      coalesce((select sum(s.total_minor) from sales_in s where s.day = d.day), 0) as sales_minor,
      coalesce((select sum(p.amount_minor) from payments_in p where p.day = d.day), 0) as payments_minor
    from days d
  ),
  stock as (
    select p.id, p.reorder_level, coalesce(sum(l.quantity), 0) as quantity
    from public.products p
    left join public.stock_levels l
      on l.product_id = p.id
     and (p_workspace_id is null or l.workspace_id = p_workspace_id)
    where p.organization_id = p_org and p.track_inventory and p.is_active
    group by p.id, p.reorder_level
  ),
  top_products as (
    select si.description as name, sum(si.quantity) as quantity, sum(si.line_total_minor) as total_minor
    from public.sale_items si
    join sales_in s on s.id = si.sale_id
    where s.day >= v_from
    group by si.description
    order by sum(si.line_total_minor) desc
    limit 5
  ),
  methods as (
    select m.method, sum(m.amount) as total_minor
    from (
      select s.payment_method as method, s.total_minor as amount from sales_in s where s.day >= v_from
      union all
      select p.method, p.amount_minor from payments_in p where p.day >= v_from
    ) m
    group by m.method
  )
  select jsonb_build_object(
    'currency_code', v_currency,
    'period_days', v_days,
    'from', v_from,
    'to', v_today,
    'sales_total_minor', (select coalesce(sum(total_minor), 0) from sales_in where day >= v_from),
    'sales_count', (select count(*) from sales_in where day >= v_from),
    'payments_total_minor', (select coalesce(sum(amount_minor), 0) from payments_in where day >= v_from),
    'previous_collected_minor',
      (select coalesce(sum(total_minor), 0) from sales_in where day < v_from)
      + (select coalesce(sum(amount_minor), 0) from payments_in where day < v_from),
    'receivables_minor', (select coalesce(sum(balance), 0) from open_invoices),
    'open_invoices_count', (select count(*) from open_invoices),
    'overdue_minor', (select coalesce(sum(balance), 0) from open_invoices where due_date < v_today),
    'overdue_count', (select count(*) from open_invoices where due_date < v_today),
    'open_quotations_count', (
      select count(*) from public.quotations q
      where q.organization_id = p_org and q.status in ('sent', 'accepted')
        and (p_workspace_id is null or q.workspace_id = p_workspace_id)),
    'open_quotations_minor', (
      select coalesce(sum(q.total_minor), 0) from public.quotations q
      where q.organization_id = p_org and q.status in ('sent', 'accepted')
        and (p_workspace_id is null or q.workspace_id = p_workspace_id)),
    'customers_count', (select count(*) from public.customers c where c.organization_id = p_org),
    'low_stock_count', (select count(*) from stock where quantity <= reorder_level),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object(
        'day', day, 'sales_minor', sales_minor, 'payments_minor', payments_minor) order by day), '[]'::jsonb)
      from daily),
    'top_products', (select coalesce(jsonb_agg(jsonb_build_object(
        'name', name, 'quantity', quantity, 'total_minor', total_minor) order by total_minor desc), '[]'::jsonb)
      from top_products),
    'payment_methods', (select coalesce(jsonb_agg(jsonb_build_object(
        'method', method, 'total_minor', total_minor) order by total_minor desc), '[]'::jsonb)
      from methods)
  ) into v_result;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges: nothing for anon; RPCs for signed-in users; helpers for no one.
-- ---------------------------------------------------------------------------
revoke all on all functions in schema app from public, anon, authenticated;
grant execute on all functions in schema app to service_role;
grant execute on function
  app.is_org_member(uuid),
  app.is_org_owner(uuid),
  app.has_permission(uuid, text),
  app.shares_org_with(uuid),
  app.try_uuid(text)
to authenticated;

revoke all on function
  public.get_my_context(),
  public.create_organization(text, text, text, text, text),
  public.set_default_workspace(uuid),
  public.save_role(uuid, uuid, text, text, text[]),
  public.delete_role(uuid),
  public.set_member_role(uuid, uuid),
  public.set_member_status(uuid, text),
  public.remove_member(uuid),
  public.leave_organization(uuid),
  public.invite_member(uuid, text, uuid),
  public.revoke_invitation(uuid),
  public.accept_invitation(uuid),
  public.adjust_stock(uuid, uuid, numeric, text, text),
  public.record_sale(uuid, uuid, uuid, text, jsonb, bigint, text),
  public.void_sale(uuid),
  public.save_quotation(uuid, uuid, uuid, uuid, date, jsonb, bigint, text),
  public.set_quotation_status(uuid, text),
  public.delete_quotation(uuid),
  public.convert_quotation_to_invoice(uuid),
  public.save_invoice(uuid, uuid, uuid, uuid, date, jsonb, bigint, text),
  public.delete_invoice_draft(uuid),
  public.issue_invoice(uuid),
  public.record_invoice_payment(uuid, bigint, text, text, timestamptz),
  public.void_invoice(uuid),
  public.dashboard_summary(uuid, uuid, integer)
from public, anon;

grant execute on function
  public.get_my_context(),
  public.create_organization(text, text, text, text, text),
  public.set_default_workspace(uuid),
  public.save_role(uuid, uuid, text, text, text[]),
  public.delete_role(uuid),
  public.set_member_role(uuid, uuid),
  public.set_member_status(uuid, text),
  public.remove_member(uuid),
  public.leave_organization(uuid),
  public.invite_member(uuid, text, uuid),
  public.revoke_invitation(uuid),
  public.accept_invitation(uuid),
  public.adjust_stock(uuid, uuid, numeric, text, text),
  public.record_sale(uuid, uuid, uuid, text, jsonb, bigint, text),
  public.void_sale(uuid),
  public.save_quotation(uuid, uuid, uuid, uuid, date, jsonb, bigint, text),
  public.set_quotation_status(uuid, text),
  public.delete_quotation(uuid),
  public.convert_quotation_to_invoice(uuid),
  public.save_invoice(uuid, uuid, uuid, uuid, date, jsonb, bigint, text),
  public.delete_invoice_draft(uuid),
  public.issue_invoice(uuid),
  public.record_invoice_payment(uuid, bigint, text, text, timestamptz),
  public.void_invoice(uuid),
  public.dashboard_summary(uuid, uuid, integer)
to authenticated, service_role;
