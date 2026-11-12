import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/theme.dart';
import '../../data/store.dart';
import '../../documents/pdf_shared.dart';
import '../../documents/share_service.dart';
import '../widgets.dart';

class _DocBlock {
  String type;
  final TextEditingController text;
  String image;
  bool bold, italic, underline;
  String align;
  _DocBlock(this.type, [String value = '', this.image = '', this.bold = false,
    this.italic = false, this.underline = false, this.align = 'left']) : text = TextEditingController(text: value);
  factory _DocBlock.fromJson(Map data) => _DocBlock('${data['type'] ?? 'paragraph'}',
    '${data['text'] ?? ''}', '${data['image'] ?? ''}', data['bold'] == true,
    data['italic'] == true, data['underline'] == true, '${data['align'] ?? 'left'}');
  Map<String, dynamic> toJson() => {'type': type, 'text': text.text,
    'bold': bold, 'italic': italic, 'underline': underline, 'align': align,
    if (image.isNotEmpty) 'image': image};
  void dispose() => text.dispose();
}

/// Word-style structured editor: cloud autosave, headings, lists, quotes,
/// simple tables, images, versioned server records and PDF export/share.
class OfficeDocumentsScreen extends StatefulWidget {
  const OfficeDocumentsScreen({super.key});
  @override State<OfficeDocumentsScreen> createState() => _OfficeDocumentsScreenState();
}

class _OfficeDocumentsScreenState extends State<OfficeDocumentsScreen> {
  final title = TextEditingController();
  final search = TextEditingController();
  final blocks = <_DocBlock>[];
  List<Map<String, dynamic>> documents = [];
  String? documentId;
  int revision = 0;
  bool loading = true, saving = false;
  String saveState = 'Saved';
  Timer? autosave;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { autosave?.cancel(); title.dispose(); search.dispose(); for (final b in blocks) { b.dispose(); } super.dispose(); }

  Future<void> _load() async {
    setState(() => loading = true);
    final response = await AppStore.instance.api?.get('/api/office-documents');
    if (response != null && response.ok && response.json is Map) {
      final rows = (response.json as Map)['documents'];
      documents = [for (final r in rows is List ? rows : const []) if (r is Map) r.cast<String, dynamic>()];
    }
    if (mounted) setState(() => loading = false);
  }

  void _new() {
    autosave?.cancel();
    for (final b in blocks) { b.dispose(); }
    setState(() {
      documentId = 'doc-${DateTime.now().microsecondsSinceEpoch}'; revision = 0;
      title.text = 'Untitled document'; blocks..clear()..add(_DocBlock('heading', 'Document title'))..add(_DocBlock('paragraph'));
    });
  }

  void _template(String kind) {
    _new();
    for (final b in blocks) { b.dispose(); }
    blocks.clear();
    if (kind == 'memo') {
      title.text = 'Internal Memo';
      blocks.addAll([_DocBlock('heading', 'INTERNAL MEMORANDUM', '', true, false, false, 'center'),
        _DocBlock('table', 'TO | \nFROM | \nDATE | \nSUBJECT | '), _DocBlock('paragraph', 'Purpose and background'),
        _DocBlock('subheading', 'Action required'), _DocBlock('bullet', '')]);
    } else if (kind == 'report') {
      title.text = 'Business Report';
      blocks.addAll([_DocBlock('heading', 'REPORT TITLE', '', true, false, false, 'center'),
        _DocBlock('subheading', 'Executive summary'), _DocBlock('paragraph', ''),
        _DocBlock('subheading', 'Findings'), _DocBlock('bullet', ''),
        _DocBlock('subheading', 'Recommendations'), _DocBlock('numbered', '')]);
    } else {
      title.text = 'Meeting Minutes';
      blocks.addAll([_DocBlock('heading', 'MEETING MINUTES', '', true, false, false, 'center'),
        _DocBlock('table', 'Date | \nVenue | \nChairperson | '), _DocBlock('subheading', 'Attendance'),
        _DocBlock('bullet', ''), _DocBlock('subheading', 'Agenda and decisions'), _DocBlock('numbered', ''),
        _DocBlock('subheading', 'Action items'), _DocBlock('table', 'Action | Owner | Due date\n | | ')]);
    }
    saveState = 'Not saved';
    setState(() {});
  }

  Future<void> _duplicate(Map<String, dynamic> doc) async {
    final newId = 'doc-${DateTime.now().microsecondsSinceEpoch}';
    final response = await AppStore.instance.api?.post('/api/office-documents/save', {
      'id': newId, 'title': 'Copy of ${doc['title']}', 'blocks': doc['blocks'] ?? const [], 'base_revision': 0,
    });
    if (response != null && response.ok) await _load();
  }

