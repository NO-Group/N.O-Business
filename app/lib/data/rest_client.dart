import 'rest_client_io.dart' if (dart.library.html) 'rest_client_web.dart' as impl;

export 'rest_client_io.dart' if (dart.library.html) 'rest_client_web.dart'
    show RestJsonResponse;

/// Supabase client — AUTH ONLY (owner directive 2026-08-30). Business data
/// never touches Supabase; it flows through ApiClient (MongoDB sections).
class RestClient {
  final String baseUrl;
  final String apiKey;
  String? accessToken; // set by AuthStore.remoteSignIn
  RestClient({required this.baseUrl, required this.apiKey});

  /// POST /auth/v1/token?grant_type=password → {access_token, user}
  Future<impl.RestJsonResponse?> authSignInRaw(String email, String password) {
    return impl.httpJson(
      method: 'POST',
      url: '$baseUrl/auth/v1/token?grant_type=password',
      headers: {'apikey': apiKey, 'Content-Type': 'application/json'},
      body: {'email': email, 'password': password},
    );
  }
}
