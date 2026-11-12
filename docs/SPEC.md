# M-Tek Fire & Safety Ltd — Inventory & Business App: Functional Spec

**Status:** Agreed in discussion — pending final go-ahead before scaffolding.
**One codebase (this repo) → two products:** Android app (APK) and Windows desktop app (EXE). *(The web/PWA target was retired on 2026-08-30 by owner directive — the app is native-only.)*
**Owner: M-Tek Fire & Safety Ltd** (Kaduna, Nigeria · RC 1082534) · Currency: **₦ (NGN)**.

---

## 1. Platforms & Delivery

| Target | Artifact | Notes |
|---|---|---|
| Android (phone/tablet) | APK + AAB | Sales floor + field use |
| Windows (desktop) | exe (zipped) | Office/counter use |
| Web (PWA) | Static build served at **`https://mtekfiresafetyltd.github.io/m-tek_fire_safety_ltd.org/`** | The app IS the site root of the company Pages URL (marketing website remains under `/site/`). Installable to home screen, own manifest (name, icons, brand colors) + service worker; `base href=/m-tek_fire_safety_ltd.org/` |

One Flutter (Dart) codebase in `/app` produces all three. CI (see §11) rebuilds the
APK/EXE builds (web/PWA retired 2026-08-30) on every push to `main` — progress on the
codebase automatically updates everything.

## 2. Repository Layout

```
/                 existing website (unchanged)
/app/             Flutter app — all 9 screens, one codebase
/backend/
  supabase/       SQL schema, RLS policies, auth config, storage buckets, edge functions
  api/            Node service for MongoDB (MILS)
  contracts/      shared API contracts
/docs/            this spec, data model, decisions
/seed/            products_seed.txt (awaiting owner edits: cost, qty/balance, reorder, unit)
```

## 3. Screens (9)

1. **Insights** (home/dashboard) — Revenue cards (today/week/month), **Avg. Transaction Value**, **Revenue Breakdown** (by category, product, payment method); trend charts. **Admin only.**
2. **Transactions** — unified ledger: sale payments, invoice payments, refunds. Filter by date/type/method/status; tap → full detail.
3. **Customers** — CRUD; individual vs corporate; phone/email/address; purchase history; outstanding credit balance.
4. **Receipts** — auto-numbered `MTK-REC-0001`; generated on every payment received; preview, print, share (WhatsApp/email).
5. **Invoice** — `MTK-INV-0001`; bill-now-pay-later for corporates; statuses Draft → Sent → Partial → Paid (+ Overdue); payment posts a Transaction + Receipt. Can originate from a Sale or a MILS job.
6. **MILS** (Maintenance Information Log Sheet) — per-equipment service records: equipment type/serial/brand/capacity, client, site location, action (install/refill/inspection/repair), findings, parts used, technician, **next-due date** with overdue alerts, photos. Stored as flexible documents (Mongo). Job → optional Invoice.
6b. **Waybill** — mirrors the physical carbon-copy book (No: 0174 series): ref chips (MILS/Receipt/Invoice/LPO No), buyer name/phone/address, items (SNO/Products/Tech. Spec/Brand/Qty), logistics (originating from, destination, driver + phone + signature, vehicle brand/plate/colour, receiver + phone, approved by), Caution! fine print on transit insurance. No prices.
6c. **Delivery Note** — mirrors the pre-printed book (No: 19790088 series): invoice address (customer/institution/address/phone), shipping address (location/receiver/receiver's no/signature), details (date of order, proforma invoice ID, customer's ID, dispatch, delivery method, account no/name, banker), items (S/NO/Description/Ordered/Delivered/Outstanding), summary, check-before-signing note, Prepared/Approved/Client sign-off, motto line. No prices.
7. **Sales** (POS) — pick customer → add items from live stock → discount → payment method (cash/transfer/POS/credit) → complete. Auto: decrement stock, create Transaction + Receipt (or Invoice if credit).
8. **Stock** — products with qty on hand, cost/selling price, reorder levels, low-stock alerts; adjustments (restock/damage/correction) with full audit trail.
9. **Summary** — period reports (daily/weekly/monthly/custom): totals, profit estimate, top products, stock valuation, outstanding invoices; export/share. **Admin only.**

