import 'dart:convert' show base64Decode;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../documents/doc_models.dart';
import '../../documents/pdf_painters.dart';
import '../../documents/pdf_shared.dart';
import '../../documents/share_service.dart';
import '../widgets.dart';

Uint8List? _signatureImage(String signerName) {
  for (final u in AuthStore.instance.users) {
    if (u.name == signerName && u.signaturePng != null) {
      final dataUrl = u.signaturePng!;
      final b64 = dataUrl.split(',').last;
      try {
        return base64Decode(b64);
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

/// RECEIPTS — proof of payment, auto-numbered MTK-REC-####.
/// M4 renders these as branded PDFs (print + WhatsApp/email share).
class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final receipts = store.receipts.reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Receipts',
            subtitle: 'Auto-issued when money is received',
            icon: Icons.receipt_long,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              MetricPill(label: 'Receipts', value: '${receipts.length}', icon: Icons.receipt_long, accent: Mtek.success),
              MetricPill(label: 'Total collected', value: fmt.nairaCompact(store.receipts.fold(0, (s, r) => s + r.amount)), icon: Icons.payments_outlined, accent: Mtek.brand600),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: receipts.isEmpty
                  ? const EmptyHint('No receipts yet — complete a sale first')
                  : ListView.separated(
                      itemCount: receipts.length + 1,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == receipts.length) return const LoadOlderTile('receipts');
                        final r = receipts[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Mtek.successTint,
                            child: Icon(Icons.receipt_long, size: 18, color: Mtek.success),
                          ),
                          title: Text('${r.number} — ${r.customer.name}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              '${fmt.fmtDate(r.date)} · ${MethodIcon.label(r.method)} · for ${r.forDoc} · by ${r.issuedBy}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AmountText(r.amount),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Preview PDF',
                                icon: const Icon(Icons.picture_as_pdf_outlined, color: Mtek.brand600),
                                onPressed: () => previewReceipt(context, r),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void previewReceipt(BuildContext context, Receipt r) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 460,
          constraints: BoxConstraints(
            maxWidth: 460,
            maxHeight: MediaQuery.sizeOf(context).height - 48,
          ),
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 420 ? 18 : 28),
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Mtek.gray100),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Image.asset(
                      'assets/branding/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.business_outlined,
                        color: Mtek.brand600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('M-TEK FIRE & SAFETY LTD', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('Kaduna, Nigeria · RC 1082534', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              const Text('OFFICIAL RECEIPT', style: TextStyle(letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.w700, color: Mtek.brand600)),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(_displayReceiptNumber(r.number),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              const SizedBox(height: 16),
              _row(context, 'Received from', r.customer.name),
              _row(context, 'Date', fmt.fmtDate(r.date)),
              _row(context, 'Being payment for', r.forDoc),
              _row(context, 'Method', MethodIcon.label(r.method)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Mtek.brandTint, borderRadius: BorderRadius.circular(12)),
                child: Text('TOTAL: ${fmt.naira(r.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Mtek.brand700)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.verified_outlined, size: 17, color: Mtek.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Digitally signed by ${r.signedBy} — ${fmt.fmtDateTime(r.date)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Mtek.success),
                    ),
                  ),
                ],
              ),
              if (_signatureImage(r.signedBy) != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.memory(_signatureImage(r.signedBy)!, height: 42, alignment: Alignment.centerLeft),
                ),
              ],
              const SizedBox(height: 12),
              Text('Issued by: ${r.issuedBy} — thank you for your business.',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final narrow = box.maxWidth < 390;
                final width = narrow ? box.maxWidth : (box.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: width, child: OutlinedButton.icon(
                      onPressed: () => _sendReceipt(context, r),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share PDF'),
                    )),
                    SizedBox(width: width, child: FilledButton.icon(
                      onPressed: () => _printReceipt(context, r),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print'),
                    )),
                  ],
                );
              }),
            ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the REAL receipt PDF bytes (branded, signed) and hands the file
  /// to the OS share sheet — never pre-filled text (owner directive).
  Future<void> _sendReceipt(BuildContext context, Receipt r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _receiptBytes(context, r);
      final filename = r.number.toLowerCase().replaceAll('_', '-') +
          '_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final outcome = await dispatchPdf(bytes: bytes, filename: filename);
      messenger.showSnackBar(SnackBar(
        backgroundColor: outcome.result == ShareResult.failed ? Mtek.danger : Mtek.success,
        content: Text(outcome.message),
      ));
    } catch (e) {
      // Full detail goes to the console only — never onto a production
      // screen (no raw exception text, no stack traces).
      debugPrint('Receipt PDF share failed: $e');
      messenger.showSnackBar(const SnackBar(
          backgroundColor: Mtek.danger,
          content: Text('Could not build the PDF — please try again.')));
    }
  }

  /// Opens the system print dialog on the real receipt PDF.
  Future<void> _printReceipt(BuildContext context, Receipt r) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _receiptBytes(context, r);
      archivePdfInBackground(bytes: bytes,
        filename: '${r.number.toLowerCase().replaceAll('_', '-')}.pdf',
        description: 'Receipt ${r.number} · ${r.customer.name}');
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      debugPrint('Receipt PDF print failed: $e');
      messenger.showSnackBar(const SnackBar(
          backgroundColor: Mtek.danger,
          content: Text('Could not build the PDF — please try again.')));
    }
  }

  Future<Uint8List> _receiptBytes(BuildContext context, Receipt r) async {
    final logo = await DefaultAssetBundle.of(context).load('assets/branding/logo.png');
    final doc = ReceiptDocState()
      ..serial = int.tryParse(r.number.replaceAll(RegExp(r'\D'), '')) ?? 0
      ..name = r.customer.name
      ..address = r.customer.address
      ..phone = r.customer.phone
      ..customerEmail = r.customer.email
      ..amount = r.amount.toDouble()
      ..beingPaymentFor = r.forDoc
      ..method = MethodIcon.label(r.method)
      ..date = r.date
      ..customerSignature = r.customerSignature;
    return buildDocument(
      GeneratedDoc.receipt,
      logoBytes: logo.buffer.asUint8List(),
      receipt: doc,
      invoice: null,
      mils: null,
      waybill: null,
      deliveryNote: null,
      signedBy: r.signedBy,
      signaturePngBytes: _signatureImage(r.signedBy),
      customerSignaturePngBytes: dataUrlToBytes(r.customerSignature),
    );
  }

  String _displayReceiptNumber(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return number;
    final serial = int.tryParse(digits) ?? 0;
    return 'MTK-REC-${serial.toString().padLeft(9, '0')}';
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 140, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );
}
