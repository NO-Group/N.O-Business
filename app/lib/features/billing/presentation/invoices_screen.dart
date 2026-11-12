import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/supabase/query_utils.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/billing_providers.dart';
import '../domain/billing_models.dart';
import 'billing_widgets.dart';

/// Filters offered above the invoice list.
enum InvoiceFilter {
  all('All'),
  draft('Drafts'),
  open('Awaiting payment'),
  overdue('Overdue'),
  paid('Paid');

  const InvoiceFilter(this.label);

  final String label;

  bool matches(Invoice invoice, DateTime today) => switch (this) {
    InvoiceFilter.all => true,
    InvoiceFilter.draft => invoice.isDraft,
    InvoiceFilter.open => invoice.isOpen,
    InvoiceFilter.overdue => invoice.isOverdue(today),
    InvoiceFilter.paid => invoice.status == 'paid',
  };

  static InvoiceFilter fromName(String? name) =>
      InvoiceFilter.values.where((filter) => filter.name == name).firstOrNull ?? InvoiceFilter.all;
}

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key, this.initialStatus});

  /// Name of an [InvoiceFilter] to start on (from `?status=`).
  final String? initialStatus;

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  late InvoiceFilter _filter = InvoiceFilter.fromName(widget.initialStatus);

  @override
  void didUpdateWidget(InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      _filter = InvoiceFilter.fromName(widget.initialStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canProvider(Permissions.invoicesRead))) {
      return const PageScaffold(title: 'Invoices', scrollable: false, child: NoAccessState());
    }
    final canWrite = ref.watch(canProvider(Permissions.invoicesWrite));
    final workspace = ref.watch(activeWorkspaceProvider);
    final invoices = ref.watch(invoicesProvider);
    final today = DateTime.now();

    return PageScaffold(
      title: 'Invoices',
      subtitle: workspace == null
          ? 'Bill customers and track what is owed.'
          : 'Billed from ${workspace.name}.',
      scrollable: false,
      actions: [
        if (canWrite)
          FilledButton.icon(
            onPressed: () => context.go('${Routes.invoices}/new'),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New invoice'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in InvoiceFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: NobSpace.sm),
                    child: ChoiceChip(
                      label: Text(filter.label),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: NobSpace.lg),
          Expanded(
            child: AsyncView(
              value: invoices,
              onRetry: () => ref.invalidate(invoicesProvider),
              builder: (all) {
                final items = all.where((invoice) => _filter.matches(invoice, today)).toList();
                if (items.isEmpty) {
                  final filtered = _filter != InvoiceFilter.all;
                  return EmptyState(
                    icon: Icons.description_outlined,
                    title: filtered ? 'Nothing here' : 'No invoices yet',
                    message: filtered
                        ? 'No invoice matches "${_filter.label}".'
                        : 'Create an invoice to bill a customer. Issue it to assign a number, then '
                              'record payments as they arrive.',
                    action: !filtered && canWrite
                        ? FilledButton(
                            onPressed: () => context.go('${Routes.invoices}/new'),
                            child: const Text('Create an invoice'),
                          )
                        : null,
                  );
                }
                return ListPanel(
                  itemCount: items.length,
                  footer: all.length >= listPageSize
                      ? const Text('Showing the most recent $listPageSize invoices.')
                      : null,
                  itemBuilder: (context, index) => InvoiceRow(invoice: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
