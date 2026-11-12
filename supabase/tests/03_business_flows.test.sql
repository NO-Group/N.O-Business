-- Sales, stock, quotations, invoices and payments: server-computed money,
-- atomic stock movement, legal state transitions only.
\set QUIET on
select tests.superuser();
select tests.create_user('owner@d.test') as owner \gset
select tests.login(:'owner');
select public.create_organization('Delta Retail', 'NGN', 'NG', 'Africa/Lagos', 'Shop') as org \gset
update public.organizations set default_tax_rate = 7.5 where id = :'org';
select id as ws from public.workspaces where organization_id = :'org' \gset
insert into public.customers (organization_id, name) values (:'org', 'Delta Customer') returning id as cust \gset
insert into public.products (organization_id, name, unit_price_minor, reorder_level)
  values (:'org', 'Tracked Item', 100000, 5) returning id as item \gset
insert into public.products (organization_id, name, kind, track_inventory, unit_price_minor, tax_rate)
  values (:'org', 'Consulting Hour', 'service', false, 2500000, 0) returning id as svc \gset

-- ---- catalogue constraints ---------------------------------------------------
select tests.throws(format($$insert into public.products (organization_id, name, kind, track_inventory) values (%L, 'Bad', 'service', true)$$, :'org'),
  '23514', 'a service cannot track inventory');
select tests.throws(format($$insert into public.products (organization_id, name, unit_price_minor) values (%L, 'Bad', -1)$$, :'org'),
  '23514', 'prices cannot be negative');
insert into public.products (organization_id, name, sku) values (:'org', 'Sku One', 'ABC-1');
select tests.throws(format($$insert into public.products (organization_id, name, sku) values (%L, 'Sku Two', 'abc-1')$$, :'org'),
  '23505', 'SKU is unique per organization, case-insensitively');

-- ---- stock --------------------------------------------------------------------
select tests.ok(public.adjust_stock(:'ws', :'item', 10, 'opening') = 10, 'opening stock is recorded');
select tests.throws(format($$select public.adjust_stock(%L, %L, -11, 'damage')$$, :'ws', :'item'), 'P0001', 'stock cannot go negative');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 10, 'a rejected adjustment leaves the level untouched');
select tests.throws(format($$select public.adjust_stock(%L, %L, 1, 'opening')$$, :'ws', :'svc'), 'P0001', 'services have no stock');
select tests.throws(format($$select public.adjust_stock(%L, %L, 1, 'sale')$$, :'ws', :'item'), 'P0001', 'system reasons cannot be used manually');
select tests.throws($$insert into public.stock_movements (organization_id, workspace_id, product_id, quantity_delta, reason) select organization_id, workspace_id, product_id, 99, 'adjustment' from public.stock_levels$$,
  '42501', 'the stock ledger cannot be written directly');
select tests.throws('update public.stock_levels set quantity = 999', '42501', 'stock levels cannot be written directly');

-- ---- sale: 3 x 1,000.00 (7.5% tax) + 1h consulting (0%) - 500.00 discount ------
select public.record_sale(:'org', :'ws', :'cust', 'cash',
  jsonb_build_array(
    jsonb_build_object('product_id', :'item', 'quantity', 3),
    jsonb_build_object('product_id', :'svc', 'quantity', 1)),
  50000, 'first sale') as sale \gset
select tests.ok((select number from public.sales where id = :'sale') = 'SAL-000001', 'sales are numbered from 1');
select tests.ok((select subtotal_minor from public.sales where id = :'sale') = 2800000, 'subtotal is computed by the server');
-- raw tax = 300000 * 7.5% = 22500; scaled by (2800000-50000)/2800000 = 22098.2 -> 22098
select tests.ok((select tax_minor from public.sales where id = :'sale') = 22098, 'tax is charged on the discounted amount');
select tests.ok((select total_minor from public.sales where id = :'sale') = 2800000 - 50000 + 22098, 'total = subtotal - discount + tax');
select tests.ok((select currency_code from public.sales where id = :'sale') = 'NGN', 'currency comes from the organization');
select tests.ok(tests.count(format('select 1 from public.sale_items where sale_id = %L', :'sale')) = 2, 'both lines are stored');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 7, 'tracked stock is decremented');
select tests.ok(tests.count(format('select 1 from public.stock_levels where product_id = %L', :'svc')) = 0, 'services never touch stock');

