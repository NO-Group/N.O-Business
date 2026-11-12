-- Tenant isolation: a member of organization B must not be able to read,
-- write, move or infer anything that belongs to organization A.
\set QUIET on
select tests.superuser();
select tests.create_user('alice@a.test') as alice \gset
select tests.create_user('bob@b.test') as bob \gset

select tests.login(:'alice');
select public.create_organization('Alpha Trading', 'NGN', 'NG', 'Africa/Lagos', 'HQ') as org_a \gset
select id as ws_a from public.workspaces where organization_id = :'org_a' \gset
insert into public.customers (organization_id, name) values (:'org_a', 'Alpha Customer') returning id as cust_a \gset
insert into public.products (organization_id, name, unit_price_minor)
  values (:'org_a', 'Alpha Widget', 150000) returning id as prod_a \gset
select public.adjust_stock(:'ws_a', :'prod_a', 10, 'opening');

-- Alpha also has transactional records and a stored document.
select public.record_sale(:'org_a', :'ws_a', :'cust_a', 'cash',
  jsonb_build_array(jsonb_build_object('product_id', :'prod_a', 'quantity', 1))) as sale_a \gset
select public.save_quotation(:'org_a', null, :'ws_a', :'cust_a', null,
  jsonb_build_array(jsonb_build_object('product_id', :'prod_a', 'quantity', 1))) as quo_a \gset
select public.save_invoice(:'org_a', null, :'ws_a', :'cust_a', null,
  jsonb_build_array(jsonb_build_object('product_id', :'prod_a', 'quantity', 1))) as inv_a \gset
select public.issue_invoice(:'inv_a');
select public.record_invoice_payment(:'inv_a', 1000, 'cash');
select gen_random_uuid() as doc_a \gset
insert into storage.objects (bucket_id, name) values ('documents', :'org_a' || '/' || :'doc_a' || '/plan.pdf');
insert into public.documents (id, organization_id, name, storage_path, mime_type, size_bytes)
  values (:'doc_a', :'org_a', 'Plan', :'org_a' || '/' || :'doc_a' || '/plan.pdf', 'application/pdf', 1024);

select tests.login(:'bob');
select public.create_organization('Beta Supplies', 'USD', 'US', 'UTC', 'Main') as org_b \gset
select id as ws_b from public.workspaces where organization_id = :'org_b' \gset
insert into public.customers (organization_id, name) values (:'org_b', 'Beta Customer') returning id as cust_b \gset

-- ---- anonymous callers get nothing ------------------------------------------
select tests.anonymous();
select tests.throws('select * from public.organizations', '42501', 'anon cannot read organizations');
select tests.throws('select * from public.customers', '42501', 'anon cannot read customers');
select tests.throws('select * from public.profiles', '42501', 'anon cannot read profiles');
select tests.throws('select * from public.audit_logs', '42501', 'anon cannot read audit logs');
select tests.throws('select public.get_my_context()', '42501', 'anon cannot call get_my_context');
select tests.throws($$select public.create_organization('X Corp')$$, '42501', 'anon cannot create organizations');
select tests.throws(format('select public.dashboard_summary(%L)', :'org_a'), '42501', 'anon cannot read dashboards');

-- ---- reads are scoped to the caller's organizations --------------------------
select tests.login(:'bob');
select tests.ok(tests.count('select 1 from public.organizations') = 1, 'bob sees exactly one organization');
select tests.ok((select name from public.organizations) = 'Beta Supplies', 'and it is his own');
select tests.ok(tests.count('select 1 from public.customers') = 1, 'bob sees only his customers');
select tests.ok(tests.count(format('select 1 from public.customers where organization_id = %L', :'org_a')) = 0,
  'filtering by another tenant id returns nothing');
select tests.ok(tests.count('select 1 from public.products') = 0, 'bob cannot see alpha products');
select tests.ok(tests.count('select 1 from public.stock_levels') = 0, 'bob cannot see alpha stock');
select tests.ok(tests.count('select 1 from public.stock_movements') = 0, 'bob cannot see alpha stock movements');
select tests.ok(tests.count(format('select 1 from public.workspaces where organization_id = %L', :'org_a')) = 0,
  'bob cannot see alpha workspaces');
select tests.ok(tests.count(format('select 1 from public.memberships where organization_id = %L', :'org_a')) = 0,
  'bob cannot see alpha memberships');
select tests.ok(tests.count(format('select 1 from public.roles where organization_id = %L', :'org_a')) = 0,
  'bob cannot see alpha roles');
