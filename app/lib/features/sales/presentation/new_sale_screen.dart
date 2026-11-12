import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_gate.dart';
import '../../../core/commerce/line_item.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/nob_card.dart';
import '../../../core/design_system/components/page_scaffold.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/reference/reference_data.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/line_items_editor.dart';
import '../../customers/domain/customer.dart';
import '../../customers/presentation/customer_picker.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/sales_providers.dart';

/// Point-of-sale entry: pick items, take payment, done.
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _discount = TextEditingController();
  final _note = TextEditingController();
  List<DraftLine> _lines = const [];
  Customer? _customer;
  String _method = paymentMethods.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _discount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _complete(String currency) async {
    if (_saving) return;
    final organizationId = ref.read(activeOrganizationIdProvider);
    final workspaceId = ref.read(activeWorkspaceProvider)?.id;
    if (organizationId == null || workspaceId == null) return;
    final discount = _discount.text.trim().isEmpty ? 0 : Money.parse(_discount.text, currency);
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    if (discount == null) {
      setState(() => _error = 'Enter the discount as an amount, for example 500.00.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(salesRepositoryProvider).record(
            organizationId: organizationId,
            workspaceId: workspaceId,
            customerId: _customer?.id,
            paymentMethod: _method,
            lines: _lines,
            discountMinor: discount,
            note: nullIfBlank(_note.text),
          );
      ref.invalidate(salesProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(sellableProductsProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) context.go('${Routes.sales}/$id');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppFailure.from(error).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    void back() => context.go(Routes.sales);
    if (!ref.watch(canProvider(Permissions.salesCreate))) {
      return PageScaffold(title: 'New sale', onBack: back, scrollable: false, child: const NoAccessState());
    }
    final organization = ref.watch(activeOrganizationProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = organization?.currencyCode ?? 'USD';
    final totals = DocumentTotals.preview(
      _lines,
      discountMinor: Money.parse(_discount.text, currency) ?? 0,
    );
    final customer = _customer;
    final error = _error;

    return PageScaffold(
      title: 'New sale',
      subtitle: workspace == null ? null : 'Sold from ${workspace.name}',
      onBack: back,
      child: TwoPane(
        primary: SectionCard(
          title: 'Items',
          child: LineItemsEditor(
            lines: _lines,
            onChanged: (lines) => setState(() => _lines = lines),
            currencyCode: currency,
            defaultTaxRate: organization?.defaultTaxRate ?? 0,
          ),
        ),
        secondary: NobCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Payment', style: NobText.title),
              const SizedBox(height: NobSpace.lg),
              CustomerField(
                customer: customer,
                optional: true,
                onPick: () async {
                  final picked = await showCustomerPicker(context);
                  if (picked != null && mounted) setState(() => _customer = picked);
                },
                onClear: () => setState(() => _customer = null),
              ),
              const SizedBox(height: NobSpace.lg),
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: [
                  for (final method in paymentMethods)
                    DropdownMenuItem(value: method, child: Text(humanize(method))),
                ],
                onChanged: (value) => setState(() => _method = value ?? _method),
              ),
              const SizedBox(height: NobSpace.lg),
              TextField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Discount ($currency, optional)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: NobSpace.lg),
              TextField(
                controller: _note,
                maxLength: 1000,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note (optional)', counterText: ''),
              ),
              const SizedBox(height: NobSpace.lg),
              TotalsSummary(totals: totals, currencyCode: currency),
              if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
              const SizedBox(height: NobSpace.lg),
              PrimaryButton(
                label: 'Complete sale',
                icon: Icons.check_rounded,
                expanded: true,
                loading: _saving,
                onPressed: _lines.isEmpty ? null : () => _complete(currency),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