-- A client-supplied price override is honoured; a client-supplied total is not a thing.
select public.record_sale(:'org', :'ws', null, 'card',
  jsonb_build_array(jsonb_build_object('product_id', :'item', 'quantity', 1, 'unit_price_minor', 90000, 'tax_rate', 0))) as sale2 \gset
select tests.ok((select total_minor from public.sales where id = :'sale2') = 90000, 'line price override is applied');
select tests.ok((select number from public.sales where id = :'sale2') = 'SAL-000002', 'numbers are sequential');

-- ---- overselling rolls everything back ----------------------------------------
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', jsonb_build_array(jsonb_build_object('product_id', %L, 'quantity', 7)))$$,
  :'org', :'ws', :'item'), 'P0001', 'overselling is rejected');
select tests.ok(tests.count('select 1 from public.sales') = 2, 'a rejected sale leaves no sale row');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 6, 'a rejected sale leaves stock untouched');
select tests.throws('select * from public.document_sequences', '42501', 'the sequence table is not readable by clients');
select tests.throws('update public.document_sequences set last_value = 0', '42501', 'the sequence table is not writable by clients');

-- ---- input validation ----------------------------------------------------------
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[]')$$, :'org', :'ws'), 'P0001', 'a sale needs at least one line');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"description":"x","quantity":0,"unit_price_minor":100}]')$$, :'org', :'ws'), 'P0001', 'zero quantity is rejected');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"description":"x","quantity":1,"unit_price_minor":-5}]')$$, :'org', :'ws'), 'P0001', 'negative price is rejected');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"quantity":1,"unit_price_minor":5}]')$$, :'org', :'ws'), 'P0001', 'a free-text line needs a description');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'cash', '[{"description":"x","quantity":1,"unit_price_minor":100}]', 101)$$, :'org', :'ws'), 'P0001', 'discount cannot exceed the subtotal');
select tests.throws(format($$select public.record_sale(%L, %L, null, 'barter', '[{"description":"x","quantity":1,"unit_price_minor":100}]')$$, :'org', :'ws'), 'P0001', 'unknown payment methods are rejected');
select tests.throws($$update public.sales set total_minor = 1$$, '42501', 'sales cannot be edited directly');
select tests.throws($$delete from public.sales$$, '42501', 'sales cannot be deleted directly');

-- ---- void restores stock, once -------------------------------------------------
select public.void_sale(:'sale');
select tests.ok((select status from public.sales where id = :'sale') = 'voided', 'sale is marked voided');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 9, 'voiding returns the goods');
select tests.throws(format('select public.void_sale(%L)', :'sale'), 'P0001', 'a sale cannot be voided twice');

-- ---- quotation lifecycle --------------------------------------------------------
select public.save_quotation(:'org', null, :'ws', :'cust', current_date + 14,
  jsonb_build_array(jsonb_build_object('product_id', :'item', 'quantity', 2))) as quo \gset
select tests.ok((select number from public.quotations where id = :'quo') = 'QUO-000001', 'quotations are numbered');
select tests.ok((select total_minor from public.quotations where id = :'quo') = 215000, 'quotation total includes default tax');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 9, 'a quotation does not move stock');
select tests.throws(format('select public.convert_quotation_to_invoice(%L)', :'quo'), 'P0001', 'a draft quotation cannot be converted');
select tests.throws(format($$select public.set_quotation_status(%L, 'accepted')$$, :'quo'), 'P0001', 'draft -> accepted is not a legal transition');
select tests.throws(format($$select public.set_quotation_status(%L, 'converted')$$, :'quo'), 'P0001', 'converted cannot be set by hand');
select public.save_quotation(:'org', :'quo', :'ws', :'cust', current_date + 14,
  jsonb_build_array(jsonb_build_object('product_id', :'item', 'quantity', 4)));
