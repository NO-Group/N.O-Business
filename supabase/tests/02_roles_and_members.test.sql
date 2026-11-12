-- Roles, permissions, invitations and the anti-escalation rules.
\set QUIET on
select tests.superuser();
select tests.create_user('owner@c.test') as owner \gset
select tests.create_user('admin@c.test') as admin \gset
select tests.create_user('staff@c.test') as staff \gset
select tests.create_user('viewer@c.test') as viewer \gset
select tests.create_user('pending@c.test', false) as unverified \gset
select tests.create_user('outsider@z.test') as outsider \gset

select tests.login(:'owner');
select public.create_organization('Gamma Works', 'NGN', 'NG', 'Africa/Lagos', 'Main') as org \gset
select id as ws from public.workspaces where organization_id = :'org' \gset
select id as r_owner from public.roles where organization_id = :'org' and name = 'Owner' \gset
select id as r_admin from public.roles where organization_id = :'org' and name = 'Admin' \gset
select id as r_manager from public.roles where organization_id = :'org' and name = 'Manager' \gset
select id as r_staff from public.roles where organization_id = :'org' and name = 'Staff' \gset
select id as r_viewer from public.roles where organization_id = :'org' and name = 'Viewer' \gset

select tests.ok(tests.count('select 1 from public.roles') = 5, 'five built-in roles are seeded');
select tests.ok(jsonb_array_length(public.get_my_context() -> 'memberships' -> 0 -> 'permissions')
  = (select count(*) from public.permissions), 'owner context carries every permission');

-- ---- workspaces ---------------------------------------------------------------
insert into public.workspaces (organization_id, name) values (:'org', 'Annex') returning id as ws2 \gset
select tests.throws(format($$insert into public.workspaces (organization_id, name, is_default) values (%L, 'Sneaky', true)$$, :'org'),
  '42501', 'a workspace cannot be inserted as the default');
select tests.throws(format($$update public.workspaces set is_default = true where id = %L$$, :'ws2'),
  '42501', 'is_default is not directly writable');
select public.set_default_workspace(:'ws2');
select tests.ok((select is_default from public.workspaces where id = :'ws2'), 'set_default_workspace promotes the workspace');
select tests.ok(not (select is_default from public.workspaces where id = :'ws'), 'the previous default is demoted');
select tests.ok(tests.count('select 1 from public.workspaces where is_default') = 1, 'exactly one default remains');
select public.set_default_workspace(:'ws2');
select tests.ok(tests.count('select 1 from public.workspaces where is_default') = 1, 'setting the current default again is a no-op');
select tests.throws(format($$update public.workspaces set is_archived = true where id = %L$$, :'ws2'),
  '23514', 'the default workspace cannot be archived');
update public.workspaces set is_archived = true where id = :'ws';
select tests.throws(format('select public.set_default_workspace(%L)', :'ws'), 'P0001', 'an archived workspace cannot become the default');
update public.workspaces set is_archived = false where id = :'ws';
select public.set_default_workspace(:'ws');
select tests.ok((select is_default from public.workspaces where id = :'ws'), 'the default can be moved back');
select tests.throws('select public.set_default_workspace(gen_random_uuid())', 'P0001', 'an unknown workspace is rejected');
select tests.superuser();
select tests.ok(tests.count(format($$select 1 from public.audit_logs where organization_id = %L
  and entity_type = 'workspaces' and action = 'update'$$, :'org')) >= 4, 'default-workspace changes are audited');
select tests.login(:'owner');

-- ---- invitations -------------------------------------------------------------
select public.invite_member(:'org', 'Admin@C.test', :'r_admin') as inv_admin \gset
select public.invite_member(:'org', 'staff@c.test', :'r_staff') as inv_staff \gset
select public.invite_member(:'org', 'viewer@c.test', :'r_viewer') as inv_viewer \gset
select public.invite_member(:'org', 'pending@c.test', :'r_staff') as inv_unverified \gset
select tests.ok((select email from public.invitations where id = :'inv_admin') = 'admin@c.test', 'invitation email is normalized');

