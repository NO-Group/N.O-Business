import '../../../core/commerce/line_item.dart';
import '../../../core/utils/json.dart';

DocumentTotals _totals(JsonMap json) => DocumentTotals(
  subtotalMinor: asInt(json['subtotal_minor']),
  discountMinor: asInt(json['discount_minor']),
  taxMinor: asInt(json['tax_minor']),
  totalMinor: asInt(json['total_minor']),
);

class Quotation {
  const Quotation({
    required this.id,
    required this.number,
    required this.workspaceId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.currencyCode,
    required this.totals,
    required this.items,
    this.issueDate,
    this.validUntil,
    this.notes,
    this.convertedInvoiceId,
  });

  factory Quotation.fromJson(JsonMap json) => Quotation(
    id: asString(json['id']),
    number: asString(json['number']),
    workspaceId: asString(json['workspace_id']),
    customerId: asString(json['customer_id']),
    customerName: asString(asJsonMap(json['customer'])['name'], 'Customer'),
    status: asString(json['status'], 'draft'),
    issueDate: asDateTime(json['issue_date']),
    validUntil: asDateTime(json['valid_until']),
    currencyCode: asString(json['currency_code'], 'USD'),
    totals: _totals(json),
    notes: asStringOrNull(json['notes']),
    convertedInvoiceId: asStringOrNull(json['converted_invoice_id']),
    items: LineItem.listFromJson(json['items']),
  );

  final String id;
  final String number;
  final String workspaceId;
  final String customerId;
  final String customerName;

  /// draft, sent, accepted, declined or converted.
  final String status;
  final DateTime? issueDate;
  final DateTime? validUntil;
  final String currencyCode;
  final DocumentTotals totals;
  final String? notes;
  final String? convertedInvoiceId;

  /// Only loaded for a single quotation, empty in lists.
  final List<LineItem> items;

  bool get isEditable => status == 'draft' || status == 'sent';
  bool get isConvertible => status == 'sent' || status == 'accepted';

  /// Sent but past its validity date.
  bool isExpired(DateTime today) {
    final until = validUntil;
    return status == 'sent' &&
        until != null &&
        until.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.amountMinor,
    required this.method,
    this.reference,
    this.paidAt,
  });

  factory Payment.fromJson(JsonMap json) => Payment(
    id: asString(json['id']),
    amountMinor: asInt(json['amount_minor']),
    method: asString(json['method'], 'other'),
    reference: asStringOrNull(json['reference']),
    paidAt: asDateTime(json['paid_at']),
  );

  final String id;
  final int amountMinor;
  final String method;
  final String? reference;
  final DateTime? paidAt;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.workspaceId,
    required this.customerId,
    required this.customerName,
    required this.status,
    required this.currencyCode,
    required this.totals,
    required this.amountPaidMinor,
    required this.items,
    required this.payments,
    this.number,
    this.quotationId,
    this.issueDate,
    this.dueDate,
    this.notes,
  });

  factory Invoice.fromJson(JsonMap json) {
    final payments = asJsonList(json['payments']).map(Payment.fromJson).toList()
      ..sort((a, b) => (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
    return Invoice(
      id: asString(json['id']),
      number: asStringOrNull(json['number']),
      workspaceId: asString(json['workspace_id']),
      customerId: asString(json['customer_id']),
      customerName: asString(asJsonMap(json['customer'])['name'], 'Customer'),
      quotationId: asStringOrNull(json['quotation_id']),
      status: asString(json['status'], 'draft'),
      issueDate: asDateTime(json['issue_date']),
      dueDate: asDateTime(json['due_date']),
      currencyCode: asString(json['currency_code'], 'USD'),
      totals: _totals(json),
      amountPaidMinor: asInt(json['amount_paid_minor']),
      notes: asStringOrNull(json['notes']),
      items: LineItem.listFromJson(json['items']),
      payments: payments,
    );
  }

  final String id;

  /// Assigned when the invoice is issued; a draft has none.
  final String? number;
  final String workspaceId;
  final String customerId;
  final String customerName;
  final String? quotationId;

  /// draft, issued, partially_paid, paid or void.
  final String status;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String currencyCode;
  final DocumentTotals totals;
  final int amountPaidMinor;
  final String? notes;

  /// Only loaded for a single invoice, empty in lists.
  final List<LineItem> items;
  final List<Payment> payments;

  String get displayNumber => number ?? 'Draft invoice';
  int get balanceMinor => totals.totalMinor - amountPaidMinor;
  bool get isDraft => status == 'draft';

  /// Issued and not fully paid.
  bool get isOpen => status == 'issued' || status == 'partially_paid';

  /// Open and past its due date. Same rule as the dashboard.
  bool isOverdue(DateTime today) {
    final due = dueDate;
    return isOpen && due != null && due.isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// What the editors send to `save_quotation` / `save_invoice`.
class BillingDraft {
  const BillingDraft({
    required this.customerId,
    required this.lines,
    required this.discountMinor,
    this.date,
    this.notes,
  });

  final String customerId;
  final List<DraftLine> lines;
  final int discountMinor;

  /// "Valid until" for a quotation, "due date" for an invoice.
  final DateTime? date;
  final String? notes;
}
