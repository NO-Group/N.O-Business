import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../commerce/line_item.dart';
import '../utils/formatters.dart';
import '../utils/money.dart';

/// Fonts embedded in generated PDFs. DejaVu Sans is used because it covers
/// the scripts and symbols business names tend to contain.
class PdfFonts {
  const PdfFonts({required this.regular, required this.bold});

  final pw.Font regular;
  final pw.Font bold;

  static PdfFonts? _cached;

  static Future<PdfFonts> load([AssetBundle? bundle]) async {
    final cached = _cached;
    if (cached != null) return cached;
    final source = bundle ?? rootBundle;
    final fonts = PdfFonts(
      regular: pw.Font.ttf(await source.load('assets/fonts/DejaVuSans.ttf')),
      bold: pw.Font.ttf(await source.load('assets/fonts/DejaVuSans-Bold.ttf')),
    );
    _cached = fonts;
    return fonts;
  }
}

/// A named party on a document with free-form detail lines under the name.
class PdfParty {
  const PdfParty({required this.name, this.lines = const []});

  final String name;
  final List<String> lines;
}

/// Everything needed to render a quotation, invoice or receipt. Built by the
/// feature that owns the record; this file knows nothing about the database.
class CommercialPdfData {
  const CommercialPdfData({
    required this.title,
    required this.seller,
    required this.items,
    required this.totals,
    required this.currencyCode,
    this.number,
    this.buyer,
    this.meta = const [],
    this.afterTotal = const [],
    this.notes,
    this.footer,
    this.brandColorHex,
    this.stamp,
  });

  /// "INVOICE", "QUOTATION" or "RECEIPT".
  final String title;
  final String? number;
  final PdfParty seller;
  final PdfParty? buyer;

  /// Label/value pairs printed under the title (dates, payment method…).
  final List<(String, String)> meta;
  final List<LineItem> items;
  final DocumentTotals totals;
  final String currencyCode;

  /// Label/amount rows under the total ("Paid", "Balance due").
  final List<(String, int)> afterTotal;
  final String? notes;

  /// The organization's own footer text (bank details, terms).
  final String? footer;

  /// The organization's accent colour as `#RRGGBB`; a neutral default is
  /// used when missing or malformed.
  final String? brandColorHex;

  /// Large diagonal mark such as "DRAFT" or "VOID".
  final String? stamp;

  String get fileName {
    final base = (number ?? title).replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return '$base.pdf';
  }
}

const _defaultAccent = PdfColor.fromInt(0xFF075BFF);
const _ink = PdfColor.fromInt(0xFF111827);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _rule = PdfColor.fromInt(0xFFE5E7EB);
const _band = PdfColor.fromInt(0xFFF3F4F6);

