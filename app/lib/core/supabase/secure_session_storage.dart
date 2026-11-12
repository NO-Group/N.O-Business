import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logging/app_logger.dart';

/// Persists the Supabase session (which contains the refresh token) in the
/// OS credential store — Android Keystore-backed storage, Windows DPAPI —
/// instead of the SDK default, which is plain shared preferences.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this._storage);

  static const _key = 'nob.auth.session';
  static const _log = AppLogger('session-storage');

  final FlutterSecureStorage _storage;

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() => _read();

  @override
  Future<bool> hasAccessToken() async => (await _read()) != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    try {
      await _storage.write(key: _key, value: persistSessionString);
    } catch (error) {
      // The user stays signed in for this run; they will sign in again next
      // launch. Never fall back to an unencrypted store.
      _log.warning('session could not be persisted', error: error);
    }
  }

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: _key);
    } catch (error) {
      _log.warning('persisted session could not be removed', error: error);
    }
  }

  Future<String?> _read() async {
    try {
      final value = await _storage.read(key: _key);
      return (value == null || value.isEmpty) ? null : value;
    } catch (error) {
      // An unreadable keystore entry (restored backup, OS key rotation) is
      // treated as "signed out" rather than crashing start-up.
      _log.warning('persisted session is unreadable; starting signed out', error: error);
      return null;
    }
  }
}
