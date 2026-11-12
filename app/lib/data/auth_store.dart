import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/biometric_service.dart';
import 'api_client.dart';
import 'env.dart';
import 'local_store.dart';
import 'rest_client.dart';
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
    if (current != null) current = byEmail[_emailKey(current!.email)];
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
    // pull the live dataset from MongoDB for this account
    await AppStore.instance.reloadRemote();
    return null;
  }

  /// Common session bootstrap: stash the token(s), warm the role/name from
  /// /api/me, reconcile into the local directory, and PERSIST the session
  /// (access + refresh token) to disk so exiting the app never signs the
  /// user out (owner directive 2026-09-01). Used by sign-in, sign-up and
  /// the silent boot-time [restoreSession].
  Future<void> _adoptSession(Map j, {String? passwordHash}) async {
    final remote = AppStore.instance.remote;
    final api = AppStore.instance.api;
    final accessTok = '${j['access_token'] ?? ''}'.trim();
    final refreshTok = '${j['refresh_token'] ?? ''}'.trim();
    final u = (j['user'] as Map?) ?? const {};
    final uid = '${u['uid'] ?? u['id'] ?? ''}';
    final mail = '${u['email'] ?? ''}'.toLowerCase();
    String role = '${u['role'] ?? 'sales'}';
    String name = '${u['name'] ?? mail.split('@').first}';
    // The CEO identity is LOCKED to this email across the whole system
    // (mirrors the offline signIn() lock). Without this, any 'sales' role
    // coming from the server — an old/stale deployed edge function, a
    // failed profile warm-up, a cached refresh session — would pin the boss
    // to the Sales UI for good. Owner directive 2026-09-02.
    if (mail == ceoEmail && role != 'ceo') role = 'ceo';
    // A refresh token is single-use/rotating. Make the replacement durable
    // before any request can observe and use its paired access token. If the
    // process is interrupted, secure storage therefore never points at the
    // already-consumed predecessor.
    if (refreshTok.isNotEmpty) {
      await BiometricService.instance.saveSession(jsonEncode({
        'refresh_token': refreshTok,
        'email': mail,
        'name': name,
        'role': role,
      }));
      await localWrite('session', jsonEncode({
        'email': mail, 'name': name, 'role': role,
      }));
    }
    if (remote != null) remote.accessToken = accessTok;
    if (api != null) {
      api.accessToken = accessTok;
      api.refreshAccessToken = refreshSession;
    }
    remoteSignInUid = uid;
    final prev = users.where((x) => _emailKey(x.email) == mail).firstOrNull;
    current = _upsertUser(StaffUser(
      name: name,
      email: mail,
      role: role,
      // keep the device copy of the password hash so this account can sign
      // in again with the server unreachable (offline-first)
      passwordHash: passwordHash ?? prev?.passwordHash ?? '',
      signaturePng: prev?.signaturePng,
    ));
    notifyListeners();
    unawaited(_persistUsers());
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

  /// Exchanges the securely stored refresh token and atomically installs the
  /// rotated access/refresh pair. All callers—including resume, timer and HTTP
  /// 401 recovery—share this lock. Without it, two rotating-token exchanges
  /// could use the same refresh token and invalidate the boss's session.
  Future<bool> refreshSession() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final future = _performSessionRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _performSessionRefresh() async {
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null) return false;
    final raw = await BiometricService.instance.session();
    if (raw == null || raw.isEmpty) return false;
    Map<String, dynamic> saved;
    try {
      saved = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return false;
    }
    final refreshToken = '${saved['refresh_token'] ?? ''}'.trim();
    if (refreshToken.isEmpty || refreshToken.contains(RegExp(r'[\x00-\x20\x7f]'))) {
      return false;
    }
    RestJsonResponse? response;
    // Brief transport/server interruptions must not leak an expired-token
    // error into the user's action. Retry transient failures inside the one
    // global refresh operation; never run parallel exchanges.
    for (var attempt = 0; attempt < 3; attempt++) {
      response = await api.postPublic('/api/auth/refresh', {'refresh_token': refreshToken});
      if (response != null && response.status != 429 && response.status < 500) break;
      if (attempt < 2) await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
    if (response?.status == 401) {
      // Never destroy the local identity from a background refresh response.
      // A temporary deployment mismatch, proxy response, or token-rotation
      // race must not throw a signed-in user back to the login screen. Keep
      // the secure refresh credential and retry on the next request/resume.
      return false;
    }
    if (response == null || !response.ok || response.json is! Map) return false;
    final body = response.json as Map;
    final access = '${body['access_token'] ?? ''}'.trim();
    if (access.split('.').length != 3 || access.contains(RegExp(r'[\x00-\x20\x7f]'))) return false;
    await _adoptSession(body);
    return true;
  }

  /// Called once at boot (before the login screen would otherwise show):
  /// reads the refresh token saved by [_adoptSession] and silently exchanges
  /// it for a fresh access token, so closing/reopening the app keeps the
  /// user signed in (owner directive 2026-09-01 — previously every restart
  /// forced a fresh sign-in with no session saved anywhere).
  Future<void> restoreSession() async {
    await loadUsers();
    final api = AppStore.instance.api;
    if (!Env.authApiConfigured || api == null) return;
    api.refreshAccessToken = refreshSession;
    // New builds use the Android Keystore / Windows credential vault. Fall
    // back once to the legacy JSON cache so upgrades preserve the session,
    // then migrate it into secure storage and scrub its tokens below.
    var raw = await BiometricService.instance.session();
    final legacyRaw = await localRead('session');
    raw ??= legacyRaw;
    if (raw == null || raw.isEmpty) return;
    Map<String, dynamic> saved;
    try {
      saved = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final refreshTok = '${saved['refresh_token'] ?? ''}';
    if (refreshTok.isEmpty) return;
    if (await BiometricService.instance.session() == null) {
      await BiometricService.instance.saveSession(jsonEncode(saved));
      await localWrite('session', jsonEncode({
        'email': saved['email'], 'name': saved['name'], 'role': saved['role'],
      }));
    }
    // Startup must use the exact same single-flight refresh path as resume,
    // timers and HTTP 401 recovery. A direct exchange here previously left a
    // rotation race during the first requests after launch.
    if (await refreshSession()) {
      await AppStore.instance.reloadRemote();
      return;
    }
    // Offline, rejected, malformed or temporarily unavailable: retain the
    // cached identity and secure refresh credential. No background condition
    // is permitted to turn into an automatic logout.
    _restoreCachedIdentity(saved);
  }

  /// Rehydrates the signed-in identity from the persisted session blob so
  /// the user lands in the app (offline-first, working off the local cache)
  /// even when the server can't be reached yet at boot.
  void _restoreCachedIdentity(Map<String, dynamic> saved) {
    final mail = '${saved['email'] ?? ''}';
    if (mail.isEmpty) return;
    // Offline/transient boot must respect the CEO lock too — a stale
    // 'sales' role saved earlier must never show the boss the Sales UI.
    var cachedRole = '${saved['role'] ?? 'sales'}';
    if (mail == ceoEmail && cachedRole != 'ceo') cachedRole = 'ceo';
    final previous = users.where((x) => _emailKey(x.email) == _emailKey(mail)).firstOrNull;
    current = _upsertUser(StaffUser(
      name: '${saved['name'] ?? mail.split('@').first}',
      email: _emailKey(mail),
      role: cachedRole,
      passwordHash: previous?.passwordHash ?? '',
      signaturePng: previous?.signaturePng,
    ));
    notifyListeners();
  }

  void signOut() {
    current = null;
    remoteSignInUid = null;
    AppStore.instance.remote?.accessToken = null;
    AppStore.instance.api?.accessToken = null;
    unawaited(localWrite('session', ''));
    unawaited(BiometricService.instance.clearSession());
    notifyListeners();
  }

  /// Public notification for external listeners (boot/data-load events).
  void ping() => notifyListeners();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
