# Assessment of the previous codebase

This records what the repository contained before the rebuild (commit
`22be766`), what was wrong with it as a foundation for a multi-tenant
product, and what was kept. The old files remain readable in git history,
for example `git show 22be766:app/lib/data/store.dart`.

## What it was

A single-company office app ("MFSL Office") built for one customer, plus
that company's marketing website, in one repository.

| Part | Contents |
| --- | --- |
| Repository root | A static marketing and shop website (HTML, CSS, JavaScript, sitemap) |
| `app/` | Flutter app for Android and Windows: about 64 Dart files, 24 screens |
| `supabase/functions/data-api` | One edge function of roughly 2,300 lines serving every API route |
| `supabase/migrations` | A single migration, which removed a trigger |
| `backend/`, `tools/` | A verification script and assorted audit and test helpers |
| `docs/` | A specification, form layouts, signing and session notes |

The app covered sales, stock, customers, staff, several printable business
forms (receipts, invoices, waybills, delivery notes, payment vouchers, stock
receipts, letterheads, a "MILS" form), simple office documents,
a gallery, insights, notifications, biometric unlock and in-app updates.

## Why it could not be extended into N.O Business

| Problem | Evidence | Consequence |
| --- | --- | --- |
| Single tenant | Company name, branding and one privileged user id are part of the code and configuration | No way to host a second organization without forking |
| Authorization in application code | Every request went through one function that used the service-role key and decided access itself; the platform's JWT verification was disabled for it | One bug exposes everything; nothing in the database stops it |
| Schema not in version control | One migration file; the tables themselves were created outside the repository | The data model could not be reviewed, tested or reproduced |
| Backend baked into the client | Production URL and public key were compiled-in defaults | Every build pointed at production; the key is in git history |
| Offline fallbacks for security decisions | Sign-in could succeed against a locally stored password hash | Access on a device could outlive the account being disabled on the server |
| One very large state object | `store.dart` was about 2,300 lines holding all data, sync and business rules | Hard to test or change one feature without touching the rest |
| Conditional web/desktop duplicates | Parallel `_io` and `_web` implementations for storage, HTTP and sharing | Extra surface for a target that was not shipped |
| Unrelated code in one repository | The website shared a root with the app | Deployments and history were entangled |
| Tests | Four test files (update check, PDF build, preferences, session blob) | Nothing covered access control or money |

None of these is a criticism of what the app did for its one customer. They
are reasons a rewrite on a new foundation was cheaper and safer than a
conversion.

## What was kept

| Kept | Where it is now |
| --- | --- |
| The N.O Business logo | [`brand/`](../brand), [`app/assets/brand/`](../app/assets/brand) |
| DejaVu Sans, for PDFs with currency symbols | [`app/assets/fonts/`](../app/assets/fonts) |
| Android and Windows runner projects, renamed and re-identified | `app/android`, `app/windows` |
| The idea of one script per build, called by CI | [`ci/`](../ci), rewritten |
| The approach of rendering business PDFs on the device | [`app/lib/core/pdf/`](../app/lib/core/pdf), rewritten |

## What was removed and not replaced

- The marketing website. It belongs in its own repository.
- The edge function and the `backend/` and `tools/` helpers.
- Company-specific forms: waybills, delivery notes, payment vouchers, stock
  receipts, letterheads and the MILS form.
- Office documents, sheets and slides, and the gallery.
- Offline mode and sync.
- Notifications, biometric unlock, home-screen widget bridge and in-app
  updates.

Any of these can return as a feature of the new app. Each would be built on
the multi-tenant model and its permission system rather than ported.

## Data

The previous project's data was not touched. How to move it is described in
the migration plan in [backend.md](backend.md).
