import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'branding.dart';
import 'doc_models.dart';
import 'forms_spec.dart';
import 'pdf_shared.dart';

/// DYNAMIC PDF PAINTER (blueprint Part 1): conditional layout builders
/// that swap grids, fields and banners per document type, mapping 1:1 to
/// the physical corporate forms (docs/forms/FORM_LAYOUTS.md).
///
/// Every document gets: single-office corporate header, centred watermark and right-side brand panel,
/// signature stamp of the signer, QR verification hash, exact disclaimers.

enum GeneratedDoc { receipt, invoice, mils, waybill, deliveryNote }

Future<Uint8List> buildDocument(
  GeneratedDoc type, {
  required Uint8List logoBytes,
  required ReceiptDocState? receipt,
  required InvoiceDocState? invoice,
  required MilsDocState? mils,
  required WaybillDocState? waybill,
  required DeliveryNoteDocState? deliveryNote,
  required String signedBy,
  Uint8List? signaturePngBytes,
  Uint8List? customerSignaturePngBytes,
}) async {
  await MtekPdfFonts.load();
  final logo = pw.MemoryImage(logoBytes);
  final signature = _safeImage(signaturePngBytes);
  final customerSig = _safeImage(customerSignaturePngBytes);

  final doc = pw.Document();
  switch (type) {
    case GeneratedDoc.receipt:
      doc.addPage(_receiptPage(logo, signature, customerSig, receipt!, signedBy));
    case GeneratedDoc.invoice:
      doc.addPage(_invoicePage(logo, signature, customerSig, invoice!, signedBy));
    case GeneratedDoc.mils:
      doc.addPage(_milsPage(logo, signature, customerSig, mils!, signedBy));
    case GeneratedDoc.waybill:
      doc.addPage(_waybillPage(logo, signature, customerSig, waybill!, signedBy));
    case GeneratedDoc.deliveryNote:
      doc.addPage(_deliveryNotePage(logo, signature, customerSig, deliveryNote!, signedBy));
  }
  return doc.save();
}

/// A PNG that fails to decode (empty capture, legacy/corrupt data URL) is
/// simply omitted from the document instead of aborting the whole PDF.
pw.ImageProvider? _safeImage(Uint8List? bytes) {
  if (bytes == null || bytes.length < 24) return null;
  try {
    final img = pw.MemoryImage(bytes);
    // force header parse now so a bad image fails HERE, not inside save()
    img.width;
    img.height;
    return img;
  } catch (_) {
    return null;
  }
}

pw.PageTheme _theme(pw.ImageProvider logo, PdfPageFormat format) {
  return pw.PageTheme(
    pageFormat: format,
    margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 16),
    theme: pw.ThemeData.withFont(base: MtekPdfFonts.base, bold: MtekPdfFonts.bold),
    buildBackground: (context) => documentBackground(logo, format),
  );
}

