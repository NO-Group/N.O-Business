import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/guard.dart';

/// The part of a session the app cares about.
class AuthSession {
  const AuthSession({required this.userId, required this.email});

  final String userId;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is AuthSession && other.userId == userId && other.email == email;

  @override
  int get hashCode => Object.hash(userId, email);
}

enum SignUpOutcome {
  /// The project does not require email confirmation; the user is signed in.
  signedIn,

  /// A code was emailed and must be entered to finish creating the account.
  confirmationRequired,
}

/// Email + password authentication against Supabase Auth.
///
/// Email confirmation and password recovery use the six-digit code from the
/// email rather than a link, so the same flow works on Android and Windows
/// without registering URL handlers.
class AuthRepository {
  const AuthRepository(this._auth);

  final GoTrueClient _auth;

  AuthSession? get currentSession => _map(_auth.currentSession);

  /// Emits whenever the user signs in, signs out or the token is refreshed.
  Stream<AuthSession?> sessionChanges() => _auth.onAuthStateChange.map((state) => _map(state.session));

  Future<void> signIn({required String email, required String password}) => guard('auth.sign_in', () async {
        await _auth.signInWithPassword(email: email.trim(), password: password);
      });

  Future<SignUpOutcome> signUp({
    required String fullName,
    required String email,
    required String password,
  }) =>
      guard('auth.sign_up', () async {
        final response = await _auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim()},
        );
        return response.session == null ? SignUpOutcome.confirmationRequired : SignUpOutcome.signedIn;
      });

  Future<void> confirmEmail({required String email, required String code}) => guard('auth.confirm', () async {
        await _auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.signup);
      });

  Future<void> resendConfirmation(String email) => guard('auth.resend', () async {
        await _auth.resend(type: OtpType.signup, email: email.trim());
      });

  Future<void> requestPasswordReset(String email) => guard('auth.reset_request', () async {
        await _auth.resetPasswordForEmail(email.trim());
      });

  /// Verifies the emailed recovery code (which signs the user in) and sets
  /// the new password.
  Future<void> completePasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      guard('auth.reset_complete', () async {
        await _auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.recovery);
        await _auth.updateUser(UserAttributes(password: newPassword));
      });

  Future<void> changePassword(String newPassword) => guard('auth.change_password', () async {
        await _auth.updateUser(UserAttributes(password: newPassword));
      });

  Future<void> signOut() => guard('auth.sign_out', () => _auth.signOut());

  static AuthSession? _map(Session? session) {
    if (session == null) return null;
    return AuthSession(userId: session.user.id, email: session.user.email ?? '');
  }
}
