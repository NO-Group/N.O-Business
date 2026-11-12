import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/phone.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/auth_store.dart';
import '../../data/store.dart';
import '../signature_dialog.dart';
import '../signature_pad.dart';
import '../widgets.dart';

/// SALES — the POS screen. Complete a sale → stock decremented, and a
/// Transaction + Receipt are issued (or an Invoice, if credit).
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final Map<String, SaleItem> _cart = {};
  final TextEditingController _search = TextEditingController();
  Customer? _customer;
  PaymentMethod _method = PaymentMethod.cash;
  String _query = '';
  bool _completing = false;
  String? _pendingSaleKey;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final sellable = store.products
        .where((p) => !p.isOutOfStock || p.isService)
        .where((p) => _fuzzyScore(p, _query) >= 0)
        .toList()
      ..sort((a, b) => _fuzzyScore(b, _query).compareTo(_fuzzyScore(a, _query)));
    final subtotal = _cart.values.fold(0, (s, i) => s + i.total);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      final catalogue = _catalogueList(sellable);

      return Padding(
        padding: const EdgeInsets.all(20),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: catalogue),
                  const SizedBox(width: 16),
                  SizedBox(width: 380, child: _cartPanel(store, subtotal)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: catalogue),
                  const SizedBox(height: 10),
                  SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openCurrentSale(store),
                        icon: const Icon(Icons.shopping_cart_checkout),
                        label: Text(
                          'Current Sale (${_cart.values.fold<int>(0, (sum, item) => sum + item.qty)})'
                          '  ·  ${fmt.naira(subtotal)}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      );
    });
  }

  Widget _catalogueList(Iterable<Product> sellable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
            title: 'Sales',
            subtitle: 'Pick items — stock & receipts update automatically',
            icon: Icons.point_of_sale),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search stock',
            hintText: 'Product name, ID, category or unit',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: sellable.isEmpty
                ? const EmptyHint('No in-stock products match this search')
                : ListView.separated(
              itemCount: sellable.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = sellable.elementAt(i);
                final inCart = _cart[p.id]?.qty ?? 0;
                return ListTile(
                  enabled: !p.isOutOfStock,
                  leading: CircleAvatar(
                    backgroundColor: Mtek.brandTint,
                    child: Text(p.name.trim().isEmpty ? '?' : p.name.trim()[0].toUpperCase(),
                        style: const TextStyle(color: Mtek.brand600, fontWeight: FontWeight.w700)),
                  ),
                  title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.id} · ${p.isService ? "service" : "${p.qtyOnHand} ${p.unit} in stock"} · ${fmt.naira(p.sellingPrice)}'),
                  trailing: inCart == 0
                      ? IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Mtek.brand600),
                          tooltip: 'Add to cart',
                          onPressed: p.isOutOfStock ? null : () => _add(p),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _remove(p)),
                            Text('$inCart', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            IconButton(icon: const Icon(Icons.add_circle_outline, color: Mtek.brand600), onPressed: () => _add(p)),
                          ],
                        ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addCustomerAtSale(AppStore store, void Function(VoidCallback) update) async {
    final name = TextEditingController(), phone = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Add new customer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name / company *')),
        const SizedBox(height: 10),
        CountryPhoneField(controller: phone, label: 'Phone number *'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add customer')),
      ],
    ));
    if (ok != true || !mounted) return;
    final phoneError = internationalPhoneError(phone.text, required: true);
    if (name.text.trim().length < 2 || phoneError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(phoneError ?? 'Enter the customer name.')));
      return;
    }
    final customer = Customer(
      id: 'C${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      name: name.text.trim(), isCorporate: false,
      phone: normalizeInternationalPhone(phone.text), email: '', address: '');
    store.addCustomer(customer);
    update(() => _customer = customer);
  }

  Widget _cartPanel(AppStore store, int subtotal, {StateSetter? routeSetState}) {
    void update(VoidCallback change) {
      setState(change);
      routeSetState?.call(() {});
    }
    // Documents can be issued ad-hoc before a customer record exists. Make
    // those session/backend-history identities immediately selectable at POS
    // and avoid duplicate choices by normalised name + contact.
    final customers = <Customer>[...store.customers];
    final seen = <String>{
      for (final c in customers) '${c.name.trim().toLowerCase()}|${c.phone.trim().toLowerCase()}',
    };
    for (final doc in store.docHistory) {
      final key = '${doc.customer.trim().toLowerCase()}|${doc.customerContact.trim().toLowerCase()}';
      if (doc.customer.trim().isEmpty || !seen.add(key)) continue;
      customers.add(Customer(
        id: 'doc-${doc.type}-${doc.serial}',
        name: doc.customer.trim(),
        isCorporate: false,
        phone: doc.customerContact.contains('@') ? '' : doc.customerContact,
        email: doc.customerContact.contains('@') ? doc.customerContact : '',
        address: '',
      ));
    }
    if (_customer != null && !customers.contains(_customer)) {
      customers.removeWhere((c) => c.id == _customer!.id);
      customers.insert(0, _customer!);
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: Mtek.brandGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_outlined, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text('CURRENT SALE (${_cart.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                const Spacer(),
                if (_cart.isNotEmpty)
                  TextButton(onPressed: () => update(_cart.clear), child: const Text('Clear')),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<Customer>(
              value: _customer,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Customer'),
              items: [
                for (final c in customers)
                  DropdownMenuItem(
                    value: c,
                    child: Text(
                      c.phone.isEmpty ? c.name : '${c.name} · ${c.phone}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (c) => update(() => _customer = c),
            ),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: () => _addCustomerAtSale(store, update),
              icon: const Icon(Icons.person_add_alt_1), label: const Text('Add new customer'))),
            const SizedBox(height: 12),
            ..._cart.values.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${i.product.name} ×${i.qty}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      AmountText(i.total, bold: false),
                    ],
                  ),
                )),
            if (_cart.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: EmptyHint('Tap + on items to start a sale'),
              ),
            const Spacer(),
            const Divider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Mtek.brandTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('TOTAL',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Mtek.brand700,
                          letterSpacing: 1)),
                  const Spacer(),
                  AmountText(subtotal, size: 20, color: Mtek.brand700),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(MethodIcon.label(m)),
                    selected: _method == m,
                    selectedColor: Theme.of(context).brightness == Brightness.dark ? Mtek.navy600 : Mtek.brandTint,
                    onSelected: (_) => update(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_cart.isEmpty || _customer == null || _completing)
                    ? null
                    : () async {
                        await _complete();
                        routeSetState?.call(() {});
                      },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_method == PaymentMethod.credit
                    ? 'Complete — bill on invoice'
                    : 'Complete sale — ${fmt.naira(subtotal)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCurrentSale(AppStore store) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) => StatefulBuilder(
        builder: (context, routeSetState) {
          final subtotal = _cart.values.fold<int>(0, (sum, item) => sum + item.total);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Current Sale'),
              leading: IconButton(
                tooltip: 'Back to products',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(routeContext).pop(),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _cartPanel(store, subtotal, routeSetState: routeSetState),
              ),
            ),
          );
        },
      ),
    ));
    if (mounted) setState(() {});
  }

  /// Lightweight fuzzy ranking: exact/prefix/substring matches rank first;
  /// otherwise all query characters must occur in order. This handles quick
  /// counter searches such as "dcp6" → "DCP 6kg Fire Extinguisher" without
  /// adding a heavyweight search dependency.
  int _fuzzyScore(Product product, String query) {
    if (query.isEmpty) return 0;
    final haystack = '${product.name} ${product.id} ${product.category.name} ${product.unit}'
        .toLowerCase();
    if (haystack == query) return 1000;
    if (haystack.startsWith(query)) return 800 - haystack.length;
    final substring = haystack.indexOf(query);
    if (substring >= 0) return 600 - substring;
    var cursor = 0;
    var gap = 0;
    for (final code in query.codeUnits) {
      final next = haystack.indexOf(String.fromCharCode(code), cursor);
      if (next < 0) return -1;
      gap += next - cursor;
      cursor = next + 1;
    }
    return 300 - gap;
  }

  void _add(Product p) {
    setState(() {
      final existing = _cart[p.id];
      final nextQuantity = (existing?.qty ?? 0) + 1;
      if (!p.isService && nextQuantity > p.qtyOnHand) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Only ${p.qtyOnHand} ${p.unit} available.')),
        );
        return;
      }
      _cart[p.id] = SaleItem(product: p, qty: nextQuantity);
    });
  }

  void _remove(Product p) {
    setState(() {
      final existing = _cart[p.id];
      if (existing == null) return;
      if (existing.qty <= 1) {
        _cart.remove(p.id);
      } else {
        _cart[p.id] = SaleItem(product: p, qty: existing.qty - 1);
      }
    });
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    final signer = await confirmSignature(context);
    if (signer == null) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not signed — sale not issued.')));
      }
      return;
    }
    // CUSTOMER SIGNS TOO (optional when absent): captured on the device and
    // stored with the sale + receipt — proof of purchase on the PDF.
    final customerSig = await _captureCustomerSignature();
    final store = AppStore.instance;
    _pendingSaleKey ??= 'sale-${AuthStore.instance.remoteSignInUid}-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await store.completeSale(
        customer: _customer!,
        items: _cart.values.toList(),
        method: _method,
        signedBy: signer.name,
        customerSignature: customerSig,
        issueKey: _pendingSaleKey!,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _completing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Mtek.danger,
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ));
      }
      return;
    }
    setState(() { _cart.clear(); _completing = false; _pendingSaleKey = null; });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: Mtek.success,
      content: Text(_method == PaymentMethod.credit
          ? 'Invoice created & signed by ${signer.name} — payable later, stock deducted.'
          : 'Sale complete — receipt signed by ${signer.name}, stock updated.'),
    ));
  }

  /// Customer signs on the device (skippable when they're not present).
  Future<String?> _captureCustomerSignature() async {
    String? captured;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Customer's signature",
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Proof of purchase — printed on the receipt. You may skip.',
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              SignaturePad(
                onDone: (bytes) {
                  if (bytes != null) {
                    captured = 'data:image/png;base64,${base64Encode(bytes)}';
                  }
                  Navigator.of(sheetCtx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
    return captured;
  }
}
