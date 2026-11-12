# Status: what exists and what was verified

This page separates what has been checked by a machine from what has only
been written. It is meant to be read before a release decision.

## Verified automatically

These run in GitHub Actions on every push
([`ci.yml`](../.github/workflows/ci.yml)).

| Check | What it establishes |
| --- | --- |
| Database suite (334 assertions) | The migrations apply cleanly to an empty PostgreSQL 16. Tenant isolation, permission checks, business rules, document authorization and the audit trail behave as specified. |
| `dart format` | The source is formatted. |
| `flutter analyze` (strict) | The app compiles with no errors, warnings or lints. |
| `flutter test` | Unit tests for money, validation, error mapping, routing rules, navigation, totals and data models; widget tests for shared components and the dashboard chart; PDF rendering of documents, including multi-page output. |
| Android build | A release APK is produced. |
| Windows build | A release folder and an MSIX installer are produced. |

Two extra one-off checks were made while writing the code and are not part of
CI:

- Every function call in the app was compared with the function signatures
  in the migrations (25 calls, parameter names included), and every column
  the app selects, filters or writes was compared with the table
  definitions. Both matched.
- Mutation testing of the database suite. See [security.md](security.md).

## Not verified

**The app has never been run against a live Supabase project, and no build
has been opened on a device.** No Supabase project or device was available
while this version was written. Everything below follows from that.

- No screen has been seen running. Layout problems, overflow on small
  phones, awkward focus order and visual defects are likely and can only be
  found by using the app.
- Sign-up, email confirmation by code, password reset and sign-in depend on
  the project's email templates and SMTP settings
  (see [`supabase/README.md`](../supabase/README.md)) and have not been
  exercised.
- The database suite runs on plain PostgreSQL with a stand-in for Supabase's
  `auth` and `storage` schemas. The real Storage service adds behaviour of
  its own, so document upload, download and deletion in particular need a
  live test.
- Printing and sharing PDFs go through the operating system and have only
  been tested up to "the PDF bytes are valid".
- File picking and saving use the platform dialogs and are untested.
- Session storage in the Android Keystore and Windows credential store is
  untested on real hardware.
- Release signing has not been exercised: no signing secrets were available,
  so CI builds are signed with a debug key (Android) and a test certificate
  (Windows).
- The repository has no backend secrets set either, so the APK and Windows
  packages that CI currently produces open on the "not configured" screen.
  They prove the app compiles and packages, nothing more. Add
  `NOB_SUPABASE_URL` and `NOB_SUPABASE_ANON_KEY` as repository secrets to get
  usable builds.

## First live run: suggested order

1. Create an empty Supabase project and apply the backend.
2. Build with the project URL and public key and sign up. Confirm the code
   email arrives and works.
3. Create an organization, then a second user, invite them and accept.
4. Add a customer and a product with stock; record a sale; check stock fell.
5. Create a quotation, convert it, issue the invoice, record a part payment,
   print the PDF.
6. Upload, open and delete a document.
7. Sign in as a Viewer and confirm that write actions are absent and that
   the server refuses them anyway.
8. Repeat the main paths on a small Android phone and at a narrow Windows
   window width.

## Capabilities

"Built" means the code exists and passes the automated checks above. Nothing
is marked as proven in use.

| Area | State | Notes |
| --- | --- | --- |
| Accounts: sign up, confirm by code, sign in, reset password, change password | Built | Needs the email templates described in the backend README |
| Organizations and workspaces | Built | Several organizations per user, switcher in the shell |
| Team: invitations, roles, custom roles, suspend, remove | Built | Invitations are shown in the app to the invited address; **no invitation email is sent** |
| Activity log | Built | Read-only view of the audit trail |
| Customers | Built | Search, detail page with history |
| Catalogue and stock | Built | Products and services, stock per workspace, adjustments with reasons, low-stock filter |
| Sales | Built | Counter sale with stock deduction, void, receipt PDF |
| Quotations | Built | Draft, send, accept or decline, convert to invoice, PDF |
| Invoices and payments | Built | Draft, issue, part and full payment, void, overdue filter, PDF |
| Documents | Built | Private per-organization file store, 20 MB, PDF, images, text, CSV, DOCX, XLSX |
| Dashboard | Built | Figures computed by the database; period and workspace filter |
| Settings | Built | Profile, password, organization profile, workspaces |
| Offline use | Not built | The app needs a connection. Failed loads show a retry state |
| Subscriptions and plans | Schema only | A subscription table and seat limit exist; nothing writes to them and there is no payment provider |
| Document understanding (OCR, extraction) | Not built | Deliberately left for a later migration |
| Notifications, biometrics, in-app updates | Not built | Present in the previous app, not carried over |
| iOS, macOS, Linux, web | Not built | Only Android and Windows are configured |
| Localization | Not built | English only; amounts and dates use the organization's currency |
| Accessibility | Partly | Semantic labels on custom components and tooltips on icon buttons; no screen-reader pass has been done |

## Known limitations in the current code

- Lists load the most recent 200 records and rely on search to narrow them;
  there is no paging.
- If saving a document record fails after its file was uploaded, the app
  removes the file again. That clean-up needs the `documents.delete`
  permission, so for a role that can upload but not delete, an orphaned file
  can remain in storage. It is not reachable by anyone without access to the
  organization's documents.
- The running total in the sale, quotation and invoice editors is a preview.
  The database recomputes every figure when the record is saved and its
  result is what is stored and printed.
- A quotation's or invoice's currency is fixed when it is created. Changing
  the organization's currency afterwards does not convert existing records.
