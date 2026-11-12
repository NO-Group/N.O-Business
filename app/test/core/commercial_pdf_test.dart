import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:no_business/core/commerce/line_item.dart';
import 'package:no_business/core/pdf/commercial_pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Loads the bundled document fonts straight from the asset folder, so the
/// test renders with the same glyphs as the app without a Flutter engine.
PdfFonts loadFonts() {
  pw.Font read(String name) =>
      pw.Font.ttf(File('assets/fonts/$name').readAsBytesSync().buffer.asByteData());
  return PdfFonts(regular: read('DejaVuSans.ttf'), bold: read('DejaVuSans-Bold.ttf'));
}

CommercialPdfData invoice({int lineCount = 2, String? brandColorHex = '#075BFF', String? stamp}) {
  final items = [
    for (var i = 0; i < lineCount; i++)
      LineItem(
        description: 'Item ${i + 1} — Ünïcödé naïve café ₦',
        quantity: 1.5,
        unitPriceMinor: 250000,
        taxRate: 7.5,
        lineTotalMinor: 375000,
      ),
  ];
  final subtotal = 375000 * lineCount;
  return CommercialPdfData(
    title: 'INVOICE',
    number: 'INV-000042',
    seller: const PdfParty(
      name: 'Acme Trading Ltd',
      lines: ['12 Market Road, Jos', '+2348012345678'],
    ),
    buyer: const PdfParty(name: 'Bola Stores', lines: ['bola@example.com']),
    meta: const [('Issued', '12 Nov 2026'), ('Due', '26 Nov 2026')],
    items: items,
    totals: DocumentTotals(
      subtotalMinor: subtotal,
      discountMinor: 0,
      taxMinor: (subtotal * 0.075).round(),
      totalMinor: subtotal + (subtotal * 0.075).round(),
    ),
    currencyCode: 'NGN',
    afterTotal: const [('Paid', 100000), ('Balance due', 706250)],
    notes: 'Thank you for your business.',
    footer: 'Bank: Example Bank · 0123456789',
    brandColorHex: brandColorHex,
    stamp: stamp,
  );
}

int pageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(latin1.decode(bytes)).length;

void main() {
  final fonts = loadFonts();

  test('renders an invoice as a PDF file', () async {
    final bytes = await buildCommercialPdf(invoice(), fonts: fonts);
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(latin1.decode(bytes.sublist(bytes.length - 8)), contains('%%EOF'));
    expect(pageCount(bytes), 1);
  });

  test('flows a long document onto further pages', () async {
    final bytes = await buildCommercialPdf(invoice(lineCount: 90), fonts: fonts);
    expect(pageCount(bytes), greaterThan(1));
  });

  test('accepts a missing or malformed accent colour and a stamp', () async {
    for (final colour in [null, 'blue', '#12']) {
      final bytes = await buildCommercialPdf(
        invoice(brandColorHex: colour, stamp: 'DRAFT'),
        fonts: fonts,
      );
      expect(bytes.length, greaterThan(1000), reason: '$colour');
    }
  });

  test('renders a document with no lines, buyer or notes', () async {
    final bytes = await buildCommercialPdf(
      const CommercialPdfData(
        title: 'RECEIPT',
        seller: PdfParty(name: 'Acme'),
        items: [],
        totals: DocumentTotals(subtotalMinor: 0, discountMinor: 0, taxMinor: 0, totalMinor: 0),
        currencyCode: 'USD',
      ),
      fonts: fonts,
    );
    expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('derives a safe file name', () {
    expect(invoice().fileName, 'INV-000042.pdf');
    const unnamed = CommercialPdfData(
      title: 'DRAFT INVOICE / 1',
      seller: PdfParty(name: 'Acme'),
      items: [],
      totals: DocumentTotals(subtotalMinor: 0, discountMinor: 0, taxMinor: 0, totalMinor: 0),
      currencyCode: 'USD',
    );
    expect(unnamed.fileName, 'DRAFT-INVOICE-1.pdf');
  });
}
