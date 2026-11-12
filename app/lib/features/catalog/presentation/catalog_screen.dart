import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/components/feedback.dart';
import '../../../core/design_system/components/fields.dart';
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
import '../application/catalog_providers.dart';
import '../domain/product.dart';
import 'product_form.dart';
import 'stock_sheet.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.lowStockOnly = false});

  /// Opens with the low-stock filter on (used by the dashboard and alerts).
  final bool lowStockOnly;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _query = '';
  late bool _lowOnly = widget.lowStockOnly;

  @override
  void didUpdateWidget(CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lowStockOnly != widget.lowStockOnly) _lowOnly = widget.lowStockOnly;
  }

  Future<void> _delete(Product product) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete ${product.name}?',
      message:
          'The item is removed from the catalogue. Items that already appear on sales, '
          'quotations or invoices cannot be deleted; mark those inactive instead.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(catalogRepositoryProvider).delete(product.id);
      ref.invalidate(productsProvider);
      ref.invalidate(sellableProductsProvider);
      if (mounted) showNobSnack(context, 'Item deleted.', tone: SnackTone.success);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(canProvider(Permissions.catalogRead))) {
      return const PageScaffold(
        title: 'Products & stock',
        scrollable: false,
        child: NoAccessState(),
      );
    }
    final canWrite = ref.watch(canProvider(Permissions.catalogWrite));
    final canDelete = ref.watch(canProvider(Permissions.catalogDelete));
    final seesStock = ref.watch(canProvider(Permissions.inventoryRead));
    final organization = ref.watch(activeOrganizationProvider);
    final workspace = ref.watch(activeWorkspaceProvider);
    final currency = organization?.currencyCode ?? 'USD';
    final products = ref.watch(productsProvider(_query));

    return PageScaffold(
      title: 'Products & stock',
      subtitle: workspace == null || !seesStock
          ? 'What you sell.'
          : 'What you sell, with stock on hand in ${workspace.name}.',
      scrollable: false,
      actions: [
        if (canWrite)
          FilledButton.icon(
            onPressed: () => showProductForm(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New item'),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SearchField(
            hint: 'Search by name or SKU',
            onChanged: (value) => setState(() => _query = value),
          ),
          if (seesStock) ...[
            const SizedBox(height: NobSpace.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Low stock only'),
                selected: _lowOnly,
                onSelected: (value) => setState(() => _lowOnly = value),
              ),
            ),
          ],
          const SizedBox(height: NobSpace.lg),
          Expanded(
            child: AsyncView(
              value: products,
              onRetry: () => ref.invalidate(productsProvider),
              builder: (all) {
                final items = _lowOnly && seesStock
                    ? all.where((p) => p.isLowIn(workspace?.id)).toList()
                    : all;
                if (items.isEmpty) {
                  final filtered = _query.isNotEmpty || _lowOnly;
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: filtered ? 'No matches' : 'Your catalogue is empty',
                    message: filtered
                        ? 'No item matches the current search or filter.'
                        : 'Add the products and services you sell. Prices and tax rates are filled '
                              'in automatically when you add them to a sale or invoice.',
                    action: !filtered && canWrite
                        ? FilledButton(
                            onPressed: () => showProductForm(context),
                            child: const Text('Add an item'),
                          )
                        : null,
                  );
                }
                return ListPanel(
                  itemCount: items.length,
                  footer: all.length >= listPageSize
                      ? const Text(
                          'Showing the first $listPageSize items. Search to narrow the list.',
                        )
                      : null,
                  itemBuilder: (context, index) {
                    final product = items[index];
                    final low = seesStock && product.isLowIn(workspace?.id);
                    final hasStock = product.trackInventory && seesStock;
                    final hasActions = hasStock || canWrite || canDelete;
                    return ListRow(
                      leading: RowIcon(
                        product.isService ? Icons.handyman_outlined : Icons.inventory_2_outlined,
                        color: product.isActive ? NobColors.cyan : NobColors.textMuted,
                      ),
                      title: product.name,
                      subtitle: [
                        ?product.sku,
                        if (product.isService) 'Service',
                        if (!product.isActive) 'Inactive',
                        if (product.trackInventory && seesStock)
                          '${formatQuantity(product.stockIn(workspace?.id))} ${product.unit} on hand',
                      ].join(' · '),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TrailingAmount(
                            amount: Money.format(product.unitPriceMinor, currency),
                            below: low
                                ? const StatusBadge(label: 'Low stock', tone: BadgeTone.warning)
                                : null,
                          ),
                          if (hasActions)
                            MenuAnchor(
                              menuChildren: [
                                if (hasStock)
                                  MenuItemButton(
                                    leadingIcon: const Icon(Icons.swap_vert_rounded, size: 18),
                                    onPressed: () => showStockSheet(context, product),
                                    child: const Text('Stock'),
                                  ),
                                if (canWrite)
                                  MenuItemButton(
                                    leadingIcon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => showProductForm(context, product: product),
                                    child: const Text('Edit'),
                                  ),
                                if (canDelete)
                                  MenuItemButton(
                                    leadingIcon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    onPressed: () => _delete(product),
                                    child: const Text('Delete'),
                                  ),
                              ],
                              builder: (context, controller, _) => IconButton(
                                tooltip: 'Actions for ${product.name}',
                                icon: const Icon(Icons.more_vert_rounded),
                                onPressed: () =>
                                    controller.isOpen ? controller.close() : controller.open(),
                              ),
                            ),
                        ],
                      ),
                      onTap: hasStock
                          ? () => showStockSheet(context, product)
                          : canWrite
                          ? () => showProductForm(context, product: product)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
