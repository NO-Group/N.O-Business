import 'dart:math';

import 'forms_spec.dart';

/// Editable form-state models behind the Document Generator UI
/// (SPEC §12.2). One live instance per document type — switching tabs
/// never loses entered context (blueprint Part 2).
///
/// Persisted to Drift in Phase B; Supabase in Phase C.

enum DocType { receipt, invoice, mils, waybill, deliveryNote }

/// WAYBILL — mirrors the physical carbon-copy book (No: 0174 series).
/// Items carry tech-spec + brand instead of prices (logistics document).
class WaybillDocState {
  int? serial;
  String milsNo = '', receiptNo = '', invoiceNo = '', lpoNo = '';
  String customerEmail = ''; // contact rule: phone OR email is required
  String name = '', address = '', phone = '';
  String originatingFrom =
      'HEAD OFFICE: YY 12, Kazaure Road, By Lagos Street Round About, Kaduna';
  String destination = '';
  String driverName = '', driverPhone = '', driverSignature = '';
  String vehicleBrand = '', plateNo = '', colour = '';
  String receiverName = '', receiverPhone = '';
  String receiverSignature = ''; // data URL — receiver signs at hand-over
  String approvedBy = 'CEO';
  DateTime date = DateTime.now();
  final List<WaybillRow> rows = [WaybillRow()];
  bool get valid =>
      name.trim().isNotEmpty &&
      destination.trim().isNotEmpty &&
      rows.any((r) => r.product.trim().isNotEmpty);
}

class WaybillRow {
  String product = '', techSpec = '', brand = '';
  double qty = 0;
  WaybillRow({this.product = '', this.techSpec = '', this.brand = '', this.qty = 0});
}

/// DELIVERY NOTE — mirrors the pre-printed book (No: 19790088 series).
/// Ordered / Delivered / Outstanding columns — no prices.
class DeliveryNoteDocState {
  int? serial;
  String customerEmail = ''; // contact rule: phone OR email is required
  String customerName = '', institution = '', address = '', phone = '';
  String location = '', receiver = '', receiverNo = '', receiverSignature = '';
  DateTime orderDate = DateTime.now();
  String proformaInvoiceId = '', customerId = '', dispatch = '', deliveryMethod = '';
  String accountNo = '', accountName = '', banker = '';
  String summary = '';
  final List<DeliveryNoteRow> rows = [DeliveryNoteRow()];
  bool get valid =>
      customerName.trim().isNotEmpty &&
      rows.any((r) => r.description.trim().isNotEmpty);
}

class DeliveryNoteRow {
  String description = '';
  double ordered = 0, delivered = 0, outstanding = 0;
  DeliveryNoteRow({this.description = '', this.ordered = 0, this.delivered = 0, this.outstanding = 0});
}

class LedgerRow {
  String description;
  double qty;
  double rate;
  LedgerRow({this.description = '', this.qty = 1, this.rate = 0});
  double get amount => qty * rate;
}

class ReceiptDocState {
  int? serial; // assigned at generation (paper-book sequence)
  String irn = '';
  String name = '';
  String address = '';
  String customerEmail = ''; // contact rule: phone OR email is required
  String phone = '';
  double amount = 0;
  String beingPaymentFor = '';
  String method = 'Cash'; // Cash | Cheque | Transfer | POS
  DateTime date = DateTime.now();
  String customerSignature = ''; // data URL — the customer signs on the device

  bool get valid => name.trim().isNotEmpty && amount > 0;

  String get amountInWords => nairaInWords(amount);
}

class InvoiceDocState {
  int? serial;
  String variant = 'SALES INVOICE'; // WAY BILL | PRO-FORMER | SERVICE INVOICE | SALES INVOICE
  bool showMilsNo = false, showReceiptNo = false;
  String milsNo = '', receiptNo = '', lpoNo = '';
  String customerEmail = ''; // contact rule: phone OR email is required
  String name = '', address = '', phone = '';
  DateTime date = DateTime.now();
  String customerSignature = ''; // data URL — customer assent on the device
  List<LedgerRow> rows = [LedgerRow()];
  double advancePayment = 0;
  double discount = 0;
  bool vatEnabled = true;
  double vatRate = MtekForms.invoiceVatRate;
  String paymentTerms = '', notes = '', paymentInstructions = '';

