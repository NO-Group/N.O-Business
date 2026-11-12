import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/commerce/line_item.dart';
import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/components/list_panel.dart';
import '../../../core/design_system/components/state_views.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../../tenancy/domain/permissions.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';

/// Editable list of document lines with a running subtotal per line.
///
/// Used by the sale, quotation and invoice editors so they all behave the
/// same way. The parent owns the list.
class LineItemsEditor extends StatelessWidget {
  const LineItemsEditor({
    super.key,
    required this.lines,
    required this.onChanged,
    required this.currencyCode,
    required this.defaultTaxRate,
  });

  final List<DraftLine> lines;
  final ValueChanged<List<DraftLine>> onChanged;
  final String currencyCode;
  final double defaultTaxRate;

  Future<void> _add(BuildContext context) async {
    final line = await showNobSheet<DraftLine>(
      context,
      child: _ProductPicker(currencyCode: currencyCode, defaultTaxRate: defaultTaxRate),
    );
    if (line == null) return;
    // Picking the same catalogue item again raises its quantity.
    final existing = line.productId == null
        ? -1
        : lines.indexWhere((l) => l.productId == line.productId && l.unitPriceMinor == line.unitPriceMinor);
    if (existing >= 0) {
      final updated = [...lines];
      updated[existing] = lines[existing].copyWith(quantity: lines[existing].quantity + line.quantity);
      onChanged(updated);
    } else {
      onChanged([...lines, line]);
    }
  }

  Future<void> _edit(BuildContext context, int index) async {
    final edited = await showNobSheet<DraftLine>(
      context,
      child: _LineForm(line: lines[index], currencyCode: currencyCode),
    );
    if (edited == null) return;
    final updated = [...lines];
    updated[index] = edited;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NobSpace.lg),
            child: Text(
              'No items yet. Add something from your catalogue or a one-off line.',
              style: NobText.body.copyWith(color: NobColors.textSecondary),
            ),
          )
        else
          RowGroup(
            children: [
              for (var i = 0; i < lines.length; i++)
                InkWell(
                  onTap: () => _edit(context, i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: NobSpace.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lines[i].description, style: NobText.subtitle),
                              const SizedBox(height: NobSpace.xxs),
                              Text(
                                '${formatQuantity(lines[i].quantity)} × '
                                '${Money.format(lines[i].unitPriceMinor, currencyCode)}'
                                '${lines[i].taxRate > 0 ? ' · tax ${formatQuantity(lines[i].taxRate)}%' : ''}',
                                style: NobText.bodySmall.copyWith(color: NobColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: NobSpace.md),
                        Text(Money.format(lines[i].lineTotalMinor, currencyCode), style: NobText.numeric),
                        IconButton(
                          tooltip: 'Remove ${lines[i].description}',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => onChanged([...lines]..removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: NobSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: lines.length >= 200 ? null : () => _add(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item'),
          ),
        ),
      ],
    );
  }
}

/// Subtotal / discount / tax / total block shown under the lines.
class TotalsSummary extends StatelessWidget {
  const TotalsSummary({super.key, required this.totals, required this.currencyCode, this.extra = const []});

  final DocumentTotals totals;
  final String currencyCode;

  /// Additional rows under the total, e.g. "Paid" and "Balance due".
  final List<(String, int)> extra;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int minor, {bool strong = false, bool negative = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: NobSpace.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: strong ? NobText.subtitle : NobText.body.copyWith(color: NobColors.textSecondary),
                ),
              ),
              Text(
                '${negative ? '− ' : ''}${Money.format(minor, currencyCode)}',
                style: strong ? NobText.title.copyWith(fontFeatures: NobText.tabular) : NobText.numeric,
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        row('Subtotal', totals.subtotalMinor),
        if (totals.discountMinor > 0) row('Discount', totals.discountMinor, negative: true),
        if (totals.taxMinor > 0) row('Tax', totals.taxMinor),
        const Divider(height: NobSpace.xl),
        row('Total', totals.totalMinor, strong: true),
        for (final (label, minor) in extra) row(label, minor),
      ],
    );
  }
}

