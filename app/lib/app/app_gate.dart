import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_providers.dart';
import '../features/tenancy/application/tenancy_providers.dart';

/// Where the user stands, which decides the part of the app they may see.
enum AppGate {
  /// Session or tenant context is still being resolved.
  loading,

  /// Nobody is signed in.
  signedOut,

  /// Signed in, but the tenant context could not be loaded.
  failed,

  /// Signed in but not a member of any organization yet.
  needsOrganization,

  /// Signed in with at least one organization.
  ready,
}

final appGateProvider = Provider<AppGate>((ref) {
  final session = ref.watch(sessionProvider);
  if (!session.hasValue) {
    return session.hasError ? AppGate.signedOut : AppGate.loading;
  }
  if (session.value == null) return AppGate.signedOut;

  final context = ref.watch(myContextProvider);
  final value = context.value;
  if (value == null) {
    return context.hasError ? AppGate.failed : AppGate.loading;
  }
  return value.memberships.isEmpty ? AppGate.needsOrganization : AppGate.ready;
});

/// Route paths. Kept in one place so redirects and navigation agree.
abstract final class Routes {
  static const loading = '/loading';
  static const failed = '/unavailable';
  static const onboarding = '/onboarding';

  static const signIn = '/auth/sign-in';
  static const signUp = '/auth/sign-up';
  static const confirmEmail = '/auth/confirm';
  static const resetPassword = '/auth/reset';

  static const dashboard = '/dashboard';
  static const sales = '/sales';
  static const quotations = '/quotations';
  static const invoices = '/invoices';
  static const customers = '/customers';
  static const catalog = '/catalog';
  static const documents = '/documents';
  static const team = '/team';
  static const settings = '/settings';
}

/// Pure routing rule: given the gate and the requested location, returns the
/// location to go to instead, or null to stay.
String? resolveRedirect({required AppGate gate, required String location}) {
  final onAuthRoute = location.startsWith('/auth/');
  switch (gate) {
    case AppGate.loading:
      return location == Routes.loading ? null : Routes.loading;
    case AppGate.failed:
      return location == Routes.failed ? null : Routes.failed;
    case AppGate.signedOut:
      return onAuthRoute ? null : Routes.signIn;
    case AppGate.needsOrganization:
      return location == Routes.onboarding ? null : Routes.onboarding;
    case AppGate.ready:
      final transitional =
          onAuthRoute ||
          location == '/' ||
          location == Routes.loading ||
          location == Routes.failed ||
          location == Routes.onboarding;
      return transitional ? Routes.dashboard : null;
  }
}
