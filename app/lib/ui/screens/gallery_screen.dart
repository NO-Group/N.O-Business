import 'package:flutter/material.dart';

import '../../core/format.dart' as fmt;
import '../../data/store.dart';
import '../widgets.dart';

class _GalleryItem {
  final String source;
  final String title;
  final String details;
  final String group;
  const _GalleryItem(this.source, this.title, this.details, this.group);
}

/// One searchable home for all user-supplied business photographs currently
/// available to this signed-in role: stock, staff passports and MILS sites.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  String query = '';
  String group = 'All';

  List<_GalleryItem> _items() {
    final store = AppStore.instance;
    final out = <_GalleryItem>[];
    for (final p in store.products) {
      for (var i = 0; i < p.imageUrls.length; i++) {
        out.add(_GalleryItem(p.imageUrls[i], p.name,
          '${p.id}${p.brand.isEmpty ? '' : ' · ${p.brand}'} · ${p.category.name.toUpperCase()} · ${p.qtyOnHand} ${p.unit} · ${fmt.naira(p.sellingPrice)} · Image ${i + 1} of ${p.imageUrls.length}', 'Stock'));
      }
    }
    for (final s in store.staff) {
      if (s.passportPhoto.isNotEmpty) {
        out.add(_GalleryItem(s.passportPhoto, s.name,
          '${s.staffId} · ${s.role.toUpperCase()} · ${s.email} · Passport photograph', 'Staff'));
      }
    }
    for (final entry in store.milsPhotos.entries) {
      final log = store.milsLogs.where((x) => x.id == entry.key).firstOrNull;
      for (var i = 0; i < entry.value.length; i++) {
        out.add(_GalleryItem(entry.value[i], log?.equipment ?? entry.key,
          '${entry.key} · ${log?.client.name ?? 'MILS customer'} · ${log?.location ?? 'Site'} · Site image ${i + 1} of ${entry.value.length}', 'MILS'));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: AppStore.instance, builder: (context, _) {
      final all = _items();
      final needle = query.trim().toLowerCase();
      final shown = all.where((x) => (group == 'All' || x.group == group) &&
        (needle.isEmpty || '${x.title} ${x.details} ${x.group}'.toLowerCase().contains(needle))).toList();
      return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Column(children: [
        TextField(onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search images and details…')),
        const SizedBox(height: 8),
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final value in const ['All', 'Stock', 'Staff', 'MILS'])
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
              label: Text(value), selected: group == value, onSelected: (_) => setState(() => group = value))),
        ])),
      ])),
      Expanded(child: shown.isEmpty
        ? EmptyHint(all.isEmpty ? 'No images have been added yet' : 'No images match this search')
        : LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 1100 ? 5 : box.maxWidth >= 760 ? 4 : box.maxWidth >= 480 ? 3 : 2;
            return GridView.builder(padding: const EdgeInsets.all(12), itemCount: shown.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns,
                crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .72),
              itemBuilder: (context, i) {
                final item = shown[i];
                return Card(clipBehavior: Clip.antiAlias, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: SizedBox(width: double.infinity, child: AppImage(source: item.source,
                    title: item.title, details: item.details, width: double.infinity, height: double.infinity))),
                  Padding(padding: const EdgeInsets.all(9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text('${item.group} · ${item.details}', maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                  ])),
                ]));
              });
          })),
      ]);
    });
  }
}

extension _FirstOrNullGallery<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
