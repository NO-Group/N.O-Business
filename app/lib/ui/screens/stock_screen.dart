import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/auth_store.dart';
import '../../data/store.dart';
import '../widgets.dart';

/// STOCK — quantities, prices, low-stock alerts, adjustments (audit trail).
/// Cloud-backed stock catalogue: products are maintained through authorized
/// fields (Add product) and saved to the one shared server.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {

  /// EVERY product enters the system through these fields — nothing about
  /// stock is hard-coded or pre-seeded. Saved to the shared server.
  Future<void> _addProduct(BuildContext context) async {
    final name = TextEditingController();
    final brand = TextEditingController();
    final cost = TextEditingController();
    final price = TextEditingController();
    final qty = TextEditingController();
    final reorder = TextEditingController();
    final unit = TextEditingController(text: 'unit');
    final length = TextEditingController(), lengthUnit = TextEditingController(text: 'cm');
    final width = TextEditingController(), widthUnit = TextEditingController(text: 'cm');
    final size = TextEditingController(), sizeUnit = TextEditingController();
    final weight = TextEditingController();
    var weightUnit = 'kg';
    final pickedImages = <PlatformFile>[];
    var category = ProductCategory.fire;
    var isService = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Add product'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, autofocus: true,
                    decoration: const InputDecoration(labelText: 'Product name *')),
                const SizedBox(height: 10),
                TextField(controller: brand,
                    decoration: const InputDecoration(labelText: 'Brand (optional)', prefixIcon: Icon(Icons.sell_outlined))),
                const SizedBox(height: 10),
                DropdownButtonFormField<ProductCategory>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: ProductCategory.fire, child: Text('Fire')),
                    DropdownMenuItem(value: ProductCategory.safety, child: Text('Safety')),
                    DropdownMenuItem(value: ProductCategory.security, child: Text('Security')),
                    DropdownMenuItem(value: ProductCategory.solar, child: Text('Solar')),
                    DropdownMenuItem(value: ProductCategory.automation, child: Text('Automation & Surveillance')),
                  ],
                  onChanged: (v) => setDialog(() => category = v ?? ProductCategory.fire),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cost price (₦)'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: price, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Selling price (₦) *'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: qty, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity on hand'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: reorder, keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reorder level'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: unit,
                      decoration: const InputDecoration(labelText: 'Unit'))),
                ]),
                const SizedBox(height: 10),
                for (final fields in [
                  ('Length', length, lengthUnit),
                  ('Width', width, widthUnit),
                  ('Size', size, sizeUnit),
                ]) ...[
                  Row(children: [
                    Expanded(flex: 2, child: TextField(controller: fields.$2,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: '${fields.$1} (optional)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: fields.$3,
                      decoration: const InputDecoration(labelText: 'Unit'))),
                  ]),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  Expanded(flex: 2, child: TextField(controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (optional)'))),
                  const SizedBox(width: 10),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: weightUnit,
                    decoration: const InputDecoration(labelText: 'Weight unit'),
                    items: const ['mg', 'g', 'kg', 'tonne', 'oz', 'lb']
                      .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setDialog(() => weightUnit = value ?? 'kg'),
                  )),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.image, allowMultiple: true, withData: true);
                    if (result != null) setDialog(() {
                      pickedImages.addAll(result.files.where((f) => f.bytes != null));
                      if (pickedImages.length > 10) pickedImages.removeRange(10, pickedImages.length);
                    });
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(pickedImages.isEmpty ? 'Add stock images (optional)' : '${pickedImages.length} image(s) selected'),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Service (not stock-counted)', style: TextStyle(fontSize: 13.5)),
                  value: isService,
                  onChanged: (v) => setDialog(() => isService = v),
                ),
              ],
            )),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save product')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty || (price.text.trim().isEmpty && !isService)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Mtek.danger,
          content: Text('Product name and selling price are required.')));
      return;
    }
    final n = (String v) => int.tryParse(v.replaceAll(',', '')) ?? 0;
    final products = AppStore.instance.products;
    String nextId() {
      final prefix = switch (category) {
        ProductCategory.fire => 'F', ProductCategory.safety => 'S',
        ProductCategory.security => 'SEC', ProductCategory.solar => 'P',
        ProductCategory.automation => 'A',
      };
      var i = 1;
      while (products.any((p) => p.id == '$prefix${i.toString().padLeft(3, '0')}')) {
        i++;
      }
      return '$prefix${i.toString().padLeft(3, '0')}';
    }

    try {
      final id = nextId();
      final imageData = pickedImages.map((f) {
        final ext = (f.extension ?? 'jpg').toLowerCase();
        final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
        return 'data:$mime;base64,${base64Encode(f.bytes!)}';
      }).toList();
      final imageUrls = await AppStore.instance.uploadProductImages(id, imageData);
      await AppStore.instance.addProduct(Product(
        id: id,
        name: name.text.trim(),
        brand: brand.text.trim(),
        category: category,
        costPrice: n(cost.text),
        sellingPrice: n(price.text),
        qtyOnHand: isService ? 0 : n(qty.text),
        reorderLevel: n(reorder.text),
        unit: unit.text.trim().isEmpty ? 'unit' : unit.text.trim(),
        length: double.tryParse(length.text), lengthUnit: length.text.trim().isEmpty ? '' : lengthUnit.text.trim(),
        width: double.tryParse(width.text), widthUnit: width.text.trim().isEmpty ? '' : widthUnit.text.trim(),
        size: double.tryParse(size.text), sizeUnit: size.text.trim().isEmpty ? '' : sizeUnit.text.trim(),
        weight: double.tryParse(weight.text), weightUnit: weight.text.trim().isEmpty ? '' : weightUnit,
        imageUrls: imageUrls,
        isService: isService,
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Mtek.success,
            content: Text('${name.text.trim()} saved to the server.')));
      }
    } catch (e) {
      debugPrint('Product save failed: $e');
      if (context.mounted) {
        final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Mtek.danger,
            content: Text(msg.isEmpty ? 'Could not save the product — please try again.' : msg)));
      }
    }
  }

  String _dimensionLabel(Product p) {
    final values = <String>[
      if (p.length != null) 'L ${p.length} ${p.lengthUnit}',
      if (p.width != null) 'W ${p.width} ${p.widthUnit}',
      if (p.size != null) 'Size ${p.size} ${p.sizeUnit}',
      if (p.weight != null) 'Weight ${p.weight} ${p.weightUnit}',
    ];
    return values.isEmpty ? '' : ' · ${values.join(' · ')}';
  }

  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final lowCount = store.products.where((p) => p.isLow).length;

    final list = store.products.where((p) {
      if (_category != null && p.category.name != _category) return false;
      return p.name.toLowerCase().contains(_query.toLowerCase()) ||
          p.brand.toLowerCase().contains(_query.toLowerCase()) ||
          p.id.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Stock',
            subtitle:
                '${store.products.length} items · $lowCount low/out of stock · ${fmt.naira(store.stockValueAtCost())} at cost',
            icon: Icons.inventory_2,
            actions: [
              // stock is created HERE, in the app — never pre-loaded
              if (AuthStore.instance.isManagement)
                FilledButton.icon(
                  onPressed: () => _addProduct(context),
                  icon: const Icon(Icons.add_box),
                  label: const Text('Add product'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final search = SearchField(
              hint: 'Search by name or ID…',
              onChanged: (v) => setState(() => _query = v),
            );
            final category = DropdownButtonFormField<String?>(
              value: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category', isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                for (final c in ProductCategory.values)
                  DropdownMenuItem<String?>(value: c.name, child: Text(c.name.toUpperCase())),
              ],
              onChanged: (v) => setState(() => _category = v),
            );
            if (constraints.maxWidth < 560) {
              return Column(children: [search, const SizedBox(height: 8), category]);
            }
            return Row(children: [Expanded(child: search), const SizedBox(width: 12), SizedBox(width: 220, child: category)]);
          }),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: list.isEmpty
                  ? const EmptyHint('No stock items match these filters')
                  : RefreshIndicator(
                      onRefresh: () async { await AppStore.instance.refreshRemote(); },
                      child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = list[i];
                  return _productRow(context, p);
                },
              ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productRow(BuildContext context, Product p) {
    final thumbnail = p.imageUrls.isNotEmpty
        ? AppImage(source: p.imageUrls.first, title: p.name,
            details: '${p.id} · ${p.category.name.toUpperCase()} · ${p.qtyOnHand} ${p.unit} · ${fmt.naira(p.sellingPrice)}',
            width: 64, height: 64)
        : CircleAvatar(
            radius: 26,
            backgroundColor: p.isOutOfStock ? Mtek.dangerTint : p.isLow ? Mtek.warnTint : Mtek.brandTint,
            child: Text('${p.qtyOnHand}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
              color: p.isOutOfStock ? Mtek.danger : p.isLow ? Mtek.warn : Mtek.brand600)));

    Widget productMenu() => PopupMenuButton<String>(
      tooltip: 'Product actions',
      onSelected: (action) {
        if (action == 'edit') _editProduct(context, p);
        if (action == 'images') _manageImages(context, p);
        if (action == 'delete') _deleteProduct(context, p);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: ListTile(dense: true,
          leading: Icon(Icons.edit_outlined), title: Text('Edit name and prices'))),
        PopupMenuItem(value: 'images', child: ListTile(dense: true,
          leading: Icon(Icons.photo_library_outlined), title: Text('Manage images'))),
        PopupMenuItem(value: 'delete', child: ListTile(dense: true,
          leading: Icon(Icons.delete_outline, color: Mtek.danger),
          title: Text('Delete product', style: TextStyle(color: Mtek.danger)))),
      ],
    );

    final details = '${p.id}${p.brand.isEmpty ? '' : ' · ${p.brand}'} · ${p.category.name.toUpperCase()} · '
        '${p.qtyOnHand} ${p.unit} · cost ${fmt.naira(p.costPrice)}${_dimensionLabel(p)}';

    return LayoutBuilder(builder: (context, constraints) {
      final phoneLayout = MediaQuery.sizeOf(context).shortestSide < 600 || constraints.maxWidth < 700;
      if (phoneLayout) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              thumbnail,
              const SizedBox(width: 12),
              Expanded(child: Text(p.name, maxLines: 4, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 10),
            Text(details, style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: AmountText(p.sellingPrice)),
              if (AuthStore.instance.isManagement)
                IconButton(
                  tooltip: 'Adjust stock',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _adjustDialog(context, p),
                ),
              if (AuthStore.instance.isCeo) productMenu(),
            ]),
          ]),
        );
      }
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: thumbnail,
        title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          AmountText(p.sellingPrice),
          const SizedBox(width: 8),
          if (AuthStore.instance.isManagement)
            IconButton(tooltip: 'Adjust stock', icon: const Icon(Icons.tune),
              onPressed: () => _adjustDialog(context, p)),
          if (AuthStore.instance.isCeo) productMenu(),
        ]),
      );
    });
  }

  Future<void> _manageImages(BuildContext context, Product p) async {
    final images = List<String>.from(p.imageUrls);
    final result = await showDialog<List<String>>(context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: Text('Images · ${p.name}'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(images.isEmpty ? 'No product images yet.' : 'Tap an image for full view. Remove unwanted images below.'),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (var i = 0; i < images.length; i++)
                Stack(clipBehavior: Clip.none, children: [
                  AppImage(source: images[i], title: p.name,
                    details: '${p.id} · Product image ${i + 1} of ${images.length}', width: 112, height: 96),
                  Positioned(right: -7, top: -7, child: IconButton(
                    tooltip: 'Remove image', visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: Mtek.danger, foregroundColor: Colors.white),
                    onPressed: () => setDialogState(() => images.removeAt(i)),
                    icon: const Icon(Icons.close, size: 17))),
                ]),
            ]),
            const SizedBox(height: 14),
            OutlinedButton.icon(icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add images'), onPressed: () async {
                final picked = await pickMilsPhotos();
                if (picked == null || !context.mounted) return;
                try {
                  final uploaded = await AppStore.instance.uploadProductImages(p.id, picked);
                  setDialogState(() => images.addAll(uploaded));
                } catch (error) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: Mtek.danger,
                    content: Text(error.toString().replaceFirst('Exception: ', ''))));
                }
              }),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, images), child: const Text('Save images')),
        ],
      )));
    if (result == null || !context.mounted) return;
    try {
      await AppStore.instance.updateProductImages(p, result);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product images updated in the cloud.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Mtek.danger, content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _editProduct(BuildContext context, Product p) async {
    final name = TextEditingController(text: p.name);
    final brand = TextEditingController(text: p.brand);
    final cost = TextEditingController(text: '${p.costPrice}');
    final price = TextEditingController(text: '${p.sellingPrice}');
    final reorder = TextEditingController(text: '${p.reorderLevel}');
    final unit = TextEditingController(text: p.unit);
    final length = TextEditingController(text: p.length?.toString() ?? '');
    final lengthUnit = TextEditingController(text: p.lengthUnit);
    final width = TextEditingController(text: p.width?.toString() ?? '');
    final widthUnit = TextEditingController(text: p.widthUnit);
    final size = TextEditingController(text: p.size?.toString() ?? '');
    final sizeUnit = TextEditingController(text: p.sizeUnit);
    final weight = TextEditingController(text: p.weight?.toString() ?? '');
    String weightUnit = p.weightUnit;
    ProductCategory category = p.category;
    bool isService = p.isService;
    final updated = await showDialog<Product>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Edit all product details'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Product name *')),
          const SizedBox(height: 10),
          TextField(controller: brand, decoration: const InputDecoration(labelText: 'Brand')),
          const SizedBox(height: 10),
          DropdownButtonFormField<ProductCategory>(initialValue: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: ProductCategory.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
            onChanged: (v) { if (v != null) setDialogState(() => category = v); }),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost price (₦)'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling price (₦) *'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: reorder, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: unit, decoration: const InputDecoration(labelText: 'Stock unit'))),
          ]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(controller: length, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Length'))), const SizedBox(width: 10), Expanded(child: TextField(controller: lengthUnit, decoration: const InputDecoration(labelText: 'Length unit')))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(controller: width, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Width'))), const SizedBox(width: 10), Expanded(child: TextField(controller: widthUnit, decoration: const InputDecoration(labelText: 'Width unit')))]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(controller: size, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Size'))), const SizedBox(width: 10), Expanded(child: TextField(controller: sizeUnit, decoration: const InputDecoration(labelText: 'Size unit')))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight'))),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(initialValue: weightUnit.isEmpty ? '' : weightUnit,
              decoration: const InputDecoration(labelText: 'Weight unit'),
              items: const ['', 'mg', 'g', 'kg', 'tonne', 'oz', 'lb'].map((v) => DropdownMenuItem(value: v, child: Text(v.isEmpty ? 'None' : v))).toList(),
              onChanged: (v) => setDialogState(() => weightUnit = v ?? ''))),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Service item (not physical stock)'), value: isService, onChanged: (v) => setDialogState(() => isService = v)),
          const Text('Quantity is controlled through approved stock receipts, sales, and stock adjustments.', style: TextStyle(fontSize: 12)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            final selling = int.tryParse(price.text.replaceAll(',', ''));
            if (name.text.trim().isEmpty || selling == null) return;
            Navigator.pop(dialogContext, Product(
              id: p.id, name: name.text.trim(), brand: brand.text.trim(), category: category,
              costPrice: int.tryParse(cost.text.replaceAll(',', '')) ?? 0, sellingPrice: selling,
              qtyOnHand: p.qtyOnHand, reorderLevel: int.tryParse(reorder.text.replaceAll(',', '')) ?? 0,
              unit: unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
              length: double.tryParse(length.text), lengthUnit: lengthUnit.text.trim(),
              width: double.tryParse(width.text), widthUnit: widthUnit.text.trim(),
              size: double.tryParse(size.text), sizeUnit: sizeUnit.text.trim(),
              weight: double.tryParse(weight.text), weightUnit: weightUnit,
              imageUrls: p.imageUrls, isService: isService,
            ));
          }, child: const Text('Save changes')),
        ],
      )));
    if (updated == null || !context.mounted) return;
    try {
      await AppStore.instance.updateProductDetails(p, updated);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All product details updated in the cloud.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Mtek.danger, content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _deleteProduct(BuildContext context, Product p) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete product?'),
      content: Text('Remove ${p.name} from the active stock catalogue? Existing sales history will be preserved.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Mtek.danger),
          onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true || !context.mounted) return;
    try {
      await AppStore.instance.deleteProduct(p);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Mtek.danger, content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _adjustDialog(BuildContext context, Product p) {
    final qtyCtrl = TextEditingController();
    // Incoming stock must use an approved Stock Receipt, never this manual
    // correction dialog.
    AdjustmentReason reason = AdjustmentReason.correction;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Adjust — ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current: ${p.qtyOnHand} ${p.unit}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity change (use − for out)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AdjustmentReason>(
                value: reason,
                items: [
                  for (final r in AdjustmentReason.values)
                    if (r != AdjustmentReason.restock)
                      DropdownMenuItem(value: r, child: Text(r.name.toUpperCase())),
                ],
                onChanged: (v) => setDialogState(() => reason = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final delta = int.tryParse(qtyCtrl.text) ?? 0;
                if (delta != 0) {
                  AppStore.instance.adjustStock(p, delta, reason, 'Manual adjustment');
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock adjusted (${delta >= 0 ? '+' : ''}$delta) — logged in audit trail.')));
                }
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
