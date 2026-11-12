import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../documents/pdf_shared.dart';
import '../../documents/share_service.dart';
import '../widgets.dart';

/// STAFF — CEO and Admin see everyone's name, email and phone number. Only
/// the CEO can promote a Sales staffer to Admin or demote an Admin back to
/// Sales (owner directive 2026-09-01); Admins see the same list read-only.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  bool _loading = false;
  String? _busyUid;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await AppStore.instance.refreshStaff();
    if (mounted) setState(() => _loading = false);
  }

  Color _roleColor(String role) => switch (role) {
        'ceo' => Mtek.navy800,
        'admin' => Mtek.brand600,
        _ => Mtek.gray500,
      };

  Widget _roleChip(String role) => switch (role) {
        'ceo' => const StatusChip.pending('CEO'),
        'admin' => const StatusChip.info('ADMIN'),
        _ => const StatusChip.neutral('SALES'),
      };

  Future<void> _toggleRole(StaffMember s) async {
    final newRole = s.role == 'admin' ? 'sales' : 'admin';
    setState(() => _busyUid = s.uid);
    final err = await AppStore.instance.setStaffRole(s.uid, newRole);
    if (mounted) setState(() => _busyUid = null);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _deleteStaff(StaffMember s) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Permanently delete staff?'),
      content: Text('Delete ${s.name.isEmpty ? s.email : s.name} from MFSL Office and Supabase Authentication? '
        'They will immediately lose access. Historical documents and transactions will be preserved.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Mtek.danger),
          onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete permanently')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _busyUid = s.uid);
    final error = await AppStore.instance.deleteStaff(s.uid);
    if (!mounted) return;
    setState(() => _busyUid = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? Mtek.success : Mtek.danger,
      content: Text(error ?? 'Staff account permanently deleted from the backend.')));
  }

  Uint8List? _passport(StaffMember s) {
    if (s.passportPhoto.isEmpty) return null;
    try { return base64Decode(s.passportPhoto.split(',').last); } catch (_) { return null; }
  }

  String _staffId(StaffMember s) => s.staffId.isNotEmpty
      ? s.staffId
      : 'MFSL-${s.uid.replaceAll('-', '').padRight(8, '0').substring(0, 8).toUpperCase()}';

  void _showStaffDetails(StaffMember s) {
    showModalBottomSheet<void>(context: context, showDragHandle: true,
      builder: (context) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_passport(s) != null) Center(child: AppImage(source: s.passportPhoto,
            title: s.name, details: '${_staffId(s)} · ${s.role.toUpperCase()} · Passport photograph',
            width: 100, height: 120)),
          if (_passport(s) != null) const SizedBox(height: 12),
          Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _detail('Staff ID', _staffId(s)), _detail('Role', s.role.toUpperCase()),
          _detail('Email', s.email), _detail('Phone', s.phone.isEmpty ? 'Not supplied' : s.phone),
          _detail('Joined', s.createdAt == null ? 'Existing staff account' : s.createdAt!.toLocal().toString().split('.').first),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => _downloadIdCard(s), icon: const Icon(Icons.badge_outlined),
            label: const Text('Download virtual ID card'))),
          if (AuthStore.instance.isCeo && s.role != 'ceo') ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Mtek.danger),
              onPressed: () {
                Navigator.pop(context);
                _deleteStaff(s);
              },
              icon: const Icon(Icons.person_remove_outlined),
              label: const Text('Delete staff permanently'),
            )),
          ],
        ]))));
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
    ]));

  Future<void> _downloadIdCard(StaffMember s) async {
    await MtekPdfFonts.load();
    final data = await rootBundle.load('assets/branding/logo.png');
    final logo = pw.MemoryImage(data.buffer.asUint8List());
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: const PdfPageFormat(243, 153), margin: pw.EdgeInsets.zero,
      build: (_) => pw.Container(decoration: const pw.BoxDecoration(color: PdfColors.white),
        child: pw.Row(children: [
          pw.Container(width: 62, color: PdfColors.blue900, padding: const pw.EdgeInsets.all(10),
            child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [pw.Image(logo), pw.SizedBox(height: 8),
              pw.Text('MFSL', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))])),
          pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(12), child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Text('M-TEK FIRE & SAFETY LTD', style: pw.TextStyle(fontSize: 9, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8), pw.Text(s.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(s.role.toUpperCase(), style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
              pw.SizedBox(height: 7), pw.Text('ID: ${_staffId(s)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text(s.email, style: const pw.TextStyle(fontSize: 6.5)),
              if (s.phone.isNotEmpty) pw.Text(s.phone, style: const pw.TextStyle(fontSize: 6.5)),
            ]))),
          if (_passport(s) != null) pw.Padding(padding: const pw.EdgeInsets.only(right: 10),
            child: pw.Image(pw.MemoryImage(_passport(s)!), width: 42, height: 54, fit: pw.BoxFit.cover)),
        ]))));
    final Uint8List bytes = await pdf.save();
    final outcome = await savePdf(bytes: bytes, filename: '${_staffId(s)}-id-card.pdf');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final isCeo = AuthStore.instance.isCeo;
    final list = store.staff;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Staff',
            subtitle: list.isEmpty
                ? 'Every account that has signed in or signed up shows here'
                : '${list.length} staff member${list.length == 1 ? '' : 's'}'
                    '${isCeo ? '' : ' · only the CEO can change roles'}',
            icon: Icons.badge,
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
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
                        child: Text('No staff records yet', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = list[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _roleColor(s.role),
                            backgroundImage: _passport(s) == null ? null : MemoryImage(_passport(s)!),
                            child: _passport(s) == null ? Text(
                              s.name.isEmpty ? '?' : s.name.trim()[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ) : null,
                          ),
                          title: Text(s.name.isEmpty ? s.email : s.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${s.email}${s.phone.isEmpty ? '' : ' · ${s.phone}'}'),
                          // FittedBox: chip + button can exceed the tile's
                          // trailing space on narrow phones — scale down
                          // instead of painting overflow stripes.
                          onTap: isCeo ? () => _showStaffDetails(s) : null,
                          trailing: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _roleChip(s.role),
                                if (isCeo && s.role != 'ceo') ...[
                                  const SizedBox(width: 10),
                                  _busyUid == s.uid
                                      ? const SizedBox(
                                          width: 18, height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : OutlinedButton(
                                          onPressed: () => _toggleRole(s),
                                          child: Text(s.role == 'admin' ? 'Demote' : 'Make Admin'),
                                        ),
                                ],
                              ],
                            ),
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
}