select tests.login(:'outsider');
select tests.ok(jsonb_array_length(public.get_my_context() -> 'invitations') = 0, 'a stranger sees no invitations');
select tests.throws(format('select public.accept_invitation(%L)', :'inv_admin'), 'P0001', 'a stranger cannot accept someone else''s invitation');
select tests.ok(tests.count('select 1 from public.invitations') = 0, 'a stranger cannot list invitations');

select tests.login(:'unverified');
select tests.ok(jsonb_array_length(public.get_my_context() -> 'invitations') = 0, 'unverified email is shown no invitations');
select tests.throws(format('select public.accept_invitation(%L)', :'inv_unverified'), '42501', 'unverified email cannot accept an invitation');

select tests.login(:'admin');
select tests.ok(jsonb_array_length(public.get_my_context() -> 'invitations') = 1, 'invitee sees the pending invitation');
select tests.ok(public.accept_invitation(:'inv_admin') = :'org'::uuid, 'invitee accepts and joins');
select tests.throws(format('select public.accept_invitation(%L)', :'inv_admin'), 'P0001', 'an invitation cannot be used twice');
select tests.login(:'staff');
select public.accept_invitation(:'inv_staff');
select tests.login(:'viewer');
select public.accept_invitation(:'inv_viewer');

-- ---- the authorization tables are read-only for every client ------------------
select tests.login(:'owner');
select tests.throws(format('insert into public.memberships (organization_id, user_id, role_id) values (%L, %L, %L)', :'org', :'outsider', :'r_admin'),
  '42501', 'even an owner cannot insert memberships directly');
select tests.throws(format('update public.memberships set role_id = %L where user_id = %L', :'r_owner', :'staff'),
  '42501', 'even an owner cannot update memberships directly');
select tests.throws('delete from public.memberships', '42501', 'even an owner cannot delete memberships directly');
select tests.throws(format($$insert into public.roles (organization_id, name) values (%L, 'Direct')$$, :'org'),
  '42501', 'roles cannot be inserted directly');
select tests.throws(format($$insert into public.role_permissions (role_id, organization_id, permission_key) values (%L, %L, 'org.manage')$$, :'r_viewer', :'org'),
  '42501', 'role permissions cannot be inserted directly');
select tests.throws(format($$insert into public.audit_logs (organization_id, action, entity_type) values (%L, 'forged', 'x')$$, :'org'),
  '42501', 'audit entries cannot be forged');
select tests.throws($$update public.organization_subscriptions set plan = 'enterprise'$$, '42501', 'a client cannot change its own plan');
select tests.throws($$update public.organizations set slug = 'taken-over'$$, '42501', 'slug is not client-editable');
select tests.throws($$insert into public.organizations (name, slug) values ('Direct Org', 'direct-org')$$, '42501', 'organizations are created only through the RPC');
select tests.throws($$update public.profiles set email = 'spoof@c.test'$$, '42501', 'profile email is not client-editable');
select tests.throws(format($$insert into public.invitations (organization_id, email, role_id) values (%L, 'x@c.test', %L)$$, :'org', :'r_owner'),
  '42501', 'invitations cannot be inserted directly');

-- ---- escalation attempts by a non-owner admin --------------------------------
select tests.login(:'admin');
select tests.throws(format('select public.set_member_role((select id from public.memberships where user_id = %L), %L)', :'staff', :'r_owner'),
  '42501', 'an admin cannot grant ownership');
select tests.throws(format('select public.set_member_role((select id from public.memberships where user_id = %L), %L)', :'admin', :'r_owner'),
  'P0001', 'nobody can change their own role');
select tests.throws(format('select public.set_member_role((select id from public.memberships where user_id = %L), %L)', :'owner', :'r_viewer'),
  '42501', 'an admin cannot demote an owner');
