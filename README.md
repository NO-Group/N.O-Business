# N.O Business

A multi-tenant business management app for Android and Windows by N.O Group.

An organization signs up, creates one or more workspaces (branches or
locations), invites its team with role-based permissions, and runs its
day-to-day commerce: customers, a product and service catalogue with stock,
counter sales, quotations, invoices with payments, printable PDFs, a private
document store and a dashboard.

| Part | Where | What |
| --- | --- | --- |
| App | [`app/`](app) | Flutter client (Android, Windows) |
| Backend | [`supabase/`](supabase) | PostgreSQL schema, row-level security, RPC functions, storage policies and their test suite |
| Build and checks | [`ci/`](ci), [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | One script per check or build; the workflow only wires them together |
| Brand | [`brand/`](brand) | Logo and app icon sources |
| Documentation | [`docs/`](docs) | Architecture, design system, backend plan, security assessment, status |

## Status

Read [`docs/status.md`](docs/status.md) before relying on anything. In short:
the code is analysed, unit- and widget-tested and built in CI, and the
database is tested against PostgreSQL, but **the app has not yet been run
against a live Supabase project**. That first end-to-end run is the next
step, and it will find things the automated checks cannot.

## Run it

You need the Flutter version pinned in [`ci/flutter-version`](ci/flutter-version)
and a Supabase project.

1. Apply the backend, following [`supabase/README.md`](supabase/README.md).
2. Start the app with your project's URL and its **public** key:

   ```sh
   cd app
   flutter pub get
   flutter run \
     --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<publishable or anon key>
   ```

Nothing about the backend is stored in the source tree. Started without those
two values, the app opens on a screen that says it has not been configured.
It refuses to start with a service-role or secret key, because anything
compiled into a client can be extracted from it.

## Checks

The same commands run locally and in CI.

| Command | What it does |
| --- | --- |
| `bash ci/check-db.sh` | Applies every migration to a throwaway PostgreSQL and runs the SQL suite (tenant isolation, roles, business rules, documents, audit). Needs Python 3.10 to 3.12. |
| `bash ci/check-app.sh` | `dart format` check, `flutter analyze`, `flutter test`. Pass `format`, `analyze` or `test` to run one. |
| `bash ci/apply-format.sh` | Rewrites `app/lib` and `app/test` with `dart format`. |
| `bash ci/build-android.sh` | Release APK into `dist/`. |
| `pwsh ci/build-windows.ps1` | Portable folder (zip) and MSIX installer into `dist/`. |

`flutter analyze` is strict: warnings and lints fail the check.

## Releases

Builds read their configuration from environment variables, which CI takes
from repository secrets. None of them is ever committed.

| Variable | Used by | Purpose |
| --- | --- | --- |
| `NOB_SUPABASE_URL` | both | Project URL |
| `NOB_SUPABASE_ANON_KEY` | both | Public client key |
| `NOB_ANDROID_KEYSTORE_BASE64` | Android | PKCS#12 keystore, base64-encoded |
| `NOB_ANDROID_KEY_ALIAS` | Android | Key alias, defaults to `no-business` |
| `NOB_WINDOWS_PFX_BASE64` | Windows | Code-signing certificate, base64-encoded |
| `NOB_SIGNING_PASSWORD` | both | Password of the keystore and of the certificate |

Without the signing values the builds still succeed, signed with a debug key
(Android) or a throw-away test certificate (Windows). Such builds are for
testing only and must not be distributed.

Application ID `com.nogroup.business` · Windows executable `no_business.exe`.

## Documentation

- [Status and what was verified](docs/status.md)
- [Architecture](docs/architecture.md)
- [Design system](docs/design-system.md)
- [Backend: schema, security model and migration plan](docs/backend.md)
- [Security assessment](docs/security.md)
- [Assessment of the previous codebase](docs/legacy-assessment.md)
