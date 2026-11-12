import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../documents/doc_models.dart';
import '../widgets.dart';
import 'generator_screen.dart';

/// DELIVERY NOTES — mirrors the physical pre-printed book (Ordered /
/// Delivered / Outstanding columns, shipping address, client acknowledges
/// receipt with a signature). History pulled from the shared
/// generated-document ledger (AppStore.docHistory).
class DeliveryNotesScreen extends StatelessWidget {
  const DeliveryNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final rows = store.docHistory.where((d) => d.type == 'deliverynote').toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Delivery Notes',
            subtitle: '${rows.length} issued — client acknowledgement of goods received',
            icon: Icons.inventory_2,
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GeneratorScreen(initialType: DocType.deliveryNote)),
                ),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('New delivery note'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: rows.isEmpty
                  ? const EmptyHint('No delivery notes yet — issue one from "New delivery note" above')
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = rows[i];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Mtek.goldTint,
                            child: Icon(Icons.inventory_2_outlined, size: 18, color: Mtek.warn),
                          ),
                          title: Text('Delivery Note No ${d.serial.toString().padLeft(9, '0')} — ${d.customer}',
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
