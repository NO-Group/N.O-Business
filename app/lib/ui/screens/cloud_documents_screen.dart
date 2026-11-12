import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../../documents/share_service.dart';
import '../widgets.dart';

/// Company cloud document library. Every PDF downloaded or shared through
/// MFSL Office is archived here and can be downloaded/shared again.
class CloudDocumentsScreen extends StatefulWidget {
  const CloudDocumentsScreen({super.key});
  @override
  State<CloudDocumentsScreen> createState() => _CloudDocumentsScreenState();
}

class _CloudDocumentsScreenState extends State<CloudDocumentsScreen> {
  List<Map<String, dynamic>> documents = [];
  bool loading = true;
  String? busyId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final response = await AppStore.instance.api?.get('/api/cloud-documents');
    if (response != null && response.ok && response.json is Map) {
      final rows = (response.json as Map)['documents'];
      documents = [for (final row in rows is List ? rows : const []) if (row is Map) row.cast<String, dynamic>()];
    }
    if (mounted) setState(() => loading = false);
  }

  Future<(Uint8List, String)?> _bytes(Map<String, dynamic> document) async {
    final id = '${document['id'] ?? ''}';
    setState(() => busyId = id);
    try {
      final response = await AppStore.instance.api?.post('/api/cloud-documents/download', {'id': id});
      if (response == null || !response.ok || response.json is! Map) throw Exception('Cloud download could not be prepared');
      final payload = response.json as Map;
      final url = Uri.parse('${payload['url']}');
      final request = await HttpClient().getUrl(url);
      final result = await request.close();
      if (result.statusCode < 200 || result.statusCode >= 300) throw Exception('Cloud download failed');
      final chunks = <int>[];
      await for (final chunk in result) { chunks.addAll(chunk); }
      return (Uint8List.fromList(chunks), '${payload['filename'] ?? document['filename'] ?? 'document.pdf'}');
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Mtek.danger, content: Text(error.toString().replaceFirst('Exception: ', ''))));
      return null;
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _download(Map<String, dynamic> document) async {
    final data = await _bytes(document); if (data == null) return;
    final outcome = await savePdf(bytes: data.$1, filename: data.$2);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _share(Map<String, dynamic> document) async {
    final data = await _bytes(document); if (data == null) return;
    final outcome = await dispatchPdf(bytes: data.$1, filename: data.$2);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  String _size(dynamic value) {
    final bytes = num.tryParse('$value')?.toInt() ?? 0;
    return bytes >= 1048576 ? '${(bytes / 1048576).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      PageHeader(title: 'Cloud Documents',
        subtitle: 'Saved company documents available on every authorised device',
        icon: Icons.cloud_done_outlined,
        actions: [IconButton(tooltip: 'Refresh', onPressed: loading ? null : _load, icon: const Icon(Icons.refresh))]),
      const SizedBox(height: 12),
      Expanded(child: loading
        ? const Center(child: CircularProgressIndicator())
        : documents.isEmpty
          ? const EmptyHint('No documents have been saved to the cloud yet')
          : Card(clipBehavior: Clip.antiAlias, child: ListView.separated(
              itemCount: documents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = documents[index];
                final id = '${item['id']}';
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.picture_as_pdf_outlined)),
                  title: Text('${item['filename'] ?? 'Document'}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${item['created_by_name'] ?? 'MFSL Office'} · ${_size(item['size'])}\n${item['created_at'] ?? ''}', maxLines: 2),
                  isThreeLine: true,
                  trailing: busyId == id ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Download', onPressed: () => _download(item), icon: const Icon(Icons.download_outlined)),
                        IconButton(tooltip: 'Share', onPressed: () => _share(item), icon: const Icon(Icons.share_outlined)),
                      ]),
                );
              })),
      ),
    ]),
  );
}