**Flow:** `Sale → Transaction → Receipt` · `Invoice → Payment → Transaction + Receipt` · `Stock feeds Sales` · `MILS job → Invoice`.

## 4. Data Model (core entities)

- **Product** — id (from seed, e.g. `F001`), name, category, unit, cost_price, selling_price, qty_on_hand, reorder_level, image_url, active
- **StockAdjustment** — product, ±qty, reason, reference, note, user, timestamp
- **Customer** — name, type, phone, email, address, credit_balance, notes
- **Sale** — customer, date, items[], subtotal, discount, VAT (if enabled), total, method, status (paid/credit/partial)
- **Invoice** — customer, issue/due dates, items[], subtotal, discount, VAT, total, amount_paid, status
- **Receipt** — number, date, amount, method, source (sale/invoice/MILS job), issued_by
- **Transaction** — date, type (sale_payment/invoice_payment/refund), amount, method, linked doc
- **MaintenanceLog (MILS)** — equipment, client, location, action, findings, parts, technician, dates, next_due, photos
- **StaffUser** — Supabase auth identity, role, name, phone
- **Settings** — VAT on/off + rate (configurable per doc), business info, numbering counters

## 5. Backend

| Concern | Service |
|---|---|
| Everything (products, stock, customers, sales, invoices, receipts, transactions, MILS) | **MongoDB Atlas**, 7 section databases, via the `data-api` Supabase Edge Function (`supabase/functions/data-api/index.ts`) — this IS the production backend |
| Auth & roles | **Supabase Auth** (email/password), role claims resolved server-side per request |
| Files (PDFs, product/MILS photos) | **Supabase Storage** |
| Offline resilience | Local Drift (SQLite) cache + sync queue — app works offline, syncs when online |

Extensible: "Supabase + Mongo and maybe more as needed."

## 6. Roles & Authentication

Levels of authority: **CEO > Admin > Sales**.

| Capability | CEO | Admin | Sales |
|---|---|---|---|
| Sell, create customers, invoices, receipts | ✅ | ✅ | ✅ |
| View stock quantities | ✅ | ✅ | ✅ |
| Stock cost prices, adjustments (stock EDITS) | ✅ | ✅ | — |
| Insights & Summary (revenue/profit) | ✅ | ✅ | — |
| MILS records | ✅ | ✅ | — |
| Settings: VAT toggle, serial reseed, seed import, reset (**CEO only**) | ✅ | — | — |
| Approver of last resort on documents ("Approved by") | ✅ | — | — |

**CEO account is hardcoded, never registered:** locked to `mtekfiresafetyltd@gmail.com`. The identity ships with the backend (preview server, Flutter AuthStore, and in Phase C the Supabase seed): signing in with that email always resolves role `ceo` and shows CEO at the top, same as Admin/Sales badges. Registration with that email is rejected ("pre-provisioned — sign in directly"), and no signup path can mint a CEO. (Owner directive, 2026-08-30.)

(One shared Sales login is acceptable at launch; technician self-service view is a future role.)

### 6.1 Authenticated document attribution

Documents and protected transactions are attributed to the currently signed-in staff account. Role permissions determine which actions a user may perform. Optional drawn signature images may be stamped on generated documents as a visual mark, but no secondary signing credential is required.

## 7. Documents, Printing & Sharing

- Branded PDFs (M-Tek logo, ₦ formatting, sequential numbering).
- **Print** on all three platforms (Android print service / Windows dialog / browser print).
- **Share: WhatsApp + email only** (share sheet, `wa.me`, `mailto:`).
- VAT: configurable toggle (off by default; 7.5% NG rate when on; per-document override).

## 8. Seed Data Workflow

1. `seed/products_seed.txt` (358 products, tab-separated, Excel-ready) → owner fills **cost price, qty/opening balance, reorder level, unit**, sets the 38 "price on request" items.
2. Owner sends file back → importer loads it into Stock (local + Supabase) at first-run/migration.

## 9. Build Milestones

1. **M1 — Skeleton:** Flutter app, navigation shell, all 9 screens as themed placeholders, PWA manifest; runs in preview.
2. **M2 — Local data:** Drift schema + repositories; TXT importer; every screen fully functional offline with sample/seed data.
3. **M3 — Backend live:** Supabase schema/auth/RLS/storage; Mongo API + contracts; app talks to real backend with sync queue; admin/sales roles.
4. **M4 — Documents:** PDF generation, printing, WhatsApp/email sharing.
5. **M5 — Polish & ship:** charts/alerts/exports finalized; Android APK, Windows build, PWA live at the company Pages root.

