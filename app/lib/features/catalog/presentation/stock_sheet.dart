import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';

/// Stock on hand, recent movements and (with permission) a manual adjustment
/// for one item in the active workspace.
Future<void> showStockSheet(BuildContext context, Product product) =>
    showNobSheet<void>(context, child: StockSheet(product: product));

class StockSheet extends ConsumerStatefulWidget {
  const StockSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<StockSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  String _reason = stockAdjustmentReasons.first;
  bool _saving = false;
  String? _error;
  double? _onHand;

  /// Damage always removes stock; a correction may go either way.
  bool get _removes => _reason == 'damage';
  bool get _signed => _reason == 'adjustment';

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final workspaceId = ref.read(activeWorkspaceProvider)?.id;
    if (workspaceId == null) return;
    final entered = double.parse(_quantity.text.trim());
    final delta = _removes ? -entered.abs() : entered;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final quantity = await ref.read(catalogRepositoryProvider).adjustStock(
            workspaceId: workspaceId,
            productId: widget.product.id,
            quantityDelta: delta,
            reason: _reason,
            note: nullIfBlank(_note.text),
          );
      ref.invalidate(productsProvider);
      ref.invalidate(sellableProductsProvider);
      ref.invalidate(stockMovementsProvider(widget.product.id));
      ref.invalidate(dashboardSummaryProvider);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _onHand = quantity;
        _quantity.clear();
        _note.clear();
      });
      showNobSnack(context, 'Stock updated.', tone: SnackTone.success);
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
    final product = widget.product;
    final workspace = ref.watch(activeWorkspaceProvider);
    final canAdjust = ref.watch(canProvider(Permissions.inventoryAdjust));
    final movements = ref.watch(stockMovementsProvider(product.id));
    final onHand = _onHand ?? product.stockIn(workspace?.id);
    final error = _error;

    return SheetScaffold(
      title: product.name,
      subtitle: workspace == null ? null : 'Stock in ${workspace.name}',
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        if (canAdjust) PrimaryButton(label: 'Apply change', onPressed: _apply, loading: _saving),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: LabeledValue(
                  label: 'On hand',
                  value: '${formatQuantity(onHand)} ${product.unit}',
                  valueStyle: NobText.metric,
                ),
              ),
              Expanded(
                child: LabeledValue(
                  label: 'Reorder level',
                  value: '${formatQuantity(product.reorderLevel)} ${product.unit}',
                ),
              ),
            ],
          ),
          if (canAdjust) ...[
            const SizedBox(height: NobSpace.xl),
            const Text('Record a change', style: NobText.subtitle),
            const SizedBox(height: NobSpace.md),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: [
                      for (final reason in stockAdjustmentReasons)
                        DropdownMenuItem(value: reason, child: Text(_reasonLabel(reason))),
                    ],
                    onChanged: (value) => setState(() => _reason = value ?? _reason),
                  ),
                  const SizedBox(height: NobSpace.lg),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.numberWithOptions(decimal: true, signed: _signed),
                    decoration: InputDecoration(
                      labelText: _removes ? 'Quantity removed' : 'Quantity',
                      helperText: _signed
                          ? 'Use a negative number to reduce stock.'
                          : _removes
                              ? 'This quantity is taken off the stock on hand.'
                              : 'This quantity is added to the stock on hand.',
                    ),
                    validator: (value) {
                      final number = double.tryParse((value ?? '').trim());
                      if (number == null || number == 0) return 'Enter a quantity';
                      if (!_signed && number < 0) return 'Enter a positive quantity';
                      return null;
                    },
                  ),
                  const SizedBox(height: NobSpace.lg),
                  TextFormField(
                    controller: _note,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Note (optional)', counterText: ''),
                  ),
                ],
              ),
            ),
          ],
          if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          const SizedBox(height: NobSpace.xl),
          const Text('Recent movements', style: NobText.subtitle),
          const SizedBox(height: NobSpace.sm),
          movements.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(NobSpace.lg),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (error, _) => FormMessage(AppFailure.from(error).message),
            data: (items) => items.isEmpty
                ? Text(
                    'No stock has moved for this item here yet.',
                    style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
                  )
                : RowGroup(
                    children: [
                      for (final movement in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: NobSpace.sm),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_reasonLabel(movement.reason), style: NobText.body),
                                    Text(
                                      [
                                        if (movement.createdAt != null) formatDateTime(movement.createdAt!),
                                        ?movement.note,
                                      ].join(' · '),
                                      style: NobText.label.copyWith(color: NobColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${movement.quantityDelta > 0 ? '+' : ''}${formatQuantity(movement.quantityDelta)}',
                                style: NobText.numeric.copyWith(
                                  color: movement.quantityDelta > 0 ? NobColors.success : NobColors.danger,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _reasonLabel(String reason) => switch (reason) {
      'opening' => 'Opening stock',
      'purchase' => 'Stock received',
      'adjustment' => 'Count correction',
      'damage' => 'Damaged or lost',
      'return' => 'Customer return',
      'sale' => 'Sale',
      'sale_void' => 'Sale voided',
      'invoice' => 'Invoice issued',
      'invoice_void' => 'Invoice voided',
      _ => humanize(reason),
    };
