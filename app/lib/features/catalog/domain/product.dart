import '../../../core/utils/json.dart';

class Product {
  const Product({
    required this.id,
    required this.organizationId,
    required this.kind,
    required this.name,
    required this.unit,
    required this.unitPriceMinor,
    required this.costPriceMinor,
    required this.trackInventory,
    required this.reorderLevel,
    required this.isActive,
    required this.stockByWorkspace,
    this.sku,
    this.description,
    this.taxRate,
  });

  factory Product.fromJson(JsonMap json) => Product(
    id: asString(json['id']),
    organizationId: asString(json['organization_id']),
    kind: asString(json['kind'], 'product'),
    name: asString(json['name']),
    sku: asStringOrNull(json['sku']),
    description: asStringOrNull(json['description']),
    unit: asString(json['unit'], 'unit'),
    unitPriceMinor: asInt(json['unit_price_minor']),
    costPriceMinor: asInt(json['cost_price_minor']),
    taxRate: asDoubleOrNull(json['tax_rate']),
    trackInventory: asBool(json['track_inventory']),
    reorderLevel: asDouble(json['reorder_level']),
    isActive: asBool(json['is_active'], true),
    stockByWorkspace: {
      for (final level in asJsonList(json['stock_levels']))
        asString(level['workspace_id']): asDouble(level['quantity']),
    },
  );

  final String id;
  final String organizationId;

  /// `product` or `service`.
  final String kind;
  final String name;
  final String? sku;
  final String? description;
  final String unit;
  final int unitPriceMinor;
  final int costPriceMinor;

  /// Percentage; null means "use the organization's default rate".
  final double? taxRate;
  final bool trackInventory;
  final double reorderLevel;
  final bool isActive;

  /// Quantity on hand per workspace id. A workspace with no entry has never
  /// held this item, which counts as zero.
  final Map<String, double> stockByWorkspace;

  bool get isService => kind == 'service';

  double stockIn(String? workspaceId) =>
      workspaceId == null ? 0 : stockByWorkspace[workspaceId] ?? 0;

  /// True when stock is tracked and the workspace holds no more than the
  /// reorder level. Same rule as the dashboard's low-stock count.
  bool isLowIn(String? workspaceId) =>
      trackInventory && isActive && stockIn(workspaceId) <= reorderLevel;
}

/// Editable fields of a catalogue item, as sent to the database.
class ProductInput {
  const ProductInput({
    required this.kind,
    required this.name,
    required this.unit,
    required this.unitPriceMinor,
    required this.costPriceMinor,
    required this.trackInventory,
    required this.reorderLevel,
    required this.isActive,
    this.sku,
    this.description,
    this.taxRate,
  });

  final String kind;
  final String name;
  final String? sku;
  final String? description;
  final String unit;
  final int unitPriceMinor;
  final int costPriceMinor;
  final double? taxRate;
  final bool trackInventory;
  final double reorderLevel;
  final bool isActive;

  JsonMap toJson() => {
    'kind': kind,
    'name': name.trim(),
    'sku': sku,
    'description': description,
    'unit': unit.trim(),
    'unit_price_minor': unitPriceMinor,
    'cost_price_minor': costPriceMinor,
    'tax_rate': taxRate,
    // A service never holds stock (enforced by the database as well).
    'track_inventory': kind == 'product' && trackInventory,
    'reorder_level': kind == 'product' && trackInventory ? reorderLevel : 0,
    'is_active': isActive,
  };
}

class StockMovement {
  const StockMovement({
    required this.quantityDelta,
    required this.reason,
    required this.workspaceId,
    this.note,
    this.createdAt,
  });

  factory StockMovement.fromJson(JsonMap json) => StockMovement(
    quantityDelta: asDouble(json['quantity_delta']),
    reason: asString(json['reason']),
    workspaceId: asString(json['workspace_id']),
    note: asStringOrNull(json['note']),
    createdAt: asDateTime(json['created_at']),
  );

  final double quantityDelta;
  final String reason;
  final String workspaceId;
  final String? note;
  final DateTime? createdAt;
}

/// Reasons a person may give for a manual stock change. Sales and invoices
/// move stock on their own and are not offered here.
const List<String> stockAdjustmentReasons = [
  'purchase',
  'opening',
  'adjustment',
  'return',
  'damage',
];
