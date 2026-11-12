import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/buttons.dart';
import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
import '../../../core/design_system/tokens.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../tenancy/application/tenancy_providers.dart';
import '../application/catalog_providers.dart';
import '../domain/product.dart';

/// Opens the create/edit form. Resolves to true when something was saved.
Future<bool> showProductForm(BuildContext context, {Product? product}) async =>
    await showNobSheet<bool>(context, child: ProductForm(product: product)) ?? false;

class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final String _currency = ref.read(activeOrganizationProvider)?.currencyCode ?? 'USD';
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _description = TextEditingController(text: widget.product?.description);
  late final _unit = TextEditingController(text: widget.product?.unit ?? 'unit');
  late final _price = TextEditingController(
    text: widget.product == null ? '' : Money.toInput(widget.product!.unitPriceMinor, _currency),
  );
  late final _cost = TextEditingController(
    text: widget.product == null ? '' : Money.toInput(widget.product!.costPriceMinor, _currency),
  );
  late final _tax = TextEditingController(
    text: widget.product?.taxRate == null ? '' : formatQuantity(widget.product!.taxRate!),
  );
  late final _reorder = TextEditingController(
    text: widget.product == null ? '0' : formatQuantity(widget.product!.reorderLevel).replaceAll(',', ''),
  );
  late String _kind = widget.product?.kind ?? 'product';
  late bool _track = widget.product?.trackInventory ?? true;
  late bool _active = widget.product?.isActive ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _sku, _description, _unit, _price, _cost, _tax, _reorder]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _money(String? value, {required bool optional}) {
    if ((value ?? '').trim().isEmpty) return optional ? null : 'Enter a price';
    return Money.parse(value!, _currency) == null ? 'Enter an amount such as 1500.00' : null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final organizationId = ref.read(activeOrganizationIdProvider);
    if (organizationId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final input = ProductInput(
      kind: _kind,
      name: _name.text,
      sku: nullIfBlank(_sku.text),
      description: nullIfBlank(_description.text),
      unit: _unit.text,
      unitPriceMinor: Money.parse(_price.text, _currency) ?? 0,
      costPriceMinor: Money.parse(_cost.text, _currency) ?? 0,
      taxRate: double.tryParse(_tax.text.trim()),
      trackInventory: _track,
      reorderLevel: double.tryParse(_reorder.text.trim()) ?? 0,
      isActive: _active,
    );
    try {
      final repository = ref.read(catalogRepositoryProvider);
      final existing = widget.product;
      if (existing == null) {
        await repository.create(organizationId, input);
      } else {
        await repository.update(existing.id, input);
      }
      ref.invalidate(productsProvider);
      ref.invalidate(sellableProductsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final error = _error;
    final isProduct = _kind == 'product';
    return SheetScaffold(
      title: widget.product == null ? 'New item' : 'Edit item',
      subtitle: 'Prices are in $_currency.',
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        PrimaryButton(label: 'Save item', onPressed: _save, loading: _saving),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'product', label: Text('Product'), icon: Icon(Icons.inventory_2_outlined)),
                ButtonSegment(value: 'service', label: Text('Service'), icon: Icon(Icons.handyman_outlined)),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _name,
              autofocus: widget.product == null,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => Validators.length(value, min: 1, max: 160, label: 'Name'),
            ),
            const SizedBox(height: NobSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    maxLength: 60,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'SKU (optional)', counterText: ''),
                  ),
                ),
                const SizedBox(width: NobSpace.md),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    maxLength: 20,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      helperText: 'unit, kg, hour…',
                      counterText: '',
                    ),
                    validator: (value) => Validators.length(value, min: 1, max: 20, label: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NobSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Selling price'),
                    validator: (value) => _money(value, optional: false),
                  ),
                ),
                const SizedBox(width: NobSpace.md),
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Cost (optional)'),
                    validator: (value) => _money(value, optional: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _tax,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tax rate % (optional)',
                helperText: 'Leave empty to use the organization default.',
              ),
              validator: (value) => (value ?? '').trim().isEmpty ? null : Validators.percentage(value),
            ),
            const SizedBox(height: NobSpace.lg),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Description (optional)', counterText: ''),
            ),
            if (isProduct) ...[
              const SizedBox(height: NobSpace.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _track,
                onChanged: (value) => setState(() => _track = value),
                title: const Text('Track stock'),
                subtitle: const Text('Sales and issued invoices reduce the quantity on hand.'),
              ),
              if (_track)
                TextFormField(
                  controller: _reorder,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Reorder level',
                    helperText: 'The item is flagged as low at or below this quantity.',
                  ),
                  validator: (value) {
                    final number = double.tryParse((value ?? '').trim());
                    return number == null || number < 0 ? 'Enter zero or more' : null;
                  },
                ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (value) => setState(() => _active = value),
              title: const Text('Active'),
              subtitle: const Text('Inactive items stay on past documents but cannot be sold.'),
            ),
            if (error != null) ...[const SizedBox(height: NobSpace.lg), FormMessage(error)],
          ],
        ),
      ),
    );
  }
}
