import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/biometric_service.dart';
import 'api_client.dart';
import 'env.dart';
import 'local_store.dart';
import 'rest_client.dart';
import 'session_blob.dart';
import 'store.dart';

/// M1 demo hashing (fnv1a) — replaced in M3 by Supabase Auth + salted
class StaffUser {
  final String name;
  final String email;
  String role; // 'ceo' | 'admin' | 'sales'
  final String passwordHash;
  final String? signaturePng; // base64 data-URL of the drawn signature
  final String? passportPhoto; // compulsory for new accounts
  StaffUser({
    required this.name,
    required this.email,
    required this.role,
    required this.passwordHash,
    this.signaturePng,
    this.passportPhoto,
  });

  Map<String, dynamic> toJson() => {
        'name': name, 'email': email, 'role': role,
        'passwordHash': passwordHash,
        'signaturePng': signaturePng,
        'passportPhoto': passportPhoto,
      };
  static StaffUser fromJson(Map<String, dynamic> j) => StaffUser(
        name: '${j['name'] ?? ''}'.trim(),
        email: '${j['email'] ?? ''}'.trim().toLowerCase(),
        role: '${j['role'] ?? 'sales'}',
        passwordHash: '${j['passwordHash'] ?? ''}',
        signaturePng: j['signaturePng'] as String?,
        passportPhoto: j['passportPhoto'] as String?,
      );
}