select tests.ok(tests.count(format('select 1 from public.role_permissions where organization_id = %L', :'org_a')) = 0,
  'bob cannot see alpha role permissions');
select tests.ok(tests.count(format('select 1 from public.audit_logs where organization_id = %L', :'org_a')) = 0,
  'bob cannot see alpha audit logs');
select tests.ok(tests.count(format('select 1 from public.profiles where id = %L', :'alice')) = 0,
  'bob cannot see the profile of a stranger');
select tests.ok(tests.count('select 1 from public.profiles') = 1, 'bob sees his own profile');
select tests.ok(tests.count('select 1 from public.sales') = 0, 'bob cannot see alpha sales');
select tests.ok(tests.count('select 1 from public.sale_items') = 0, 'bob cannot see alpha sale lines');
select tests.ok(tests.count('select 1 from public.quotations') = 0, 'bob cannot see alpha quotations');
select tests.ok(tests.count('select 1 from public.quotation_items') = 0, 'bob cannot see alpha quotation lines');
select tests.ok(tests.count('select 1 from public.invoices') = 0, 'bob cannot see alpha invoices');
select tests.ok(tests.count('select 1 from public.invoice_items') = 0, 'bob cannot see alpha invoice lines');
select tests.ok(tests.count('select 1 from public.payments') = 0, 'bob cannot see alpha payments');
select tests.ok(tests.count('select 1 from public.documents') = 0, 'bob cannot see alpha documents');
select tests.ok(tests.count('select 1 from public.organization_subscriptions') = 1, 'bob sees only his own subscription');

-- ---- writes into another tenant are rejected ---------------------------------
select tests.throws(format($$insert into public.customers (organization_id, name) values (%L, 'Intruder')$$, :'org_a'),
  '42501', 'bob cannot insert a customer into alpha');
select tests.throws(format($$insert into public.products (organization_id, name) values (%L, 'Intruder')$$, :'org_a'),
  '42501', 'bob cannot insert a product into alpha');
select tests.throws(format($$insert into public.workspaces (organization_id, name) values (%L, 'Intruder')$$, :'org_a'),
  '42501', 'bob cannot insert a workspace into alpha');
select tests.affects_none(format($$update public.customers set name = 'Hacked' where id = %L$$, :'cust_a'),
  'bob cannot update an alpha customer');
select tests.affects_none(format('delete from public.customers where id = %L', :'cust_a'),
  'bob cannot delete an alpha customer');
select tests.affects_none(format($$update public.organizations set name = 'Hacked' where id = %L$$, :'org_a'),
  'bob cannot rename alpha');
select tests.affects_none(format($$update public.products set unit_price_minor = 1 where id = %L$$, :'prod_a'),
  'bob cannot reprice an alpha product');
select tests.affects_none(format('delete from public.products where id = %L', :'prod_a'),
  'bob cannot delete an alpha product');
select tests.affects_none(format($$update public.workspaces set name = 'Hacked' where id = %L$$, :'ws_a'),
  'bob cannot rename an alpha workspace');
select tests.affects_none(format($$update public.profiles set full_name = 'Hacked' where id = %L$$, :'alice'),
  'bob cannot edit another user''s profile');
select tests.affects_none(format($$update public.documents set name = 'Hacked' where id = %L$$, :'doc_a'),
  'bob cannot rename an alpha document');
select tests.affects_none(format('delete from public.documents where id = %L', :'doc_a'),
  'bob cannot delete an alpha document');
select tests.throws(format($$insert into public.documents (id, organization_id, name, storage_path, mime_type, size_bytes)
    values (%L, %L, 'Planted', %L, 'application/pdf', 10)$$,
  :'doc_a', :'org_a', :'org_a' || '/' || :'doc_a' || '/planted.pdf'), '42501', 'bob cannot plant document metadata in alpha');
select tests.throws(format($$update public.customers set organization_id = %L where id = %L$$, :'org_a', :'cust_b'),
  '42501', 'bob cannot move his customer into alpha');

-- ---- RPCs check the target organization, not just "is signed in" -------------
select tests.throws(format('select public.dashboard_summary(%L)', :'org_a'), '42501', 'bob cannot read the alpha dashboard');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"description":"x","quantity":1,"unit_price_minor":100}]')$$,
  :'org_a', :'ws_a'), '42501', 'bob cannot record a sale in alpha');