PdfColor _accentOf(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return _defaultAccent;
  return PdfColor.fromInt(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// Renders [data] as an A4 PDF and returns the file bytes.
Future<Uint8List> buildCommercialPdf(CommercialPdfData data, {required PdfFonts fonts}) {
  final accent = _accentOf(data.brandColorHex);
  final currency = data.currencyCode;
  String money(int minor) => Money.formatIso(minor, currency);

  final base = pw.TextStyle(font: fonts.regular, fontBold: fonts.bold, fontSize: 9.5, color: _ink);
  final small = base.copyWith(fontSize: 8.5, color: _muted);
  final strong = base.copyWith(fontWeight: pw.FontWeight.bold);

  pw.Widget party(String heading, PdfParty value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(heading.toUpperCase(), style: small.copyWith(letterSpacing: 0.8)),
      pw.SizedBox(height: 3),
      pw.Text(value.name, style: strong.copyWith(fontSize: 11)),
      for (final line in value.lines) pw.Text(line, style: base),
    ],
  );

  pw.Widget cell(
    String text, {
    pw.TextStyle? style,
    pw.Alignment alignment = pw.Alignment.centerLeft,
  }) => pw.Container(
    alignment: alignment,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(text, style: style ?? base),
  );

  final header = strong.copyWith(fontSize: 8.5, color: PdfColors.white);
  const right = pw.Alignment.centerRight;

  final table = pw.Table(
    columnWidths: const {
      0: pw.FlexColumnWidth(5),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(2.2),
      3: pw.FlexColumnWidth(1.2),
      4: pw.FlexColumnWidth(2.4),
    },
    border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _rule, width: 0.5)),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: pw.BoxDecoration(color: accent),
        children: [
          cell('DESCRIPTION', style: header),
          cell('QTY', style: header, alignment: right),
          cell('UNIT PRICE', style: header, alignment: right),
          cell('TAX %', style: header, alignment: right),
          cell('AMOUNT', style: header, alignment: right),
        ],
      ),
      for (final item in data.items)
        pw.TableRow(
          children: [
            cell(item.description),
            cell(formatQuantity(item.quantity), alignment: right),
            cell(money(item.unitPriceMinor), alignment: right),
            cell(formatQuantity(item.taxRate), alignment: right),
            cell(money(item.lineTotalMinor), alignment: right),
          ],
        ),
    ],
  );

  pw.Widget totalRow(String label, String value, {bool emphasised = false}) => pw.Container(
    color: emphasised ? _band : null,
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: emphasised ? strong.copyWith(fontSize: 11) : base),
        pw.Text(value, style: emphasised ? strong.copyWith(fontSize: 11) : base),
      ],
    ),
  );

  final totals = data.totals;
  final notes = data.notes;
  final footer = data.footer;
  final buyer = data.buyer;
  final number = data.number;
  final stamp = data.stamp;

  final document = pw.Document(
    title: number ?? data.title,
    author: data.seller.name,
    creator: 'N.O Business',
  );
  document.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 36),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        buildBackground: stamp == null
            ? null
            : (context) => pw.Center(
                child: pw.Transform.rotate(
                  angle: 0.5,
                  child: pw.Text(
                    stamp,
                    style: pw.TextStyle(
                      font: fonts.bold,
                      fontSize: 110,
                      color: const PdfColor.fromInt(0x14000000),
                    ),
                  ),
                ),
              ),
      ),
      footer: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(data.seller.name, style: small),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: small),
          ],
        ),
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: party('From', data.seller)),
            pw.SizedBox(width: 24),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  data.title,
                  style: strong.copyWith(fontSize: 22, color: accent, letterSpacing: 1.5),
                ),
                if (number != null) pw.Text(number, style: strong.copyWith(fontSize: 11)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Container(height: 2, color: accent),
        pw.SizedBox(height: 16),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: buyer == null ? pw.SizedBox() : party('Bill to', buyer)),
            pw.SizedBox(width: 24),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                for (final (label, value) in data.meta)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(text: '$label  ', style: small),
                          pw.TextSpan(text: value, style: strong),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 18),
        table,
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: notes == null || notes.trim().isEmpty
                  ? pw.SizedBox()
                  : pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NOTES', style: small.copyWith(letterSpacing: 0.8)),
                        pw.SizedBox(height: 3),
                        pw.Text(notes, style: base),
                      ],
                    ),
            ),
            pw.SizedBox(width: 24),
            pw.Expanded(
              flex: 4,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  totalRow('Subtotal', money(totals.subtotalMinor)),
                  if (totals.discountMinor > 0)
                    totalRow('Discount', '- ${money(totals.discountMinor)}'),
                  if (totals.taxMinor > 0) totalRow('Tax', money(totals.taxMinor)),
                  pw.SizedBox(height: 2),
                  totalRow('Total', money(totals.totalMinor), emphasised: true),
                  for (final (label, minor) in data.afterTotal) totalRow(label, money(minor)),
                ],
              ),
            ),
          ],
        ),
        if (footer != null && footer.trim().isNotEmpty) ...[
          pw.SizedBox(height: 22),
          pw.Text(footer, style: small),
        ],
      ],
    ),
  );
  return document.save();
}