// =====================================================================
// 1. PAYMENT RECEIPT (landscape — mirrors No: 2131 book)
// =====================================================================
pw.MultiPage _receiptPage(
    pw.ImageProvider logo,
    pw.ImageProvider? signature,
    pw.ImageProvider? customerSig,
    ReceiptDocState r,
    String signedBy) {
  final methodChecked = (String m) => r.method.toLowerCase() == m.toLowerCase();
  final hashPayload =
      '${r.serial}|${r.amount}|${r.date.toIso8601String()}|${r.name}';

  return pw.MultiPage(
    pageTheme: _theme(logo, PdfPageFormat.a4.landscape),
    maxPages: 20,
    build: (context) => [
      corporateHeader(logo),
      pw.SizedBox(height: 10),

      // Identity row: customer | IRN + title | No + Date
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              ruledField('Name:', value: r.name),
              ruledField('Address:', value: r.address, maxLines: 2),
              ruledField('Phone No.', value: r.phone),
            ]),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 2,
          child: pw.Column(children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red900, width: 1.4)),
              child: pw.Text('IRN: ${r.irn}',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              color: PdfColors.red900,
              alignment: pw.Alignment.center,
              child: pw.Text('PAYMENT RECEIPT',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            ),
          ]),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 2,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('No: ${_pad9(r.serial)}',
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ruledField('Date:', value: _d(r.date)),
          ]),
        ),
      ]),
      pw.SizedBox(height: 10),

      // The Sum of | Being Payment for
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              ruledField('The Sum of', value: r.amountInWords, fontSize: 9),
              ruledField(''),
              ruledField(''),
            ]),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              ruledField('Being Payment for', value: r.beingPaymentFor),
              ruledField(''),
            ]),
          ),
        ),
      ]),
      pw.SizedBox(height: 10),

      // 2×2 payment-method grid (exact paper layout)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(children: [
            _methodBox('Cash', methodChecked('Cash'), '₦${_money(r.amount)}'),
            pw.SizedBox(height: 8),
            _methodBox('Transfer', methodChecked('Transfer')),
          ]),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(children: [
            _methodBox('Cheque', methodChecked('Cheque')),
            pw.SizedBox(height: 8),
            _methodBox('POS', methodChecked('POS')),
          ]),
        ),
      ]),
      pw.SizedBox(height: 12),

      // Sign-off boxes. NOTE: no Spacer/Expanded inside these — under
      // MultiPage that resolves to an infinite height and the pdf package
      // throws "Widget won't fit into the page (height Infinity)", which
      // is exactly what made every receipt fail to generate.
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            height: 56,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('For: M-TEK FIRE & SAFETY LTD',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  if (signature != null)
                    pw.Image(signature, width: 62, height: 20, fit: pw.BoxFit.contain),
                  if (signature != null) pw.SizedBox(width: 6),
                  pw.Text(signedBy, style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                ]),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            height: 56,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("For: CUSTOMER'S/CLIENT",
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                customerSig != null
                    ? pw.Image(customerSig, width: 70, height: 24, fit: pw.BoxFit.contain)
                    : pw.Container(
                        width: 120,
                        height: 1,
                        margin: const pw.EdgeInsets.only(bottom: 4),
                        color: PdfColors.grey600),
              ],
            ),
          ),
        ),
      ]),
      pw.SizedBox(height: 8),

      // Disclaimers (exact wording from the book)
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        color: PdfColors.amber50,
        child: pw.Text(MtekBranding.receiptDisclaimer,
            style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.left),
      ),
      pw.SizedBox(height: 6),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Digitally signed by $signedBy — ${_dt(r.date)}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
        verificationFooter('receipt', r.serial ?? 0, hashPayload),
      ]),
    ],
  );
}

pw.Widget _methodBox(String label, bool checked, [String value = '']) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
    child: pw.Row(children: [
      pw.Container(
        width: 10,
        height: 10,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
        alignment: pw.Alignment.center,
        child: checked ? pw.Text('✓', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)) : null,
      ),
      pw.SizedBox(width: 6),
      pw.Container(width: 52, child: pw.Text(label, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold))),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(left: 4),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: .7))),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 9.5, fontWeight: checked ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ),
    ]),
  );
}