## 10. Design

Matches the website's brand system (Sora/Poppins, brand color tokens from `styles.css`, M-Tek logo from assets). Material 3, mobile-first layouts that expand gracefully to desktop width.

## 11. CI/CD — "progress updates everything"

Workflow (sourced at `docs/ci/build-app.yml`; activate by copying to
`.github/workflows/build-app.yml` on the **company repo** `mtekfiresafetyltd/m-tek_fire_safety_ltd.org`,
with Settings → Pages → Source = **GitHub Actions**):

| Push to `main` (touches `app/**`) | Manual dispatch |
|---|---|
| Build **PWA** (`--base-href=/m-tek_fire_safety_ltd.org/`) → artifact | All of the left column, **plus** deploy to Pages (**app at the site root**, website under `/site/`) |
| Build **APK** + **AAB** → artifacts | Optionally cut a GitHub Release with APK/AAB/EXE attached |
| Build **Windows EXE** (zipped) → artifact | |

Live URLs after activation: **app `https://mtekfiresafetyltd.github.io/m-tek_fire_safety_ltd.org/`**
(the bare company URL opens the app), website `…/m-tek_fire_safety_ltd.org/site/`.

## 12. Document Generation Module (owner blueprint, adopted)

Owner's 5-part technical blueprint (Aug 2026), reconciled with this spec. Scope: dynamically map
transactional entries to M-Tek's **physical corporate forms** — MILS, Payment Receipt, Sales
Invoice — and export unalterable PDFs for WhatsApp/email dispatch.

