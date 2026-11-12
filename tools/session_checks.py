#!/usr/bin/env python3
"""Session-persistence regression gate.

`tools/static_checks.py` verifies Dart syntax/imports. This script verifies
the *behavioural invariants* that caused the "users are signed out on their
own" bug, so they cannot silently regress:

  1. `current = null` exists in exactly one place (explicit sign-out).
  2. signOut() has no callers other than the two explicit UI buttons.
  3. The boot screen waits for session restore before choosing AppShell or
     LoginScreen.
  4. Restore rehydrates the cached identity and resolves the boot gate BEFORE
     any network call, and always resolves the gate in `finally`.
  5. The session is written to BOTH stores and read from BOTH independently.
  6. Every OS-credential-vault access is exception-safe.
  7. A failed refresh NEVER clears the identity; it only sets a UI hint.
  8. Mid-session "sync now" uses the refresh path, not a second boot restore.

Exit code 1 on any failure. No third-party dependencies.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
errors = []


def src(rel):
    with open(os.path.join(ROOT, rel), encoding='utf-8') as fh:
        return fh.read()


def require(condition, message):
    if not condition:
        errors.append(message)


def section(text, start_marker, end_marker):
    """Body of the first function/declaration between two markers."""
    a = text.find(start_marker)
    b = text.find(end_marker, a + len(start_marker)) if a >= 0 else -1
    return text[a:b] if a >= 0 and b >= 0 else ''


auth = src('app/lib/data/auth_store.dart')
main = src('app/lib/main.dart')
shell = src('app/lib/ui/app_shell.dart')
bio = src('app/lib/core/biometric_service.dart')
api = src('app/lib/data/api_client.dart')
store = src('app/lib/data/store.dart')
blob = src('app/lib/data/session_blob.dart')
settings = src('app/lib/ui/screens/settings_screen.dart')
all_lib = {}
for base, _dirs, files in os.walk(os.path.join(ROOT, 'app', 'lib')):
    for f in files:
        if f.endswith('.dart'):
            p = os.path.join(base, f)
            all_lib[os.path.relpath(p, ROOT)] = open(p, encoding='utf-8').read()

# 1. Only signOut() may null the signed-in identity.
nullers = [(rel, i + 1, line.strip())
           for rel, text in all_lib.items()
           for i, line in enumerate(text.split('\n'))
           if re.search(r'\bcurrent\s*=\s*null\b', line)]
require(len(nullers) == 1,
        f'expected exactly one `current = null` (explicit sign-out), found {nullers}')

# 2. signOut() is only reachable from the two explicit UI buttons.
callers = [(rel, i + 1) for rel, text in all_lib.items()
           for i, line in enumerate(text.split('\n'))
           if 'AuthStore.instance.signOut()' in line]
require(sorted(rel for rel, _ in callers) ==
        ['app/lib/ui/app_shell.dart', 'app/lib/ui/screens/settings_screen.dart'],
        f'unexpected signOut() callers: {callers}')
require('signOut()' not in blob, 'pure session helper must never sign out')

# 3. Boot gate waits for BOTH data load and session restore.
require('!AuthStore.instance.bootReady' in main,
        'main.dart must gate the home widget on AuthStore.bootReady')
require('AppStore.instance.bootstrap()' in main,
        'main.dart must use the idempotent one-time boot pipeline')
require('bootstrap() => _bootstrapFuture ??= _doBootstrap()' in store,
        'AppStore.bootstrap() must be idempotent (rotating refresh tokens)')

# 4. Restore order: identity first, boot gate resolved, network last.
restore = section(auth, 'Future<void> _performRestoreSession()',
                  '/// Rehydrates the signed-in identity')
require('_restoreCachedIdentity(saved)' in restore,
        'restore must rehydrate the cached identity')
require(restore.find('_restoreCachedIdentity(saved)') <
        restore.find('forceRefreshSession()'),
        'identity restore must happen BEFORE any network call')
require(restore.find('markBootReady()') < restore.find('forceRefreshSession()'),
        'the splash screen must resolve before the slow network refresh')
require('finally' in restore and
        restore.rfind('markBootReady()') > restore.rfind('finally'),
        'restore must always resolve the boot gate in finally')
require('catch (error)' in restore and '_setNeedsReconnect(true)' in restore,
        'restore errors must be non-fatal status updates, never a logout')
require('restoreSession()' in auth and '_restoreInFlight' in auth,
        'restoreSession must be single-flight/idempotent')

# 5. Both stores are written and both are read independently.
require("localWrite(SessionBlob.localKey, encoded)" in auth and
        'BiometricService.instance.saveSession(encoded)' in auth,
        'session must be dual-written to vault + app-private JSON')
require('_rawSessionBlobs()' in auth and
        "localRead(SessionBlob.localKey)" in auth and
        'BiometricService.instance.session()' in auth,
        'both session copies must be read independently')
require(not re.search(r"local(?:Read|Write)\(\s*'session'\s*", auth),
        "auth_store must not use the raw 'session' key literal")
require('_repairSessionCopies' in auth,
        'old vault-only / identity-only builds must be migrated on boot')

# 6. Every OS credential vault access is exception-safe.
helpers = ''.join(section(bio, marker, '\n  }\n')
                   for marker in ('Future<void> _write(', 'Future<String?> _read(',
                                  'Future<void> _delete('))
require(all(marker in bio for marker in
            ('Future<void> _write(', 'Future<String?> _read(',
             'Future<void> _delete(')),
        'guarded vault helpers are missing')
vault_calls = len(re.findall(r'_storage\.(?:read|write|delete)\(', bio))
require(vault_calls == 3 and
        helpers.count('_storage.') == 3 and
        helpers.count('catch (error)') == 3,
        'every _storage call must live inside a try/catch guarded helper')

# 7. Failure never clears identity; cooldown prevents refresh storms.
refresh = section(auth, 'Future<bool> _performSessionRefresh()',
                  '/// Called once at boot')
require('current' not in re.sub(r'//.*', '', refresh),
        'the refresh path must never touch the signed-in identity')
require('_setNeedsReconnect(true)' in refresh,
        'a failed refresh must only flip the non-blocking reconnect hint')
require('_refreshCooldown' in auth and '_refreshInFlight' in auth,
        'refresh must be single-flight with a failure cooldown')
require('api.refreshAccessToken = refreshSession' in auth and
        'api.refreshAccessToken = null' in auth,
        'sign-out must detach the refresh callback so a late 401 cannot resurrect')

# 8. No second boot restore during live sync.
sync_now = section(store, 'Future<bool> syncNow()', 'Future<bool> refreshRemote(')
require('await AuthStore.instance.forceRefreshSession();' in sync_now and
        'restoreSession()' not in sync_now,
        'syncNow must refresh, not re-run the whole boot restore')
require('_cleanToken == null || _tokenExpiresSoon' in api,
        'protected requests must refresh when the bearer token is missing')

# 9. UI hint is informational only.
require('if (AuthStore.instance.sessionNeedsReconnect) _reconnectBanner()' in shell,
        'the shell must show a non-blocking reconnect hint')
require('showReconnectDialog' in shell,
        'users must be able to re-authenticate without leaving the workspace')
require(len(re.findall(r'AuthStore\.instance\.signOut\(\)', shell)) == 1,
        'the shell must not sign out except from the explicit drawer button')

# 10. Pure helper has no platform dependencies (so it stays unit-testable).
require("import 'package:flutter" not in blob and "import 'dart:html" not in blob,
        'session_blob.dart must stay platform-independent')

if errors:
    for e in errors:
        print(f'  FAIL: {e}')
    print(f'\n{len(errors)} session invariant(s) broken')
    sys.exit(1)
print('session checks passed: no background logout, dual-write restore, '
      'boot gate, guarded vault, single-flight refresh')