// =====================================================================
// 2. SALES INVOICE (portrait — mirrors No: 4335 book)
// =====================================================================
pw.MultiPage _invoicePage(
    pw.ImageProvider logo,
    pw.ImageProvider? signature,
    pw.ImageProvider? customerSig,
    InvoiceDocState v,
    String signedBy) {
  final hashPayload = '${v.serial}|${v.grandTotal}|${v.date.toIso8601String()}|${v.name}';

  final rows = <List<String>>[
    for (var i = 0; i < v.rows.length; i++)
      if (v.rows[i].description.trim().isNotEmpty)
        [
          '${i + 1}',
          v.rows[i].description,
          _qty(v.rows[i].qty),
          _money(v.rows[i].rate),
          _nairaPart(v.rows[i].amount),
          _koboPart(v.rows[i].amount),
        ],
    ];
  while (rows.length < 14) {
    rows.add(['', '', '', '', '', '']); // blank ruled rows like the book
  }

  return pw.MultiPage(
    pageTheme: _theme(logo, PdfPageFormat.a4),
    maxPages: 20,
    build: (context) => [
      corporateHeader(logo),
      pw.SizedBox(height: 8),

      // Document-type checkbox cluster
      pw.Row(children: [
        checkboxCell('MILS No:', v.showMilsNo),
        pw.SizedBox(width: 8),
        checkboxCell('RECEIPT NO:', v.showReceiptNo),
        pw.SizedBox(width: 8),
        checkboxCell('WAY BILL', v.variant == 'WAY BILL'),
        pw.SizedBox(width: 8),
        checkboxCell('PRO-FORMER', v.variant == 'PRO-FORMER'),
        pw.SizedBox(width: 8),
        checkboxCell('SERVICE INVOICE', v.variant == 'SERVICE INVOICE'),
        pw.SizedBox(width: 8),
        checkboxCell('SALES INVOICE', v.variant == 'SALES INVOICE'),
      ]),
      pw.SizedBox(height: 6),

      // Three clean information rows: reference numbers, name/date, then
      // address/phone. Full labels remain readable and every numeric document
      // reference is rendered as nine digits.
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(child: ruledField('MILS No:', value: _docNo(v.milsNo), fontSize: 7.5)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: ruledField('Receipt No:', value: _docNo(v.receiptNo), fontSize: 7.5)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: ruledField('L.P.O No:', value: _docNo(v.lpoNo), fontSize: 7.5)),
        pw.SizedBox(width: 12),
        pw.Text('No: ${_pad9(v.serial)}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ]),
      pw.Row(children: [
        pw.Expanded(flex: 4, child: ruledField('Name:', value: v.name)),
        pw.SizedBox(width: 10),
        pw.Expanded(flex: 2, child: ruledField('Date:', value: _d(v.date))),
      ]),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Expanded(flex: 3, child: ruledField('Address:', value: v.address, maxLines: 2)),
        pw.SizedBox(width: 10),
        pw.Expanded(flex: 2, child: ruledField('Phone:', value: v.phone)),
      ]),
      pw.SizedBox(height: 4),

      // Itemised ledger (dual naira/kobo amount columns)
      pw.TableHelper.fromTextArray(
        context: context,
        headers: ['S/NO', 'DESCRIPTION', 'QTY', 'RATE (₦)', 'AMOUNT (₦)', 'K'],
        data: rows,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignment: pw.Alignment.centerLeft,
        columnWidths: const {
          0: pw.FixedColumnWidth(30),
          1: pw.FlexColumnWidth(5),
          2: pw.FixedColumnWidth(36),
          3: pw.FixedColumnWidth(60),
          4: pw.FixedColumnWidth(66),
          5: pw.FixedColumnWidth(28),
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
      ),
      pw.SizedBox(height: 8),

      // Financial summary
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Spacer(),
        pw.SizedBox(
          width: 240,
          child: pw.Column(children: [
            if (v.discount > 0) _summaryRow('Subtotal', v.subtotal),
            if (v.discount > 0) _summaryRow('Discount', -v.discount),
            _summaryRow('TOTAL (before VAT)', v.total, bold: true),
            if (v.vatEnabled) _summaryRow('${(v.vatRate * 100).toStringAsFixed(2)}% VAT', v.vat),
            _summaryRow('GRAND TOTAL', v.grandTotal, bold: true),
            pw.SizedBox(height: 4),
          ]),
        ),
      ]),
      pw.SizedBox(height: 6),
      ruledField('Amount in words:', value: v.amountInWords, fontSize: 8.5),
      if (v.paymentTerms.trim().isNotEmpty) ruledField('Payment terms:', value: v.paymentTerms, fontSize: 8.2),
      if (v.paymentInstructions.trim().isNotEmpty) ruledField('Payment instructions:', value: v.paymentInstructions, fontSize: 8.2, maxLines: 2),
      if (v.notes.trim().isNotEmpty) ruledField('Notes:', value: v.notes, fontSize: 8.2, maxLines: 3),
      pw.SizedBox(height: 4),
      pw.Row(children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Text('Advance Payment: ₦${_money(v.advancePayment)}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Text('Balance Payment: ₦${_money(v.balance)}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          ),
        ),
      ]),
      pw.SizedBox(height: 12),

      _signOffRow(signature, signedBy, ['Prepared by:', 'Approved by:', 'Customer/Client']),
      if (customerSig != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Row(children: [
            pw.Text("Customer's signature:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 8),
            pw.Image(customerSig, height: 34),
          ]),
        ),
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        color: PdfColors.amber50,
        child: pw.Text(MtekBranding.invoiceDisclaimer, style: const pw.TextStyle(fontSize: 6.5)),
      ),
      pw.SizedBox(height: 6),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Digitally signed by $signedBy — ${_dt(v.date)}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
        verificationFooter('invoice', v.serial ?? 0, hashPayload),
      ]),
    ],
  );
}

