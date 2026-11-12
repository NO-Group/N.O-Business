# Session persistence — "users are signed out after some time"

**Fixed:** 2026-11-04 · **Affected build:** Android APK · **Scope:** `app/lib` only
(no Supabase/Edge Function change, nothing to redeploy).

## Reported symptom

A user signs in, uses the app, leaves it for a while, and on reopening is back
at the **Sign in** screen — without ever tapping **Sign out**.

## Root cause (cold-start restore, not a timer and not the server)

Nothing in the running app can clear the signed-in identity: `signOut()` is
called **only** from the two explicit Sign out buttons, and HTTP 401s have
always been deliberately non-fatal. The screen appears on the *next process
start*, when `AuthStore.current` starts as `null` and `restoreSession()` fails
to rehydrate it. Four defects made that possible:

| # | Defect (before) | Effect |
|---|---|---|
| 1 | The refresh token was written **only** to the OS credential vault (`auth_session`). The local `mtek_session.json` held `{email,name,role}` with **no token**. | If Android's Keystore key is invalidated (lockscreen change, backup/restore, OS upgrade, read before first unlock), the vault returns null → the legacy fallback has no token → `restoreSession()` **returned early without restoring any identity** → login screen. |
| 2 | `BiometricService.session()` / `saveSession()` were unguarded. | A `PlatformException` from the vault aborted the entire restore (or the entire sign-in/refresh) before the local fallback was even read. |
| 3 | `AppStore.init()` flipped `isLoaded = true` **before** `restoreSession()` ran. | `main.dart` rendered `LoginScreen` while restore was still in flight — a login-screen flash on every launch, permanent if restore failed. |
| 4 | A corrupt JSON blob, or a single 401 from `/api/auth/refresh`, ended the restore with no identity and no recovery path. | Consumed/rotated refresh token → cloud sync silently dead forever; no way back except a manual sign-in. |

Two secondary races were also fixed: `_dedupeUsers()` could null `current`
while rebuilding the account directory, and `signOut()` cleared storage with
`unawaited` while leaving `api.refreshAccessToken` attached (a late 401 could
bring a signed-out user back).

## The fix

1. **Dual-write, dual-read.** `AuthStore._persistSession()` writes the full
   session blob (`refresh_token`, `email`, `name`, `role`, `saved_at`) to the
   OS vault **and** the app-private `mtek_session.json`. `_rawSessionBlobs()`
   reads both independently; one corrupt/unavailable copy can never hide the
   other. `_repairSessionCopies()` migrates old vault-only / identity-only
   builds in both directions at boot.
2. **Every vault access is exception-safe** (`BiometricService` + AuthStore
   helpers). Storage failures are logged and ignored, never propagated.
3. **Identity first, network last.** `_performRestoreSession()` rehydrates the
   cached identity, repairs the copies, and resolves the boot gate **before**
   making any network call. A slow/offline/failing server can no longer decide
   that the login screen is the right destination.
4. **Boot gate.** `main.dart` keeps the splash screen until
   `AuthStore.bootReady` is true; `AppStore.bootstrap()` is idempotent, so a
   theme rebuild cannot launch a second restore and consume the rotating token
   twice. `finally` always resolves the gate (no stuck splash).
5. **Never an automatic sign-out.** A 401 from the refresh endpoint, a missing
   token, a network error, 5xx/429 and a corrupt blob all leave `current`
   untouched. They only flip `sessionNeedsReconnect`, which shows a
   **non-blocking** banner in the shell: *Retry* (force a refresh) and
   *Sign in again* (an in-place `reconnect_dialog.dart` that re-authenticates
   without ever calling `signOut()` or navigating to the login screen).
6. **Refresh robustness.** Single-flight with a 45 s failure cooldown (so the
   8-second data poll cannot storm an offline device), both distinct persisted
   tokens tried in turn, and proactive refresh when the bearer token is
   missing — not only when it is about to expire. Session timer reduced from
   30 minutes to 5 minutes.
7. **Explicit sign-out stays authoritative.** A generation counter invalidates
   any in-flight refresh, the refresh callback is detached, and a serial guard
   stops a late storage clear from wiping a fresh sign-in.

The CEO email lock, role reconciliation, offline data cache and all business
screens are unchanged.

## Security note

The refresh token now also lives in the app-private `mtek_session.json`
(Android app sandbox / Windows user profile), in addition to the encrypted OS
credential vault. This is deliberate: the owner's requirement is that **no
background condition may ever sign a user out**, which is impossible if the
token has a single point of failure. Older builds already stored the token in
that file before it was moved into the vault. If you later prefer vault-only
storage, remove `_writeLocalSession` from `_persistSession()` — the restore
logic will still keep the user signed in from the identity-only copy, but a
wiped Keystore will then require one manual re-authentication.

## What still shows the Sign in screen

Only: a **fresh install / cleared app data**, or the user tapping **Sign out**.
There is no inactivity timeout, no JWT-expiry logout and no server-driven
logout. `Sign in again` in the offline banner reconnects in place.

## Verification

- `python3 tools/static_checks.py` — Dart braces/imports/assets gate.
- `python3 tools/session_checks.py` — behavioural invariants (single
  `current = null`, boot gate, identity-before-network, dual-write, guarded
  vault, no background logout).
- `app/test/session_blob_test.dart` — 9 unit tests covering corrupt copies,
  vault loss, legacy identity-only blobs, token dedupe/validation and CEO email
  canonicalisation. **CI already runs `flutter test` for every push**
  (`ci/build-android.sh`) and fails the APK build on a test failure.
- Android/Windows release builds compile the whole `app/lib` tree on push.

### Manual check on a device (Android)

1. Install the new APK over the old one, sign in, close the app.
2. Reopen → should land straight in the workspace (no login flash).
3. Toggle airplane mode, force-stop and reopen → still in the workspace, with
   the offline banner. Turn data back on → banner clears and data syncs.
4. Change the device lockscreen PIN (invalidates the Keystore) and reopen →
   still signed in; the local recovery copy re-seeds the vault.
5. Tap **Sign out** → login screen appears and stays on the next launch.