  double get subtotal => rows.fold(0, (s, r) => s + r.amount);
  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get vat => vatEnabled ? total * vatRate : 0;
  double get grandTotal => total + vat;
  double get balance => grandTotal - advancePayment;
  bool get valid =>
      name.trim().isNotEmpty && rows.any((r) => r.description.trim().isNotEmpty && r.amount > 0);
  String get amountInWords => nairaInWords(grandTotal);
}

class MilsDocState {
  String customerEmail = ''; // contact rule: phone OR email is required
  int? serial;
  DateTime entryDate = DateTime.now();
  DateTime collectionDate = DateTime.now().add(const Duration(days: 7));
  DateTime nextServiceDate = DateTime.now().add(const Duration(days: 180));
  String invoiceNo = '', receiptNo = '', lpoNo = '';

  String name = '', address = '', phone = '';

  /// Section A: weight class (kg) → qty and unit rate.
  final Map<int, double> weightQty = {};
  final Map<int, double> weightRate = {};

  /// Section B: component → qty and rate.
  final Map<String, double> componentQty = {};
  final Map<String, double> componentRate = {};

  bool vatEnabled = true;
  double vatRate = MtekForms.invoiceVatRate;
  double advancePayment = 0;
  double discount = 0;
  String paymentTerms = '', notes = '', paymentInstructions = '';

  double get subtotal {
    double s = 0;
    for (final kg in weightQty.keys) {
      s += (weightQty[kg] ?? 0) * (weightRate[kg] ?? 0);
    }
    for (final c in componentQty.keys) {
      s += (componentQty[c] ?? 0) * (componentRate[c] ?? 0);
    }
    return s;
  }

  double get total => (subtotal - discount).clamp(0, double.infinity);
  double get vat => vatEnabled ? total * vatRate : 0;
  double get grandTotal => total + vat;
  double get balance => grandTotal - advancePayment;
  bool get hasWork =>
      weightQty.values.any((q) => q > 0) || componentQty.values.any((q) => q > 0);
  bool get valid => name.trim().isNotEmpty && hasWork;
  String get amountInWords => nairaInWords(grandTotal);

  /// Extinguishers serviced by weight class — feeds Insights (blueprint Part 5).
  Map<int, double> get servicedByWeight =>
      Map.fromEntries(weightQty.entries.where((e) => e.value > 0));
}

/// ---------------- Amount in words (₦) ----------------

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen',
];
const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _below1000(int n) {
  if (n == 0) return '';
  if (n < 20) return _ones[n];
  if (n < 100) {
    return _tens[n ~/ 10] + (n % 10 == 0 ? '' : '-${_ones[n % 10]}');
  }
  return '${_ones[n ~/ 100]} Hundred${n % 100 == 0 ? '' : ' ${_below1000(n % 100)}'}';
}

/// ₦4,021,000.50 → "Four Million, Twenty-One Thousand Naira, Fifty Kobo"
String nairaInWords(num amount) {
  final total = (amount * 100).round();
  final naira = total ~/ 100;
  final kobo = total % 100;

  String words(int n) {
    if (n == 0) return 'Zero';
    final groups = <(int, String)>[
      (pow(10, 9).toInt(), 'Billion'),
      (pow(10, 6).toInt(), 'Million'),
      (1000, 'Thousand'),
    ];
    var rest = n;
    final out = <String>[];
    for (final g in groups) {
      final unit = g.$1;
      final count = rest ~/ unit;
      rest %= unit;
      if (count > 0) out.add('${_below1000(count)} ${g.$2}');
    }
    if (rest > 0) out.add(_below1000(rest));
    return out.join(', ');
  }

  final buffer = StringBuffer(words(naira));
  buffer.write(' Naira');
  if (kobo > 0) buffer.write(', ${_below1000(kobo)} Kobo');
  buffer.write(' Only');
  return buffer.toString();
}