String demoHash(String input) {
  // FNV-1a 32-bit — DEMO ONLY (client-side, unsalted). M3 moves all
  // credential verification server-side with salted hashes.
  var h = 0x811c9dc5;
  for (final code in utf8.encode('mtek::$input')) {
    h ^= code;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

class AuthStore extends ChangeNotifier {
  AuthStore._() {
    // NO preset accounts (owner directive 2026-08-30): real sign-in happens
    // against Supabase Auth; the local directory fills from real sign-ins
    // and real Sign Ups only. The CEO identity is locked via [ceoEmail] and
    // is never registrable — it signs in with the owner's real credentials.
  }

  /// The CEO identity is fixed to this email across the whole system
  /// (Flutter app, preview server, Supabase backend in Phase C).
  static const String ceoEmail = 'mtekfiresafetyltd@gmail.com';
  static final AuthStore instance = AuthStore._();

  final List<StaffUser> users = [];
  StaffUser? current;

  bool get isSignedIn => current != null;
  bool get isAdmin => current?.role == 'admin';

  /// CEO outranks admin — full management reach everywhere.
  bool get isCeo => current?.role == 'ceo';

  /// Management-level authority (CEO or Admin): settings, seeds, approvals.
  bool get isManagement => isAdmin || isCeo;

  // ---- boot / session state ------------------------------------------------
  /// True once boot-time session restore has decided who is signed in. The
  /// splash screen stays up until then, so the login screen can neither flash
  /// nor become permanent while storage/network work is still in flight.
  bool bootReady = false;

  /// Non-blocking hint for the shell: cloud auth has not been re-established
  /// yet. NEVER used to force a sign-out — the workspace stays fully usable
  /// (owner directive 2026-11-04: no user may ever be signed out automatically).
  bool sessionNeedsReconnect = false;

  /// Incremented on explicit sign-out so a refresh already in flight cannot
  /// adopt a new session and resurrect the signed-in identity.
  int _sessionGeneration = 0;

  /// Serial of the last durable session write. Guards sign-out's asynchronous
  /// storage clears against wiping a session created immediately afterwards.
  int _sessionWriteSerial = 0;

  Future<void>? _restoreInFlight;
  DateTime? _lastFailedRefresh;
  static const Duration _refreshCooldown = Duration(seconds: 45);

  /// Resolves the boot gate. Safe to call repeatedly.
  void markBootReady() {
    if (bootReady) return;
    bootReady = true;
    notifyListeners();
  }

  void _setNeedsReconnect(bool value) {
    if (sessionNeedsReconnect == value) return;
    sessionNeedsReconnect = value;
    notifyListeners();
  }

  // ---- device-local account directory (offline-first) --------------------
  // Every account that has ever signed in / signed up on this device is kept
  // here (password hash only), so sign-in keeps working with no server.
  bool _usersLoaded = false;

  String _emailKey(String email) => email.trim().toLowerCase();

  /// Rebuilds the local directory using canonical email keys. Later records
  /// win because they carry the freshest server role/name, while non-empty
  /// local credential/signature fields are retained. The CEO email is always
  /// represented by exactly one locked CEO row.
  void _dedupeUsers() {
    final byEmail = <String, StaffUser>{};
    for (final candidate in users) {
      final email = _emailKey(candidate.email);
      if (email.isEmpty || !email.contains('@')) continue;
      final previous = byEmail[email];
      final role = email == ceoEmail ? 'ceo' : candidate.role;
      byEmail[email] = StaffUser(
        name: candidate.name.isNotEmpty
            ? candidate.name
            : (previous?.name.isNotEmpty == true ? previous!.name : email.split('@').first),
        email: email,
        role: role,
        passwordHash: candidate.passwordHash.isNotEmpty
            ? candidate.passwordHash
            : previous?.passwordHash ?? '',
        signaturePng: candidate.signaturePng ?? previous?.signaturePng,
      );
    }
    users
      ..clear()
      ..addAll(byEmail.values);
    // A cache rebuild must NEVER clear the signed-in identity. Rebuilding the
    // directory from a partially corrupt file used to null `current` here and
    // silently dump the user on the login screen with no sign-out requested.
    final signedIn = current;
    if (signedIn != null) {
      current = byEmail[_emailKey(signedIn.email)] ?? signedIn;
    }
  }

  StaffUser _upsertUser(StaffUser user) {
    final key = _emailKey(user.email);
    users.removeWhere((existing) => _emailKey(existing.email) == key);
    users.add(user);
    _dedupeUsers();
    return users.singleWhere((existing) => _emailKey(existing.email) == key);
  }

  Future<void> loadUsers() async {
    if (_usersLoaded) return;
    _usersLoaded = true;
    final raw = await localRead('users');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        for (final e in list) {
          if (e is Map) users.add(StaffUser.fromJson(e.cast<String, dynamic>()));
        }
        final before = users.length;
        _dedupeUsers();
        // Repair already-corrupted caches immediately; this turns hundreds
        // of historical CEO copies into one canonical record on first boot.
        if (users.length != before) await _persistUsers();
      }
    } catch (_) {
      users.clear(); // corrupt cache — start clean
    }
  }

  Future<void> persistUsers() => _persistUsers();
  Future<void> _persistUsers() async {
    _dedupeUsers();
    await localWrite('users', jsonEncode(users.map((u) => u.toJson()).toList()));
  }

  String? signIn(String email, String password) {
    if (users.isEmpty) {
      return 'No account on this device yet — connect once to sign in, or create an account.';
    }
    final mail = email.trim().toLowerCase();
    final user = users.where((u) => u.email == mail).firstOrNull;
    if (user == null) return 'No account with that email';
    if (user.passwordHash.isEmpty) return 'This account has not signed in on this device while online yet';
    if (user.passwordHash != demoHash(password)) return 'Wrong password';
    if (mail == ceoEmail && user.role != 'ceo') user.role = 'ceo'; // locked
    current = user;
    notifyListeners();
    return null;
  }

  /// OFFLINE-ONLY fallback (no backend configured in this build) — kept so
  /// the app is still usable in a dev/demo checkout with no Supabase set up.
  /// The real, server-backed path is [remoteSignUp] below.
  String? signUp({
    required String name,
    required String email,
    required String password,
    required String role,
    String? signaturePng,
    String? passportPhoto,
  }) {
    final mail = email.trim().toLowerCase();
    if (name.trim().isEmpty) return 'Enter your full name';
    if (passportPhoto == null || passportPhoto.isEmpty) return 'A passport photograph is required';
    if (!mail.contains('@')) return 'Enter a valid email';
    if (password.length < 6) return 'Password must be at least 6 characters';
    if (mail == ceoEmail) return 'The CEO account is pre-provisioned — sign in directly';
    if (users.any((u) => u.email == mail)) return 'An account with that email already exists';
    users.add(StaffUser(
      name: name.trim(),
      email: mail,
      role: role == 'ceo' ? 'admin' : role,
      passwordHash: demoHash(password),
      signaturePng: signaturePng,
      passportPhoto: passportPhoto,
    ));
    current = users.last;
    notifyListeners();
    unawaited(_persistUsers());
    return null;
  }

  /// REAL sign-up: creates an actual Supabase Auth user via the data API
  /// (which holds the service-role key server-side) then signs the new
  /// account straight in with a live session, exactly like [remoteSignIn].
  /// New self-signups always land as 'sales' — the server enforces this
  /// too, so nobody can grant themselves admin/CEO from this screen; only
  /// the CEO promotes staff afterwards from the in-app Staff screen (owner
  /// directive 2026-09-01). `phone` is set on the actual Supabase Auth user
  /// (shows up in Authentication → Users) and `recoveryString` (≥15 chars,
  /// chosen by the user) is the only way to reset a forgotten password —
  /// there is no email/OTP flow.
  Future<String?> remoteSignUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String recoveryString,
    required String passportPhoto,
  }) async {
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null) {
      return 'No backend configured in this build.';
    }
    final mail = email.trim().toLowerCase();
    final res = await api.postPublic('/api/auth/signup', {
      'name': name.trim(),
      'email': mail,
      'phone': phone.trim(),
      'password': password,
      'recovery_string': recoveryString,
      'passport_photo': passportPhoto,
    });
    final j = res?.json;
    final serverOk = res != null && res.ok && j is Map && j['access_token'] is String && j['user'] is Map;
    if (!serverOk && res != null && res.status < 500) {
      // a real validation/duplicate answer from the auth service — show it
      final msg = (j is Map ? j['error'] : null);
      return msg is String ? msg : 'Could not create the account — please try again.';
    }
    if (serverOk) {
      await _adoptSession(j);
      await AppStore.instance.reloadRemote();
      return null;
    }
    // An account that exists on only one device cannot sync and must never
    // be presented as a successful company account.
    return 'Cloud account creation is unavailable — no account was created. Check your connection and try again.';
  }

  /// No-email, no-OTP password reset: the user proves ownership with the
  /// recovery phrase they set at sign-up (owner directive 2026-09-01).
  Future<String?> resetPasswordWithRecovery({
    required String email,
    required String recoveryString,
    required String newPassword,
  }) async {
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null) {
      return 'No backend configured in this build.';
    }
    final res = await api.postPublic('/api/auth/reset-password', {
      'email': email.trim().toLowerCase(),
      'recovery_string': recoveryString,
      'new_password': newPassword,
    });
    if (res == null) return 'Network unreachable — check your connection';
    if (!res.ok) {
      final msg = (res.json is Map ? (res.json as Map)['error'] : null);
      return msg is String ? msg : 'Could not reset the password';
    }
    return null;
  }

  /// Rotates the recovery phrase after verifying the account password
  /// (Settings → Account → Recovery).
  Future<String?> resetRecovery({
    required String email,
    required String password,
    required String newRecoveryString,
  }) async {
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null) {
      return 'No backend configured in this build.';
    }
    final res = await api.postPublic('/api/auth/reset-recovery', {
      'email': email.trim().toLowerCase(),
      'password': password,
      'new_recovery_string': newRecoveryString,
    });
    if (res == null) return 'Network unreachable — check your connection';
    if (!res.ok) {
      final msg = (res.json is Map ? (res.json as Map)['error'] : null);
      return msg is String ? msg : 'Could not reset the recovery string';
    }
    return null;
  }

  /// Changes the account password while signed in (Settings → Account).
  /// Requires the current password; no email/OTP round-trip.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null || accessToken == null) {
      return 'You must be signed in to change your password.';
    }
    final res = await api.post('/api/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (res == null) return 'Network unreachable — check your connection';
    if (!res.ok) {
      final msg = (res.json is Map ? (res.json as Map)['error'] : null);
      return msg is String ? msg : 'Could not change the password';
    }
    return null;
  }

  /// Real Supabase Auth sign-in. On success the RestClient carries the
  /// user's JWT so every read/write runs under RLS as that account, and
  /// the profile (name/role) comes from public.profiles.
  Future<String?> remoteSignIn(String email, String password) async {
    final remote = AppStore.instance.remote;
    if (!Env.backendConfigured || remote == null) return null; // caller falls back to local
    final mail = email.trim().toLowerCase();
    final res = await remote.authSignInRaw(mail, password);
    if (res == null) {
      // Never open a disconnected local account as though it were cloud
      // signed-in. That hides the fact that this user's work cannot sync.
      return 'Cloud sign-in is unavailable — check your connection and try again.';
    }
    final j = res.json;
    if (!res.ok) {
      final msg = (j is Map ? (j['error_description'] ?? j['error'] ?? j['msg']) : null);
      return msg is String ? msg : 'Sign-in failed — please try again.';
    }
    if (j is! Map || j['access_token'] is! String || j['user'] is! Map) {
      return 'Unexpected auth response';
    }
    // The login response's `user` object is `{uid, email, name, role}` — key
    // it on `uid` (NOT `id`, which the response never contains; the previous
    // code read `id`, leaving remoteSignInUid empty) and carry the role/name
    // straight through so the client trusts the server's authoritative role.
    await _adoptSession({
      'access_token': j['access_token'],
      'refresh_token': j['refresh_token'],
      'user': {
        'uid': j['user']['uid'] ?? '',
        'email': j['user']['email'] ?? mail,
        'name': j['user']['name'],
        'role': j['user']['role'],
      },
    }, passwordHash: demoHash(password));
    // pull the live dataset from Supabase Postgres for this account
    await AppStore.instance.reloadRemote();
    return null;
  }

  /// Common session bootstrap: stash the token(s), reconcile the authoritative
  /// role/name into the local directory, and PERSIST the session to BOTH the
  /// OS credential vault and the app-private JSON recovery copy, so a vault
  /// wipe can never strand a signed-in user on the login screen.
  ///
  /// Every storage failure is swallowed: losing a write must never abort a
  /// sign-in or a token refresh. Returns false when an explicit sign-out
  /// started while this call was in flight (so a late refresh cannot bring
  /// the user back after they chose to sign out).
  Future<bool> _adoptSession(
    Map j, {
    String? passwordHash,
    int? generation,
  }) async {
    final activeGeneration = generation ?? _sessionGeneration;
    final remote = AppStore.instance.remote;
    final api = AppStore.instance.api;
    final accessTok = '${j['access_token'] ?? ''}'.trim();
    final refreshTok = '${j['refresh_token'] ?? ''}'.trim();
    final u = (j['user'] as Map?) ?? const {};
    final uid = '${u['uid'] ?? u['id'] ?? ''}';
    final mail = '${u['email'] ?? ''}'.trim().toLowerCase();

    // A refresh response from an older/degraded deploy may omit identity
    // fields. Fall back to the persisted identity rather than replacing it
    // with an empty email (which would make the next boot unrecoverable).
    final stored = await _readSessionBlobs();
    if (activeGeneration != _sessionGeneration) return false;
    final savedIdentity = SessionBlob.identity(stored);
    final identityMail = mail.contains('@')
        ? mail
        : (SessionBlob.email(savedIdentity) ?? '');
    String role = '${u['role'] ?? 'sales'}';
    if (u['role'] == null && savedIdentity != null) {
      role = '${savedIdentity['role'] ?? role}';
    }
    var name = '${u['name'] ?? ''}'.trim();
    if (name.isEmpty) name = '${savedIdentity?['name'] ?? ''}'.trim();
    if (name.isEmpty) {
      name = identityMail.isEmpty ? 'Staff' : identityMail.split('@').first;
    }
    // The CEO identity is LOCKED to this email across the whole system
    // (mirrors the offline signIn() lock). Without this, any 'sales' role
    // coming from the server — an old/stale deployed edge function, a
    // failed profile warm-up, a cached refresh session — would pin the boss
    // to the Sales UI for good. Owner directive 2026-09-02.
    if (identityMail == ceoEmail && role != 'ceo') role = 'ceo';

    // Refresh tokens are single-use/rotating. Make the replacement durable
    // before any request can observe its paired access token. If a response
    // carries no new refresh token, keep the currently stored one.
    final storedTokens = SessionBlob.refreshTokens(stored);
    final effectiveRefresh = refreshTok.isNotEmpty
        ? refreshTok
        : (storedTokens.isEmpty ? '' : storedTokens.first);
    if (effectiveRefresh.isNotEmpty && identityMail.isNotEmpty) {
      await _persistSession({
        'refresh_token': effectiveRefresh,
        'email': identityMail,
        'name': name,
        'role': role,
        'saved_at': DateTime.now().toIso8601String(),
      });
    }
    if (activeGeneration != _sessionGeneration) return false;
    if (remote != null) remote.accessToken = accessTok;
    if (api != null) {
      api.accessToken = accessTok;
      api.refreshAccessToken = refreshSession;
    }
    remoteSignInUid = uid;
    final prev = users
        .where((x) => _emailKey(x.email) == identityMail)
        .firstOrNull;
    current = _upsertUser(StaffUser(
      name: name,
      email: identityMail,
      role: role,
      // keep the device copy of the password hash so this account can sign
      // in again with the server unreachable (offline-first)
      passwordHash: passwordHash ?? prev?.passwordHash ?? '',
      signaturePng: prev?.signaturePng,
    ));
    _setNeedsReconnect(false);
    notifyListeners();
    unawaited(_persistUsers());
    return true;
  }

  /// Supabase auth.users id of the signed-in account. Offline-first: falls
  /// back to the account email so read-receipts / ownership still work with
  /// a device-local sign-in.
  String? get remoteSignInUid => _remoteUid ?? current?.email;
  set remoteSignInUid(String? v) => _remoteUid = v;
  String? _remoteUid;

  /// Current Supabase JWT for data-API calls (null when signed out/offline).
  String? get accessToken => AppStore.instance.remote?.accessToken;

  /// Checks the JWT bytes without contacting the server when at least five
  /// minutes remain. Used on app resume and by a periodic guard so a device
  /// left open for days refreshes before background synchronization resumes.
  Future<bool> ensureFreshSession() async {
    final token = accessToken?.trim();
    if (token != null && token.split('.').length == 3) {
      try {
        final payload = jsonDecode(utf8.decode(
          base64Url.decode(base64Url.normalize(token.split('.')[1]))));
        final expiry = payload is Map ? int.tryParse('${payload['exp'] ?? ''}') : null;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (expiry != null && expiry > now + 300) return true;
      } catch (_) { /* malformed tokens are refreshed below */ }
    }
    return refreshSession();
  }

  Future<bool>? _refreshInFlight;

  /// Exchanges the persisted refresh token and atomically installs the
  /// rotated access/refresh pair. All callers — resume, timer, HTTP 401
  /// recovery and boot restore — share this lock. Without it, two rotating
  /// token exchanges could use the same token and invalidate the session.
  ///
  /// A short cooldown after a failed attempt stops the 8-second data poll
  /// from turning an offline device into a refresh storm. A failure NEVER
  /// signs the user out; it only flips the non-blocking "reconnect" hint.
  Future<bool> refreshSession() => _refreshSession(force: false);

  /// Boot-time / user-requested refresh that ignores the retry cooldown.
  Future<bool> forceRefreshSession() => _refreshSession(force: true);

  Future<bool> _refreshSession({required bool force}) {
    if (!force) {
      final last = _lastFailedRefresh;
      if (last != null && DateTime.now().difference(last) < _refreshCooldown) {
        return Future<bool>.value(false);
      }
    }
    final running = _refreshInFlight;
    if (running != null) return running;
    final future = _performSessionRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  /// Reads BOTH persisted copies independently. A corrupt or unavailable
  /// vault must never hide the app-private recovery copy (and vice versa).
  /// The vault copy is always first, so it wins when both are healthy.
  Future<List<String?>> _rawSessionBlobs() async {
    String? vault;
    String? local;
    try {
      vault = await BiometricService.instance.session();
    } catch (error) {
      debugPrint('secure session read failed: $error');
    }
    try {
      local = await localRead(SessionBlob.localKey);
    } catch (error) {
      debugPrint('local session read failed: $error');
    }
    return <String?>[vault, local];
  }

  Future<List<Map<String, dynamic>>> _readSessionBlobs() async {
    final blobs = <Map<String, dynamic>>[];
    for (final raw in await _rawSessionBlobs()) {
      final blob = SessionBlob.decode(raw);
      if (blob != null) blobs.add(blob);
    }
    return blobs;
  }

  /// Durable write to BOTH stores. Each write is independent: a Keystore or
  /// DPAPI failure must never abort sign-in or leave the device with no
  /// session at all. This dual copy is what makes a wiped Android Keystore
  /// recoverable on the next launch.
  Future<void> _persistSession(Map<String, dynamic> blob) async {
    final generation = _sessionGeneration;
    final serial = ++_sessionWriteSerial;
    final encoded = jsonEncode(blob);
    await _writeVaultSession(encoded);
    await _writeLocalSession(encoded);
    // A sign-out that began while these writes were in flight wins.
    if (generation != _sessionGeneration) {
      unawaited(_clearPersistedSession(serial));
    }
  }

  Future<void> _writeVaultSession(String encoded) async {
    try {
      await BiometricService.instance.saveSession(encoded);
    } catch (error) {
      debugPrint('secure session write failed: $error');
    }
  }

  Future<void> _writeLocalSession(String encoded) async {
    try {
      await localWrite(SessionBlob.localKey, encoded);
    } catch (error) {
      debugPrint('local session write failed: $error');
    }
  }

  /// Older builds kept the refresh token ONLY in the vault and identity ONLY
  /// in the local file. Migrate to the dual-write format in both directions:
  /// whichever copy has a usable token is copied into the other one.
  Future<void> _repairSessionCopies(List<String?> raw) async {
    final vault = SessionBlob.decode(raw[0]);
    final local = SessionBlob.decode(raw[1]);
    final vaultToken = SessionBlob.refreshToken(vault);
    final localToken = SessionBlob.refreshToken(local);
    if (vault != null && vaultToken != null &&
        SessionBlob.email(vault) != null && localToken != vaultToken) {
      await _writeLocalSession(jsonEncode(vault));
    }
    if (local != null && localToken != null &&
        SessionBlob.email(local) != null && vaultToken == null) {
      await _writeVaultSession(jsonEncode(local));
    }
  }

  Future<bool> _performSessionRefresh() async {
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null) return false;
    final generation = _sessionGeneration;
    final tokens = SessionBlob.refreshTokens(await _readSessionBlobs());
    if (tokens.isEmpty) {
      _lastFailedRefresh = DateTime.now();
      _setNeedsReconnect(true);
      return false;
    }
    for (final refreshToken in tokens) {
      if (generation != _sessionGeneration) return false;
      RestJsonResponse? response;
      // Brief transport/server interruptions must not leak an expired-token
      // error into the user's action. Retry transient failures inside the one
      // global refresh operation; never run parallel exchanges.
      for (var attempt = 0; attempt < 3; attempt++) {
        response = await api.postPublic(
            '/api/auth/refresh', {'refresh_token': refreshToken});
        if (response != null && response.status != 429 && response.status < 500) break;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
      if (generation != _sessionGeneration) return false;
      // A 401 from the refresh endpoint (revoked/rotated token, stale deploy,
      // proxy) is NEVER a reason to sign out. Try the other persisted copy,
      // then keep the cached identity and retry later.
      if (response == null || !response.ok || response.json is! Map) continue;
      final body = response.json as Map;
      final access = '${body['access_token'] ?? ''}'.trim();
      if (access.split('.').length != 3 ||
          access.contains(RegExp(r'[\x00-\x20\x7f]'))) continue;
      final adopted = await _adoptSession(body, generation: generation);
      if (!adopted || generation != _sessionGeneration) return false;
      _lastFailedRefresh = null;
      _setNeedsReconnect(false);
      return true;
    }
    _lastFailedRefresh = DateTime.now();
    _setNeedsReconnect(true);
    return false;
  }

  /// Called once at boot (before the login screen would otherwise show).
  /// Idempotent + single-flight: a theme rebuild or a manual sync can never
  /// launch a second restore and consume the rotating refresh token twice.
  ///
  /// ORDER IS THE FIX: rehydrate the cached identity FIRST from whichever
  /// session copy is readable, resolve the boot gate, and only THEN touch the
  /// network. A slow, offline, corrupt or failing vault/server can no longer
  /// decide that the login screen is the right destination. No background
  /// condition is permitted to sign a user out (owner directive 2026-11-04).
  Future<void> restoreSession() {
    final running = _restoreInFlight;
    if (running != null) return running;
    final future = _performRestoreSession();
    _restoreInFlight = future;
    return future.whenComplete(() => _restoreInFlight = null);
  }

  Future<void> _performRestoreSession() async {
    try {
      await loadUsers();
      final api = AppStore.instance.api;
      if (Env.authApiConfigured && api != null) {
        api.refreshAccessToken = refreshSession;
      }
      final raw = await _rawSessionBlobs();
      final blobs = <Map<String, dynamic>>[];
      for (final value in raw) {
        final blob = SessionBlob.decode(value);
        if (blob != null) blobs.add(blob);
      }
      final saved = SessionBlob.identity(blobs);
      if (saved != null) _restoreCachedIdentity(saved);
      await _repairSessionCopies(raw);
      // The workspace can be shown now; the network refresh below keeps
      // running while the user is already inside the app.
      markBootReady();
      final tokens = SessionBlob.refreshTokens(blobs);
      if (tokens.isEmpty || !Env.authApiConfigured || api == null) {
        _setNeedsReconnect(saved != null);
        return;
      }
      final refreshed = await forceRefreshSession();
      if (refreshed) {
        try {
          await AppStore.instance.reloadRemote();
        } catch (error) {
          debugPrint('post-restore data reload failed: $error');
        }
      }
    } catch (error) {
      // Storage, decode and network failures are ALL non-fatal. The cached
      // identity is restored above and stays signed in.
      debugPrint('session restore (non-fatal): $error');
      _setNeedsReconnect(true);
    } finally {
      markBootReady();
    }
  }

  /// Rehydrates the signed-in identity from the persisted session blob so
  /// the user lands in the app (offline-first, working off the local cache)
  /// even when the server can't be reached yet at boot.
  void _restoreCachedIdentity(Map<String, dynamic> saved) {
    final mail = _emailKey('${saved['email'] ?? ''}');
    if (!mail.contains('@')) return;
    final signedIn = current;
    if (signedIn != null && _emailKey(signedIn.email) == mail) return;
    // Offline/transient boot must respect the CEO lock too — a stale
    // 'sales' role saved earlier must never show the boss the Sales UI.
    var cachedRole = '${saved['role'] ?? 'sales'}';
    if (mail == ceoEmail && cachedRole != 'ceo') cachedRole = 'ceo';
    final previous =
        users.where((x) => _emailKey(x.email) == mail).firstOrNull;
    current = _upsertUser(StaffUser(
      name: '${saved['name'] ?? mail.split('@').first}',
      email: mail,
      role: cachedRole,
      passwordHash: previous?.passwordHash ?? '',
      signaturePng: previous?.signaturePng,
    ));
    notifyListeners();
  }

  void signOut() {
    // Invalidate any in-flight refresh BEFORE clearing state: a late 401
    // must never adopt a new session and bring the user back after they
    // explicitly chose to sign out.
    ++_sessionGeneration;
    current = null;
    remoteSignInUid = null;
    _lastFailedRefresh = null;
    sessionNeedsReconnect = false;
    final remote = AppStore.instance.remote;
    final api = AppStore.instance.api;
    if (remote != null) remote.accessToken = null;
    if (api != null) {
      api.accessToken = null;
      api.refreshAccessToken = null;
    }
    unawaited(_clearPersistedSession(_sessionWriteSerial));
    notifyListeners();
  }

  /// Clears BOTH copies, serially guarded so an explicit sign-out that is
  /// still finishing cannot wipe a session created by a quick re-sign-in.
  Future<void> _clearPersistedSession(int serialAtSignOut) async {
    if (serialAtSignOut != _sessionWriteSerial) return;
    try {
      await BiometricService.instance.clearSession();
    } catch (error) {
      debugPrint('secure session clear failed: $error');
    }
    if (serialAtSignOut != _sessionWriteSerial) return;
    try {
      await localWrite(SessionBlob.localKey, '');
    } catch (error) {
      debugPrint('local session clear failed: $error');
    }
  }

  /// Public notification for external listeners (boot/data-load events).
  void ping() => notifyListeners();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
