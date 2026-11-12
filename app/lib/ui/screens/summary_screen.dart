import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../documents/pdf_shared.dart' show MtekPdfFonts;
import '../../documents/share_service.dart';
import '../widgets.dart';

/// SUMMARY — period report: totals, profit estimate, top products,
/// stock valuation, outstanding invoices. M4: export as PDF/share.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {

  /// Builds the REAL business report PDF and hands the file to the OS share
  /// sheet (WhatsApp/Gmail/Drive) — never pre-filled text (owner directive).
  Future<void> _exportPdf(BuildContext context, DateTime from, String label) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = AppStore.instance;
      final bytes = await _reportBytes(store, from, label);
      final outcome = await dispatchPdf(
        bytes: bytes,
        filename: 'mtek_summary_${label.toLowerCase().replaceAll(' ', '_')}'
            '_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      messenger.showSnackBar(SnackBar(
        backgroundColor: outcome.result == ShareResult.failed ? Mtek.danger : Mtek.success,
        content: Text(outcome.message),
      ));
    } catch (e) {
      // Full detail goes to the console only — never onto a production
      // screen (no raw exception text, no stack traces).
      debugPrint('Summary export failed: $e');
      messenger.showSnackBar(const SnackBar(
          backgroundColor: Mtek.danger,
          content: Text('Could not build the report — please try again.')));
    }
  }

  Future<Uint8List> _reportBytes(AppStore store, DateTime from, String label) async {
    await MtekPdfFonts.load();
    final doc = pw.Document();
    final now = DateTime.now();
    final revenue = store.revenue(from: from);
    final profit = store.estimatedProfit(from: from);
    final stockValue = store.stockValueAtCost();
    final outstanding = store.outstandingInvoicesTotal();
    final unpaid = store.invoices.where((v) => v.balance > 0).toList();
    final low = store.products.where((p) => !p.isService && p.qtyOnHand <= p.reorderLevel).toList();

    pw.Widget line(String k, String v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text(k), pw.Text(v, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))]));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: MtekPdfFonts.base, bold: MtekPdfFonts.bold),
      build: (context) => [
        pw.Header(child: pw.Text('M-TEK FIRE & SAFETY LTD. — Business Summary ($label)',
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
        pw.Text('Generated ${fmt.fmtDateTime(now)} · RC 1082534 · mtekfiresafetyltd@gmail.com',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        line('Revenue (net)', fmt.naira(revenue), bold: true),
        line('Profit estimate', fmt.naira(profit)),
        line('Stock value (cost)', fmt.naira(stockValue)),
        line('Outstanding invoices', fmt.naira(outstanding), bold: true),
        pw.SizedBox(height: 14),
        pw.Text('Low / out of stock (${low.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 4),
        if (low.isEmpty)
          pw.Text('None — stock healthy.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Product', 'Qty', 'Reorder at'],
            data: low.take(40).map((p) => [p.name, '${p.qtyOnHand}', '${p.reorderLevel}']).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        pw.SizedBox(height: 14),
        pw.Text('Unpaid invoices (${unpaid.length})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        pw.SizedBox(height: 4),
        if (unpaid.isEmpty)
          pw.Text('None — all settled.')
        else
          pw.TableHelper.fromTextArray(
            headers: ['Invoice', 'Customer', 'Balance'],
            data: unpaid.map((Invoice v) =>
                [v.number, v.customer.name, fmt.naira(v.balance)]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
          ),
        pw.SizedBox(height: 16),
        pw.Text('Digitally generated by the M-TEK workspace.',
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
      ],
    ));
    return doc.save();
  }

  String _period = 'month';

  String _monthYear(DateTime d) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][d.month - 1] + ' ${d.year}';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final now = DateTime.now();
    final (from, label) = switch (_period) {
      'today' => (DateTime(now.year, now.month, now.day), 'Today'),
      'week' => (
          now.subtract(Duration(days: now.weekday - 1)),
          'This week',
        ),
      _ => (DateTime(now.year, now.month), 'This month'),
    };

    return RefreshIndicator(
      onRefresh: () async { await AppStore.instance.refreshRemote(); },
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        PageHeader(
          title: 'Summary',
          subtitle: 'Business report — $label · ${_monthYear(now)}',
          icon: Icons.summarize,
          actions: [
            OutlinedButton.icon(
              onPressed: () => _exportPdf(context, from, label),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Export PDF'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final p in const [('today', 'Daily'), ('week', 'Weekly'), ('month', 'Monthly')])
              ChoiceChip(
                label: Text(p.$2),
                selected: _period == p.$1,
                selectedColor: Theme.of(context).brightness == Brightness.dark ? Mtek.navy600 : Mtek.brandTint,
                onSelected: (_) => setState(() => _period = p.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1000 ? 4 : 2;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final card in [
                ('Revenue (net)', store.revenue(from: from), Icons.payments_outlined, Mtek.brand600),
                ('Profit estimate', store.estimatedProfit(from: from), Icons.trending_up_outlined, Mtek.success),
                ('Stock value (cost)', store.stockValueAtCost(), Icons.inventory_2_outlined, Mtek.navy700),
                ('Outstanding invoices', store.outstandingInvoicesTotal(), Icons.hourglass_top_outlined, Mtek.warn),
              ])
                SizedBox(
                  width: (c.maxWidth - (cols - 1) * 14) / cols,
                  child: StatCard(label: card.$1, value: fmt.naira(card.$2), icon: card.$3, accent: card.$4),
                ),
            ],
          );
        }),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth > 900;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: two ? c.maxWidth * 0.485 : c.maxWidth,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Top products (all-time)', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ...store.topProducts().entries.toList().asMap().entries.map((e) {
                          final max = store.topProducts().values.first;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('#${e.key + 1} ${e.value.key}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 10),
                                    AmountText(e.value.value),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: max == 0 ? 0 : e.value.value / max,
                                    minHeight: 8,
                                    backgroundColor: Mtek.gray100,
                                    color: Mtek.gold500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: two ? c.maxWidth * 0.485 : c.maxWidth,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Attention needed', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        for (final p in store.products.where((p) => p.isLow))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              p.isOutOfStock ? Icons.error_outline : Icons.warning_amber_outlined,
                              color: p.isOutOfStock ? Mtek.danger : Mtek.warn,
                            ),
                            title: Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text('${p.qtyOnHand} left · reorder level ${p.reorderLevel}', style: const TextStyle(fontSize: 12)),
                            trailing: Text(p.isOutOfStock ? 'OUT' : 'LOW',
                                style: TextStyle(color: p.isOutOfStock ? Mtek.danger : Mtek.warn, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        for (final inv in store.invoices.where((i) => i.balance > 0))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: const Icon(Icons.request_quote_outlined, color: Mtek.brand600),
                            title: Text('${inv.number} — ${inv.customer.name}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text('Due ${fmt.fmtDate(inv.due)}', style: const TextStyle(fontSize: 12)),
                            trailing: AmountText(inv.balance, color: Mtek.danger),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    ),
    );
  }
}
