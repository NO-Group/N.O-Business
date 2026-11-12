import 'dart:convert';

/// Pure helpers for the persisted session blob.
///
/// Deliberately free of Flutter / platform imports so the session-recovery
/// rules can be unit-tested on their own. The blob is:
///
/// ```
/// { refresh_token, email, name, role, saved_at }
/// ```
///
/// Two copies are kept: the OS credential vault (primary) and the app-private
/// JSON file (recovery). See `AuthStore._persistSession` for why.
abstract final class SessionBlob {
  /// Key used by `local_store` (`mtek_session.json`).
  static const String localKey = 'session';

  /// Decodes ONE copy. A corrupt/truncated/empty copy returns null instead of
  /// throwing — the other copy may still be perfectly healthy.
  static Map<String, dynamic>? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // One unreadable copy must never hide the other one.
    }
    return null;
  }

  /// Refresh tokens are opaque ASCII with no whitespace/control characters.
  static bool validToken(String? token) {
    final value = token?.trim() ?? '';
    return value.isNotEmpty && !value.contains(RegExp(r'[\x00-\x20\x7f]'));
  }

  static String? refreshToken(Map<String, dynamic>? blob) {
    if (blob == null) return null;
    final value = '${blob['refresh_token'] ?? ''}'.trim();
    return validToken(value) ? value : null;
  }

  static String? email(Map<String, dynamic>? blob) {
    if (blob == null) return null;
    final value = '${blob['email'] ?? ''}'.trim().toLowerCase();
    return value.contains('@') ? value : null;
  }

  /// Every DISTINCT usable refresh token, vault copy first. Supabase rotates
  /// refresh tokens, so a crash between the two writes can leave the copies
  /// out of sync; trying both is how a half-written rotation is recovered.
  static List<String> refreshTokens(Iterable<Map<String, dynamic>> blobs) {
    final tokens = <String>[];
    for (final blob in blobs) {
      final token = refreshToken(blob);
      if (token != null && !tokens.contains(token)) tokens.add(token);
    }
    return tokens;
  }

  /// Best cached identity. Prefer a copy that ALSO carries a refresh token
  /// (it is the most recent complete session), but never reject an
  /// identity-only legacy copy: that copy is enough to keep the user signed
  /// in while the cloud reconnects.
  static Map<String, dynamic>? identity(Iterable<Map<String, dynamic>> blobs) {
    Map<String, dynamic>? fallback;
    for (final blob in blobs) {
      if (email(blob) == null) continue;
      if (refreshToken(blob) != null) return blob;
      fallback ??= blob;
    }
    return fallback;
  }
}
