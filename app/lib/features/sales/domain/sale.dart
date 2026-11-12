import '../../../core/commerce/line_item.dart';
import '../../../core/utils/json.dart';

class Sale {
  const Sale({
    required this.id,
    required this.number,
    required this.workspaceId,
    required this.status,
    required this.paymentMethod,
    required this.currencyCode,
    required this.totals,
    required this.items,
    this.customerId,
    this.customerName,
    this.note,
    this.soldAt,
    this.voidedAt,
  });

  factory Sale.fromJson(JsonMap json) => Sale(
        id: asString(json['id']),
        number: asString(json['number']),
        workspaceId: asString(json['workspace_id']),
        customerId: asStringOrNull(json['customer_id']),
        customerName: asStringOrNull(asJsonMap(json['customer'])['name']),
        status: asString(json['status'], 'completed'),
        paymentMethod: asString(json['payment_method'], 'other'),
        currencyCode: asString(json['currency_code'], 'USD'),
        totals: DocumentTotals(
          subtotalMinor: asInt(json['subtotal_minor']),
          discountMinor: asInt(json['discount_minor']),
          taxMinor: asInt(json['tax_minor']),
          totalMinor: asInt(json['total_minor']),
        ),
        note: asStringOrNull(json['note']),
        soldAt: asDateTime(json['sold_at']),
        voidedAt: asDateTime(json['voided_at']),
        items: LineItem.listFromJson(json['items']),
      );

  final String id;
  final String number;
  final String workspaceId;
  final String? customerId;
  final String? customerName;

  /// `completed` or `voided`.
  final String status;
  final String paymentMethod;
  final String currencyCode;
  final DocumentTotals totals;
  final String? note;
  final DateTime? soldAt;
  final DateTime? voidedAt;

  /// Only loaded for a single sale, empty in lists.
  final List<LineItem> items;

  bool get isVoided => status == 'voided';
}
