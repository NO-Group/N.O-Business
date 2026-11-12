import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/theme.dart';
import '../../data/auth_store.dart';
import '../../data/local_store.dart';
import '../../documents/pdf_shared.dart';
import '../../documents/share_service.dart';
import '../widgets.dart';

/// CEO-only official letter composer. Drafts remain on-device until exported.
class LetterheadScreen extends StatefulWidget {
  const LetterheadScreen({super.key});

  @override
  State<LetterheadScreen> createState() => _LetterheadScreenState();
}

class _LetterheadScreenState extends State<LetterheadScreen> {
  static const _draftKey = 'ceo_letterhead_draft';
  final _recipient = TextEditingController();
  final _address = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _closing = TextEditingController(text: 'Yours faithfully,');
  Timer? _saveTimer;
  bool _bold = false, _italic = false, _underline = false, _busy = false;
  bool _landscape = false, _trackingHistory = true;
  double _fontSize = 11, _lineSpacing = 1.35, _margin = 36, _zoom = 1;
  TextAlign _alignment = TextAlign.left;
  final _footerText = TextEditingController();
  final List<List<TextEditingController>> _table = [];
  final List<String> _images = [];
  final List<String> _undo = [], _redo = [];
  String _lastBody = '';
  static const _pageBreak = '[[PAGE_BREAK]]';

  @override
  void initState() {
    super.initState();
    for (final c in [_recipient, _address, _subject, _closing, _footerText]) {
      c.addListener(_scheduleSave);
    }
    _body.addListener(_bodyChanged);
    unawaited(_restore());
  }

  void _bodyChanged() {
    if (_trackingHistory && _body.text != _lastBody) {
      _undo.add(_lastBody);
      if (_undo.length > 100) _undo.removeAt(0);
      _redo.clear();
    }
    _lastBody = _body.text;
    _scheduleSave();
    if (mounted) setState(() {});
  }

  void _setBody(String value) {
    _trackingHistory = false;
    _body.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
    _lastBody = value;
    _trackingHistory = true;
  }

  void _undoEdit() {
    if (_undo.isEmpty) return;
    _redo.add(_body.text);
    _setBody(_undo.removeLast());
    setState(() {});
  }

  void _redoEdit() {
    if (_redo.isEmpty) return;
    _undo.add(_body.text);
    _setBody(_redo.removeLast());
    setState(() {});
  }