select tests.throws(format($$select public.adjust_stock(%L, %L, 5, 'adjustment')$$, :'ws_a', :'prod_a'),
  '42501', 'bob cannot adjust alpha stock');
select tests.throws(format($$select public.adjust_stock(%L, %L, 5, 'adjustment')$$, :'ws_b', :'prod_a'),
  '42501', 'bob cannot pull an alpha product into his own workspace');
select tests.throws(format($$select public.invite_member(%L, 'mallory@x.test', (select id from public.roles limit 1))$$, :'org_a'),
  '42501', 'bob cannot invite into alpha');
select tests.throws(format($$select public.save_role(%L, null, 'Backdoor', '', array['org.manage'])$$, :'org_a'),
  '42501', 'bob cannot create a role in alpha');
select tests.throws(format($$select public.save_invoice(%L, null, %L, %L, null, '[{"description":"x","quantity":1,"unit_price_minor":100}]')$$,
  :'org_a', :'ws_a', :'cust_a'), '42501', 'bob cannot create an invoice in alpha');

-- ---- cross-tenant references are impossible even inside one's own tenant -----
select tests.throws(format($$select public.record_sale(%L, %L, %L, 'cash', '[{"description":"x","quantity":1,"unit_price_minor":100}]')$$,
  :'org_b', :'ws_b', :'cust_a'), 'P0001', 'a sale cannot reference another tenant''s customer');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"description":"x","quantity":1,"unit_price_minor":100}]')$$,
  :'org_b', :'ws_a'), 'P0001', 'a sale cannot use another tenant''s workspace');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', jsonb_build_array(jsonb_build_object('product_id', %L, 'quantity', 1)))$$,
  :'org_b', :'ws_b', :'prod_a'), 'P0001', 'a sale cannot reference another tenant''s product');

-- The composite foreign keys hold even for a caller that bypasses RLS.
select tests.superuser();
select tests.throws(format($$insert into public.sales (organization_id, workspace_id, number, customer_id, payment_method,
    currency_code, subtotal_minor, total_minor) values (%L, %L, 'X-1', %L, 'cash', 'USD', 1, 1)$$,
  :'org_b', :'ws_b', :'cust_a'), '23503', 'FK rejects a cross-tenant customer even without RLS');
select tests.throws(format($$insert into public.memberships (organization_id, user_id, role_id)
    values (%L, %L, (select id from public.roles where organization_id = %L and is_owner))$$,
  :'org_a', :'bob', :'org_b'), '23503', 'FK rejects a role from another tenant');

-- ---- alpha is untouched ------------------------------------------------------
select tests.login(:'alice');
select tests.ok((select name from public.customers where id = :'cust_a') = 'Alpha Customer', 'alpha customer is intact');
select tests.ok((select name from public.organizations where id = :'org_a') = 'Alpha Trading', 'alpha name is intact');
select tests.ok(tests.count('select 1 from public.customers') = 1, 'alice sees only alpha customers');
select tests.ok((select quantity from public.stock_levels where product_id = :'prod_a') = 8, 'alpha stock is intact');
select tests.ok((select unit_price_minor from public.products where id = :'prod_a') = 150000, 'alpha product is intact');
select tests.ok((select name from public.workspaces where id = :'ws_a') = 'HQ', 'alpha workspace is intact');
select tests.ok((select name from public.documents where id = :'doc_a') = 'Plan', 'alpha document is intact');
select tests.ok((select full_name from public.profiles where id = :'alice') = 'Alice', 'alice''s profile is intact');

-- ---- a suspended member loses access immediately -----------------------------
select tests.superuser();
select tests.create_user('sam@a.test') as sam \gset
insert into public.memberships (organization_id, user_id, role_id)
  select :'org_a', :'sam', id from public.roles where organization_id = :'org_a' and name = 'Admin';
select tests.login(:'sam');
select tests.ok(tests.count('select 1 from public.customers') = 1, 'active admin can read');
select tests.login(:'alice');
select public.set_member_status((select id from public.memberships where user_id = :'sam'), 'suspended');
select tests.login(:'sam');
select tests.ok(tests.count('select 1 from public.customers') = 0, 'suspended member reads nothing');
select tests.ok(tests.count('select 1 from public.organizations') = 0, 'suspended member no longer sees the organization');
select tests.throws(format('select public.dashboard_summary(%L)', :'org_a'), '42501', 'suspended member cannot call RPCs');
select tests.ok(jsonb_array_length(public.get_my_context() -> 'memberships') = 0, 'suspended membership is absent from the session context');
select tests.superuser();