class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({required this.currencyCode, required this.defaultTaxRate});

  final String currencyCode;
  final double defaultTaxRate;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  String _query = '';

  Future<void> _custom() async {
    final line = await showNobSheet<DraftLine>(
      context,
      child: _LineForm(
        line: DraftLine(description: '', quantity: 1, unitPriceMinor: 0, taxRate: widget.defaultTaxRate),
        currencyCode: widget.currencyCode,
        isNew: true,
      ),
    );
    if (line != null && mounted) Navigator.of(context).pop(line);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(sellableProductsProvider);
    final seesStock = ref.watch(canProvider(Permissions.inventoryRead));
    final workspaceId = ref.watch(activeWorkspaceProvider)?.id;
    final needle = _query.trim().toLowerCase();

    return SizedBox(
      height: 520,
      child: Padding(
        padding: const EdgeInsets.all(NobSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Add an item', style: NobText.title)),
                TextButton.icon(
                  onPressed: _custom,
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('One-off line'),
                ),
              ],
            ),
            const SizedBox(height: NobSpace.md),
            SearchField(hint: 'Search your catalogue', onChanged: (value) => setState(() => _query = value)),
            const SizedBox(height: NobSpace.md),
            Expanded(
              child: AsyncView(
                value: products,
                onRetry: () => ref.invalidate(sellableProductsProvider),
                builder: (all) {
                  final items = needle.isEmpty
                      ? all
                      : all
                          .where(
                            (p) =>
                                p.name.toLowerCase().contains(needle) ||
                                (p.sku ?? '').toLowerCase().contains(needle),
                          )
                          .toList();
                  if (items.isEmpty) {
                    return EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: all.isEmpty ? 'Your catalogue is empty' : 'No matches',
                      message: all.isEmpty
                          ? 'Add items under Products & stock, or use a one-off line.'
                          : 'Nothing in the catalogue matches "$_query".',
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final Product product = items[index];
                      return ListRow(
                        dense: true,
                        title: product.name,
                        subtitle: [
                          ?product.sku,
                          if (product.trackInventory && seesStock)
                            '${formatQuantity(product.stockIn(workspaceId))} ${product.unit} on hand',
                        ].join(' · '),
                        trailing: Text(
                          Money.format(product.unitPriceMinor, widget.currencyCode),
                          style: NobText.numeric,
                        ),
                        onTap: () => Navigator.of(context).pop(
                          DraftLine(
                            productId: product.id,
                            description: product.name,
                            quantity: 1,
                            unitPriceMinor: product.unitPriceMinor,
                            taxRate: product.taxRate ?? widget.defaultTaxRate,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineForm extends StatefulWidget {
  const _LineForm({required this.line, required this.currencyCode, this.isNew = false});

  final DraftLine line;
  final String currencyCode;
  final bool isNew;

  @override
  State<_LineForm> createState() => _LineFormState();
}

class _LineFormState extends State<_LineForm> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.line.description);
  late final _quantity = TextEditingController(text: formatQuantity(widget.line.quantity).replaceAll(',', ''));
  late final _price = TextEditingController(
    text: widget.isNew ? '' : Money.toInput(widget.line.unitPriceMinor, widget.currencyCode),
  );
  late final _tax = TextEditingController(text: formatQuantity(widget.line.taxRate));

  @override
  void dispose() {
    for (final controller in [_description, _quantity, _price, _tax]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _done() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      widget.line.copyWith(
        description: _description.text.trim(),
        quantity: double.parse(_quantity.text.replaceAll(',', '').trim()),
        unitPriceMinor: Money.parse(_price.text, widget.currencyCode),
        taxRate: double.tryParse(_tax.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.isNew ? 'One-off line' : 'Edit line',
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        PrimaryButton(label: widget.isNew ? 'Add line' : 'Done', onPressed: _done),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _description,
              autofocus: widget.isNew,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description', counterText: ''),
              validator: (value) => Validators.length(value, min: 1, max: 300, label: 'Description'),
            ),
            const SizedBox(height: NobSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (value) => Validators.positiveNumber(value, label: 'Quantity'),
                  ),
                ),
                const SizedBox(width: NobSpace.md),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Unit price (${widget.currencyCode})'),
                    validator: (value) => Money.parse(value ?? '', widget.currencyCode) == null
                        ? 'Enter an amount such as 1500.00'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _tax,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tax rate %'),
              validator: Validators.percentage,
            ),
          ],
        ),
      ),
    );
  }
}
