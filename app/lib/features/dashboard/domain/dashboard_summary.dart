import '../../../core/utils/json.dart';

class DailyPoint {
  const DailyPoint({required this.day, required this.salesMinor, required this.paymentsMinor});

  factory DailyPoint.fromJson(JsonMap json) => DailyPoint(
    day: asDateTime(json['day']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    salesMinor: asInt(json['sales_minor']),
    paymentsMinor: asInt(json['payments_minor']),
  );

  final DateTime day;
  final int salesMinor;
  final int paymentsMinor;

  int get totalMinor => salesMinor + paymentsMinor;
}

class TopProduct {
  const TopProduct({required this.name, required this.quantity, required this.totalMinor});

  factory TopProduct.fromJson(JsonMap json) => TopProduct(
    name: asString(json['name']),
    quantity: asDouble(json['quantity']),
    totalMinor: asInt(json['total_minor']),
  );

  final String name;
  final double quantity;
  final int totalMinor;
}

class MethodTotal {
  const MethodTotal({required this.method, required this.totalMinor});

  factory MethodTotal.fromJson(JsonMap json) =>
      MethodTotal(method: asString(json['method']), totalMinor: asInt(json['total_minor']));

  final String method;
  final int totalMinor;
}

/// Result of the `dashboard_summary` RPC. Every figure is computed by the
/// database from recorded sales, invoices and payments.
class DashboardSummary {
  const DashboardSummary({
    required this.currencyCode,
    required this.periodDays,
    required this.salesTotalMinor,
    required this.salesCount,
    required this.paymentsTotalMinor,
    required this.previousCollectedMinor,
    required this.receivablesMinor,
    required this.openInvoicesCount,
    required this.overdueMinor,
    required this.overdueCount,
    required this.openQuotationsCount,
    required this.openQuotationsMinor,
    required this.customersCount,
    required this.lowStockCount,
    required this.daily,
    required this.topProducts,
    required this.paymentMethods,
  });

  factory DashboardSummary.fromJson(JsonMap json) => DashboardSummary(
    currencyCode: asString(json['currency_code'], 'USD'),
    periodDays: asInt(json['period_days'], 30),
    salesTotalMinor: asInt(json['sales_total_minor']),
    salesCount: asInt(json['sales_count']),
    paymentsTotalMinor: asInt(json['payments_total_minor']),
    previousCollectedMinor: asInt(json['previous_collected_minor']),
    receivablesMinor: asInt(json['receivables_minor']),
    openInvoicesCount: asInt(json['open_invoices_count']),
    overdueMinor: asInt(json['overdue_minor']),
    overdueCount: asInt(json['overdue_count']),
    openQuotationsCount: asInt(json['open_quotations_count']),
    openQuotationsMinor: asInt(json['open_quotations_minor']),
    customersCount: asInt(json['customers_count']),
    lowStockCount: asInt(json['low_stock_count']),
    daily: asJsonList(json['daily']).map(DailyPoint.fromJson).toList(),
    topProducts: asJsonList(json['top_products']).map(TopProduct.fromJson).toList(),
    paymentMethods: asJsonList(json['payment_methods']).map(MethodTotal.fromJson).toList(),
  );

  final String currencyCode;
  final int periodDays;
  final int salesTotalMinor;
  final int salesCount;
  final int paymentsTotalMinor;
  final int previousCollectedMinor;
  final int receivablesMinor;
  final int openInvoicesCount;
  final int overdueMinor;
  final int overdueCount;
  final int openQuotationsCount;
  final int openQuotationsMinor;
  final int customersCount;
  final int lowStockCount;
  final List<DailyPoint> daily;
  final List<TopProduct> topProducts;
  final List<MethodTotal> paymentMethods;

  /// Money received in the period: counter sales plus invoice payments.
  int get collectedMinor => salesTotalMinor + paymentsTotalMinor;

  /// Change against the preceding period of the same length, as a fraction
  /// (0.25 = +25%). Null when there is nothing to compare with.
  double? get collectedChange {
    if (previousCollectedMinor <= 0) return null;
    return (collectedMinor - previousCollectedMinor) / previousCollectedMinor;
  }

  bool get hasActivity => daily.any((point) => point.totalMinor > 0);
}
