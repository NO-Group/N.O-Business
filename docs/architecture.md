# Architecture

## Overview

```
Flutter app (Android, Windows)
   │  supabase_flutter: Auth, PostgREST, Storage, over HTTPS with the public key
   ▼
Supabase project
   ├─ Auth            accounts, sessions, email codes
   ├─ PostgreSQL      tables + row-level security + functions (all business rules)
   └─ Storage         private "documents" bucket, authorized by SQL policies
```

There is no application server. The client talks to the database through
Supabase's Data API, and the database decides what each signed-in user may
see and do. That choice has one consequence that shapes everything else:
**the client is not trusted.** Hiding a button is a courtesy to the user; the
rule that matters is the policy or function in the database.

- Reads are plain table queries, filtered by row-level security.
- Writes that are a single-row edit with no side effects (a customer, a
  product, organization settings) are table writes, also under row-level
  security and column-level grants.
- Writes with rules or side effects (recording a sale, issuing an invoice,
  inviting a member, changing a role) go through SQL functions that check the
  caller's permission, validate input, compute money and stock, and write an
  audit record, in one transaction.

## Repository layout

```
app/                 Flutter client
  lib/
    main.dart, bootstrap.dart      start-up: error hooks, config, storage, Supabase
    app/                           root widget, router, access gate, navigation shell
    core/                          shared code with no feature knowledge
      config/  errors/  logging/  storage/  supabase/  utils/
      commerce/                    line items and totals shared by sales and billing
      pdf/                         quotation, invoice and receipt rendering
      design_system/               tokens, theme, components
    features/<name>/
      domain/                      plain data classes
      data/                        repository: the only code that calls Supabase
      application/                 Riverpod providers
      presentation/                screens and sheets
  test/
supabase/            migrations, config, SQL tests
ci/                  check and build scripts
brand/               logo and icon sources
docs/
```

Features: `auth`, `tenancy` (organizations, workspaces, permissions),
`dashboard`, `customers`, `catalog`, `sales`, `billing` (quotations, invoices,
payments), `documents`, `team`, `settings`.

## Layers and their rules

| Layer | May depend on | Rule |
| --- | --- | --- |
| `domain` | `core/utils` | No Flutter, no Supabase. Parsing is defensive: a missing or oddly typed field becomes a default, never a crash |
| `data` | `domain`, `core` | Every call is wrapped in `guard`, which turns any exception into an `AppFailure` and logs the technical cause once |
| `application` | `data`, `domain` | Providers expose `AsyncValue`s keyed by the active organization, so switching organization refetches everything |
| `presentation` | all of the above | Renders loading, empty, error and no-access states; shows only `AppFailure.message` to users |

State is managed with Riverpod. Navigation uses go_router with a single
redirect function.

## Start-up and access gate

`bootstrap()` installs error handlers, reads the build-time configuration and
initializes Supabase with a session store backed by the operating system's
credential storage. If the configuration is missing or unsafe, the app shows
a configuration screen instead.

One provider, `appGateProvider`, reduces "who is this user" to five states,
and `resolveRedirect` maps each state to where the user may be:

| Gate | Meaning | Goes to |
| --- | --- | --- |
| `loading` | Session or memberships still resolving | Loading screen |
| `signedOut` | No session | Sign-in (auth pages allowed) |
| `failed` | Signed in, memberships could not be loaded | "Unavailable" with retry |
| `needsOrganization` | Signed in, member of nothing | Onboarding: create an organization or accept an invitation |
| `ready` | Has at least one organization | The app |

`resolveRedirect` is a pure function and is unit-tested.

## Tenancy in the client

After sign-in the app calls `get_my_context`, which returns the profile,
every membership with its role and permission set, and pending invitations.
The active organization and workspace are remembered per device. Every
repository call takes the organization id explicitly, and the permission set
drives which destinations and actions are shown.

## Errors

`AppFailure.from` is the only place that interprets backend errors. Messages
raised on purpose by our SQL functions are shown as written. Everything else
(constraint names, permission internals, network exceptions) is replaced by a
neutral sentence, and the detail is logged. Logs are single-line JSON with
credential-like fields redacted.

## Money

Amounts are integers in the currency's minor unit, in the database and in
the client. Totals are always computed by the database; the client's preview
uses the same rule (tax is exclusive and charged on the discounted amount)
and is tested against fixed examples.

## PDFs

`core/pdf` renders quotations, invoices and receipts with the `pdf` package
from a plain data object, so it has no dependency on the database or on
Flutter widgets and can be tested headlessly. Printing and sharing use the
`printing` package.

## Build and release

`ci/` holds one script per task; the GitHub workflow calls them and adds
secrets and artifact upload. The Flutter version is pinned in
`ci/flutter-version` and `pubspec.lock` is committed, so builds are
repeatable. Backend settings are passed with `--dart-define`.

## Decisions and their trade-offs

| Decision | Why | Cost |
| --- | --- | --- |
| No application server; rules in SQL | One place to enforce and test authorization; nothing to host | Business logic is PL/pgSQL; integrations that need secrets (payments, email) will need edge functions later |
| Online only | Offline sync with multi-user stock and numbering is hard to get right; the previous app's local fallbacks were a source of risk | The app is unusable without a connection |
| Email codes instead of links | Works the same on Android and Windows without registering URL handlers | Requires editing the project's email templates |
| Lists capped at 200 rows with search | Simple and predictable | Not enough for large data sets; paging is future work |
| Hand-written models, no code generation | No build step, readable diffs | More boilerplate per model |