select tests.throws(format('select public.remove_member((select id from public.memberships where user_id = %L))', :'owner'),
  '42501', 'an admin cannot remove an owner');
select tests.throws(format($$select public.set_member_status((select id from public.memberships where user_id = %L), 'suspended')$$, :'owner'),
  '42501', 'an admin cannot suspend an owner');
select tests.throws(format($$select public.invite_member(%L, 'friend@c.test', %L)$$, :'org', :'r_owner'),
  '42501', 'an admin cannot invite a new owner');
select tests.throws(format($$select public.save_role(%L, %L, 'Admin', '', array['org.manage'])$$, :'org', :'r_admin'),
  'P0001', 'built-in roles cannot be edited');
select tests.throws(format('select public.delete_role(%L)', :'r_viewer'), 'P0001', 'built-in roles cannot be deleted');

-- An admin may do what the role is for.
select public.set_member_role((select id from public.memberships where user_id = :'staff'), :'r_manager');
select tests.ok((select role_id from public.memberships where user_id = :'staff') = :'r_manager'::uuid, 'an admin can promote staff to manager');
select public.set_member_role((select id from public.memberships where user_id = :'staff'), :'r_staff');

-- ---- custom roles cannot exceed their author ----------------------------------
select tests.login(:'owner');
select public.save_role(:'org', null, 'Team Lead', 'Manages the team only',
  array['members.read', 'members.manage', 'roles.manage', 'customers.read']) as r_lead \gset
select public.set_member_role((select id from public.memberships where user_id = :'staff'), :'r_lead');

select tests.login(:'staff');  -- now Team Lead: can manage roles, but holds few permissions
select tests.throws(format($$select public.save_role(%L, null, 'Sneaky', '', array['audit.read'])$$, :'org'),
  '42501', 'a role author cannot grant a permission they lack');
select tests.throws(format($$select public.save_role(%L, %L, 'Team Lead', '', array['members.manage', 'roles.manage', 'org.manage'])$$, :'org', :'r_lead'),
  '42501', 'a role author cannot widen their own role');
select tests.throws(format('select public.set_member_role((select id from public.memberships where user_id = %L), %L)', :'viewer', :'r_admin'),
  '42501', 'cannot assign a role broader than your own');
select tests.throws(format($$select public.invite_member(%L, 'friend@c.test', %L)$$, :'org', :'r_admin'),
  '42501', 'cannot invite someone into a role broader than your own');
select tests.throws(format($$select public.save_role(%L, null, 'Ghost', '', array['does.notexist'])$$, :'org'),
  'P0001', 'unknown permissions are rejected');
select public.save_role(:'org', null, 'Greeter', '', array['customers.read']) as r_greeter \gset
select tests.ok(tests.count(format('select 1 from public.role_permissions where role_id = %L', :'r_greeter')) = 1, 'a narrower custom role can be created');
select public.set_member_role((select id from public.memberships where user_id = :'viewer'), :'r_greeter');
select tests.throws(format('select public.delete_role(%L)', :'r_greeter'), 'P0001', 'a role in use cannot be deleted');
select tests.login(:'owner');
select public.set_member_role((select id from public.memberships where user_id = :'viewer'), :'r_viewer');
select tests.login(:'staff');
select public.delete_role(:'r_greeter');
select tests.ok(tests.count(format('select 1 from public.roles where id = %L', :'r_greeter')) = 0, 'an unused custom role can be deleted');

-- ---- permissions gate table access --------------------------------------------
select tests.login(:'owner');
select public.set_member_role((select id from public.memberships where user_id = :'staff'), :'r_staff');
insert into public.customers (organization_id, name) values (:'org', 'Gamma Customer') returning id as cust \gset
insert into public.products (organization_id, name, unit_price_minor) values (:'org', 'Gamma Item', 5000) returning id as prod \gset

