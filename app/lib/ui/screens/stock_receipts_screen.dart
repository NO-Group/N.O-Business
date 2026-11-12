import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../documents/pdf_shared.dart';
import '../../documents/share_service.dart';
import '../signature_dialog.dart';
import '../widgets.dart';

class StockReceiptsScreen extends StatefulWidget {
  const StockReceiptsScreen({super.key});
  @override State<StockReceiptsScreen> createState() => _StockReceiptsScreenState();
}

class _StockRow {
  Product? product;
  final qty = TextEditingController(), damaged = TextEditingController(), missing = TextEditingController();
  void dispose() { qty.dispose(); damaged.dispose(); missing.dispose(); }
}

class _StockReceiptsScreenState extends State<StockReceiptsScreen> {
  final List<Map<String, dynamic>> _receipts = [];
  bool _loading = false;
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final api = AppStore.instance.api; if (api == null) return;
    setState(() => _loading = true);
    final res = await api.get('/api/stock-receipts');
    if (mounted) setState(() {
      _loading = false; _receipts
        ..clear()
        ..addAll([for (final x in (res?.json is Map ? (res!.json as Map)['rows'] as List? ?? [] : [])) if (x is Map) x.cast<String, dynamic>()]);
    });
  }

  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeader(title: 'Stock Receipts', subtitle: 'Received stock, deficits and CEO approval',
        icon: Icons.inventory_2_outlined, actions: [FilledButton.icon(onPressed: _create,
          icon: const Icon(Icons.add), label: const Text('New receipt'))]),
      const SizedBox(height: 14),
      Expanded(child: Card(child: _loading ? const Center(child: CircularProgressIndicator()) :
        _receipts.isEmpty ? const EmptyHint('No stock receipts yet') : ListView.separated(
          itemCount: _receipts.length, separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) { final r = _receipts[i]; final approved = r['status'] == 'approved';
            return ListTile(leading: Icon(approved ? Icons.verified : Icons.pending_actions,
              color: approved ? Mtek.success : Mtek.warn),
              title: Text('Stock Receipt ${(r['serial'] as num? ?? 0).toInt().toString().padLeft(9, '0')}'),
              subtitle: Text('${r['receipt_date'] ?? ''} · ${r['receiver_name'] ?? ''} · ${approved ? 'APPROVED' : 'PENDING CEO APPROVAL'}'),
              trailing: Wrap(children: [IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: () => _pdf(r)),
                if (!approved && AuthStore.instance.isCeo) FilledButton(onPressed: () => _approve(r), child: const Text('Approve'))]),
            ); },
        ))),
    ]));

  Future<void> _create() async {
    final rows = <_StockRow>[_StockRow()];
    final accepted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (_, update) => AlertDialog(title: const Text('New Stock Receipt'),
        content: SizedBox(width: 650, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Date: ${DateTime.now().toIso8601String().split('T').first}'), const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
            Autocomplete<Product>(displayStringForOption: (p) => p.name,
              optionsBuilder: (v) { final q = v.text.toLowerCase(); return AppStore.instance.products.where((p) => !p.isService && (q.isEmpty || p.name.toLowerCase().contains(q) || p.id.toLowerCase().contains(q))); },
              onSelected: (p) => rows[i].product = p,
              fieldViewBuilder: (_, c, f, __) => TextField(controller: c, focusNode: f,
                decoration: InputDecoration(labelText: 'S/No ${i + 1} — type to select existing stock item'))),
            const SizedBox(height: 8), Row(children: [
              Expanded(child: TextField(controller: rows[i].qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity received'))),
              const SizedBox(width: 6), Expanded(child: TextField(controller: rows[i].damaged, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Damaged'))),
              const SizedBox(width: 6), Expanded(child: TextField(controller: rows[i].missing, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Missing'))),
              IconButton(onPressed: rows.length == 1 ? null : () => update(() { rows.removeAt(i).dispose(); }), icon: const Icon(Icons.delete_outline)),
            ])
          ]))),
          TextButton.icon(onPressed: () => update(() => rows.add(_StockRow())), icon: const Icon(Icons.add), label: const Text('Add row')),
          Text('Net stock added after CEO approval = received − damaged − missing.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Sign & submit'))])));
    if (accepted != true) { for (final r in rows) r.dispose(); return; }
    final valid = rows.where((r) => r.product != null && (int.tryParse(r.qty.text) ?? 0) > 0).toList();
    if (valid.isEmpty) { _snack('Select at least one existing stock item.'); return; }
    for (final r in valid) if ((int.tryParse(r.damaged.text) ?? 0) + (int.tryParse(r.missing.text) ?? 0) > (int.tryParse(r.qty.text) ?? 0)) { _snack('Deficits cannot exceed quantity received.'); return; }
    final signer = await confirmSignature(context); if (signer == null) return;
    final api = AppStore.instance.api;
    final res = await api?.post('/api/stock-receipts', {'date': DateTime.now().toIso8601String(), 'receiver_signature': signer.signaturePng ?? '',
      'rows': [for (final r in valid) {'product_id': r.product!.id, 'particulars': r.product!.name, 'quantity': int.parse(r.qty.text), 'damaged': int.tryParse(r.damaged.text) ?? 0, 'missing': int.tryParse(r.missing.text) ?? 0}]});
    for (final r in rows) r.dispose();
    if (res == null || !res.ok) { _snack('${res?.json is Map ? (res!.json as Map)['error'] : 'Cloud unavailable — stock receipt was not submitted'}'); return; }
    await _load(); _snack('Stock Receipt submitted for CEO approval.');
  }

  Future<void> _approve(Map<String, dynamic> r) async {
    final signer = await confirmSignature(context, force: true); if (signer == null) return;
    final res = await AppStore.instance.api?.post('/api/stock-receipts/approve', {'id': '${r['_id']}', 'approval_signature': signer.signaturePng ?? ''});
    if (res == null || !res.ok) { _snack('${res?.json is Map ? (res!.json as Map)['error'] : 'Approval failed'}'); return; }
    await AppStore.instance.refreshRemote(); await _load(); _snack('Approved. Net quantities were added to stock.');
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> r) async {
    await MtekPdfFonts.load(); final data = await rootBundle.load('assets/branding/logo.png'); final logo = pw.MemoryImage(data.buffer.asUint8List()); final pdf = pw.Document();
    final rows = [for (final x in (r['rows'] as List? ?? [])) if (x is Map) x];
    pdf.addPage(pw.MultiPage(pageTheme: pw.PageTheme(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(28), theme: pw.ThemeData.withFont(base: MtekPdfFonts.base, bold: MtekPdfFonts.bold), buildBackground: (_) => documentBackground(logo, PdfPageFormat.a4)), build: (_) => [
      corporateHeader(logo), pw.SizedBox(height: 14), pw.Center(child: pw.Text('STOCK RECEIPT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 8), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Date: ${r['receipt_date'] ?? ''}'), pw.Text('No: ${(r['serial'] as num? ?? 0).toInt().toString().padLeft(9, '0')}')]), pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(headers: ['S/No', 'Particulars', 'Quantity', 'Damaged', 'Missing', 'Net'], data: [for (final x in rows) ['${x['sno']}', '${x['particulars']}', '${x['quantity']}', '${x['damaged']}', '${x['missing']}', '${(x['quantity'] as num) - (x['damaged'] as num) - (x['missing'] as num)}']], headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700), headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 24), pw.Text("Receiver's Signature: ${r['receiver_name'] ?? ''}"), pw.SizedBox(height: 16), pw.Text("Approval's Signature: ${r['approver_name'] ?? (r['status'] == 'approved' ? 'CEO' : 'Pending CEO approval')}")
    ])); return pdf.save();
  }
  Future<void> _pdf(Map<String, dynamic> r) async {
    final bytes = await _buildPdf(r);
    final serial = (r['serial'] as num? ?? 0).toInt().toString().padLeft(9, '0');
    final filename = 'MFSL-Stock-Receipt-$serial.pdf';
    archivePdfInBackground(bytes: bytes, filename: filename,
      description: 'Stock Receipt $serial · ${r['supplier'] ?? 'Supplier'}');
    if (!mounted) return;
    final action = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Stock Receipt PDF'),
      content: const Text('The PDF is ready. Cloud backup continues in the background.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'print'), child: const Text('Print')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, 'download'), child: const Text('Download')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, 'share'), child: const Text('Share')),
      ],
    ));
    if (action == 'print') await Printing.layoutPdf(onLayout: (_) async => bytes);
    if (action == 'download') {
      final outcome = await savePdf(bytes: bytes, filename: filename);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
    }
    if (action == 'share') {
      final outcome = await dispatchPdf(bytes: bytes, filename: filename);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
    }
  }
  void _snack(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
}
