import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Biometric convenience + the OS credential vault used for session tokens.
///
/// EVERY vault operation is exception-safe. On Android the RSA key behind
/// `flutter_secure_storage` lives in the Keystore and can be invalidated by a
/// lockscreen change, a backup/restore, an OS upgrade or a read before first
/// unlock; Windows DPAPI can fail the same way. A `PlatformException` from the
/// vault must never escape into the session-restore pipeline, because that
/// used to abort restore entirely and show the login screen to a signed-in
/// user. The app-private JSON recovery copy handles the data loss instead.
class BiometricService {
  BiometricService._() {
    // Remove the obsolete secondary-signing credential from upgraded devices.
    unawaited(_delete('bio_signature'));
  }
  static final instance = BiometricService._();
  final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> saveLogin(String email, String password) async {
    await _write('bio_email', email);
    await _write('bio_password', password);
  }

  Future<(String, String)?> login() async {
    if (!await authenticate('Sign in to MFSL Office')) return null;
    final e = await _read('bio_email');
    final p = await _read('bio_password');
    return e == null || p == null ? null : (e, p);
  }

  /// Session tokens are credentials too. Keep them in the OS credential vault
  /// even when biometric convenience is disabled.
  Future<void> saveSession(String value) => _write('auth_session', value);
  Future<String?> session() => _read('auth_session');
  Future<void> clearSession() => _delete('auth_session');

  /// Clear only biometric convenience secrets; never sign the user out as a
  /// side effect of disabling biometrics.
  Future<void> clear() async {
    await _delete('bio_email');
    await _delete('bio_password');
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (error) {
      debugPrint('secure storage write failed ($key): $error');
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (error) {
      debugPrint('secure storage read failed ($key): $error');
      return null;
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (error) {
      debugPrint('secure storage delete failed ($key): $error');
    }
  }
}
