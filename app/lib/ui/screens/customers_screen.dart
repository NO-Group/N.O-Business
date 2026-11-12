import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../widgets.dart';

/// CUSTOMERS — individuals & corporates, contacts, credit balance,
/// purchase history. M3: Supabase `customers` table.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final list = store.customers
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Customers',
            subtitle: '${store.customers.length} on file — ${store.customers.where((c) => c.isCorporate).length} corporate',
            icon: Icons.people,
            actions: [
              FilledButton.icon(
                onPressed: () => _showNewCustomerDialog(context),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('New customer'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetricPill(label: 'Total', value: '${store.customers.length}', icon: Icons.people_outline, accent: Mtek.brand600),
              MetricPill(label: 'Corporate', value: '${store.customers.where((c) => c.isCorporate).length}', icon: Icons.business_outlined, accent: Mtek.navy700),
              MetricPill(label: 'Credit owed', value: fmt.nairaCompact(store.customers.fold(0, (s, c) => s + c.creditBalance)), icon: Icons.hourglass_top_outlined, accent: Mtek.warn),
            ],
          ),
          const SizedBox(height: 12),
          SearchField(hint: 'Search customers…', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    leading: InitialsAvatar(
                      c.name.split(' ').take(2).map((w) => w[0]).join().toUpperCase(),
                      background: c.isCorporate ? Mtek.navy800 : Mtek.brand600,
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${c.isCorporate ? "Corporate" : "Individual"} · ${c.phone}'),
                    trailing: c.creditBalance > 0
                        ? StatusChip.bad('Credit ${fmt.nairaCompact(c.creditBalance)}')
                        : const StatusChip.neutral('No dues'),
                    onTap: () => _showDetail(context, c),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewCustomerDialog(BuildContext context) {
    final name = TextEditingController();
    final phone = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name / Company')),
            const SizedBox(height: 12),
            CountryPhoneField(controller: phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              // Capture these BEFORE the await: addCustomer now waits for the
              // server, so no BuildContext is touched across the async gap.
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final phoneError = internationalPhoneError(phone.text, required: true);
              if (phoneError != null) {
                messenger.showSnackBar(SnackBar(content: Text(phoneError)));
                return;
              }
              if (name.text.trim().isNotEmpty) {
                try {
                  await AppStore.instance.addCustomer(Customer(
                    id: 'C${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
                    name: name.text.trim(),
                    isCorporate: name.text.toLowerCase().contains('ltd') || name.text.toLowerCase().contains('depot'),
                    phone: normalizeInternationalPhone(phone.text),
                    email: '',
                    address: '',
                  ));
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('$e')));
                  return;
                }
              }
              nav.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, Customer c) {
    final store = AppStore.instance;
    final history = store.sales.where((s) => s.customer.id == c.id).toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            Text(c.isCorporate ? 'Corporate customer' : 'Individual customer', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            _row('Phone', c.phone),
            _row('Email', c.email.isEmpty ? '—' : c.email),
            _row('Address', c.address.isEmpty ? '—' : c.address),
            _row('Credit balance', fmt.naira(c.creditBalance)),
            const SizedBox(height: 8),
            Text('PURCHASE HISTORY (${history.length})', style: TextStyle(fontSize: 11, letterSpacing: 1, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (history.isEmpty) Text('No purchases yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ...history.take(5).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(width: 70, child: Text(fmt.fmtDateShort(s.date), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
                      Expanded(child: Text(s.items.map((i) => '${i.product.name} ×${i.qty}').join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                      AmountText(s.total),
                    ],
                  ),
                )),
            if (AuthStore.instance.isCeo) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Mtek.danger),
                onPressed: () => _deleteCustomer(context, c),
                icon: const Icon(Icons.delete_outline), label: const Text('Delete customer')),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCustomer(BuildContext sheetContext, Customer customer) async {
    final confirmed = await showDialog<bool>(context: sheetContext, builder: (dialogContext) => AlertDialog(
      title: const Text('Delete customer?'),
      content: Text('Remove ${customer.name} from the active customer directory? Existing receipts and sales history will remain.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Mtek.danger),
          onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true || !sheetContext.mounted) return;
    try {
      await AppStore.instance.deleteCustomer(customer);
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer deleted.')));
      }
    } catch (error) {
      if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(
        backgroundColor: Mtek.danger, content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );
}
