/// Machine-readable structure of the three physical corporate forms
/// (docs/forms/FORM_LAYOUTS.md) — drives both the generator UI and the
/// PDF painters, so paper and digital stay 1:1.
///
/// Serials on the physical books are PRE-PRINTED (Receipt 2131, MILS 925,
/// Invoice 4335): the app's SerialService is seeded by Admin to continue
/// from the current book numbers.
library;

class WeightClass {
  final int kg;
  const WeightClass(this.kg);
  String get label => '${kg}kg';
}

class MtekForms {
  /// MILS Section A — exact weight classes from the physical sheet.
  static const weightClasses = <WeightClass>[
    WeightClass(1), WeightClass(2), WeightClass(3), WeightClass(5),
    WeightClass(6), WeightClass(9), WeightClass(12), WeightClass(25),
    WeightClass(50), WeightClass(75),
  ];

  /// MILS Section B — REPLACEMENT component rows (12, incl. Seal).
  static const components = <String>[
    'Nipple', 'Horn', 'Hose', 'Manometre', 'Valve', 'Strap',
    'Label', 'Lever', 'Seal', 'Powder', 'Pull Pin', 'Cartridge',
  ];

  /// Sales Invoice document-type checkboxes.
  static const invoiceVariants = <String>[
    'WAY BILL', 'PRO-FORMER', 'SERVICE INVOICE', 'SALES INVOICE',
  ];

  /// Receipt payment methods (2×2 grid on the form).
  static const receiptMethods = <String>['Cash', 'Cheque', 'Transfer', 'POS'];

  /// Current book numbers (Admin-seedable in Settings → Serials).
  /// Every book starts from 000000001 (owner directive 2026-08-30).
  /// Values are "last used" counters — CEO-reseedable in Settings.
  static const seedSerials = <String, int>{
    'receipt': 0,
    'mils': 0,
    'invoice': 0,
    'waybill': 0,
    'deliverynote': 0,
  };

  /// VAT rate offered per priced document during document creation.
  static const double invoiceVatRate = 0.075;
}
