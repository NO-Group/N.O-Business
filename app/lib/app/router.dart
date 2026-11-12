import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/confirm_email_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/billing/presentation/billing_editor.dart';
import '../features/billing/presentation/invoice_detail_screen.dart';
import '../features/billing/presentation/invoices_screen.dart';
import '../features/billing/presentation/quotation_detail_screen.dart';
import '../features/billing/presentation/quotations_screen.dart';
import '../features/catalog/presentation/catalog_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/sales/presentation/new_sale_screen.dart';
import '../features/sales/presentation/sale_detail_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/team/presentation/team_screen.dart';
import '../features/tenancy/presentation/onboarding_screen.dart';
import 'app_gate.dart';
import 'shell/app_shell.dart';
import 'status_screens.dart';

/// Tells the router to re-run its redirect whenever the gate changes.
class _GateListenable extends ChangeNotifier {
  _GateListenable(Ref ref) {
    ref.listen<AppGate>(appGateProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final gateListenable = _GateListenable(ref);
  final router = GoRouter(
    initialLocation: Routes.dashboard,
    refreshListenable: gateListenable,
    redirect: (context, state) =>
        resolveRedirect(gate: ref.read(appGateProvider), location: state.uri.path),
    errorBuilder: (context, state) => NotFoundScreen(onHome: () => context.go(Routes.dashboard)),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.dashboard),
      GoRoute(path: Routes.loading, builder: (_, _) => const LoadingScreen()),
      GoRoute(path: Routes.failed, builder: (_, _) => const UnavailableScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(path: Routes.resetPassword, builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(
        path: Routes.confirmEmail,
        builder: (_, state) => ConfirmEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          _tab(Routes.dashboard, (_) => const DashboardScreen()),
          _tab(
            Routes.sales,
            (_) => const SalesScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => const NewSaleScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) => SaleDetailScreen(saleId: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
          _tab(
            Routes.invoices,
            (state) => InvoicesScreen(initialStatus: state.uri.queryParameters['status']),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, state) =>
                    InvoiceEditorScreen(customerId: state.uri.queryParameters['customer']),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) => InvoiceDetailScreen(invoiceId: state.pathParameters['id'] ?? ''),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => InvoiceEditorScreen(invoiceId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          _tab(
            Routes.quotations,
            (_) => const QuotationsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, state) =>
                    QuotationEditorScreen(customerId: state.uri.queryParameters['customer']),
              ),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    QuotationDetailScreen(quotationId: state.pathParameters['id'] ?? ''),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, state) => QuotationEditorScreen(quotationId: state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
          _tab(
            Routes.customers,
            (_) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => CustomerDetailScreen(customerId: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
          _tab(
            Routes.catalog,
            (state) => CatalogScreen(lowStockOnly: state.uri.queryParameters['stock'] == 'low'),
          ),
          _tab(Routes.documents, (_) => const DocumentsScreen()),
          _tab(Routes.team, (_) => const TeamScreen()),
          _tab(Routes.settings, (_) => const SettingsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    gateListenable.dispose();
  });
  return router;
});

/// A top-level module page. Switching between modules does not animate, so
/// the shell feels like one surface rather than a stack of pages.
GoRoute _tab(
  String path,
  Widget Function(GoRouterState state) builder, {
  List<RouteBase> routes = const [],
}) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => NoTransitionPage<void>(key: state.pageKey, child: builder(state)),
    routes: routes,
  );
}