select tests.ok((select total_minor from public.quotations where id = :'quo') = 430000, 'editing a quotation recomputes totals');
select tests.ok(tests.count(format('select 1 from public.quotation_items where quotation_id = %L', :'quo')) = 1, 'editing replaces the lines');
select public.set_quotation_status(:'quo', 'sent');
select public.set_quotation_status(:'quo', 'accepted');
select tests.throws(format($$select public.save_quotation(%L, %L, %L, %L, null, '[{"description":"x","quantity":1,"unit_price_minor":1}]')$$, :'org', :'quo', :'ws', :'cust'),
  'P0001', 'an accepted quotation is locked');
select tests.throws(format('select public.delete_quotation(%L)', :'quo'), 'P0001', 'only drafts can be deleted');
select public.convert_quotation_to_invoice(:'quo') as inv \gset
select tests.ok((select status from public.quotations where id = :'quo') = 'converted', 'quotation is marked converted');
select tests.throws(format('select public.convert_quotation_to_invoice(%L)', :'quo'), 'P0001', 'a quotation converts only once');

-- ---- invoice lifecycle -----------------------------------------------------------
select tests.ok((select status from public.invoices where id = :'inv') = 'draft', 'conversion creates a draft invoice');
select tests.ok((select number from public.invoices where id = :'inv') is null, 'drafts are not numbered');
select tests.ok((select total_minor from public.invoices where id = :'inv') = 430000, 'invoice carries the quotation total');
select tests.throws(format($$select public.record_invoice_payment(%L, 1000, 'cash')$$, :'inv'), 'P0001', 'a draft cannot be paid');
select tests.throws(format('select public.void_invoice(%L)', :'inv'), 'P0001', 'a draft cannot be voided');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 9, 'a draft does not move stock');

select tests.ok(public.issue_invoice(:'inv') = 'INV-000001', 'issuing assigns the first number');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 5, 'issuing releases stock');
select tests.ok((select issue_date from public.invoices where id = :'inv') is not null, 'issue date is set');
select tests.throws(format('select public.issue_invoice(%L)', :'inv'), 'P0001', 'an invoice is issued once');
select tests.throws(format($$select public.save_invoice(%L, %L, %L, %L, null, '[{"description":"x","quantity":1,"unit_price_minor":1}]')$$, :'org', :'inv', :'ws', :'cust'),
  'P0001', 'an issued invoice cannot be edited');
select tests.throws(format('select public.delete_invoice_draft(%L)', :'inv'), 'P0001', 'an issued invoice cannot be deleted');
select tests.throws($$update public.invoices set amount_paid_minor = total_minor, status = 'paid'$$, '42501', 'invoices cannot be marked paid directly');
select tests.throws(format($$insert into public.payments (organization_id, invoice_id, amount_minor, method) values (%L, %L, 1, 'cash')$$, :'org', :'inv'),
  '42501', 'payments cannot be inserted directly');

select tests.throws(format($$select public.record_invoice_payment(%L, 0, 'cash')$$, :'inv'), 'P0001', 'zero payments are rejected');
select tests.throws(format($$select public.record_invoice_payment(%L, 430001, 'cash')$$, :'inv'), 'P0001', 'overpayment is rejected');
select tests.throws(format($$select public.record_invoice_payment(%L, 100, 'iou')$$, :'inv'), 'P0001', 'unknown payment methods are rejected');
select public.record_invoice_payment(:'inv', 130000, 'bank_transfer', 'TRX-1');
select tests.ok((select status from public.invoices where id = :'inv') = 'partially_paid', 'a part payment marks the invoice partially paid');
select tests.ok((select amount_paid_minor from public.invoices where id = :'inv') = 130000, 'amount paid accumulates');
select tests.throws(format('select public.void_invoice(%L)', :'inv'), 'P0001', 'an invoice with payments cannot be voided');
select tests.throws(format($$select public.record_invoice_payment(%L, 300001, 'cash')$$, :'inv'), 'P0001', 'cannot pay more than the balance');
select public.record_invoice_payment(:'inv', 300000, 'cash');
select tests.ok((select status from public.invoices where id = :'inv') = 'paid', 'settling the balance marks the invoice paid');
select tests.throws(format($$select public.record_invoice_payment(%L, 1, 'cash')$$, :'inv'), 'P0001', 'a paid invoice takes no more payments');
select tests.ok(tests.count('select 1 from public.payments') = 2, 'both payments are on record');