// =====================================================================
// 3. MAINTENANCE INFORMATION LOG SHEET (portrait — mirrors No: 925 book)
// =====================================================================
pw.MultiPage _milsPage(pw.ImageProvider logo, pw.ImageProvider? signature,
    pw.ImageProvider? customerSig, MilsDocState m, String signedBy) {
  final hashPayload = '${m.serial}|${m.grandTotal}|${m.entryDate.toIso8601String()}|${m.name}';

  final weightRows = <List<String>>[
    for (final wc in MtekForms.weightClasses)
      [
        wc.label,
        m.weightQty[wc.kg]?.toStringAsFixed(0) ?? '',
        m.weightRate[wc.kg] != null ? _money(m.weightRate[wc.kg]!) : '',
        (m.weightQty[wc.kg] ?? 0) > 0 ? _money((m.weightQty[wc.kg] ?? 0) * (m.weightRate[wc.kg] ?? 0)) : '',
      ],
  ];

  final componentRows = <List<String>>[
    for (final c in MtekForms.components)
      [
        c,
        m.componentQty[c]?.toStringAsFixed(0) ?? '',
        m.componentRate[c] != null ? _money(m.componentRate[c]!) : '',
        (m.componentQty[c] ?? 0) > 0 ? _money((m.componentQty[c] ?? 0) * (m.componentRate[c] ?? 0)) : '',
      ],
  ];

  return pw.MultiPage(
    pageTheme: _theme(logo, PdfPageFormat.a4),
    maxPages: 20,
    build: (context) => [
      corporateHeader(logo),
      pw.SizedBox(height: 6),

      // Red title banner + MILS No
      pw.Row(children: [
        pw.Expanded(
          child: pw.Container(
            color: PdfColors.red900,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            alignment: pw.Alignment.center,
            child: pw.Text('MAINTENANCE INFORMATION LOG SHEET',
                style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red900, width: 1.2)),
          child: pw.Text('MILS No: ${_pad9(m.serial)}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
        ),
      ]),
      pw.SizedBox(height: 6),

      // Top field row
      pw.Row(children: [
        pw.Expanded(child: ruledField('Entry Date:', value: _d(m.entryDate), fontSize: 7.5)),
        pw.SizedBox(width: 10),
        pw.Expanded(child: ruledField('Collection Date:', value: _d(m.collectionDate), fontSize: 7.5)),
        pw.SizedBox(width: 10),
        pw.Expanded(child: ruledField('Next Service Date:', value: _d(m.nextServiceDate), fontSize: 7.5)),
      ]),
      pw.Row(children: [
        pw.Expanded(child: ruledField('Invoice No:', value: _docNo(m.invoiceNo), fontSize: 7.5)),
        pw.SizedBox(width: 6),
        pw.Expanded(child: ruledField('Receipt No:', value: _docNo(m.receiptNo), fontSize: 7.5)),
        pw.SizedBox(width: 6),
        pw.Expanded(child: ruledField('L.P.O No:', value: _docNo(m.lpoNo), fontSize: 7.5)),
      ]),
      pw.SizedBox(height: 4),

      // SECTION A — DESCRIPTION (weights)
      pw.Text('DESCRIPTION:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        context: context,
        headers: ['Description', 'Qty', 'Rate (₦)', 'Amount (₦)'],
        data: weightRows,
        headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(4),
          1: pw.FixedColumnWidth(50),
          2: pw.FixedColumnWidth(64),
          3: pw.FixedColumnWidth(70),
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.8),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
      ),
      pw.SizedBox(height: 6),

      // SECTION B — REPLACEMENT (components)
      pw.Text('REPLACEMENT:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
      pw.SizedBox(height: 3),
      pw.TableHelper.fromTextArray(
        context: context,
        headers: ['Component', 'Qty', 'Rate (₦)', 'Amount (₦)'],
        data: componentRows,
        headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        columnWidths: const {
          0: pw.FlexColumnWidth(4),
          1: pw.FixedColumnWidth(50),
          2: pw.FixedColumnWidth(64),
          3: pw.FixedColumnWidth(70),
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.8),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
      ),
      pw.SizedBox(height: 8),

      // Customer block + summary boxes
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            ruledField("Customer's Name:", value: m.name, fontSize: 8.5),
            ruledField('Address:', value: m.address, fontSize: 8.5, maxLines: 2),
            ruledField('Phone:', value: m.phone, fontSize: 8.5),
            ruledField('Bill in words:', value: m.amountInWords, fontSize: 8.5),
          ]),
        ),
        pw.SizedBox(width: 14),
        pw.SizedBox(
          width: 200,
          child: pw.Column(children: [
            if (m.discount > 0) _summaryBox('Subtotal', m.subtotal),
            if (m.discount > 0) pw.SizedBox(height: 5),
            if (m.discount > 0) _summaryBox('Discount', -m.discount),
            if (m.discount > 0) pw.SizedBox(height: 5),
            _summaryBox('TOTAL (before VAT)', m.total, bold: true),
            pw.SizedBox(height: 5),
            if (m.vatEnabled) ...[
              _summaryBox('${(m.vatRate * 100).toStringAsFixed(2)}% VAT', m.vat),
              pw.SizedBox(height: 5),
            ],
            _summaryBox('Grand Total', m.grandTotal, bold: true),
            pw.SizedBox(height: 5),
            _summaryBox('Advance Payment', m.advancePayment),
            pw.SizedBox(height: 5),
            _summaryBox('Balance Total', m.balance, bold: true),
          ]),
        ),
      ]),
      pw.SizedBox(height: 8),
      if (m.paymentTerms.trim().isNotEmpty) ruledField('Payment terms:', value: m.paymentTerms, fontSize: 8.2),
      if (m.paymentInstructions.trim().isNotEmpty) ruledField('Payment instructions:', value: m.paymentInstructions, fontSize: 8.2, maxLines: 2),
      if (m.notes.trim().isNotEmpty) ruledField('Service notes:', value: m.notes, fontSize: 8.2, maxLines: 3),
      pw.SizedBox(height: 6),

      if (customerSig != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(children: [
            pw.Text("Customer's assent:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 8),
            pw.Image(customerSig, height: 34),
          ]),
        ),
      _signOffRow(signature, signedBy,
          ['Prepared by:', 'APPROVED by:', "Customer's Assent:", "Collector's Assent:"]),
      pw.SizedBox(height: 8),

      // Caution fine print (owner-confirmed wording)
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        color: PdfColors.amber50,
        child: pw.Text(MtekBranding.milsCaution, style: const pw.TextStyle(fontSize: 6.2)),
      ),
      pw.SizedBox(height: 6),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Digitally signed by $signedBy — ${_dt(m.entryDate)}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
        verificationFooter('mils', m.serial ?? 0, hashPayload),
      ]),
    ],
  );
}

