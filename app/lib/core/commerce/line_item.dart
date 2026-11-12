import '../utils/json.dart';

/// A stored line of a sale, quotation or invoice.
class LineItem {
  const LineItem({
    required this.description,
    required this.quantity,
    required this.unitPriceMinor,
    required this.taxRate,
    required this.lineTotalMinor,
    this.productId,
  });

  factory LineItem.fromJson(JsonMap json) => LineItem(
    productId: asStringOrNull(json['product_id']),
    description: asString(json['description']),
    quantity: asDouble(json['quantity']),
    unitPriceMinor: asInt(json['unit_price_minor']),
    taxRate: asDouble(json['tax_rate']),
    lineTotalMinor: asInt(json['line_total_minor']),
  );

  final String? productId;
  final String description;
  final double quantity;
  final int unitPriceMinor;
  final double taxRate;
  final int lineTotalMinor;

  /// Stored lines sorted by their position on the document.
  static List<LineItem> listFromJson(Object? value) {
    final rows = asJsonList(value)
      ..sort((a, b) => asInt(a['position']).compareTo(asInt(b['position'])));
    return rows.map(LineItem.fromJson).toList();
  }
}

/// A line being composed in an editor, before the server has priced it.
class DraftLine {
  const DraftLine({
    required this.description,
    required this.quantity,
    required this.unitPriceMinor,
    required this.taxRate,
    this.productId,
  });

  factory DraftLine.fromItem(LineItem item) => DraftLine(
    productId: item.productId,
    description: item.description,
    quantity: item.quantity,
    unitPriceMinor: item.unitPriceMinor,
    taxRate: item.taxRate,
  );

  final String? productId;
  final String description;
  final double quantity;
  final int unitPriceMinor;

  /// Percentage, 0-100.
  final double taxRate;

  int get lineTotalMinor => (quantity * unitPriceMinor).round();

  DraftLine copyWith({
    String? description,
    double? quantity,
    int? unitPriceMinor,
    double? taxRate,
  }) => DraftLine(
    productId: productId,
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
    taxRate: taxRate ?? this.taxRate,
  );

  /// Shape expected by the `record_sale`, `save_quotation` and
  /// `save_invoice` functions.
  JsonMap toJson() => {
    if (productId != null) 'product_id': productId,
    'description': description.trim(),
    'quantity': quantity,
    'unit_price_minor': unitPriceMinor,
    'tax_rate': taxRate,
  };
}

/// Subtotal, tax and total of a document.
class DocumentTotals {
  const DocumentTotals({
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
  });

  /// Preview of what the database will compute for [lines].
  ///
  /// The database is the authority: it recomputes every figure when the
  /// document is saved. This mirrors its rule (tax is exclusive and charged
  /// on the discounted amount) so the editor can show a running total.
  factory DocumentTotals.preview(List<DraftLine> lines, {int discountMinor = 0}) {
    var subtotal = 0;
    var rawTax = 0.0;
    for (final line in lines) {
      final lineTotal = line.lineTotalMinor;
      subtotal += lineTotal;
      rawTax += lineTotal * line.taxRate / 100;
    }
    final discount = discountMinor.clamp(0, subtotal).toInt();
    final tax = subtotal == 0 ? 0 : (rawTax * (subtotal - discount) / subtotal).round();
    return DocumentTotals(
      subtotalMinor: subtotal,
      discountMinor: discount,
      taxMinor: tax,
      totalMinor: subtotal - discount + tax,
    );
  }

  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
}