-- A second invoice: issue fails on insufficient stock, void returns stock.
select public.save_invoice(:'org', null, :'ws', :'cust', current_date + 30,
  jsonb_build_array(jsonb_build_object('product_id', :'item', 'quantity', 6))) as inv2 \gset
select tests.throws(format('select public.issue_invoice(%L)', :'inv2'), 'P0001', 'issuing beyond available stock is rejected');
select tests.ok((select status from public.invoices where id = :'inv2') = 'draft', 'the failed issue left the draft untouched');
select tests.ok((select number from public.invoices where id = :'inv2') is null, 'and consumed no invoice number');
select public.save_invoice(:'org', :'inv2', :'ws', :'cust', current_date + 30,
  jsonb_build_array(jsonb_build_object('product_id', :'item', 'quantity', 2)));
select tests.ok(public.issue_invoice(:'inv2') = 'INV-000002', 'the series has no gap after a failed issue');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 3, 'stock after second invoice');
select public.void_invoice(:'inv2');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 5, 'voiding an invoice returns stock');
select tests.ok((select status from public.invoices where id = :'inv2') = 'void', 'invoice is void');

select public.save_invoice(:'org', null, :'ws', :'cust', current_date - 1,
  '[{"description":"Late job","quantity":1,"unit_price_minor":100000,"tax_rate":0}]') as inv3 \gset
select tests.throws(format('select public.issue_invoice(%L)', :'inv3'), 'P0001', 'cannot issue with a due date in the past');
select public.delete_invoice_draft(:'inv3');
select tests.ok(tests.count(format('select 1 from public.invoices where id = %L', :'inv3')) = 0, 'a draft can be deleted');

-- ---- referential safety ----------------------------------------------------------
select tests.throws(format('delete from public.customers where id = %L', :'cust'), '23503', 'a customer with documents cannot be deleted');
select tests.throws(format('delete from public.products where id = %L', :'item'), '23503', 'a product on documents cannot be deleted');

-- ---- dashboard reflects the rows above --------------------------------------------
select public.dashboard_summary(:'org') as dash \gset
select tests.ok((:'dash'::jsonb ->> 'sales_total_minor')::bigint = 90000, 'dashboard sales exclude the voided sale');
select tests.ok((:'dash'::jsonb ->> 'sales_count')::int = 1, 'dashboard sale count');
select tests.ok((:'dash'::jsonb ->> 'payments_total_minor')::bigint = 430000, 'dashboard invoice payments');
select tests.ok((:'dash'::jsonb ->> 'receivables_minor')::bigint = 0, 'no receivables once paid or void');
select tests.ok((:'dash'::jsonb ->> 'low_stock_count')::int = 2, 'low stock counts the item at its reorder level and the never-stocked item');
select tests.ok(jsonb_array_length(:'dash'::jsonb -> 'daily') = 30, 'daily series covers the period');
select tests.ok((select sum((d ->> 'sales_minor')::bigint + (d ->> 'payments_minor')::bigint) from jsonb_array_elements(:'dash'::jsonb -> 'daily') d) = 520000,
  'daily series adds up to the headline numbers');
select tests.ok((:'dash'::jsonb -> 'top_products' -> 0 ->> 'name') = 'Tracked Item', 'top products come from completed sales');

-- An open, overdue receivable shows up (fixture back-dated as superuser).
select public.save_invoice(:'org', null, :'ws', :'cust', current_date + 5,
  '[{"description":"Retainer","quantity":1,"unit_price_minor":200000,"tax_rate":0}]') as inv4 \gset
select public.issue_invoice(:'inv4');
select tests.superuser();
update public.invoices set due_date = current_date - 10 where id = :'inv4';
select tests.login(:'owner');
select public.dashboard_summary(:'org') as dash \gset
select tests.ok((:'dash'::jsonb ->> 'receivables_minor')::bigint = 200000, 'open invoice counts as receivable');
select tests.ok((:'dash'::jsonb ->> 'overdue_minor')::bigint = 200000, 'past-due invoice counts as overdue');
select tests.ok((:'dash'::jsonb ->> 'overdue_count')::int = 1, 'overdue count');

