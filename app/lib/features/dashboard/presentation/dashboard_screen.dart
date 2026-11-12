import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../app/shell/nav_destinations.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/metric_tile.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/dashboard_providers.dart';
import '../domain/dashboard_summary.dart';
import 'revenue_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(activeOrganizationProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final workspaces = ref.watch(workspacesProvider).value ?? const [];
    final permissions = ref.watch(permissionsProvider);
    final filter = ref.watch(dashboardFilterProvider);
    final canReports = permissions.contains(Permissions.reportsView);
    final manyWorkspaces = workspaces.where((w) => !w.isArchived).length > 1;

    final scope = filter.allWorkspaces || workspace == null ? 'All workspaces' : workspace.name;

    return PageScaffold(
      title: organization?.name ?? 'Dashboard',
      subtitle: canReports ? '$scope · last ${filter.days} days' : 'Welcome back.',
      actions: [
        if (permissions.contains(Permissions.salesCreate))
          OutlinedButton.icon(
            onPressed: () => context.go('${Routes.sales}/new'),
            icon: const Icon(Icons.point_of_sale_outlined, size: 18),
            label: const Text('New sale'),
          ),
        if (permissions.contains(Permissions.invoicesWrite))
          FilledButton.icon(
            onPressed: () => context.go('${Routes.invoices}/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New invoice'),
          ),
      ],
      child: canReports
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: NobSpace.md,
                  runSpacing: NobSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7 days')),
                        ButtonSegment(value: 30, label: Text('30 days')),
                        ButtonSegment(value: 90, label: Text('90 days')),
                      ],
                      selected: {filter.days},
                      onSelectionChanged: (selection) =>
                          ref.read(dashboardFilterProvider.notifier).setDays(selection.first),
                    ),
                    if (manyWorkspaces)
                      FilterChip(
                        label: const Text('All workspaces'),
                        selected: filter.allWorkspaces,
                        onSelected: (value) =>
                            ref.read(dashboardFilterProvider.notifier).setAllWorkspaces(value),
                      ),
                  ],
                ),
                const SizedBox(height: NobSpace.lg),
                _SummaryView(value: ref.watch(dashboardSummaryProvider), permissions: permissions),
              ],
            )
          : _ModuleLinks(permissions: permissions),
    );
  }
}

class _SummaryView extends ConsumerWidget {
  const _SummaryView({required this.value, required this.permissions});

