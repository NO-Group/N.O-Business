// Renders every document type headlessly so a PDF layout/asset failure
// breaks the CI build with the REAL exception instead of surfacing only as
// "PDF could not be generated" on a phone.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtek_inventory/documents/doc_models.dart';
import 'package:mtek_inventory/documents/pdf_painters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Serve real files from assets/ for rootBundle.load (no asset bundle in tests).
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (ByteData? message) async {
      final key = utf8Decode(message!);
      final f = File(key);
      if (!f.existsSync()) return null;
      final bytes = f.readAsBytesSync();
      return ByteData.view(bytes.buffer);
    });
  });

  final logo = File('assets/branding/logo.png').readAsBytesSync();

  Future<void> render(GeneratedDoc type) async {
    final receipt = ReceiptDocState()
      ..serial = 1..name = 'Test Customer'..phone = '0800'..amount = 12500..beingPaymentFor = 'Refill';
    final invoice = InvoiceDocState()
      ..serial = 1..name = 'Test Customer'..phone = '0800'
      ..rows = [LedgerRow(description: '9kg DCP refill', qty: 2, rate: 5000)];
    final mils = MilsDocState()..serial = 1..name = 'Test Customer'..phone = '0800';
    final waybill = WaybillDocState()..serial = 1..name = 'Test Customer'..phone = '0800';
    final dn = DeliveryNoteDocState()..serial = 1..customerName = 'Test Customer'..phone = '0800';
    final bytes = await buildDocument(type,
        logoBytes: logo, receipt: receipt, invoice: invoice, mils: mils,
        waybill: waybill, deliveryNote: dn, signedBy: 'CI Tester',
        signaturePngBytes: Uint8List.fromList([1, 2, 3]), // deliberately bad → must be ignored
        customerSignaturePngBytes: null);
    expect(bytes.length, greaterThan(1000), reason: '$type produced an empty PDF');
    // keep the output so CI can rasterise it for layout review
    final out = File('build/pdf_preview/${type.name}.pdf')..parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes);
  }

  for (final t in GeneratedDoc.values) {
    test('builds $t PDF', () => render(t));
  }
}

String utf8Decode(ByteData d) => String.fromCharCodes(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