  void _insertAtSelection(String text) {
    final selection = _body.selection;
    final start = selection.isValid ? selection.start : _body.text.length;
    final end = selection.isValid ? selection.end : start;
    final next = _body.text.replaceRange(start, end, text);
    _body.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: start + text.length));
  }

  void _formatSelectedLines({required bool numbered}) {
    final selection = _body.selection;
    if (!selection.isValid) return;
    final start = selection.start <= 0 ? 0 : _body.text.lastIndexOf('\n', selection.start - 1) + 1;
    final after = _body.text.indexOf('\n', selection.end);
    final end = after < 0 ? _body.text.length : after;
    var n = 0;
    final changed = _body.text.substring(start, end).split('\n').map((line) {
      n++;
      return numbered ? '$n. ${line.replaceFirst(RegExp(r'^\\s*(?:•|\\d+\\.)\\s*'), '')}'
          : '• ${line.replaceFirst(RegExp(r'^\\s*(?:•|\\d+\\.)\\s*'), '')}';
    }).join('\n');
    _body.value = TextEditingValue(text: _body.text.replaceRange(start, end, changed),
      selection: TextSelection(baseOffset: start, extentOffset: start + changed.length));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() => localWrite(_draftKey, jsonEncode({
        'recipient': _recipient.text, 'address': _address.text,
        'subject': _subject.text, 'body': _body.text, 'closing': _closing.text,
        'bold': _bold, 'italic': _italic, 'underline': _underline,
        'fontSize': _fontSize, 'alignment': _alignment.name,
        'lineSpacing': _lineSpacing, 'margin': _margin, 'zoom': _zoom,
        'landscape': _landscape, 'footer': _footerText.text,
        'images': _images,
        'table': [for (final row in _table) [for (final cell in row) cell.text]],
      }));

  Future<void> _restore() async {
    final raw = await localRead(_draftKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final d = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _recipient.text = '${d['recipient'] ?? ''}';
      _address.text = '${d['address'] ?? ''}';
      _subject.text = '${d['subject'] ?? ''}';
      _setBody('${d['body'] ?? ''}');
      _closing.text = '${d['closing'] ?? 'Yours faithfully,'}';
      _footerText.text = '${d['footer'] ?? ''}';
      _bold = d['bold'] == true; _italic = d['italic'] == true;
      _underline = d['underline'] == true;
      _fontSize = (d['fontSize'] as num?)?.toDouble() ?? 11;
      _lineSpacing = (d['lineSpacing'] as num?)?.toDouble() ?? 1.35;
      _margin = (d['margin'] as num?)?.toDouble() ?? 36;
      _zoom = (d['zoom'] as num?)?.toDouble() ?? 1;
      _landscape = d['landscape'] == true;
      _images.addAll((d['images'] as List? ?? const []).map((x) => '$x'));
      for (final rawRow in (d['table'] as List? ?? const [])) {
        _table.add([for (final value in rawRow as List) TextEditingController(text: '$value')]);
      }
      _alignment = TextAlign.values.firstWhere(
        (a) => a.name == d['alignment'], orElse: () => TextAlign.left);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_save());
    for (final c in [_recipient, _address, _subject, _body, _closing, _footerText]) {
      c.dispose();
    }
    for (final row in _table) { for (final c in row) { c.dispose(); } }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthStore.instance.isCeo) {
      return const Center(child: Text('Only the CEO can compose official letters.'));
    }
    final style = TextStyle(
      fontSize: _fontSize,
      fontWeight: _bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _italic ? FontStyle.italic : FontStyle.normal,
      decoration: _underline ? TextDecoration.underline : TextDecoration.none,
    );
    return ListView(padding: const EdgeInsets.all(20), children: [
      PageHeader(
        title: 'Official Letterhead',
        subtitle: 'Compose, preview, download and share company letters',
        icon: Icons.article_outlined,
        actions: [
          OutlinedButton.icon(onPressed: _busy ? null : _preview,
              icon: const Icon(Icons.print_outlined), label: const Text('Print')),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _busy ? null : _share,
              icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Share PDF')),
        ],
      ),
      const SizedBox(height: 14),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _recipient,
              decoration: const InputDecoration(labelText: 'Recipient / organisation'))),
          const SizedBox(width: 10),
          SizedBox(width: 180, child: TextField(
              decoration: const InputDecoration(labelText: 'Date'),
              controller: TextEditingController(text: _date(DateTime.now())), readOnly: true)),
        ]),
        TextField(controller: _address, maxLines: 2,
            decoration: const InputDecoration(labelText: 'Recipient address')),
        TextField(controller: _subject,
            decoration: const InputDecoration(labelText: 'Subject / reference')),
      ]))),
      const SizedBox(height: 12),
      Card(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 4), child: Wrap(
          spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            IconButton(tooltip: 'Undo', onPressed: _undo.isEmpty ? null : _undoEdit, icon: const Icon(Icons.undo)),
            IconButton(tooltip: 'Redo', onPressed: _redo.isEmpty ? null : _redoEdit, icon: const Icon(Icons.redo)),
            IconButton(tooltip: 'Find and replace', onPressed: _findReplace, icon: const Icon(Icons.find_replace)),
            IconButton(tooltip: 'Bulleted list', onPressed: () => _formatSelectedLines(numbered: false), icon: const Icon(Icons.format_list_bulleted)),
            IconButton(tooltip: 'Numbered list', onPressed: () => _formatSelectedLines(numbered: true), icon: const Icon(Icons.format_list_numbered)),
            IconButton(tooltip: 'Insert page break', onPressed: () => _insertAtSelection('\n$_pageBreak\n'), icon: const Icon(Icons.insert_page_break_outlined)),
            IconButton(tooltip: 'Insert images', onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate_outlined)),
            IconButton(tooltip: 'Templates', onPressed: _chooseTemplate, icon: const Icon(Icons.dashboard_customize_outlined)),
            _toggle(Icons.format_bold, _bold, () => _bold = !_bold, 'Bold'),
            _toggle(Icons.format_italic, _italic, () => _italic = !_italic, 'Italic'),
            _toggle(Icons.format_underlined, _underline, () => _underline = !_underline, 'Underline'),
            const SizedBox(width: 8),
            for (final a in [TextAlign.left, TextAlign.center, TextAlign.right, TextAlign.justify])
              _toggle(_alignIcon(a), _alignment == a, () => _alignment = a, a.name),
            const SizedBox(width: 8),
            IconButton(tooltip: 'Insert table', icon: const Icon(Icons.table_chart_outlined),
              onPressed: () => setState(() {
                if (_table.isEmpty) _table.addAll(List.generate(3, (_) => List.generate(3, (_) => TextEditingController())));
              })),
            DropdownButton<double>(value: _fontSize,
              items: [9, 10, 11, 12, 14, 16, 18].map((s) =>
                DropdownMenuItem(value: s.toDouble(), child: Text('${s}pt'))).toList(),
              onChanged: (v) => setState(() { _fontSize = v ?? 11; _scheduleSave(); })),
          ],
        )),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Wrap(
          spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            DropdownButton<double>(value: _lineSpacing, hint: const Text('Line spacing'),
              items: const [1.0, 1.15, 1.35, 1.5, 2.0].map((v) => DropdownMenuItem(value: v, child: Text('${v}× lines'))).toList(),
              onChanged: (v) => setState(() { _lineSpacing = v ?? 1.35; _scheduleSave(); })),
            DropdownButton<double>(value: _margin,
              items: const [24.0, 36.0, 48.0, 60.0].map((v) => DropdownMenuItem(value: v, child: Text('${v.toInt()}pt margins'))).toList(),
              onChanged: (v) => setState(() { _margin = v ?? 36; _scheduleSave(); })),
            SegmentedButton<bool>(segments: const [
              ButtonSegment(value: false, label: Text('Portrait'), icon: Icon(Icons.stay_current_portrait)),
              ButtonSegment(value: true, label: Text('Landscape'), icon: Icon(Icons.stay_current_landscape)),
            ], selected: {_landscape}, onSelectionChanged: (v) => setState(() { _landscape = v.first; _scheduleSave(); })),
            SizedBox(width: 180, child: Slider(value: _zoom, min: .75, max: 1.5, divisions: 3,
              label: '${(_zoom * 100).round()}% zoom', onChanged: (v) => setState(() => _zoom = v))),
          ])),
        const Divider(height: 1),
        Padding(padding: EdgeInsets.all(16 * _zoom), child: TextField(
          controller: _body, minLines: 16, maxLines: null,
          textAlign: _alignment, style: style,
          decoration: const InputDecoration(border: InputBorder.none,
            hintText: 'Write the official letter here...'),
        )),
      ])),
      if (_table.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
          for (final row in _table) Row(children: [for (final cell in row)
            Expanded(child: Padding(padding: const EdgeInsets.all(2), child: TextField(
              controller: cell, onChanged: (_) => _scheduleSave(),
              decoration: const InputDecoration(isDense: true, hintText: 'Table cell'))))]),
          Row(children: [TextButton.icon(onPressed: () => setState(() => _table.add(
            List.generate(_table.first.length, (_) => TextEditingController()))), icon: const Icon(Icons.add), label: const Text('Add row')),
            TextButton.icon(onPressed: () => setState(() { for (final row in _table) { row.add(TextEditingController()); } }), icon: const Icon(Icons.view_column_outlined), label: const Text('Add column')),
            const Spacer(), IconButton(tooltip: 'Remove table', onPressed: () => setState(() { for (final row in _table) { for (final c in row) { c.dispose(); } } _table.clear(); }), icon: const Icon(Icons.delete_outline))])
        ]))),
      ],
      if (_images.isNotEmpty) ...[
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Inserted images', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [for (var i = 0; i < _images.length; i++)
            Stack(children: [AppImage(source: _images[i], title: 'Letterhead attachment',
              details: 'Letterhead image ${i + 1}', width: 130, height: 100),
              Positioned(right: 0, child: IconButton(style: IconButton.styleFrom(backgroundColor: Colors.white),
                icon: const Icon(Icons.close), onPressed: () => setState(() { _images.removeAt(i); _scheduleSave(); })))])]),
        ]))),
      ],
      const SizedBox(height: 12),
      TextField(controller: _footerText, decoration: const InputDecoration(
        labelText: 'Custom footer (optional)', hintText: 'Confidential · Reference · Contact')),
      const SizedBox(height: 12),
      TextField(controller: _closing, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Closing / sign-off')),
      const SizedBox(height: 12),
      Row(children: [
        OutlinedButton.icon(onPressed: _busy ? null : _download,
            icon: const Icon(Icons.download_outlined), label: const Text('Download PDF')),
        const Spacer(),
        TextButton.icon(onPressed: _clear,
            icon: const Icon(Icons.delete_outline), label: const Text('Clear draft')),
      ]),
    ]);
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
    if (result == null) return;
    for (final file in result.files) {
      if (file.bytes == null || file.bytes!.length > 5 * 1024 * 1024) continue;
      final ext = (file.extension ?? 'jpg').toLowerCase();
      final mime = ext == 'png' ? 'image/png' : ext == 'webp' ? 'image/webp' : 'image/jpeg';
      _images.add('data:$mime;base64,${base64Encode(file.bytes!)}');
    }
    if (_images.length > 10) _images.removeRange(10, _images.length);
    setState(() {}); _scheduleSave();
  }

  Future<void> _findReplace() async {
    final find = TextEditingController(), replace = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Find and replace'), content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: find, autofocus: true, decoration: const InputDecoration(labelText: 'Find')),
        const SizedBox(height: 8), TextField(controller: replace, decoration: const InputDecoration(labelText: 'Replace with')),
      ]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Replace all'))]));
    if (ok == true && find.text.isNotEmpty) {
      _undo.add(_body.text); _redo.clear();
      _setBody(_body.text.replaceAll(find.text, replace.text));
      setState(() {}); _scheduleSave();
    }
  }

  Future<void> _chooseTemplate() async {
    final selected = await showDialog<String>(context: context, builder: (c) => SimpleDialog(
      title: const Text('Start from a template'), children: [
        for (final item in const [('general', 'General business letter'), ('appointment', 'Appointment letter'),
          ('warning', 'Staff warning'), ('quotation', 'Quotation cover letter')])
          SimpleDialogOption(onPressed: () => Navigator.pop(c, item.$1), child: Text(item.$2)),
      ]));
    if (selected == null) return;
    final text = switch (selected) {
      'appointment' => 'Dear Sir/Madam,\n\nAPPOINTMENT\n\nWe are pleased to offer you an appointment with M-TEK Fire & Safety Ltd. The terms and effective date are set out below.\n\n',
      'warning' => 'Dear Sir/Madam,\n\nFORMAL WARNING\n\nThis letter serves as a formal warning concerning the matter described below. Please provide your response within the stated period.\n\n',
      'quotation' => 'Dear Sir/Madam,\n\nPlease find attached our quotation for the requested products and services. We remain available to clarify any part of our proposal.\n\n',
      _ => 'Dear Sir/Madam,\n\n',
    };
    if (_body.text.trim().isNotEmpty) {
      final replace = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Replace current writing?'),
        content: const Text('Your current draft will remain in Undo history.'), actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Replace'))]));
      if (replace != true) return;
    }
    _undo.add(_body.text); _redo.clear();
    _setBody(text); setState(() {}); _scheduleSave();
  }

  Widget _toggle(IconData icon, bool selected, VoidCallback change, String tip) =>
      IconButton(tooltip: tip, isSelected: selected, icon: Icon(icon), onPressed: () {
        setState(change); _scheduleSave();
      });

  IconData _alignIcon(TextAlign a) => switch (a) {
    TextAlign.center => Icons.format_align_center,
    TextAlign.right => Icons.format_align_right,
    TextAlign.justify => Icons.format_align_justify,
    _ => Icons.format_align_left,
  };

  Future<Uint8List?> _bytes() async {
    if (_body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write the letter before creating the PDF.')));
      return null;
    }
    setState(() => _busy = true);
    try {
      await MtekPdfFonts.load();
      final logoData = await rootBundle.load('assets/branding/logo.png');
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());
      final pdf = pw.Document();
      final align = switch (_alignment) {
        TextAlign.center => pw.TextAlign.center,
        TextAlign.right => pw.TextAlign.right,
        TextAlign.justify => pw.TextAlign.justify,
        _ => pw.TextAlign.left,
      };
      final pageFormat = _landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
      final bodyWidgets = <pw.Widget>[];
      final sections = _body.text.split(_pageBreak);
      for (var i = 0; i < sections.length; i++) {
        if (i > 0) bodyWidgets.add(pw.NewPage());
        if (sections[i].trim().isNotEmpty) bodyWidgets.add(pw.Text(sections[i], textAlign: align,
          style: pw.TextStyle(fontSize: _fontSize, fontWeight: _bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: _italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: _underline ? pw.TextDecoration.underline : null, lineSpacing: _lineSpacing * 2)));
      }
      for (final dataUrl in _images) {
        try {
          bodyWidgets.add(pw.Padding(padding: const pw.EdgeInsets.only(top: 12), child: pw.Image(
            pw.MemoryImage(base64Decode(dataUrl.split(',').last)), fit: pw.BoxFit.contain, height: 220)));
        } catch (_) { /* invalid draft image is ignored */ }
      }
      pdf.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(pageFormat: pageFormat,
          margin: pw.EdgeInsets.fromLTRB(_margin, 24, _margin, 36),
          theme: pw.ThemeData.withFont(base: MtekPdfFonts.base, bold: MtekPdfFonts.bold),
          buildBackground: (_) => documentBackground(logo, pageFormat)),
        header: (_) => pw.Column(children: [corporateHeader(logo), pw.SizedBox(height: 16)]),
        footer: (c) => pw.Row(children: [
          if (_footerText.text.trim().isNotEmpty) pw.Expanded(child: pw.Text(_footerText.text,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600))),
          pw.Text('Page ${c.pageNumber} of ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
        ]),
        build: (_) => [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_date(DateTime.now()))),
            if (_recipient.text.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18), pw.Text(_recipient.text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
            if (_address.text.trim().isNotEmpty) pw.Text(_address.text),
            if (_subject.text.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Container(width: double.infinity, child: pw.Text(_subject.text.toUpperCase(), textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline))),
            ],
          ]),
          pw.SizedBox(height: 16),
          ...bodyWidgets,
          if (_table.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              data: [for (final row in _table) [for (final cell in row) cell.text]],
              border: pw.TableBorder.all(color: PdfColors.grey700, width: .6),
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_closing.text), pw.SizedBox(height: 8),
            pw.Text(AuthStore.instance.current?.name ?? 'Chief Executive Officer',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Chief Executive Officer'),
          ]),
        ],
      ));
      return pdf.save();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview() async {
    final bytes = await _bytes(); if (bytes == null) return;
    archivePdfInBackground(bytes: bytes, filename: _filename(),
      description: 'Official letter · ${_subject.text.trim()} · ${_recipient.text.trim()}');
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _share() async {
    final bytes = await _bytes(); if (bytes == null) return;
    final out = await dispatchPdf(bytes: bytes, filename: _filename());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(out.message)));
  }

  Future<void> _download() async {
    final bytes = await _bytes(); if (bytes == null) return;
    final out = await savePdf(bytes: bytes, filename: _filename());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(out.message)));
  }

  Future<void> _clear() async {
    for (final c in [_recipient, _address, _subject, _body]) { c.clear(); }
    _closing.text = 'Yours faithfully,'; _footerText.clear();
    _images.clear(); _undo.clear(); _redo.clear();
    for (final row in _table) { for (final cell in row) { cell.dispose(); } }
    _table.clear();
    if (mounted) setState(() {});
    await localWrite(_draftKey, '');
  }

  String _filename() => 'mtek_official_letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
  static String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
