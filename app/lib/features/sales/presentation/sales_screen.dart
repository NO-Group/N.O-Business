import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/components/status_badge.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/supabase/query_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/sales_providers.dart';
import '../domain/sale.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canProvider(Permissions.salesRead))) {
      return const PageScaffold(title: 'Sales', scrollable: false, child: NoAccessState());
    }
    final canCreate = ref.watch(canProvider(Permissions.salesCreate));
    final workspace = ref.watch(activeWorkspaceProvider);
    final sales = ref.watch(salesProvider);

    return PageScaffold(
      title: 'Sales',
      subtitle: workspace == null
          ? 'Sales paid for on the spot.'
          : 'Sales paid for on the spot in ${workspace.name}.',
      scrollable: false,
      actions: [
        if (canCreate)
          FilledButton.icon(
            onPressed: () => context.go('${Routes.sales}/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New sale'),
          ),
      ],
      child: AsyncView(
        value: sales,
        onRetry: () => ref.invalidate(salesProvider),
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.point_of_sale_outlined,
              title: 'No sales yet',
              message:
                  'Record a sale when a customer pays straight away. Stock is reduced and the '
                  'amount shows up on the dashboard.',
              action: canCreate
                  ? FilledButton(
                      onPressed: () => context.go('${Routes.sales}/new'),
                      child: const Text('Record a sale'),
                    )
                  : null,
            );
          }
          return ListPanel(
            itemCount: items.length,
            footer: items.length >= listPageSize
                ? const Text('Showing the most recent $listPageSize sales.')
                : null,
            itemBuilder: (context, index) => SaleRow(sale: items[index]),
          );
        },
      ),
    );
  }
}

/// One sale in a list. Also used on the customer page.
class SaleRow extends StatelessWidget {
  const SaleRow({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final soldAt = sale.soldAt;
    return ListRow(
      leading: RowIcon(
        Icons.receipt_long_outlined,
        color: sale.isVoided ? NobColors.textMuted : NobColors.emerald,
      ),
      title: sale.number,
      subtitle: [
        sale.customerName ?? 'Walk-in customer',
        if (soldAt != null) formatDateTime(soldAt),
        humanize(sale.paymentMethod),
      ].join(' · '),
      trailing: TrailingAmount(
        amount: Money.format(sale.totals.totalMinor, sale.currencyCode),
        below: sale.isVoided ? const StatusBadge(label: 'Voided', tone: BadgeTone.danger) : null,
      ),
      onTap: () => context.go('${Routes.sales}/${sale.id}'),
    );
  }
}
