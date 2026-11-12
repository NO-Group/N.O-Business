import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../documents/doc_models.dart';
import '../widgets.dart';
import 'generator_screen.dart';

/// MILS — Maintenance Information Log Sheet.
/// Per-equipment service records with next-due tracking & overdue alerts.
/// M3: stored as flexible documents in MongoDB Atlas (photos, checklists).
class MilsScreen extends StatefulWidget {
  const MilsScreen({super.key});

  @override
  State<MilsScreen> createState() => _MilsScreenState();
}

class _MilsScreenState extends State<MilsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final now = DateTime.now();
    final overdueCount = store.milsLogs.where((l) => l.isOverdue(now)).length;

    final logs = store.milsLogs.where((l) {
      return switch (_filter) {
        'overdue' => l.isOverdue(now),
        'upcoming' => !l.isOverdue(now),
        _ => true,
      };
    }).toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'MILS — Maintenance Log',
            subtitle:
                '${store.milsLogs.length} service records · $overdueCount overdue',
            icon: Icons.build_circle,
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GeneratorScreen(initialType: DocType.mils)),
                ),
                icon: const Icon(Icons.add_task),
                label: const Text('Log service'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: [
              for (final f in const [('all', 'All'), ('overdue', 'Overdue'), ('upcoming', 'Upcoming')])
                ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  selectedColor: Theme.of(context).brightness == Brightness.dark ? Mtek.navy600 : Mtek.brandTint,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: logs.isEmpty
                  ? const EmptyHint('Nothing here — good news!')
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = logs[i];
                        final overdue = l.isOverdue(now);
                        final days = fmt.daysUntil(l.nextDue);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: overdue ? Mtek.dangerTint : Mtek.navy800.withOpacity(.08),
                            child: Icon(
                              switch (l.action) {
                                MaintenanceAction.refill => Icons.local_fire_department_outlined,
                                MaintenanceAction.installation => Icons.construction_outlined,
                                MaintenanceAction.inspection => Icons.fact_check_outlined,
                                MaintenanceAction.repair => Icons.handyman_outlined,
                                MaintenanceAction.calibration => Icons.speed_outlined,
                              },
                              size: 18,
                              color: overdue ? Mtek.danger : Mtek.navy700,
                            ),
                          ),
                          title: Text(l.equipment,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              '${l.client.name} · ${l.location}\n${l.action.name.toUpperCase()} ${fmt.fmtDate(l.serviceDate)} — ${l.technician}'),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Next due ${fmt.fmtDate(l.nextDue)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: overdue ? Mtek.danger : Mtek.gray600)),
                              const SizedBox(height: 6),
                              overdue
                                  ? const StatusChip.bad('OVERDUE')
                                  : StatusChip.paid('in $days days'),
                            ],
                          ),
                          onTap: () => _detail(context, l),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _attachPhotos(BuildContext context, MaintenanceLog l) async {
    final store = AppStore.instance;
    final result = await pickMilsPhotos();
    if (result == null || result.isEmpty) return;
    try {
      await store.attachMilsPhotos(l.id, result);
    } catch (e) {
      debugPrint('attachMilsPhotos failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photos could not be attached — please try again.')));
      }
      return;
    }
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Mtek.success,
          content: Text('${result.length} photo(s) attached to ${l.id}.')));
    }
  }

  Widget _photosStrip(MaintenanceLog l) {
    final photos = AppStore.instance.milsPhotos[l.id] ?? const <String>[];
    if (photos.isEmpty) {
      return Text('No site photos yet — use Photos to attach real ones.',
          style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: MilsPhotoImage(dataUrl: photos[i], size: 64, title: l.equipment,
            details: '${l.id} · ${l.client.name} · ${l.location} · Site photograph ${i + 1}'),
        ),
      ),
    );
  }

  void _detail(BuildContext context, MaintenanceLog l) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.id, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            Text(l.equipment, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 14),
            _row('Client', '${l.client.name} — ${l.location}'),
            _row('Action', l.action.name.toUpperCase()),
            if (l.serial != null) _row('Serial', l.serial!),
            _row('Serviced', fmt.fmtDate(l.serviceDate)),
            _row('Technician', l.technician),
            _row('Findings', l.findings),
            _row('Next due', fmt.fmtDate(l.nextDue)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const GeneratorScreen(initialType: DocType.invoice)));
                  },
                  icon: const Icon(Icons.request_quote_outlined, size: 18),
                  label: const Text('Invoice this job'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _attachPhotos(context, l),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Photos'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _photosStrip(l),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 90, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );
}
