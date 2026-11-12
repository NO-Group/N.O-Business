import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../documents/doc_models.dart';
import '../widgets.dart';
import 'generator_screen.dart';

/// WAYBILLS — logistics dispatch record (mirrors the physical carbon-copy
/// book: MILS/Receipt/Invoice/LPO refs, driver + vehicle, receiver
/// signature at hand-over). No prices — items carry tech-spec + brand.
/// History pulled from the shared generated-document ledger
/// (AppStore.docHistory), same source Receipts/Invoices/MILS read from.
class WaybillsScreen extends StatelessWidget {
  const WaybillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final rows = store.docHistory.where((d) => d.type == 'waybill').toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Waybills',
            subtitle: '${rows.length} issued — dispatch record for goods in transit',
            icon: Icons.local_shipping,
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GeneratorScreen(initialType: DocType.waybill)),
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('New waybill'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: rows.isEmpty
                  ? const EmptyHint('No waybills yet — issue one from "New waybill" above')
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = rows[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Mtek.brandTint,
                            child: Icon(Icons.local_shipping_outlined, size: 18, color: Mtek.brand600),
                          ),
                          title: Text('Waybill No ${d.serial.toString().padLeft(9, '0')} — ${d.customer}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('${fmt.fmtDateTime(d.issuedAt)} · signed by ${d.signedBy}'
                              '${d.customerContact.isNotEmpty ? ' · ${d.customerContact}' : ''}'),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
