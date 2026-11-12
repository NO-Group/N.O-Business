import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../billing/application/billing_providers.dart';
import '../../billing/presentation/billing_widgets.dart';
import '../../sales/application/sales_providers.dart';
import '../../sales/presentation/sales_screen.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/customer_providers.dart';
import '../domain/customer.dart';
import 'customer_form.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void back() => context.go(Routes.customers);
    if (!ref.watch(canProvider(Permissions.customersRead))) {
      return PageScaffold(title: 'Customer', onBack: back, scrollable: false, child: const NoAccessState());
    }
    return DetailLoader<Customer>(
      value: ref.watch(customerProvider(customerId)),
      title: 'Customer',
      onBack: back,
      onRetry: () => ref.invalidate(customerProvider(customerId)),
      builder: (customer) => _CustomerView(customer: customer, onBack: back),
    );
  }
}

class _CustomerView extends ConsumerWidget {
  const _CustomerView({required this.customer, required this.onBack});

  final Customer customer;
  final VoidCallback onBack;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${customer.name}?',
      message: 'The customer record is removed. Customers that appear on sales, quotations or '
          'invoices cannot be deleted, because those records must stay complete.',
      confirmLabel: 'Delete customer',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(customerRepositoryProvider).delete(customer.id);
      ref.invalidate(customersProvider);
      onBack();
    } catch (error) {
      if (context.mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final can = ref.watch(permissionsProvider);
    final createdAt = customer.createdAt;

    return PageScaffold(
      title: customer.name,
      subtitle: customer.isCompany ? 'Company' : 'Individual',
      onBack: onBack,
      actions: [
        if (can.contains(Permissions.quotationsWrite))
          OutlinedButton.icon(
            onPressed: () => context.go('${Routes.quotations}/new?customer=${customer.id}'),
            icon: const Icon(Icons.request_quote_outlined, size: 18),
            label: const Text('New quotation'),
          ),
        if (can.contains(Permissions.invoicesWrite))
          FilledButton.icon(
            onPressed: () => context.go('${Routes.invoices}/new?customer=${customer.id}'),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('New invoice'),
          ),
      ],
      child: TwoPane(
        primary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (can.contains(Permissions.invoicesRead))
              _History(
                title: 'Invoices',
                empty: 'No invoices for this customer yet.',
                value: ref.watch(customerInvoicesProvider(customer.id)),
                row: (invoice) => InvoiceRow(invoice: invoice),
              ),
            if (can.contains(Permissions.quotationsRead)) ...[
              const SizedBox(height: NobSpace.lg),
              _History(
                title: 'Quotations',
                empty: 'No quotations for this customer yet.',
                value: ref.watch(customerQuotationsProvider(customer.id)),
                row: (quotation) => QuotationRow(quotation: quotation),
              ),
            ],
            if (can.contains(Permissions.salesRead)) ...[
              const SizedBox(height: NobSpace.lg),
              _History(
                title: 'Sales',
                empty: 'No sales to this customer yet.',
                value: ref.watch(customerSalesProvider(customer.id)),
                row: (sale) => SaleRow(sale: sale),
              ),
            ],
          ],
        ),
        secondary: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Contact',
              trailing: can.contains(Permissions.customersWrite)
                  ? IconButton(
                      tooltip: 'Edit customer',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => showCustomerForm(context, customer: customer),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LabeledValue(label: 'Email', value: customer.email ?? 'Not provided'),
                  const SizedBox(height: NobSpace.md),
                  LabeledValue(label: 'Phone', value: customer.phone ?? 'Not provided'),
                  const SizedBox(height: NobSpace.md),
                  LabeledValue(label: 'Address', value: customer.address ?? 'Not provided'),
                  if (customer.taxId != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Tax ID', value: customer.taxId!),
                  ],
                  if (customer.notes != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Notes', value: customer.notes!),
                  ],
                  if (createdAt != null) ...[
                    const SizedBox(height: NobSpace.md),
                    LabeledValue(label: 'Customer since', value: formatDate(createdAt)),
                  ],
                ],
              ),
            ),
            if (can.contains(Permissions.customersDelete)) ...[
              const SizedBox(height: NobSpace.lg),
              Align(
                alignment: Alignment.centerLeft,
                child: DangerButton(
                  label: 'Delete customer',
                  icon: Icons.delete_outline_rounded,
                  onPressed: () => _delete(context, ref),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A card listing related records, with inline loading and failure states.
class _History<T> extends StatelessWidget {
  const _History({required this.title, required this.empty, required this.value, required this.row});

  final String title;
  final String empty;
  final AsyncValue<List<T>> value;
  final Widget Function(T item) row;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      flush: true,
      child: value.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(NobSpace.lg),
          child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.fromLTRB(NobSpace.xl, 0, NobSpace.xl, NobSpace.md),
          child: FormMessage(AppFailure.from(error).message),
        ),
        data: (items) => items.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(NobSpace.xl, 0, NobSpace.xl, NobSpace.md),
                child: Text(empty, style: NobText.body.copyWith(color: NobColors.textSecondary)),
              )
            : RowGroup(children: [for (final item in items.take(20)) row(item)]),
      ),
    );
  }
}