  final AsyncValue<DashboardSummary?> value;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return value.when(
      loading: () => const SizedBox(height: 320, child: LoadingView()),
      error: (error, _) => SizedBox(
        height: 320,
        child: ErrorState(
          message: AppFailure.from(error).message,
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
      ),
      data: (summary) {
        if (summary == null) return const SizedBox(height: 320, child: LoadingView());
        return _Summary(summary: summary, permissions: permissions);
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary, required this.permissions});

  final DashboardSummary summary;
  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final currency = summary.currencyCode;
    final change = summary.collectedChange;
    String money(int minor) => Money.format(minor, currency);
    VoidCallback? link(String permission, String route) =>
        permissions.contains(permission) ? () => context.go(route) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          minItemWidth: 220,
          children: [
            MetricTile(
              label: 'Money received',
              value: money(summary.collectedMinor),
              icon: Icons.account_balance_wallet_outlined,
              color: NobColors.emerald,
              caption: change == null
                  ? 'No earlier period to compare'
                  : '${change >= 0 ? '+' : ''}${(change * 100).toStringAsFixed(0)}% vs previous period',
              captionColor: change == null
                  ? null
                  : change >= 0
                      ? NobColors.success
                      : NobColors.danger,
            ),
            MetricTile(
              label: 'Sales',
              value: money(summary.salesTotalMinor),
              icon: Icons.point_of_sale_outlined,
              caption: summary.salesCount == 1 ? '1 sale' : '${summary.salesCount} sales',
              onTap: link(Permissions.salesRead, Routes.sales),
            ),
            MetricTile(
              label: 'Owed to you',
              value: money(summary.receivablesMinor),
              icon: Icons.hourglass_bottom_rounded,
              color: NobColors.cobalt,
              caption: summary.openInvoicesCount == 1
                  ? '1 open invoice'
                  : '${summary.openInvoicesCount} open invoices',
              onTap: link(Permissions.invoicesRead, '${Routes.invoices}?status=open'),
            ),
            MetricTile(
              label: 'Overdue',
              value: money(summary.overdueMinor),
              icon: Icons.schedule_rounded,
              color: summary.overdueCount > 0 ? NobColors.danger : NobColors.textSecondary,
              caption: summary.overdueCount == 0
                  ? 'Nothing overdue'
                  : summary.overdueCount == 1
                      ? '1 invoice past due'
                      : '${summary.overdueCount} invoices past due',
              captionColor: summary.overdueCount > 0 ? NobColors.danger : null,
              onTap: link(Permissions.invoicesRead, '${Routes.invoices}?status=overdue'),
            ),
            MetricTile(
              label: 'Open quotations',
              value: money(summary.openQuotationsMinor),
              icon: Icons.request_quote_outlined,
              color: NobColors.violet,
              caption: summary.openQuotationsCount == 1
                  ? '1 awaiting a decision'
                  : '${summary.openQuotationsCount} awaiting a decision',
              onTap: link(Permissions.quotationsRead, Routes.quotations),
            ),
            MetricTile(
              label: 'Customers',
              value: '${summary.customersCount}',
              icon: Icons.groups_2_outlined,
              caption: 'In this organization',
              onTap: link(Permissions.customersRead, Routes.customers),
            ),
            MetricTile(
              label: 'Low stock',
              value: '${summary.lowStockCount}',
              icon: Icons.inventory_outlined,
              color: summary.lowStockCount > 0 ? NobColors.warning : NobColors.textSecondary,
              caption: summary.lowStockCount == 0 ? 'Stock levels are healthy' : 'At or below reorder level',
              onTap: link(Permissions.catalogRead, '${Routes.catalog}?stock=low'),
            ),
          ],
        ),
        const SizedBox(height: NobSpace.lg),
        SectionCard(
          title: 'Money received per day',
          subtitle: 'Counter sales and payments recorded against invoices.',
          child: summary.hasActivity
              ? RevenueChart(points: summary.daily, currencyCode: currency)
              : const _QuietPeriod(),
        ),
        const SizedBox(height: NobSpace.lg),
        ResponsiveGrid(
          minItemWidth: 320,
          children: [
            SectionCard(
              title: 'Best sellers',
              subtitle: 'By value sold in this period.',
              child: summary.topProducts.isEmpty
                  ? const _Hint('Items you sell will be ranked here.')
                  : ShareBars(
                      color: NobColors.cyan,
                      rows: [
                        for (final product in summary.topProducts)
                          (
                            label: '${product.name} · ${formatQuantity(product.quantity)} sold',
                            value: money(product.totalMinor),
                            amount: product.totalMinor,
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'How customers paid',
              subtitle: 'Sales and invoice payments by method.',
              child: summary.paymentMethods.isEmpty
                  ? const _Hint('Payment methods appear once money has been received.')
                  : ShareBars(
                      color: NobColors.violet,
                      rows: [
                        for (final method in summary.paymentMethods)
                          (
                            label: humanize(method.method),
                            value: money(method.totalMinor),
                            amount: method.totalMinor,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: NobText.body.copyWith(color: NobColors.textSecondary));
}

class _QuietPeriod extends StatelessWidget {
  const _QuietPeriod();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NobSpace.xl),
      child: Column(
        children: [
          const Icon(Icons.show_chart_rounded, size: 32, color: NobColors.textMuted),
          const SizedBox(height: NobSpace.md),
          Text(
            'No money was received in this period.',
            style: NobText.subtitle.copyWith(color: NobColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: NobSpace.xs),
          Text(
            'Record a sale or an invoice payment and it will be charted here.',
            style: NobText.bodySmall.copyWith(color: NobColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Dashboard for roles without access to reports: a way into each module
/// they can open, instead of an empty page.
class _ModuleLinks extends StatelessWidget {
  const _ModuleLinks({required this.permissions});

  final Set<String> permissions;

  @override
  Widget build(BuildContext context) {
    final destinations =
        visibleDestinations(permissions).where((destination) => destination.path != Routes.dashboard).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your role does not include business reports. Here is what you can work on.',
          style: NobText.body.copyWith(color: NobColors.textSecondary),
        ),
        const SizedBox(height: NobSpace.lg),
        NobCard(
          padding: EdgeInsets.zero,
          child: RowGroup(
            children: [
              for (final destination in destinations)
                ListRow(
                  leading: RowIcon(destination.icon),
                  title: destination.label,
                  subtitle: destination.section,
                  trailing: const Icon(Icons.chevron_right_rounded, color: NobColors.textMuted),
                  onTap: () => context.go(destination.path),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