**✅ Photos of all three physical forms received & transcribed — see
[`docs/forms/FORM_LAYOUTS.md`](forms/FORM_LAYOUTS.md) (authoritative layout source).**
Owner confirmations (2026-08-29): MILS caution wording ✅, "PRO-FORMER" spelling kept ✅.
Owner decisions: **faint watermark pattern on all documents AND the app UI**; **full dual-office
header on every document** (receipt's compact block retired).
**Phase A is BUILT** (2026-08-29): `app/lib/documents/` (branding, forms spec, doc models +
amount-in-words, serial service seeded to books 2131/925/4335, watermark + corporate header +
QR verification, three PDF painters, share pipeline with conditional io/web impls and fallback),
`GeneratorScreen` (type switcher, live Qty×Rate/VAT/advance/balance, validation, signature gate),
`Documents` destination (10th screen), DejaVu fonts bundled for ₦/✓ glyphs, watermark in app shell
+ preview. Preview parity: full generator mock with paper-style watermarked previews; smoke tests
cover gated generation + serial continuity.
Corrections learned from the physical forms: MILS has **12 component rows (incl. `Seal`)**;
weight classes fixed at **1, 2, 3, 5, 6, 9, 12, 25, 50, 75 kg**; invoice amount column is
**dual ₦/# + K (kobo)**; invoice doc-type cluster includes MILS No / Receipt No cross-refs and
the form's own spelling **"PRO-FORMER"** (kept as printed); receipt methods are a 2×2 grid
**Cash / Cheque / Transfer / POS**; serials are **pre-printed** (Receipt 2131, MILS 925,
Invoice 4335) → the app's serial service is **Admin-seedable** to continue book numbering
without collisions; MILS footer has four assent blocks (Prepared / Approved / Customer's /
Collector's) + Caution fine print (transcribed, owner to confirm exact wording).

### 12.1 Adopted from blueprint

- **Three form-accurate documents**, mirroring the physical carbon-copy books:
  - **MILS**: MILS No, LPO No, entry/collection/next-service dates; **weight grid 1kg→75kg**;
    **component checklist** (Nipple, Horn, Hose, Manometre, Valve, Strap, Label, Lever, Powder,
    Pull Pin, Cartridge); footer with Prepared by / Approved by / Customer assent + statutory
    maintenance conditions.
  - **Payment Receipt**: title, **IRN** field, serial no, date; customer name/address/phone;
    **"The Sum of" (amount in words)**; "Being Payment for"; method checkboxes **Cash, Cheque,
    Transfer, POS**; footer "For: M-Tek Fire & Safety Ltd" / "For: Customer's Client" + non-returnable disclaimer.
  - **Sales Invoice**: doc-type checkboxes (**Way Bill, Proforma, Service Invoice, Sales Invoice**),
    serial no, phone/address/customer, **MILS No / Receipt No / LPO No** cross-references, date;
    ledger table S/NO · Description · Qty · Rate · Amount (₦/K); summary with **7.5% VAT, Grand
    Total, Advance Payment, Balance Payment**, amount in words, three sign-off blocks.
- **Generator UI**: document-type switcher (segmented control) → per-type form state (context kept
  per type); dynamic item rows with live Qty×Rate, VAT, Grand/Advance/Balance calculations;
  MILS interactive weight grid + component toggles.
- **Pipeline**: validate mandatory fields → `pdf` byte stream → cache as `mtek_<type>_[timestamp].pdf`
  (`path_provider`) → `share_plus` system sheet (WhatsApp/email) with pre-formatted message body →
  fallback: save to Downloads + toast. `url_launcher` deep-links (`wa.me`, `mailto:`) for known customers.
- **History & serials**: local cache of every generated doc (view/reprint/re-share offline) +
  auto-increment serial service per document type (no duplicates).
- **PDF engine**: `pw.MultiPage` for long lists; cell widths/borders tuned to the physical books;
  embedded logo (assets/img/logo-256.png) + statutory header (RC 1082534; HO: YY 12 Kazaure Road,
  By Lagos Street Roundabout, Kaduna — 0803 349 8452; Branch: Plot 45, Sir P.I. Yakowa Way,
  By Milton School, Kamazou — 0817 057 7595; mtekfiresafetyltd@gmail.com).
- **Later phases**: Supabase backup of doc ledger + customer directory auto-complete; audit log;
  analytics (docs/day, payments collected, **extinguishers serviced by weight class** → feeds
  Insights); QA (calc unit tests: Qty×Rate, 7.5% VAT, amount-in-words; PDF snapshot tests);
  template versioning (disclaimers/addresses/VAT rate as remote-config-style settings).

### 12.2 Integrations with existing spec (decisions)

| Blueprint item | Reconciliation |
|---|---|
| Digital signing | Authenticated account and role checks apply; stamp `✓ Digitally signed by <name> + signature image` on every page footer |
| Ad-hoc documents | **Admin only** (decided Aug 2026). Sales staff issue documents only from recorded transactions (sales, invoice payments, MILS jobs); Admin can additionally write up freehand docs, as with the paper books |
| Local DB "isar or sqflite" | **Drift (SQLite)** — already chosen (§5); type-safe, reactive, **web/PWA-compatible** (Isar's web support is weak) — one DB serves history + inventory + sync queue |
| Serial formats | Continue `MTK-REC-####` / `MTK-INV-####` / `MTK-MILS-####`; IRN + LPO are additional stored fields |
| Doc ↔ business data | Documents generated **from** app records (sale, invoice payment, MILS log) pre-fill automatically; **ad-hoc documents** also allowed (see open questions) |
| Payment methods | Add `cheque` to `PaymentMethod` (was cash/transfer/pos/credit) |
| Invoice model | Add: `docVariant` (waybill/proforma/service/sales), `lpoNo`, `irn`, `advancePayment`, `balance` computed, `amountInWords`, VAT lines per §7 |
| MILS model | Add: weight-class counts map (kg→qty), component states map (11 parts), `lpoNo`, collection date |
| Analytics | MILS weight-class volumes feed Insights as "extinguishers serviced" metric |
| Unalterability | PDFs get document-hash + QR verification code (M4+); audit trail gives tamper evidence |

### 12.3 Execution order

1. **Phase A (next)** — Generator UI + PDF painters + signature gate + share/dispatch (Parts 1–2 + §6.1).
   **Gated on owner's photos of the 3 physical forms** (decided Aug 2026) — build once, zero rework.
2. **Phase B** — Drift history ledger, serial service, validation & fallbacks (Part 3) — same Drift layer as TXT import.
3. **Phase C** — Supabase doc-ledger sync, customer auto-complete, audit log (Part 4 = §5 M3).
4. **Phase D** — Analytics, QA suite, template versioning, archival (Part 5).