// =====================================================================
// 4. WAYBILL (landscape — mirrors the No: 0174 carbon-copy book)
// =====================================================================
pw.MultiPage _waybillPage(
    pw.ImageProvider logo,
    pw.ImageProvider? signature,
    pw.ImageProvider? customerSig,
    WaybillDocState w,
    String signedBy) {
  final hashPayload =
      '${w.serial}|${w.destination}|${w.date.toIso8601String()}|${w.name}';
  final itemRows = <List<String>>[
    for (var i = 0; i < w.rows.length; i++)
      if (w.rows[i].product.trim().isNotEmpty)
        [
          '${i + 1}',
          w.rows[i].product,
          w.rows[i].techSpec,
          w.rows[i].brand,
          w.rows[i].qty == 0 ? '' : w.rows[i].qty.toString(),
        ]
  ];
  return pw.MultiPage(
    pageTheme: _theme(logo, PdfPageFormat.a4.portrait),
    maxPages: 20,
    build: (context) => [
      corporateHeader(logo),
      pw.SizedBox(height: 8),
      pw.Center(
          child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 3),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue700, width: 1.4),
                color: PdfColors.blue50,
              ),
              child: pw.Text('WAYBILL',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold, letterSpacing: 2)))),
      pw.SizedBox(height: 6),

      // Reference chips row (mirrors the physical boxes)
      pw.Row(children: [
        _refBox('MILS NO:', w.milsNo),
        _refBox('RECEIPT NO:', w.receiptNo),
        _refBox('INVOICE NO:', w.invoiceNo),
        _refBox('LPO NO:', w.lpoNo),
      ]),
      pw.SizedBox(height: 5),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          flex: 3,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              ruledField("Buyer's name:", value: w.name),
              ruledField('Phone:', value: w.phone),
              ruledField('Address:', value: w.address, maxLines: 2),
            ]),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.2)),
            child: pw.Column(children: [
              pw.Text('No:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(_pad9(w.serial),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text('Date: ${_dt(w.date)}', style: const pw.TextStyle(fontSize: 8)),
            ]),
          ),
        ),
      ]),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        context: context,
        headers: ['SNO', 'PRODUCTS', 'TECH. SPEC', 'BRAND', 'QTY'],
        data: itemRows.isEmpty ? [['', '', '', '', '']] : itemRows,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 8),
        columnWidths: const {
          0: pw.FixedColumnWidth(34),
          1: pw.FlexColumnWidth(4),
          2: pw.FlexColumnWidth(3),
          3: pw.FlexColumnWidth(2),
          4: pw.FixedColumnWidth(44),
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
      ),
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
        child: pw.Column(children: [
          ruledField('Originating from:', value: w.originatingFrom),
          ruledField('Destination:', value: w.destination),
          ruledField("Driver's name:", value: '${w.driverName}   Phone no: ${w.driverPhone}'),
          ruledField("Vehicle's brand:", value: '${w.vehicleBrand}   Plate no: ${w.plateNo}'),
          ruledField('Colour:', value: w.colour),
          ruledField("Receiver's name:", value: '${w.receiverName}   Phone no: ${w.receiverPhone}'),
          ruledField('Approved by:', value: w.approvedBy),
        ]),
      ),
      pw.SizedBox(height: 5),
      _signOffRow(signature, signedBy, ['Prepared by:', "Buyer's signature:"]),
      if (customerSig != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Row(children: [
            pw.Text("Receiver's signature:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 8),
            pw.Image(customerSig, height: 34),
          ]),
        ),
      pw.SizedBox(height: 4),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        color: PdfColors.red50,
        child: pw.Text(
          'Caution! Once contact is established between the buyer or his agent with the '
          'waybill company, it is only the responsibility of the customer to do goods on '
          'transit insurance cover and tracking, until his/her goods are secured. '
          'Therefore, we bear no liability on goods lost on transit or damaged.',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.red900, fontStyle: pw.FontStyle.italic),
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Digitally signed by $signedBy — ${_dt(w.date)}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
        verificationFooter('waybill', w.serial ?? 0, hashPayload),
      ]),
    ],
  );
}

