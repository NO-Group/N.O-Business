import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/app/app_gate.dart';
import 'package:no_business/app/shell/nav_destinations.dart';
import 'package:no_business/features/tenancy/domain/permissions.dart';

void main() {
  group('resolveRedirect', () {
    test('holds every location on the loading screen while the session resolves', () {
      expect(resolveRedirect(gate: AppGate.loading, location: Routes.invoices), Routes.loading);
      expect(resolveRedirect(gate: AppGate.loading, location: Routes.loading), isNull);
    });

    test('sends signed-out visitors to sign-in but leaves auth pages alone', () {
      expect(resolveRedirect(gate: AppGate.signedOut, location: Routes.dashboard), Routes.signIn);
      expect(
        resolveRedirect(gate: AppGate.signedOut, location: '${Routes.invoices}/abc'),
        Routes.signIn,
      );
      expect(resolveRedirect(gate: AppGate.signedOut, location: Routes.signUp), isNull);
      expect(resolveRedirect(gate: AppGate.signedOut, location: Routes.resetPassword), isNull);
    });

    test('keeps a user without an organization on onboarding', () {
      expect(
        resolveRedirect(gate: AppGate.needsOrganization, location: Routes.sales),
        Routes.onboarding,
      );
      expect(
        resolveRedirect(gate: AppGate.needsOrganization, location: Routes.signIn),
        Routes.onboarding,
      );
      expect(resolveRedirect(gate: AppGate.needsOrganization, location: Routes.onboarding), isNull);
    });

    test('shows the unavailable page when the tenant context failed to load', () {
      expect(resolveRedirect(gate: AppGate.failed, location: Routes.dashboard), Routes.failed);
      expect(resolveRedirect(gate: AppGate.failed, location: Routes.failed), isNull);
    });

    test('moves a ready user off transitional pages and nowhere else', () {
      for (final location in [
        '/',
        Routes.loading,
        Routes.failed,
        Routes.onboarding,
        Routes.signIn,
      ]) {
        expect(
          resolveRedirect(gate: AppGate.ready, location: location),
          Routes.dashboard,
          reason: location,
        );
      }
      expect(resolveRedirect(gate: AppGate.ready, location: Routes.dashboard), isNull);
      expect(resolveRedirect(gate: AppGate.ready, location: '${Routes.customers}/42'), isNull);
    });
  });

  group('navigation', () {
    test('a role without permissions only sees the dashboard and settings', () {
      final paths = visibleDestinations(const {}).map((destination) => destination.path).toList();
      expect(paths, [Routes.dashboard, Routes.settings]);
    });

    test('each module appears only with its read permission', () {
      final paths = visibleDestinations(const {
        Permissions.invoicesRead,
        Permissions.membersRead,
      }).map((destination) => destination.path).toList();
      expect(paths, [Routes.dashboard, Routes.invoices, Routes.team, Routes.settings]);
    });

    test('every destination has a unique path', () {
      final paths = navDestinations.map((destination) => destination.path).toSet();
      expect(paths.length, navDestinations.length);
    });

    test('sub-routes belong to their module', () {
      final all = visibleDestinations(
        navDestinations.map((d) => d.permission).whereType<String>().toSet(),
      );
      expect(all.length, navDestinations.length);
      int indexOf(String path) => all.indexWhere((destination) => destination.path == path);

      expect(destinationIndexFor('${Routes.invoices}/123/edit', all), indexOf(Routes.invoices));
      expect(destinationIndexFor(Routes.sales, all), indexOf(Routes.sales));
      expect(destinationIndexFor('/unknown', all), -1);
      // "/salesforce" must not be mistaken for "/sales".
      expect(destinationIndexFor('${Routes.sales}force', all), -1);
    });
  });
}
