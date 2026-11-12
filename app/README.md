# MFSL Office — ONE app, TWO build paths

The Flutter app in this folder is the whole product. There is no web/PWA
version anymore (owner directive 2026-08-30). Both builds talk to the SAME
server (Supabase Auth + the `data-api` Edge Function over Supabase Postgres), so data
entered on the phone appears on the PC instantly.

Production stock was populated once from the owner-provided `STOCK` directory.
Future products are entered or maintained through the app itself; application
installation never re-seeds or overwrites the cloud catalogue:
- **Stock → Add product** (name, category, cost, selling price, quantity,
  reorder level, unit, service toggle).

## Staying signed in

A user stays signed in until they tap **Sign out** — there is no inactivity
timeout and no JWT-expiry logout. The session is stored in two places (the OS
credential vault and the app-private `mtek_session.json`), so a wiped Android
Keystore, an offline start or a rejected token refresh can never drop a user
on the login screen; the workspace stays open with the local cache instead.
See [`docs/SESSION_PERSISTENCE.md`](../docs/SESSION_PERSISTENCE.md) for the
full write-up and the device test plan.

## Install the app (no local build needed)
Every push to `main` that touches the app — and every manual run of
**Actions → Build MFSL Office (APK + EXE)** — publishes fresh installers to
the rolling **`ci` pre-release** on the Releases page. GitHub serves release
assets **byte-for-byte: never re-zipped, never encrypted** — the download *is*
the installer, so there is nothing to extract and no “password protected”
errors, ever:

- **Android** (open on the phone itself): 
  https://github.com/NO-Group/mtek_fire_safety_ltd/releases/download/ci/MFSL.Inventory.apk
- **Windows installer**: 
  https://github.com/NO-Group/mtek_fire_safety_ltd/releases/download/ci/MFSL.Inventory.Setup.msix
- **Windows portable** (whole Release folder, zipped by *us*, not GitHub): 
  https://github.com/NO-Group/mtek_fire_safety_ltd/releases/download/ci/MFSL-Office-portable.zip

Asset names use dots because GitHub renames release-asset spaces to dots.
(Build logic lives in `ci/build-android.sh` / `ci/build-windows.ps1`; the
workflow file `.github/workflows/build-mfsl.yml` is a stable shim that just
calls those scripts — edit the scripts, never the workflow. Old Actions
*artifacts*, by contrast, always arrive wrapped in a GitHub-made zip, and a
truncated download of that zip is what made Windows claim “password
protected”.)

## Build the APK (Android)
1. Install Flutter SDK (flutter.dev) and Android Studio once.
2. Open this `app/` folder.
3. Double-click **`make_apk.bat`** — nothing else. Server and keys are
   already baked into the app.
   → APK appears at `app\MFSL Office.apk` (also kept at
   `app\build\app\outputs\flutter-apk\app-release.apk`).

Command line equivalent:
```
flutter build apk --release
```
(SUPABASE_URL and MILS_API_BASE are already baked in.)

## Build the EXE (Windows)
One-time prerequisite: install **Visual Studio 2022** (the free Community
edition) and tick **"Desktop development with C++"** in the installer —
Flutter needs its compiler for Windows EXEs.

Same prerequisites, then double-click **`make_exe.bat`** — nothing else.
It builds the app and then packages a Windows installer for you:

→ **Installer (recommended)**: `app\build\windows\x64\runner\Release\MFSL Office Setup.msix`.
Double-click it to install like any normal Windows app. It shows
**Publisher: N.O Group** in the install wizard. The very first time you
install it, Windows will ask you to confirm trusting a self-signed
developer certificate — click **Yes**; this only prompts once per PC.

→ Plain folder (no installer, portable): `app\build\windows\x64\runner\Release\`
— run `MFSL Office.exe` from inside that folder (needs the whole folder,
not just the .exe by itself). A zip of the whole folder is also made for
you: `app\MFSL Office.zip`.

Command line equivalent:
```
flutter build windows --release
dart run msix:create
```

## Sign in
The CEO signs in with `mtekfiresafetyltd@gmail.com` + the company password.
The server (Supabase Auth + Postgres) must be deployed first — see
`supabase/README.md` in the repo root.
