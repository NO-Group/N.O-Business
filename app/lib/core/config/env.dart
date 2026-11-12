import 'dart:convert';

/// Build-time configuration.
///
/// Nothing is baked into the source tree: the backend is supplied when the
/// app is built, e.g.
///
/// ```
/// flutter build apk \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<publishable or anon key>
/// ```
///
/// Only the *public* client key belongs here. [validate] refuses to start
/// with a privileged key, because anything compiled into a client binary can
/// be extracted from it.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  /// Null when the configuration is usable, otherwise a human-readable reason.
  static String? validate({required String url, required String key}) {
    if (url.isEmpty || key.isEmpty) {
      return 'SUPABASE_URL and SUPABASE_ANON_KEY were not provided at build time.';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) {
      return 'SUPABASE_URL is not a valid URL.';
    }
    final isLocal = uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '10.0.2.2';
    if (uri.scheme != 'https' && !isLocal) {
      return 'SUPABASE_URL must use https.';
    }
    if (isPrivilegedKey(key)) {
      return 'A privileged (service-role / secret) key was supplied. '
          'Client builds accept only the public key.';
    }
    return null;
  }

  /// True for Supabase secret keys and for JWTs whose role is not the public
  /// `anon` role.
  static bool isPrivilegedKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      if (payload is Map<String, dynamic>) {
        final role = payload['role'];
        return role is String && role != 'anon';
      }
    } on FormatException {
      return false;
    }
    return false;
  }
}

/// Resolved configuration, injectable so tests can supply their own.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.appVersion,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: Env.supabaseUrl,
    supabaseAnonKey: Env.supabaseAnonKey,
    appVersion: Env.appVersion,
  );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String appVersion;

  String? get problem => Env.validate(url: supabaseUrl, key: supabaseAnonKey);
  bool get isUsable => problem == null;
}
