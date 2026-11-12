import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/components/status_badge.dart';
import '../../core/design_system/tokens.dart';
import '../../core/utils/money.dart';
import '../../features/dashboard/application/dashboard_providers.dart';
import '../../features/tenancy/application/tenancy_providers.dart';
import '../../features/tenancy/domain/permissions.dart';
import '../app_gate.dart';

/// Something that needs the user's attention, derived from live data.
class AttentionItem {
  const AttentionItem({
    required this.icon,
    required this.title,
    required this.detail,
    required this.route,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String route;
  final BadgeTone tone;
}

/// In-app notifications. These are computed from the current state of the
/// organization (overdue invoices, low stock, pending invitations); there is
/// no separate notification store yet.
final attentionItemsProvider = Provider<List<AttentionItem>>((ref) {
  final items = <AttentionItem>[];
  final permissions = ref.watch(permissionsProvider);

  final invitations = ref.watch(myContextProvider).value?.invitations ?? const [];
  if (invitations.isNotEmpty) {
    items.add(
      AttentionItem(
        icon: Icons.mark_email_unread_outlined,
        title: invitations.length == 1
            ? '1 pending invitation'
            : '${invitations.length} pending invitations',
        detail:
            'You have been invited to join ${invitations.first.organizationName}'
            '${invitations.length > 1 ? ' and others' : ''}.',
        route: Routes.settings,
        tone: BadgeTone.info,
      ),
    );
  }

  final summary = ref.watch(dashboardSummaryProvider).value;
  if (summary != null) {
    if (summary.overdueCount > 0 && permissions.contains(Permissions.invoicesRead)) {
      items.add(
        AttentionItem(
          icon: Icons.schedule_rounded,
          title: summary.overdueCount == 1
              ? '1 overdue invoice'
              : '${summary.overdueCount} overdue invoices',
          detail:
              '${Money.format(summary.overdueMinor, summary.currencyCode)} is past its due date.',
          route: '${Routes.invoices}?status=overdue',
          tone: BadgeTone.danger,
        ),
      );
    }
    if (summary.lowStockCount > 0 && permissions.contains(Permissions.catalogRead)) {
      items.add(
        AttentionItem(
          icon: Icons.inventory_outlined,
          title: summary.lowStockCount == 1
              ? '1 item is low on stock'
              : '${summary.lowStockCount} items are low on stock',
          detail: 'At or below the reorder level in this workspace.',
          route: '${Routes.catalog}?stock=low',
          tone: BadgeTone.warning,
        ),
      );
    }
  }
  return items;
});

/// Bell button with a count; opens the list of attention items.
class AttentionButton extends ConsumerWidget {
  const AttentionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(attentionItemsProvider);
    return MenuAnchor(
      alignmentOffset: const Offset(0, NobSpace.sm),
      builder: (context, controller, _) => IconButton(
        tooltip: items.isEmpty ? 'Notifications' : 'Notifications (${items.length})',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: Badge(
          isLabelVisible: items.isNotEmpty,
          label: Text('${items.length}'),
          backgroundColor: NobColors.magenta,
          textColor: NobColors.onAccent,
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ),
      menuChildren: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(NobSpace.lg),
            child: SizedBox(
              width: 280,
              child: Text(
                'Nothing needs your attention right now.',
                style: NobText.body.copyWith(color: NobColors.textSecondary),
              ),
            ),
          )
        else
          for (final item in items)
            MenuItemButton(
              onPressed: () => context.go(item.route),
              leadingIcon: Icon(item.icon, color: StatusBadge.colorOf(item.tone)),
              child: SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: NobSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.title, style: NobText.subtitle),
                      const SizedBox(height: NobSpace.xxs),
                      Text(
                        item.detail,
                        style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
