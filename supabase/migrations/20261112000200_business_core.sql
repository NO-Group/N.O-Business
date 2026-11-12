-- ============================================================================
-- N.O Business — core business records
--
-- Conventions
--   * Money is stored as bigint MINOR units (kobo, cents) alongside an ISO
--     4217 currency_code. No floating point touches a total.
--   * Quantities are numeric(14,3).
--   * Totals on sales / quotations / invoices are computed by the server
--     (see 20261112000400_rpc.sql). Clients cannot write those tables
--     directly; they call the RPCs, which also move stock and write audit
--     entries inside the same transaction.
--   * Customers and the catalogue are plain CRUD and are written directly
--     through the Data API under RLS.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------------
create table public.customers (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  kind            text not null default 'individual' check (kind in ('individual', 'company')),
  name            text not null check (char_length(btrim(name)) between 1 and 160),
  email           text check (email is null or email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone           text check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$'),
  address         text check (address is null or char_length(address) <= 500),
  tax_id          text check (tax_id is null or char_length(tax_id) <= 60),
  notes           text check (notes is null or char_length(notes) <= 2000),
  created_by      uuid default auth.uid() references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (id, organization_id)
);

create index customers_org_name_idx on public.customers (organization_id, lower(name));

create trigger customers_touch before update on public.customers
  for each row execute function app.touch_updated_at();
create trigger customers_tenant_lock before update on public.customers
  for each row execute function app.prevent_tenant_change();
create trigger customers_audit after delete on public.customers
  for each row execute function app.audit_row_change();

-- ---------------------------------------------------------------------------
-- Catalogue: products and services
-- ---------------------------------------------------------------------------
create table public.products (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  kind             text not null default 'product' check (kind in ('product', 'service')),
  name             text not null check (char_length(btrim(name)) between 1 and 160),
  sku              text check (sku is null or char_length(btrim(sku)) between 1 and 60),
  description      text check (description is null or char_length(description) <= 2000),
  unit             text not null default 'unit' check (char_length(unit) between 1 and 20),
  unit_price_minor bigint not null default 0 check (unit_price_minor >= 0),
  cost_price_minor bigint not null default 0 check (cost_price_minor >= 0),
  tax_rate         numeric(5, 2) check (tax_rate is null or (tax_rate >= 0 and tax_rate <= 100)),
  track_inventory  boolean not null default true,
  reorder_level    numeric(14, 3) not null default 0 check (reorder_level >= 0),
  is_active        boolean not null default true,
  created_by       uuid default auth.uid() references auth.users (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (id, organization_id),
  -- A service has no stock to track.
  constraint products_service_untracked check (kind = 'product' or not track_inventory)
);

create unique index products_sku_key
  on public.products (organization_id, lower(btrim(sku))) where sku is not null;
create index products_org_name_idx on public.products (organization_id, lower(name));

create trigger products_touch before update on public.products
  for each row execute function app.touch_updated_at();
create trigger products_tenant_lock before update on public.products
  for each row execute function app.prevent_tenant_change();
create trigger products_audit after delete on public.products
  for each row execute function app.audit_row_change();

-- ---------------------------------------------------------------------------
-- Inventory: an append-only movement ledger and the level it maintains
-- ---------------------------------------------------------------------------
create table public.stock_levels (
  organization_id uuid not null,
  workspace_id    uuid not null,
  product_id      uuid not null,
  quantity        numeric(14, 3) not null default 0,
  updated_at      timestamptz not null default now(),
  primary key (workspace_id, product_id),
  foreign key (workspace_id, organization_id)
    references public.workspaces (id, organization_id) on delete cascade,
  foreign key (product_id, organization_id)
    references public.products (id, organization_id) on delete cascade
);

create index stock_levels_org_idx on public.stock_levels (organization_id, product_id);

create table public.stock_movements (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  workspace_id    uuid not null,
  product_id      uuid not null,
  quantity_delta  numeric(14, 3) not null check (quantity_delta <> 0),
  reason          text not null check (reason in (
                    'opening', 'purchase', 'sale', 'sale_void', 'invoice',
                    'invoice_void', 'adjustment', 'damage', 'return')),
  reference_type  text,
  reference_id    uuid,
  note            text check (note is null or char_length(note) <= 500),
  created_by      uuid default auth.uid() references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  foreign key (workspace_id, organization_id)
    references public.workspaces (id, organization_id) on delete cascade,
  foreign key (product_id, organization_id)
    references public.products (id, organization_id) on delete cascade
);

create index stock_movements_product_idx
  on public.stock_movements (organization_id, product_id, created_at desc);

-- The level is derived state: every movement folds into it atomically.
create or replace function app.apply_stock_movement()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.stock_levels (organization_id, workspace_id, product_id, quantity)
  values (new.organization_id, new.workspace_id, new.product_id, new.quantity_delta)
  on conflict (workspace_id, product_id)
  do update set quantity = public.stock_levels.quantity + excluded.quantity,
                updated_at = now();
  return new;
end;
$$;

create trigger stock_movements_apply after insert on public.stock_movements
  for each row execute function app.apply_stock_movement();

-- ---------------------------------------------------------------------------
-- Document numbering — race-safe, per organization and document type
-- ---------------------------------------------------------------------------
create table public.document_sequences (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  doc_type        text not null check (doc_type in ('sale', 'quotation', 'invoice')),
  prefix          text not null check (prefix ~ '^[A-Z0-9-]{1,8}$'),
  last_value      bigint not null default 0 check (last_value >= 0),
  primary key (organization_id, doc_type)
);

-- One statement, one row lock: two devices can never receive the same number.
create or replace function app.next_document_number(p_org uuid, p_doc_type text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_prefix text;
  v_value bigint;
begin
  insert into public.document_sequences (organization_id, doc_type, prefix, last_value)
  values (
    p_org,
    p_doc_type,
    case p_doc_type when 'sale' then 'SAL' when 'quotation' then 'QUO' else 'INV' end,
    1
  )
  on conflict (organization_id, doc_type)
  do update set last_value = public.document_sequences.last_value + 1
  returning prefix, last_value into v_prefix, v_value;
  return v_prefix || '-' || lpad(v_value::text, 6, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- Sales (settled at the point of sale)
-- ---------------------------------------------------------------------------
create table public.sales (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  workspace_id    uuid not null,
  number          text not null,
  customer_id     uuid,
  status          text not null default 'completed' check (status in ('completed', 'voided')),
  payment_method  text not null check (payment_method in (
                    'cash', 'bank_transfer', 'card', 'mobile_money', 'other')),
  currency_code   text not null check (currency_code ~ '^[A-Z]{3}$'),
  subtotal_minor  bigint not null check (subtotal_minor >= 0),
  discount_minor  bigint not null default 0 check (discount_minor >= 0),
  tax_minor       bigint not null default 0 check (tax_minor >= 0),
  total_minor     bigint not null check (total_minor >= 0),
  note            text check (note is null or char_length(note) <= 1000),
  sold_at         timestamptz not null default now(),
  voided_at       timestamptz,
  voided_by       uuid references auth.users (id) on delete set null,
  created_by      uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  unique (id, organization_id),
  unique (organization_id, number),
  foreign key (workspace_id, organization_id)
    references public.workspaces (id, organization_id),
  foreign key (customer_id, organization_id)
    references public.customers (id, organization_id)
);

create index sales_org_time_idx on public.sales (organization_id, sold_at desc);
create index sales_customer_idx on public.sales (customer_id);

create table public.sale_items (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null,
  sale_id          uuid not null,
  product_id       uuid,
  description      text not null check (char_length(btrim(description)) between 1 and 300),
  quantity         numeric(14, 3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  tax_rate         numeric(5, 2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  line_total_minor bigint not null check (line_total_minor >= 0),
  position         integer not null default 0,
  foreign key (sale_id, organization_id)
    references public.sales (id, organization_id) on delete cascade,
  foreign key (product_id, organization_id)
    references public.products (id, organization_id)
);

create index sale_items_sale_idx on public.sale_items (sale_id);
create index sale_items_product_idx on public.sale_items (product_id);

-- ---------------------------------------------------------------------------
-- Quotations
-- ---------------------------------------------------------------------------
create table public.quotations (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references public.organizations (id) on delete cascade,
  workspace_id         uuid not null,
  number               text not null,
  customer_id          uuid not null,
  status               text not null default 'draft' check (status in (
                         'draft', 'sent', 'accepted', 'declined', 'converted')),
  issue_date           date not null default current_date,
  valid_until          date,
  currency_code        text not null check (currency_code ~ '^[A-Z]{3}$'),
  subtotal_minor       bigint not null default 0 check (subtotal_minor >= 0),
  discount_minor       bigint not null default 0 check (discount_minor >= 0),
  tax_minor            bigint not null default 0 check (tax_minor >= 0),
  total_minor          bigint not null default 0 check (total_minor >= 0),
  notes                text check (notes is null or char_length(notes) <= 2000),
  sent_at              timestamptz,
  converted_invoice_id uuid,
  created_by           uuid references auth.users (id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (id, organization_id),
  unique (organization_id, number),
  foreign key (workspace_id, organization_id)
    references public.workspaces (id, organization_id),
  foreign key (customer_id, organization_id)
    references public.customers (id, organization_id)
);

create index quotations_org_time_idx on public.quotations (organization_id, created_at desc);
create index quotations_customer_idx on public.quotations (customer_id);

create trigger quotations_touch before update on public.quotations
  for each row execute function app.touch_updated_at();

create table public.quotation_items (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null,
  quotation_id     uuid not null,
  product_id       uuid,
  description      text not null check (char_length(btrim(description)) between 1 and 300),
  quantity         numeric(14, 3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  tax_rate         numeric(5, 2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  line_total_minor bigint not null check (line_total_minor >= 0),
  position         integer not null default 0,
  foreign key (quotation_id, organization_id)
    references public.quotations (id, organization_id) on delete cascade,
  foreign key (product_id, organization_id)
    references public.products (id, organization_id)
);

create index quotation_items_quotation_idx on public.quotation_items (quotation_id);
create index quotation_items_product_idx on public.quotation_items (product_id);

-- ---------------------------------------------------------------------------
-- Invoices and payments
-- ---------------------------------------------------------------------------
create table public.invoices (
  id                uuid primary key default gen_random_uuid(),
  organization_id   uuid not null references public.organizations (id) on delete cascade,
  workspace_id      uuid not null,
  -- Assigned when the invoice is issued, so the numbered series has no gaps
  -- from abandoned drafts.
  number            text,
  customer_id       uuid not null,
  quotation_id      uuid,
  status            text not null default 'draft' check (status in (
                      'draft', 'issued', 'partially_paid', 'paid', 'void')),
  issue_date        date,
  due_date          date,
  currency_code     text not null check (currency_code ~ '^[A-Z]{3}$'),
  subtotal_minor    bigint not null default 0 check (subtotal_minor >= 0),
  discount_minor    bigint not null default 0 check (discount_minor >= 0),
  tax_minor         bigint not null default 0 check (tax_minor >= 0),
  total_minor       bigint not null default 0 check (total_minor >= 0),
  amount_paid_minor bigint not null default 0 check (amount_paid_minor >= 0),
  notes             text check (notes is null or char_length(notes) <= 2000),
  issued_at         timestamptz,
  voided_at         timestamptz,
  created_by        uuid references auth.users (id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (id, organization_id),
  unique (organization_id, number),
  constraint invoices_paid_within_total check (amount_paid_minor <= total_minor),
  constraint invoices_numbered_when_issued check (status = 'draft' or number is not null),
  foreign key (workspace_id, organization_id)
    references public.workspaces (id, organization_id),
  foreign key (customer_id, organization_id)
    references public.customers (id, organization_id),
  foreign key (quotation_id, organization_id)
    references public.quotations (id, organization_id)
);

create index invoices_org_time_idx on public.invoices (organization_id, created_at desc);
create index invoices_customer_idx on public.invoices (customer_id);
create index invoices_quotation_idx on public.invoices (quotation_id);
create index invoices_open_idx on public.invoices (organization_id, due_date)
  where status in ('issued', 'partially_paid');

create trigger invoices_touch before update on public.invoices
  for each row execute function app.touch_updated_at();

alter table public.quotations
  add constraint quotations_converted_invoice_fk
  foreign key (converted_invoice_id, organization_id)
  references public.invoices (id, organization_id);

create index quotations_converted_invoice_idx on public.quotations (converted_invoice_id);

create table public.invoice_items (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null,
  invoice_id       uuid not null,
  product_id       uuid,
  description      text not null check (char_length(btrim(description)) between 1 and 300),
  quantity         numeric(14, 3) not null check (quantity > 0),
  unit_price_minor bigint not null check (unit_price_minor >= 0),
  tax_rate         numeric(5, 2) not null default 0 check (tax_rate >= 0 and tax_rate <= 100),
  line_total_minor bigint not null check (line_total_minor >= 0),
  position         integer not null default 0,
  foreign key (invoice_id, organization_id)
    references public.invoices (id, organization_id) on delete cascade,
  foreign key (product_id, organization_id)
    references public.products (id, organization_id)
);

create index invoice_items_invoice_idx on public.invoice_items (invoice_id);
create index invoice_items_product_idx on public.invoice_items (product_id);

create table public.payments (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  invoice_id      uuid not null,
  amount_minor    bigint not null check (amount_minor > 0),
  method          text not null check (method in (
                    'cash', 'bank_transfer', 'card', 'mobile_money', 'other')),
  reference       text check (reference is null or char_length(reference) <= 120),
  paid_at         timestamptz not null default now(),
  received_by     uuid references auth.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  foreign key (invoice_id, organization_id)
    references public.invoices (id, organization_id) on delete cascade
);

create index payments_invoice_idx on public.payments (invoice_id);
create index payments_org_time_idx on public.payments (organization_id, paid_at desc);

create trigger invoices_audit after delete on public.invoices
  for each row execute function app.audit_row_change();
create trigger quotations_audit after delete on public.quotations
  for each row execute function app.audit_row_change();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.customers          enable row level security;
alter table public.products           enable row level security;
alter table public.stock_levels       enable row level security;
alter table public.stock_movements    enable row level security;
alter table public.document_sequences enable row level security;
alter table public.sales              enable row level security;
alter table public.sale_items         enable row level security;
alter table public.quotations         enable row level security;
alter table public.quotation_items    enable row level security;
alter table public.invoices           enable row level security;
alter table public.invoice_items      enable row level security;
alter table public.payments           enable row level security;

revoke all on
  public.customers, public.products, public.stock_levels, public.stock_movements,
  public.document_sequences, public.sales, public.sale_items, public.quotations,
  public.quotation_items, public.invoices, public.invoice_items, public.payments
from public, anon, authenticated;

grant all on
  public.customers, public.products, public.stock_levels, public.stock_movements,
  public.document_sequences, public.sales, public.sale_items, public.quotations,
  public.quotation_items, public.invoices, public.invoice_items, public.payments
to service_role;

-- Customers: direct CRUD under RLS.
-- Column allow-lists keep id / created_by / timestamps server-assigned.
grant select, delete on public.customers to authenticated;
grant insert (organization_id, kind, name, email, phone, address, tax_id, notes)
  on public.customers to authenticated;
grant update (kind, name, email, phone, address, tax_id, notes) on public.customers to authenticated;

create policy customers_select on public.customers
  for select to authenticated
  using (app.has_permission(organization_id, 'customers.read'));
create policy customers_insert on public.customers
  for insert to authenticated
  with check (app.has_permission(organization_id, 'customers.write'));
create policy customers_update on public.customers
  for update to authenticated
  using (app.has_permission(organization_id, 'customers.write'))
  with check (app.has_permission(organization_id, 'customers.write'));
create policy customers_delete on public.customers
  for delete to authenticated
  using (app.has_permission(organization_id, 'customers.delete'));

-- Catalogue: direct CRUD under RLS.
grant select, delete on public.products to authenticated;
grant insert (
  organization_id, kind, name, sku, description, unit, unit_price_minor,
  cost_price_minor, tax_rate, track_inventory, reorder_level, is_active
) on public.products to authenticated;
grant update (
  kind, name, sku, description, unit, unit_price_minor, cost_price_minor,
  tax_rate, track_inventory, reorder_level, is_active
) on public.products to authenticated;

create policy products_select on public.products
  for select to authenticated
  using (app.has_permission(organization_id, 'catalog.read'));
create policy products_insert on public.products
  for insert to authenticated
  with check (app.has_permission(organization_id, 'catalog.write'));
create policy products_update on public.products
  for update to authenticated
  using (app.has_permission(organization_id, 'catalog.write'))
  with check (app.has_permission(organization_id, 'catalog.write'));
create policy products_delete on public.products
  for delete to authenticated
  using (app.has_permission(organization_id, 'catalog.delete'));

-- Everything below is read-only for clients; writes go through RPCs.
grant select on
  public.stock_levels, public.stock_movements, public.sales, public.sale_items,
  public.quotations, public.quotation_items, public.invoices, public.invoice_items,
  public.payments
to authenticated;
-- document_sequences: no client access at all (no grant, no policy).

create policy stock_levels_select on public.stock_levels
  for select to authenticated
  using (app.has_permission(organization_id, 'inventory.read'));
create policy stock_movements_select on public.stock_movements
  for select to authenticated
  using (app.has_permission(organization_id, 'inventory.read'));

create policy sales_select on public.sales
  for select to authenticated
  using (app.has_permission(organization_id, 'sales.read'));
create policy sale_items_select on public.sale_items
  for select to authenticated
  using (app.has_permission(organization_id, 'sales.read'));

create policy quotations_select on public.quotations
  for select to authenticated
  using (app.has_permission(organization_id, 'quotations.read'));
create policy quotation_items_select on public.quotation_items
  for select to authenticated
  using (app.has_permission(organization_id, 'quotations.read'));

create policy invoices_select on public.invoices
  for select to authenticated
  using (app.has_permission(organization_id, 'invoices.read'));
create policy invoice_items_select on public.invoice_items
  for select to authenticated
  using (app.has_permission(organization_id, 'invoices.read'));
create policy payments_select on public.payments
  for select to authenticated
  using (app.has_permission(organization_id, 'invoices.read'));

revoke all on function app.apply_stock_movement() from public, anon, authenticated;
revoke all on function app.next_document_number(uuid, text) from public, anon, authenticated;