pw.Widget _refBox(String label, String value) {
  final displayValue = _docNo(value);
  final valueSize = displayValue.length > 9 ? 6.5 : 7.5;
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
      child: pw.Row(children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(width: 2),
        pw.Expanded(
          child: pw.Text(displayValue, maxLines: 1, softWrap: false,
              style: pw.TextStyle(fontSize: valueSize, fontWeight: pw.FontWeight.bold)),
        ),
      ]),
    ),
  );
}

// =====================================================================
// 5. DELIVERY NOTE (portrait — mirrors the pre-printed 19790088 book)
// =====================================================================
pw.MultiPage _deliveryNotePage(
    pw.ImageProvider logo,
    pw.ImageProvider? signature,
    pw.ImageProvider? customerSig,
    DeliveryNoteDocState d,
    String signedBy) {
  final hashPayload =
      '${d.serial}|${d.customerName}|${d.orderDate.toIso8601String()}|${d.location}';
  final itemRows = <List<String>>[
    for (var i = 0; i < d.rows.length; i++)
      if (d.rows[i].description.trim().isNotEmpty)
        [
          '${i + 1}',
          d.rows[i].description,
          d.rows[i].ordered == 0 ? '' : d.rows[i].ordered.toString(),
          d.rows[i].delivered == 0 ? '' : d.rows[i].delivered.toString(),
          d.rows[i].outstanding == 0 ? '' : d.rows[i].outstanding.toString(),
        ]
  ];
  pw.Widget addrCol(String title, List<pw.Widget> fields) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey500)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: PdfColors.grey300,
                child: pw.Text(title,
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 4),
            ...fields,
          ]),
        ),
      );
  return pw.MultiPage(
    pageTheme: _theme(logo, PdfPageFormat.a4.portrait),
    maxPages: 20,
    build: (context) => [
      corporateHeader(logo),
      pw.SizedBox(height: 8),
      pw.Center(
          child: pw.Text('DELIVERY NOTE',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold, letterSpacing: 2, color: PdfColors.blue900))),
      pw.SizedBox(height: 6),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        addrCol('Invoice Address:', [
          ruledField("CUSTOMER'S NAME:", value: d.customerName),
          ruledField('INSTITUTION:', value: d.institution),
          ruledField('ADDRESS:', value: d.address),
          ruledField('PHONE NO.:', value: d.phone),
        ]),
        pw.SizedBox(width: 10),
        addrCol('Shipping Address:', [
          ruledField('LOCATION:', value: d.location),
          ruledField('RECEIVER:', value: d.receiver),
          ruledField("RECEIVER'S NO.:", value: d.receiverNo),
          ruledField('SIGNATURE:', value: d.receiverSignature),
        ]),
      ]),
      pw.SizedBox(height: 6),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            ruledField('Date of Order:', value: _dt(d.orderDate)),
            ruledField('Proforma Invoice ID:', value: d.proformaInvoiceId),
            ruledField("Customer's ID:", value: d.customerId),
            ruledField('Dispatch:', value: d.dispatch),
            ruledField('Delivery Method:', value: d.deliveryMethod),
          ]),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.2)),
            child: pw.Column(children: [
              pw.Text('Delivery Note No:',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text(_pad9(d.serial),
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            ]),
          ),
        ),
      ]),
      pw.SizedBox(height: 4),
      ruledField('Account No.:', value: '${d.accountNo}   Account Name: ${d.accountName}'),
      ruledField('Banker:', value: d.banker),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        context: context,
        headers: ['S/NO', 'DESCRIPTION', 'ORDERED', 'DELIVERED', 'OUTSTANDING'],
        data: itemRows.isEmpty ? [['', '', '', '', '']] : itemRows,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 8),
        columnWidths: const {
          0: pw.FixedColumnWidth(34),
          1: pw.FlexColumnWidth(5),
          2: pw.FixedColumnWidth(56),
          3: pw.FixedColumnWidth(60),
          4: pw.FixedColumnWidth(68),
        },
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
        border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
      ),
      pw.SizedBox(height: 6),
      ruledField('SUMMARY:', value: d.summary),
      pw.SizedBox(height: 6),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          'Goods must be checked before signing as signature and or Stamp confirms correct '
          'quantity and satisfactory condition. Only payment made into the company\'s '
          'designated account are recognized.',
          style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
        ),
      ),
      pw.SizedBox(height: 5),
      _signOffRow(signature, signedBy, ['Prepared by:', 'Approved by:', 'Client — acknowledges the receipt of the goods described above:']),
      if (customerSig != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Row(children: [
            pw.Text("Client's signature:", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 8),
            pw.Image(customerSig, height: 34),
          ]),
        ),
      pw.SizedBox(height: 6),
      pw.Center(
          child: pw.Text('Motto: We are not competing, we are setting standards',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, fontStyle: pw.FontStyle.italic))),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Digitally signed by $signedBy — ${_dt(d.orderDate)}',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
        verificationFooter('deliverynote', d.serial ?? 0, hashPayload),
      ]),
    ],
  );
}