select tests.login(:'viewer');
select tests.ok(tests.count('select 1 from public.customers') = 1, 'viewer can read customers');
select tests.throws(format($$insert into public.customers (organization_id, name) values (%L, 'Nope')$$, :'org'), '42501', 'viewer cannot create customers');
select tests.affects_none($$update public.customers set name = 'Nope'$$, 'viewer cannot edit customers');
select tests.affects_none('delete from public.customers', 'viewer cannot delete customers');
select tests.ok(tests.count('select 1 from public.products') = 1, 'viewer can read the catalogue');
select tests.affects_none('update public.products set unit_price_minor = 1', 'viewer cannot reprice products');
select tests.affects_none('delete from public.products', 'viewer cannot delete products');
select tests.affects_none($$update public.workspaces set name = 'Renamed'$$, 'viewer cannot rename workspaces');
select tests.affects_none(format($$update public.profiles set full_name = 'Renamed' where id = %L$$, :'owner'),
  'a colleague''s profile is readable but not editable');
update public.profiles set full_name = 'Vera Viewer' where id = :'viewer';
select tests.ok((select full_name from public.profiles where id = :'viewer') = 'Vera Viewer', 'a user can edit their own profile');
select tests.ok(tests.count('select 1 from public.memberships') = 1, 'viewer sees only their own membership');
select tests.ok(tests.count('select 1 from public.audit_logs') = 0, 'viewer cannot read the audit trail');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"description":"x","quantity":1,"unit_price_minor":100}]')$$, :'org', :'ws'),
  '42501', 'viewer cannot record sales');
select tests.ok((public.dashboard_summary(:'org') ->> 'customers_count')::int = 1, 'viewer can read the dashboard');

select tests.login(:'staff');
insert into public.customers (organization_id, name) values (:'org', 'Staff Customer');
select tests.ok(tests.count('select 1 from public.customers') = 2, 'staff can create customers');
select tests.affects_none('delete from public.customers', 'staff cannot delete customers');
select tests.throws(format($$insert into public.products (organization_id, name) values (%L, 'Nope')$$, :'org'), '42501', 'staff cannot edit the catalogue');
select tests.throws(format($$select public.adjust_stock(%L, %L, 5, 'adjustment')$$, :'ws', :'prod'), '42501', 'staff cannot adjust stock');
select tests.throws(format('select public.dashboard_summary(%L)', :'org'), '42501', 'staff cannot read reports');
select tests.throws(format($$select public.invite_member(%L, 'friend@c.test', %L)$$, :'org', :'r_viewer'), '42501', 'staff cannot invite');
select tests.throws(format($$insert into public.customers (organization_id, name, created_by) values (%L, 'Forged', %L)$$, :'org', :'owner'),
  '42501', 'created_by cannot be forged');
select tests.affects_none($$update public.organizations set name = 'Renamed'$$, 'staff cannot edit the organization');

-- ---- ownership invariants ------------------------------------------------------
select tests.login(:'owner');
begin;
select public.leave_organization(:'org');
select tests.throws('set constraints all immediate', 'P0001', 'the last owner cannot leave');
rollback;
select tests.login(:'owner');
select public.set_member_role((select id from public.memberships where user_id = :'admin'), :'r_owner');
select public.leave_organization(:'org');
select tests.ok(tests.count('select 1 from public.organizations') = 0, 'after handing over, the former owner has left');
select tests.login(:'admin');
select tests.ok((public.get_my_context() -> 'memberships' -> 0 -> 'role' ->> 'is_owner')::boolean, 'ownership was transferred');

-- ---- abuse guard ---------------------------------------------------------------
select tests.login(:'outsider');
select public.create_organization('Org ' || g) from generate_series(1, 10) g;
select tests.throws($$select public.create_organization('One Too Many')$$, 'P0001', 'organization creation is capped per account');
select tests.throws($$select public.create_organization('x')$$, 'P0001', 'organization name is validated');
select tests.superuser();
