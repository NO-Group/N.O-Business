import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/supabase/query_utils.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/billing_providers.dart';
import 'billing_widgets.dart';

class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(canProvider(Permissions.quotationsRead))) {
      return const PageScaffold(title: 'Quotations', scrollable: false, child: NoAccessState());
    }
    final canWrite = ref.watch(canProvider(Permissions.quotationsWrite));
    final workspace = ref.watch(activeWorkspaceProvider);
    final quotations = ref.watch(quotationsProvider);

    return PageScaffold(
      title: 'Quotations',
      subtitle: workspace == null
          ? 'Price offers you can turn into invoices.'
          : 'Price offers from ${workspace.name}.',
      scrollable: false,
      actions: [
        if (canWrite)
          FilledButton.icon(
            onPressed: () => context.go('${Routes.quotations}/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New quotation'),
          ),
      ],
      child: AsyncView(
        value: quotations,
        onRetry: () => ref.invalidate(quotationsProvider),
        builder: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.request_quote_outlined,
              title: 'No quotations yet',
              message:
                  'Send a customer a price before they commit. An accepted quotation becomes '
                  'an invoice in one step.',
              action: canWrite
                  ? FilledButton(
                      onPressed: () => context.go('${Routes.quotations}/new'),
                      child: const Text('Create a quotation'),
                    )
                  : null,
            );
          }
          return ListPanel(
            itemCount: items.length,
            footer: items.length >= listPageSize
                ? const Text('Showing the most recent $listPageSize quotations.')
                : null,
            itemBuilder: (context, index) => QuotationRow(quotation: items[index]),
          );
        },
      ),
    );
  }
}