-- ---- every RPC enforces its permission, for insiders and outsiders alike ------------
-- Fixtures: an open invoice (inv4), a draft invoice, a draft and a sent quotation,
-- and a completed sale (sale2). A read-only member and a member of another
-- organization each try every write operation by id.
select public.save_invoice(:'org', null, :'ws', :'cust', null,
  '[{"description":"Draft job","quantity":1,"unit_price_minor":5000,"tax_rate":0}]') as draft_inv \gset
select public.save_quotation(:'org', null, :'ws', :'cust', null,
  '[{"description":"Draft quote","quantity":1,"unit_price_minor":5000,"tax_rate":0}]') as draft_quo \gset
select public.save_quotation(:'org', null, :'ws', :'cust', null,
  '[{"description":"Sent quote","quantity":1,"unit_price_minor":5000,"tax_rate":0}]') as sent_quo \gset
select public.set_quotation_status(:'sent_quo', 'sent');
select public.invite_member(:'org', 'viewer@d.test',
  (select id from public.roles where organization_id = :'org' and name = 'Viewer')) as inv_viewer \gset
select public.save_role(:'org', null, 'Custom', '', array['customers.read']) as custom_role \gset
insert into public.workspaces (organization_id, name) values (:'org', 'Second Shop') returning id as ws2 \gset
select public.invite_member(:'org', 'nobody@d.test',
  (select id from public.roles where organization_id = :'org' and name = 'Viewer')) as open_invitation \gset
select tests.superuser();
select tests.create_user('viewer@d.test') as viewer \gset
select tests.create_user('outsider@y.test') as outsider \gset
-- A plain (non-owner) member for the member-management attempts to aim at.
select tests.create_user('staffer@d.test') as staffer \gset
insert into public.memberships (organization_id, user_id, role_id)
  select :'org', :'staffer', id from public.roles where organization_id = :'org' and name = 'Staff'
  returning id as target_membership \gset
select tests.login(:'outsider');
select public.create_organization('Yankee Inc') as org_y \gset
select tests.login(:'viewer');
select public.accept_invitation(:'inv_viewer');

\set line '[{"description":"x","quantity":1,"unit_price_minor":100}]'
select tests.login(:'viewer') as "who", 'read-only member' as label \gset
\ir support/rpc_denials.sql
select tests.login(:'outsider') as "who", 'other tenant' as label \gset
\ir support/rpc_denials.sql

-- Converting a quotation needs BOTH quotations.write and invoices.write.
select tests.login(:'owner');
select public.save_role(:'org', :'custom_role', 'Custom', '', array['quotations.read', 'quotations.write']);
select public.set_member_role((select id from public.memberships where user_id = :'viewer'), :'custom_role');
select tests.login(:'viewer');
select tests.throws(format('select public.convert_quotation_to_invoice(%L)', :'sent_quo'), '42501', 'converting needs invoices.write as well');
select tests.login(:'owner');
select public.save_role(:'org', :'custom_role', 'Custom', '', array['invoices.read', 'invoices.write']);
select tests.login(:'viewer');
select tests.throws(format('select public.convert_quotation_to_invoice(%L)', :'sent_quo'), '42501', 'converting needs quotations.write as well');

-- Nothing moved.
select tests.login(:'owner');
select tests.ok((select status from public.invoices where id = :'inv4') = 'issued', 'the open invoice is unchanged');
select tests.ok((select status from public.invoices where id = :'draft_inv') = 'draft', 'the draft invoice is unchanged');
select tests.ok((select status from public.quotations where id = :'sent_quo') = 'sent', 'the sent quotation is unchanged');
select tests.ok((select status from public.sales where id = :'sale2') = 'completed', 'the sale is unchanged');
select tests.ok((select quantity from public.stock_levels where product_id = :'item') = 5, 'stock is unchanged');
select tests.ok((select status from public.invitations where id = :'open_invitation') = 'pending', 'the invitation is unchanged');
select tests.ok((select status from public.memberships where id = :'target_membership') = 'active', 'the targeted member is unchanged');
select tests.superuser();
