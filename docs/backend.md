# Backend: data model, security model and migration plan

## Data model

| Group | Tables |
| --- | --- |
| Identity and tenancy | `profiles`, `organizations`, `workspaces` |
| Access control | `permissions`, `roles`, `role_permissions`, `memberships`, `invitations` |
| Platform | `audit_logs`, `organization_subscriptions`, `document_sequences` |
| Business | `customers`, `products`, `stock_levels`, `stock_movements`, `sales`, `sale_items`, `quotations`, `quotation_items`, `invoices`, `invoice_items`, `payments` |
| Files | `documents` (plus the `documents` storage bucket) |

- An **organization** is the tenant. Every business row carries
  `organization_id`.
- A **workspace** is a branch or location inside an organization. Stock,
  sales, quotations and invoices belong to a workspace. Customers and the
  catalogue are shared across the organization.
- A **membership** links a user to an organization with exactly one **role**.
  A role is a named set of **permissions** owned by the organization.
  Each new organization gets five built-in roles: Owner, Admin, Manager,
  Staff and Viewer. Custom roles can be added.
- Document numbers (`INV-000001`, …) come from per-organization sequences.
  A sale and a quotation are numbered when they are created; an invoice is
  numbered when it is issued, so discarded invoice drafts leave no gaps.

## Security model

1. **Row-level security on every table.** Policies call
   `app.has_permission(organization_id, '<key>')`, which is true only for an
   active member whose role holds the permission. A test asserts that no
   table in `public` lacks row-level security.
2. **Nothing for anonymous callers.** Default privileges are revoked;
   `authenticated` gets explicit grants only, down to the column where it
   matters (for example, `slug` and `created_by` of an organization cannot be
   updated).
3. **Authorization tables are read-only to clients.** Roles, memberships,
   invitations, subscriptions and the audit trail change only through
   functions.
4. **Functions check first.** Each function begins with
   `app.require_permission`, runs with a fixed empty `search_path`, and
   validates its input. A role cannot grant a permission its author does not
   hold, built-in roles cannot be edited, and an organization can never lose
   its last active owner.
5. **Tenants cannot be crossed by reference.** Child tables use composite
   foreign keys `(id, organization_id)`, and a trigger refuses to change a
   row's `organization_id`. A row cannot point at another tenant's data even
   if a policy were wrong.
6. **The database computes money and stock.** The client sends quantities
   and, optionally, prices; totals, tax, balances and stock movements are
   derived in the function. Stock cannot go negative. Only legal status
   transitions are accepted.
7. **Append-only audit trail.** Sensitive changes are recorded with actor,
   action and entity. Updates and deletes on the trail are refused for every
   role, including the service role. The only exceptions are the cascades
   from deleting a whole organization or an auth user.
8. **Files are private.** The bucket is not public, limits size and type,
   and its object policies authorize by the organization id in the first
   path segment. A document row may only describe a file inside its own
   organization's folder.

The permission keys, grouped by module, are listed in
[`…000100_platform_core.sql`](../supabase/migrations/20261112000100_platform_core.sql).

## Functions the app calls

| Area | Functions |
| --- | --- |
| Context and tenancy | `get_my_context`, `create_organization`, `leave_organization`, `set_default_workspace` |
| Team | `invite_member`, `revoke_invitation`, `accept_invitation`, `set_member_role`, `set_member_status`, `remove_member`, `save_role`, `delete_role` |
| Stock and sales | `adjust_stock`, `record_sale`, `void_sale` |
| Quotations | `save_quotation`, `set_quotation_status`, `delete_quotation`, `convert_quotation_to_invoice` |
| Invoices | `save_invoice`, `delete_invoice_draft`, `issue_invoice`, `record_invoice_payment`, `void_invoice` |
| Reporting | `dashboard_summary` |

## Migration plan from the previous system

The previous app served one company from one Supabase project through a
single edge function that used the service-role key
(see [legacy-assessment.md](legacy-assessment.md)). Its tables were created
outside version control, so their exact shape is not known from this
repository. The plan therefore starts with discovery and never modifies the
old project.

**Principle: new project, copy in, cut over.** The new schema is applied to a
new, empty Supabase project. The old project stays untouched and available
until the new one has been accepted.

| Step | Action | Done when |
| --- | --- | --- |
| 1. Inventory | Export the old project's schema (`supabase db dump --schema public`) and row counts per table. List storage buckets and object counts | Every old table is mapped to a new table, or explicitly marked "not carried over" |
| 2. Stand up | Create the new project; apply migrations; configure email templates and SMTP | `bash ci/check-db.sh` passes and a test account can sign up |
| 3. Seed the tenant | Create the company as one organization with its workspaces. Invite staff so they create their own accounts | Owner can sign in; roles assigned |
| 4. Map and load | Write a one-off import script (service role, run from a trusted machine, never shipped) that loads customers and products first, then opening stock through `stock_movements`, then historical sales and invoices | Row counts and sums of totals match the inventory per table |
| 5. Files | Copy stored files into `documents/<organization id>/<document id>/…` and create their rows | Object count matches; a sample opens in the app |
| 6. Rehearse | Run steps 4 and 5 against a scratch copy first; time them; fix mapping errors | A clean rehearsal with matching totals |
| 7. Cut over | Freeze writes in the old app, run the final import, verify, release the new builds | Users are on the new app |
| 8. Retire | Keep the old project read-only for an agreed period, then export a final backup, rotate its keys and pause it | Old keys no longer work |

Points that need a decision before step 4:

- **Accounts.** Passwords cannot be moved between projects by an application.
  Either users sign up again and accept an invitation (simplest, recommended
  for a small team), or auth users are exported and imported with their
  password hashes using Supabase's tooling.
- **Historical documents.** The old app produced several document types
  (delivery notes, waybills, payment vouchers and others) that have no
  equivalent table here. They can be carried over as PDF files in the
  document store, or left in the old project's final backup.
- **Numbering.** Set each `document_sequences` counter above the highest
  imported number so new documents continue the series.
- **Money.** Convert amounts to integer minor units during import and check
  sums before and after.
- **History is immutable.** Imported sales and issued invoices should be
  inserted as historical rows by the import script, not replayed through
  `record_sale`, so that importing them does not move today's stock.

Rollback at any point before step 8 is to keep using the old app: nothing in
the old project has been changed.
