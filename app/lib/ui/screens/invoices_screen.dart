import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/auth_store.dart';
import '../../data/store.dart';
import '../../documents/doc_models.dart';
import '../signature_dialog.dart';
import '../widgets.dart';
import 'generator_screen.dart';

/// INVOICES — bill now, pay later (corporate clients).
/// Payments post a Transaction + Receipt automatically.
class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final invoices = store.invoices.reversed.toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Invoices',
            subtitle: '${store.outstandingInvoicesTotal() == 0 ? "All settled" : "${fmt.naira(store.outstandingInvoicesTotal())} outstanding"}',
            icon: Icons.request_quote,
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GeneratorScreen(initialType: DocType.invoice)),
                ),
                icon: const Icon(Icons.post_add),
                label: const Text('New invoice'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                itemCount: invoices.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == invoices.length) return const LoadOlderTile('invoices');
                  final inv = invoices[i];
                  final status = inv.status(DateTime.now());
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Mtek.brandTint,
                      child: Icon(Icons.request_quote, size: 18, color: Mtek.brand600),
                    ),
                    title: Text('${inv.number} — ${inv.customer.name}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Issued ${fmt.fmtDate(inv.issued)} · Due ${fmt.fmtDate(inv.due)}'),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: inv.total == 0 ? 0 : inv.amountPaid / inv.total,
                            minHeight: 6,
                            backgroundColor: Mtek.gray100,
                            color: status == InvoiceStatus.paid ? Mtek.success : Mtek.brand600,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusChip(status),
                        const SizedBox(height: 6),
                        AmountText(inv.total),
                        if (inv.balance > 0)
                          Text('Balance ${fmt.nairaCompact(inv.balance)}',
                              style: const TextStyle(fontSize: 11, color: Mtek.danger)),
                      ],
                    ),
                    onTap: () => _actions(context, inv),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  StatusChip _statusChip(InvoiceStatus s) => switch (s) {
        InvoiceStatus.paid => const StatusChip.paid('PAID'),
        InvoiceStatus.partial => const StatusChip.pending('PARTIAL'),
        InvoiceStatus.overdue => const StatusChip.bad('OVERDUE'),
        InvoiceStatus.unpaid => const StatusChip.neutral('UNPAID'),
      };

  Future<void> _actions(BuildContext context, Invoice inv) async {
    if (inv.balance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${inv.number} is fully paid — receipt already issued.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record payment — ${inv.number}'),
        content: Text(
            '${inv.customer.name} owes ${fmt.naira(inv.balance)} of ${fmt.naira(inv.total)}.\n'
            'Record a payment now? It will post to Transactions and issue a receipt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final signer = await confirmSignature(context);
    if (signer == null || !context.mounted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not signed — payment not recorded.')));
      }
      return;
    }
    try {
      await AppStore.instance.payInvoice(inv, inv.balance,
          signedBy: signer.name,);
    } catch (e) {
      debugPrint('payInvoice failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment could not be recorded — please try again.')));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Payment recorded — receipt issued & signed by ${signer.name}, stock untouched.')));
  }
}
