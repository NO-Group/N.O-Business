import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../signature_dialog.dart';
import '../widgets.dart';

/// NOTIFICATIONS — every signed-in user (CEO, Admin, Sales) sees a live feed
/// of transactions, documents, stock changes, new customers/products, MILS
/// jobs, staff role changes, and CEO/Admin announcements (owner directive
/// 2026-09-01: "any significant write in the app"). CEO/Admin can compose a
/// new announcement from here and see exactly who has read it.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await AppStore.instance.refreshNotifications();
    if (mounted) setState(() => _loading = false);
  }

  IconData _iconFor(String kind) => switch (kind) {
        'transaction' => Icons.point_of_sale_outlined,
        'document' => Icons.description_outlined,
        'stock' => Icons.inventory_2_outlined,
        'stockApproval' => Icons.approval_outlined,
        'voucherApproval' => Icons.payments_outlined,
        'customer' => Icons.person_add_alt_1_outlined,
        'product' => Icons.category_outlined,
        'mils' => Icons.build_circle_outlined,
        'staff' => Icons.badge_outlined,
        'announcement' => Icons.campaign_outlined,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final uid = AuthStore.instance.remoteSignInUid ?? '';
    final canAnnounce = AuthStore.instance.isManagement;
    final list = store.notifications;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Notifications',
            subtitle: list.isEmpty
                ? 'Nothing yet — every sale, document, stock change and announcement will appear here'
                : '${list.length} notification${list.length == 1 ? '' : 's'} · ${store.unreadNotificationCount} unread',
            icon: Icons.notifications,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
              if (canAnnounce) ...[
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => _composeAnnouncement(context),
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Announce'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No notifications yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final n = list[i];
                        final read = uid.isNotEmpty && n.isReadBy(uid);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: n.kind == 'announcement' ? Mtek.navy800 : Mtek.brand600,
                            child: Icon(_iconFor(n.kind), color: Colors.white, size: 18),
                          ),
                          title: Text(n.title,
                              style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.w800)),
                          subtitle: Text('${n.message}\n${fmt.fmtDateTime(n.createdAt)} · ${n.createdByName}',
                              style: const TextStyle(fontSize: 12.5)),
                          isThreeLine: true,
                          trailing: (n.kind == 'stockApproval' || n.kind == 'voucherApproval') && AuthStore.instance.isCeo
                              ? FilledButton.icon(
                                  onPressed: _loading ? null : () => n.kind == 'stockApproval'
                                      ? _approveStockReceipt(n) : _approvePaymentVoucher(n),
                                  icon: const Icon(Icons.draw_outlined, size: 16),
                                  label: Text(n.kind == 'voucherApproval' ? 'Approve & Pay' : 'Approve'),
                                )
                              : n.createdBy == AuthStore.instance.remoteSignInUid && canAnnounce
                                  ? TextButton(
                                      onPressed: () => _showReadReceipts(context, n),
                                      child: Text('Read ${n.readBy.length}'),
                                    )
                                  : (read ? null : const Icon(Icons.circle, size: 9, color: Mtek.brand600)),
                          onTap: () => AppStore.instance.markNotificationRead(n.id),
                        );
                      },
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approvePaymentVoucher(AppNotification notification) async {
    final signer = await confirmSignature(context, force: true);
    if (signer == null || !mounted) return;
    setState(() => _loading = true);
    final response = await AppStore.instance.api?.post('/api/payment-vouchers/approve', {
      'id': notification.ref,
    });
    if (response != null && response.ok) {
      await AppStore.instance.markNotificationRead(notification.id);
      await AppStore.instance.refreshRemote();
      await AppStore.instance.refreshNotifications();
    }
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: response != null && response.ok ? Mtek.success : Mtek.danger,
      content: Text(response != null && response.ok ? 'Payment Voucher approved and posted as expenditure.' :
        '${response?.json is Map ? (response!.json as Map)['error'] : 'Approval failed.'}'),
    ));
  }

  Future<void> _approveStockReceipt(AppNotification notification) async {
    // Approval is deliberately force-authenticated: the CEO must enter the
    final signer = await confirmSignature(context, force: true);
    if (signer == null || !mounted) return;
    setState(() => _loading = true);
    final response = await AppStore.instance.api?.post(
      '/api/stock-receipts/approve',
      {
        'id': notification.ref,
        'approval_signature': signer.signaturePng ?? '',
      },
    );
    if (response != null && response.ok) {
      await AppStore.instance.markNotificationRead(notification.id);
      await AppStore.instance.refreshRemote();
      await AppStore.instance.refreshNotifications();
    }
    if (!mounted) return;
    setState(() => _loading = false);
    final message = response != null && response.ok
        ? 'Stock Receipt approved. Net quantities were added to stock.'
        : '${response?.json is Map ? (response!.json as Map)['error'] : 'Approval failed — check the connection and try again.'}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: response != null && response.ok ? Mtek.success : Mtek.danger,
      content: Text(message),
    ));
  }

  void _showReadReceipts(BuildContext context, AppNotification n) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Read by ${n.readBy.length} staff member${n.readBy.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
              const SizedBox(height: 10),
              if (n.readBy.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nobody has read this yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                )
              else
                ...n.readBy.map((r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.check_circle, color: Mtek.success, size: 20),
                      title: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      trailing: Text(fmt.fmtDateTime(r.at), style: const TextStyle(fontSize: 11.5)),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _composeAnnouncement(BuildContext context) {
    final title = TextEditingController();
    final message = TextEditingController();
    String? error;
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New announcement'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 12),
                TextField(
                  controller: message,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Mtek.danger, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty || message.text.trim().isEmpty) {
                  setDialogState(() => error = 'Enter a title and a message');
                  return;
                }
                final err = await AppStore.instance.sendAnnouncement(title.text.trim(), message.text.trim());
                if (err != null) {
                  setDialogState(() => error = err);
                  return;
                }
                if (context.mounted) Navigator.pop(context);
                _refresh();
              },
              child: const Text('Send to all staff'),
            ),
          ],
        ),
      ),
    );
  }
}