  void _open(Map<String, dynamic> doc) {
    autosave?.cancel(); for (final b in blocks) { b.dispose(); }
    setState(() {
      documentId = '${doc['id']}'; title.text = '${doc['title'] ?? 'Untitled document'}';
      revision = (doc['revision'] as num? ?? 1).toInt(); blocks.clear();
      for (final raw in doc['blocks'] is List ? doc['blocks'] as List : const []) {
        if (raw is Map) blocks.add(_DocBlock.fromJson(raw));
      }
      if (blocks.isEmpty) blocks.add(_DocBlock('paragraph'));
    });
  }

  void _changed([String? _]) {
    if (documentId == null) return;
    if (mounted) setState(() => saveState = 'Not saved');
    autosave?.cancel(); autosave = Timer(const Duration(milliseconds: 1200), () => _save(silent: true));
  }

  Future<bool> _save({bool silent = false}) async {
    if (documentId == null || title.text.trim().isEmpty || saving) return false;
    setState(() { saving = true; saveState = 'Saving…'; });
    final response = await AppStore.instance.api?.post('/api/office-documents/save', {
      'id': documentId, 'title': title.text.trim(), 'blocks': blocks.map((b) => b.toJson()).toList(),
      'base_revision': revision,
    });
    final ok = response != null && response.ok;
    if (ok && response.json is Map) revision = ((response.json as Map)['revision'] as num? ?? revision).toInt();
    if (mounted) {
      setState(() { saving = false; saveState = ok ? 'Saved' : 'Save failed'; });
      if (!silent || !ok) {
        final serverError = response?.json is Map ? '${(response!.json as Map)['error'] ?? ''}' : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: ok ? Mtek.success : Mtek.danger,
          content: Text(ok ? 'Editable document saved to the cloud.'
            : (serverError.isEmpty ? 'Cloud save failed. Your editor remains open.' : serverError))));
      }
    }
    if (ok) unawaited(_load());
    return ok;
  }

  void _add(String type) {
    setState(() => blocks.add(_DocBlock(type, type == 'table' ? 'Heading 1 | Heading 2\nValue 1 | Value 2' : '')));
    _changed();
  }

  Future<void> _addImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    final ext = (file!.extension ?? 'jpg').toLowerCase();
    final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => blocks.add(_DocBlock('image', file.name, 'data:$mime;base64,${base64Encode(file.bytes!)}')));
    _changed();
  }

  Future<Uint8List> _pdf() async {
    await MtekPdfFonts.load();
    final logoData = await rootBundle.load('assets/branding/logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(base: MtekPdfFonts.base, bold: MtekPdfFonts.bold),
      header: (_) => corporateHeader(logo),
      footer: (ctx) => pw.Align(alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))),
      build: (_) => [pw.SizedBox(height: 18), for (var i = 0; i < blocks.length; i++) ..._pdfBlock(blocks[i], i)],
    ));
    return pdf.save();
  }

  List<pw.Widget> _pdfBlock(_DocBlock block, int index) {
    final text = block.text.text.trim();
    final alignment = switch (block.align) {
      'center' => pw.TextAlign.center, 'right' => pw.TextAlign.right,
      'justify' => pw.TextAlign.justify, _ => pw.TextAlign.left,
    };
    pw.TextStyle styled(double size, {pw.FontWeight? weight}) => pw.TextStyle(
      fontSize: size, fontWeight: block.bold ? pw.FontWeight.bold : weight,
      fontStyle: block.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      decoration: block.underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
      lineSpacing: 2,
    );
    switch (block.type) {
      case 'heading': return [pw.Text(text, textAlign: alignment, style: styled(24, weight: pw.FontWeight.bold)), pw.SizedBox(height: 8)];
      case 'subheading': return [pw.Text(text, textAlign: alignment, style: styled(17, weight: pw.FontWeight.bold)), pw.SizedBox(height: 6)];
      case 'bullet': return [pw.Bullet(text: text), pw.SizedBox(height: 2)];
      case 'numbered': return [pw.Bullet(text: '${index + 1}. $text', bulletSize: 0), pw.SizedBox(height: 2)];
      case 'quote': return [pw.Container(padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: PdfColors.red700, width: 3))), child: pw.Text(text, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))), pw.SizedBox(height: 5)];
      case 'table':
        final rows = [for (final line in block.text.text.split('\n')) line.split('|').map((x) => x.trim()).toList()];
        return [if (rows.isNotEmpty) pw.TableHelper.fromTextArray(data: rows, headerCount: 1,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 7)];
      case 'image':
        try { return [pw.Center(child: pw.Image(pw.MemoryImage(base64Decode(block.image.split(',').last)), height: 220, fit: pw.BoxFit.contain)), if (text.isNotEmpty) pw.Center(child: pw.Text(text, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700))), pw.SizedBox(height: 8)]; } catch (_) { return []; }
      default: return [if (text.isNotEmpty) pw.Text(text, textAlign: alignment, style: styled(10.5)), pw.SizedBox(height: 5)];
    }
  }

  Future<void> _export(bool share) async {
    if (!await _save()) return;
    final bytes = await _pdf();
    final filename = '${title.text.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')}.pdf';
    final outcome = share ? await dispatchPdf(bytes: bytes, filename: filename) : await savePdf(bytes: bytes, filename: filename);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _history(Map<String, dynamic> doc) async {
    final versions = (doc['versions'] as List? ?? const []).cast<Map>();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Version history · ${doc['title']}'),
      content: SizedBox(width: 480, child: versions.isEmpty
        ? const Text('No earlier versions are available yet.')
        : ListView.builder(shrinkWrap: true, itemCount: versions.length, itemBuilder: (_, i) {
            final version = versions[versions.length - i - 1];
            return ListTile(
              leading: const Icon(Icons.history),
              title: Text('Revision ${version['revision']}'),
              subtitle: Text('${version['saved_at'] ?? ''} · ${version['saved_by_name'] ?? 'Unknown editor'}'),
              trailing: TextButton(onPressed: () async {
                final response = await AppStore.instance.api?.post('/api/office-documents/restore', {
                  'id': '${doc['id']}', 'revision': version['revision'],
                });
                if (!mounted) return;
                if (response != null && response.ok) {
                  Navigator.pop(dialogContext);
                  await _load();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Version restored as a new revision.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not restore that version.')));
                }
              }, child: const Text('Restore')),
            );
          })),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
    ));
  }

  Future<void> _delete(Map<String, dynamic> doc) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete document?'), content: Text('Remove “${doc['title']}” from the active office workspace?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
    if (yes != true) return;
    final response = await AppStore.instance.api?.post('/api/office-documents/delete', {'id': '${doc['id']}'});
    if (response != null && response.ok) { if (documentId == doc['id']) setState(() => documentId = null); await _load(); }
  }

  @override
  Widget build(BuildContext context) => documentId == null ? _library() : _editor();

  Widget _library() {
    final q = search.text.trim().toLowerCase();
    final shown = q.isEmpty ? documents : documents.where((d) {
      final body = (d['blocks'] as List? ?? const []).map((x) => x is Map ? '${x['text'] ?? ''}' : '').join(' ');
      return '${d['title'] ?? ''} $body'.toLowerCase().contains(q);
    }).toList();
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      PageHeader(title: 'Office Documents', subtitle: 'Create structured documents with cloud autosave and PDF export', icon: Icons.description_outlined,
        actions: [PopupMenuButton<String>(tooltip: 'New from template', onSelected: (v) => v == 'blank' ? _new() : _template(v), icon: const Icon(Icons.add), itemBuilder: (_) => const [
          PopupMenuItem(value: 'blank', child: Text('Blank document')), PopupMenuItem(value: 'memo', child: Text('Internal memo')),
          PopupMenuItem(value: 'report', child: Text('Business report')), PopupMenuItem(value: 'minutes', child: Text('Meeting minutes'))]),
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh))]),
      const SizedBox(height: 10),
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search titles and document content', suffixIcon: Icon(Icons.manage_search))),
      const SizedBox(height: 12),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : shown.isEmpty ? const EmptyHint('No matching editable documents') : Card(child: ListView.separated(itemCount: shown.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final d = shown[i]; return ListTile(leading: const Icon(Icons.article_outlined), title: Text('${d['title']}'), subtitle: Text('Revision ${d['revision'] ?? 1} · ${d['owner_name'] ?? ''} · ${d['updated_at'] ?? ''}', maxLines: 2), onTap: () => _open(d), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(tooltip: 'Duplicate', onPressed: () => _duplicate(d), icon: const Icon(Icons.copy_outlined)), IconButton(tooltip: 'Version history', onPressed: () => _history(d), icon: const Icon(Icons.history)), IconButton(tooltip: 'Delete', onPressed: () => _delete(d), icon: const Icon(Icons.delete_outline))])); }))),
    ]));
  }

  Widget _editor() => Column(children: [
    Material(color: Theme.of(context).colorScheme.surfaceContainer, child: SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
      Row(children: [IconButton(tooltip: 'Back to library', onPressed: () { autosave?.cancel(); _save(silent: true); setState(() => documentId = null); }, icon: const Icon(Icons.arrow_back)), Expanded(child: TextField(controller: title, onChanged: _changed, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), decoration: const InputDecoration(hintText: 'Document title', border: InputBorder.none))), if (saving) const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))), Text('$saveState · Rev $revision')]),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _tool(Icons.title, 'Heading', () => _add('heading')), _tool(Icons.short_text, 'Paragraph', () => _add('paragraph')),
        _tool(Icons.format_list_bulleted, 'Bullet', () => _add('bullet')), _tool(Icons.format_list_numbered, 'Numbered', () => _add('numbered')),
        _tool(Icons.format_quote, 'Quote', () => _add('quote')), _tool(Icons.table_chart_outlined, 'Table', () => _add('table')),
        _tool(Icons.image_outlined, 'Image', _addImage), _tool(Icons.cloud_upload_outlined, 'Save', _save),
        _tool(Icons.download_outlined, 'PDF', () => _export(false)), _tool(Icons.share_outlined, 'Share', () => _export(true)),
      ])),
    ])))),
    Expanded(child: ListView.builder(padding: const EdgeInsets.fromLTRB(18, 18, 18, 50), itemCount: blocks.length, itemBuilder: (_, i) => _blockEditor(i))),
  ]);

  Widget _tool(IconData icon, String label, VoidCallback action) => Padding(padding: const EdgeInsets.only(right: 5), child: TextButton.icon(onPressed: action, icon: Icon(icon, size: 17), label: Text(label)));

  Widget _blockEditor(int index) {
    final b = blocks[index];
    final style = TextStyle(
      fontSize: b.type == 'heading' ? 25 : b.type == 'subheading' ? 19 : 15,
      fontWeight: (b.bold || b.type == 'heading' || b.type == 'subheading') ? FontWeight.w700 : FontWeight.normal,
      fontStyle: b.italic ? FontStyle.italic : FontStyle.normal,
      decoration: b.underline ? TextDecoration.underline : TextDecoration.none,
      height: 1.45,
    );
    final alignment = switch (b.align) {
      'center' => TextAlign.center, 'right' => TextAlign.right,
      'justify' => TextAlign.justify, _ => TextAlign.left,
    };
    void change(VoidCallback update) { setState(update); _changed(); }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
        child: Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            SizedBox(width: 130, child: DropdownButton<String>(
              value: b.type,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: const {
                'paragraph': 'Paragraph', 'heading': 'Heading', 'subheading': 'Subheading',
                'bullet': 'Bullet', 'numbered': 'Numbered', 'quote': 'Quote',
                'table': 'Table', 'image': 'Image',
              }.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: b.type == 'image' ? null : (value) => change(() => b.type = value ?? b.type),
            )),
            IconButton(tooltip: 'Bold', isSelected: b.bold,
              onPressed: () => change(() => b.bold = !b.bold), icon: const Icon(Icons.format_bold)),
            IconButton(tooltip: 'Italic', isSelected: b.italic,
              onPressed: () => change(() => b.italic = !b.italic), icon: const Icon(Icons.format_italic)),
            IconButton(tooltip: 'Underline', isSelected: b.underline,
              onPressed: () => change(() => b.underline = !b.underline), icon: const Icon(Icons.format_underlined)),
            PopupMenuButton<String>(tooltip: 'Alignment', icon: const Icon(Icons.format_align_left),
              onSelected: (value) => change(() => b.align = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'left', child: Text('Align left')),
                PopupMenuItem(value: 'center', child: Text('Align centre')),
                PopupMenuItem(value: 'right', child: Text('Align right')),
                PopupMenuItem(value: 'justify', child: Text('Justify')),
              ]),
            IconButton(tooltip: 'Move up', onPressed: index == 0 ? null : () => change(() {
              final item = blocks.removeAt(index); blocks.insert(index - 1, item);
            }), icon: const Icon(Icons.arrow_upward, size: 18)),
            IconButton(tooltip: 'Move down', onPressed: index == blocks.length - 1 ? null : () => change(() {
              final item = blocks.removeAt(index); blocks.insert(index + 1, item);
            }), icon: const Icon(Icons.arrow_downward, size: 18)),
            IconButton(tooltip: 'Duplicate', onPressed: () => change(() {
              blocks.insert(index + 1, _DocBlock.fromJson(b.toJson()));
            }), icon: const Icon(Icons.copy_outlined, size: 18)),
            IconButton(tooltip: 'Remove block', onPressed: () => change(() {
              blocks.removeAt(index).dispose();
            }), icon: const Icon(Icons.close, size: 18)),
          ])),
          const Divider(),
          if (b.type == 'image')
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AppImage(source: b.image, title: b.text.text.isEmpty ? 'Document image' : b.text.text,
                width: 220, height: 150),
              TextField(controller: b.text, onChanged: _changed,
                decoration: const InputDecoration(labelText: 'Image caption')),
            ])
          else
            TextField(
              controller: b.text,
              onChanged: _changed,
              maxLines: null,
              textAlign: alignment,
              style: style,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: b.type == 'table'
                  ? 'Separate columns with | and rows with a new line'
                  : 'Type here…',
              ),
            ),
        ]),
      ),
    );
  }
}