// shared bits -----------------------------------------------------------

pw.Widget _summaryRow(String label, double amount, {bool bold = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.black, width: bold ? 1.1 : .7),
      color: bold ? PdfColors.amber50 : null,
    ),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      pw.Text('₦${_money(amount)}', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
    ]),
  );
}

pw.Widget _summaryBox(String label, double amount, {bool bold = false}) {
  return _summaryRow(label, amount, bold: bold);
}

pw.Widget _signOffRow(pw.ImageProvider? signature, String signedBy, List<String> labels) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0) pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 1, color: PdfColors.grey600),
            pw.SizedBox(height: 2),
            pw.Text(labels[i], style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            if (i == 0 && signature != null)
              pw.Image(signature, width: 62, height: 20, fit: pw.BoxFit.contain)
            else if (i == 0)
              pw.Text(signedBy, style: const pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
          ]),
        ),
      ],
    ],
  );
}

String _d(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _dt(DateTime d) =>
    '${_d(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _money(num n) => n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2)
    .replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
String _qty(num q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(1);
String _nairaPart(num n) => n.floor().toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), ',');
String _koboPart(num n) => ((n - n.floor()) * 100).round().toString().padLeft(2, '0');

/// Printed document serials are always exactly nine digits.
String _pad9(int? value) => (value ?? 0).toString().padLeft(9, '0');

/// User-entered cross references receive the same nine-digit treatment when
/// they are numeric. Prefixed references are preserved verbatim.
String _docNo(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';
  return RegExp(r'^\d+$').hasMatch(clean) && clean.length <= 9
      ? clean.padLeft(9, '0')
      : clean;
}
