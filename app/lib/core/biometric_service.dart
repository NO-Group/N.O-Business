import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._() {
    // Remove the obsolete secondary-signing credential from upgraded devices.
    _storage.delete(key: 'bio_${'signature'}');
  }
  static final instance = BiometricService._();
  final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();

  Future<bool> available() async {
    try { return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics; }
    catch (_) { return false; }
  }

  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true));
    } catch (_) { return false; }
  }

  Future<void> saveLogin(String email, String password) async {
    await _storage.write(key: 'bio_email', value: email);
    await _storage.write(key: 'bio_password', value: password);
  }
  Future<(String, String)?> login() async {
    if (!await authenticate('Sign in to MFSL Office')) return null;
    final e = await _storage.read(key: 'bio_email'), p = await _storage.read(key: 'bio_password');
    return e == null || p == null ? null : (e, p);
  }

  /// Session tokens are credentials too. Keep them in the OS credential vault
  /// even when biometric convenience is disabled.
  Future<void> saveSession(String value) => _storage.write(key: 'auth_session', value: value);
  Future<String?> session() => _storage.read(key: 'auth_session');
  Future<void> clearSession() => _storage.delete(key: 'auth_session');

  /// Clear only biometric convenience secrets; never sign the user out as a
  /// side effect of disabling biometrics.
  Future<void> clear() async {
    await _storage.delete(key: 'bio_email');
    await _storage.delete(key: 'bio_password');
  }
}
