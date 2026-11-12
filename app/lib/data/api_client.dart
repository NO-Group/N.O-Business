import 'dart:convert';

import 'rest_client_io.dart' if (dart.library.html) 'rest_client_web.dart' as impl;

export 'rest_client_io.dart' if (dart.library.html) 'rest_client_web.dart'
    show RestJsonResponse;

/// Authenticated M-TEK DATA API client. A request rejected with HTTP 401 is
/// retried exactly once after a single shared refresh-token exchange.
class ApiClient {
  final String baseUrl;
  String? accessToken;
  Future<bool> Function()? refreshAccessToken;
  Future<bool>? _refreshInFlight;

  ApiClient({required this.baseUrl});

  String? get _cleanToken {
    final token = accessToken?.trim();
    if (token == null || token.isEmpty || token == 'null') return null;
    // JWTs are ASCII and contain exactly three base64url sections. Rejecting
    // control bytes/newlines here prevents malformed Authorization headers.
    if (token.contains(RegExp(r'[\x00-\x20\x7f]')) || token.split('.').length != 3) return null;
    return token;
  }

  Map<String, String> _headers() {
    final token = _cleanToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> _refreshOnce() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final callback = refreshAccessToken;
    if (callback == null) return Future.value(false);
    final future = callback();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  bool get _tokenExpiresSoon {
    final token = _cleanToken;
    if (token == null) return false;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))));
      final expiry = payload is Map ? int.tryParse('${payload['exp'] ?? ''}') : null;
      return expiry != null && expiry <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;
    } catch (_) {
      return true;
    }
  }

  Future<impl.RestJsonResponse?> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    if (_tokenExpiresSoon) await _refreshOnce();
    var response = await impl.httpJson(
      method: method, url: '$baseUrl$path', headers: _headers(), body: body);
    if (response?.status == 401 && await _refreshOnce()) {
      response = await impl.httpJson(
        method: method, url: '$baseUrl$path', headers: _headers(), body: body);
    }
    return response;
  }

  Future<impl.RestJsonResponse?> get(String path) =>
      _request(method: 'GET', path: path);

  Future<impl.RestJsonResponse?> post(String path, Map<String, dynamic> body) =>
      _request(method: 'POST', path: path, body: body);

  /// Authentication routes must never inherit a stale bearer token.
  Future<impl.RestJsonResponse?> postPublic(String path, Map<String, dynamic> body) =>
      impl.httpJson(
        method: 'POST', url: '$baseUrl$path',
        headers: const {'Content-Type': 'application/json'}, body: body);
}
