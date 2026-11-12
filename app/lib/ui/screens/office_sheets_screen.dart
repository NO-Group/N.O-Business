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

class OfficeSheetsScreen extends StatefulWidget {
  const OfficeSheetsScreen({super.key});
  @override State<OfficeSheetsScreen> createState() => _OfficeSheetsScreenState();
}

class _OfficeSheetsScreenState extends State<OfficeSheetsScreen> {
  static const rows = 20, cols = 8;
  final title = TextEditingController();
  final search = TextEditingController();
  final cells = List.generate(rows, (_) => List.generate(cols, (_) => TextEditingController()));
  List<Map<String, dynamic>> files = [];
  String? id;
  int revision = 0;
  bool loading = true, saving = false;
  Timer? timer;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { timer?.cancel(); title.dispose(); search.dispose(); for (final r in cells) { for (final c in r) { c.dispose(); } } super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final res = await AppStore.instance.api?.get('/api/office-files?kind=sheet');
    if (res != null && res.ok && res.json is Map) {
      files = [for (final x in ((res.json as Map)['files'] as List? ?? const [])) if (x is Map) x.cast<String, dynamic>()];
    }
    if (mounted) setState(() => loading = false);
  }

  void _clear() { for (final r in cells) { for (final c in r) { c.clear(); } } }
  void _new({String template = 'blank'}) {
    _clear(); id = 'sheet-${DateTime.now().microsecondsSinceEpoch}'; revision = 0;
    title.text = template == 'stock' ? 'Stock Count Sheet' : template == 'expenses' ? 'Expense Tracker' : 'Untitled sheet';
    if (template == 'stock') {
      const h = ['Product', 'Opening', 'Received', 'Issued', 'Balance', 'Unit Price', 'Value'];
      for (var i=0;i<h.length;i++) cells[0][i].text=h[i];
      for (var r=1;r<rows;r++) { cells[r][4].text='=B${r+1}+C${r+1}-D${r+1}'; cells[r][6].text='=E${r+1}*F${r+1}'; }
    } else if (template == 'expenses') {
      const h = ['Date', 'Description', 'Category', 'Method', 'Amount'];
      for (var i=0;i<h.length;i++) cells[0][i].text=h[i];
    }
    setState(() {});
  }

  void _open(Map<String,dynamic> f) {
    _clear(); id='${f['id']}'; revision=(f['revision'] as num? ?? 1).toInt(); title.text='${f['title'] ?? 'Untitled sheet'}';
    final data=(f['content'] as Map?)?['cells'] as List? ?? const [];
    for(var r=0;r<data.length && r<rows;r++) if(data[r] is List) for(var c=0;c<(data[r] as List).length && c<cols;c++) cells[r][c].text='${data[r][c]}';
    setState(() {});
  }

  void _changed([String? _]) { timer?.cancel(); timer=Timer(const Duration(milliseconds: 1000),()=>_save(silent:true)); setState(() {}); }
  List<List<String>> get _data => [for(final r in cells)[for(final c in r)c.text]];

  Future<bool> _save({bool silent=false}) async {
    if(id==null || saving) return false; setState(()=>saving=true);
    final res=await AppStore.instance.api?.post('/api/office-files/save', {'id':id,'kind':'sheet','title':title.text.trim(),'content':{'cells':_data},'base_revision':revision});
    final ok=res!=null&&res.ok; if(ok&&res.json is Map) revision=((res.json as Map)['revision'] as num? ?? revision).toInt();
    if(mounted){setState(()=>saving=false);if(!silent||!ok)ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor:ok?Mtek.success:Mtek.danger,content:Text(ok?'Spreadsheet saved.':'Spreadsheet could not be saved.')));}
    if(ok)unawaited(_load()); return ok;
  }

  String _name(int c)=>String.fromCharCode(65+c);
  double _number(String ref, Set<String> stack) {
    final match = RegExp(r'^([A-H])(\d+)$').firstMatch(ref.toUpperCase());
    if (match == null) return 0;
    final column = match.group(1)!.codeUnitAt(0) - 65;
    final row = int.parse(match.group(2)!) - 1;
    if (row < 0 || row >= rows) return 0;
    return double.tryParse(_value(row, column, stack)) ?? 0;
  }

  String _value(int row, int column, [Set<String>? ancestors]) {
    final raw = cells[row][column].text.trim();
    if (!raw.startsWith('=')) return raw;
    final key = '${_name(column)}${row + 1}';
    final stack = {...?ancestors};
    if (!stack.add(key)) return '#CYCLE';
    final sum = RegExp(r'^=SUM\(([A-H]\d+):([A-H]\d+)\)$', caseSensitive: false).firstMatch(raw);
    if (sum != null) {
      final first = RegExp(r'([A-H])(\d+)').firstMatch(sum.group(1)!)!;
      final last = RegExp(r'([A-H])(\d+)').firstMatch(sum.group(2)!)!;
      double value = 0;
      for (var r = int.parse(first.group(2)!); r <= int.parse(last.group(2)!); r++) {
        for (var c = first.group(1)!.codeUnitAt(0); c <= last.group(1)!.codeUnitAt(0); c++) {
          final calculated = _value(r - 1, c - 65, stack);
          if (calculated == '#CYCLE') return calculated;
          value += double.tryParse(calculated) ?? 0;
        }
      }
      return _fmt(value);
    }
    final operation = RegExp(r'^=([A-H]\d+)\s*([+\-*/])\s*([A-H]\d+)$', caseSensitive: false).firstMatch(raw);
    if (operation == null) return '#FORMULA';
    final leftText = _value(int.parse(RegExp(r'\d+').firstMatch(operation.group(1)!)!.group(0)!) - 1,
      operation.group(1)!.toUpperCase().codeUnitAt(0) - 65, stack);
    final rightText = _value(int.parse(RegExp(r'\d+').firstMatch(operation.group(3)!)!.group(0)!) - 1,
      operation.group(3)!.toUpperCase().codeUnitAt(0) - 65, stack);
    if (leftText == '#CYCLE' || rightText == '#CYCLE') return '#CYCLE';
    final left = double.tryParse(leftText) ?? 0;
    final right = double.tryParse(rightText) ?? 0;
    final value = switch (operation.group(2)) {
      '+' => left + right, '-' => left - right, '*' => left * right,
      '/' => right == 0 ? double.nan : left / right, _ => 0.0,
    };
    return value.isNaN ? '#DIV/0' : _fmt(value);
  }

  String _fmt(double n)=>n==n.roundToDouble()?n.toInt().toString():n.toStringAsFixed(2);

  Future<void> _csv() async {
    final lines = <String>[];
    for (var r = 0; r < rows; r++) {
      final values = <String>[];
      for (var c = 0; c < cols; c++) {
        final value = _value(r, c).replaceAll('"', '""');
        values.add('"$value"');
      }
      lines.add(values.join(','));
    }
    final bytes = Uint8List.fromList(utf8.encode(lines.join('\n')));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save spreadsheet CSV',
      fileName: '${title.text.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')}.csv',
      type: FileType.custom, allowedExtensions: const ['csv'], bytes: bytes,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path == null ? 'Export cancelled.' : 'CSV saved.')));
  }

  Future<void> _pdf({bool share = false}) async { await MtekPdfFonts.load(); final logo=pw.MemoryImage((await rootBundle.load('assets/branding/logo.png')).buffer.asUint8List()); final pdf=pw.Document(); pdf.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4.landscape,margin:const pw.EdgeInsets.all(24),theme:pw.ThemeData.withFont(base:MtekPdfFonts.base,bold:MtekPdfFonts.bold),build:(_)=>[corporateHeader(logo),pw.SizedBox(height:12),pw.Text(title.text,style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:10),pw.TableHelper.fromTextArray(data:[for(var r=0;r<rows;r)[for(var c=0;c<cols;c)_value(r,c)]],headerCount:1,cellStyle:const pw.TextStyle(fontSize:7),headerStyle:pw.TextStyle(fontSize:7,fontWeight:pw.FontWeight.bold))])); final bytes=await pdf.save(); final filename='${title.text.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'),'-')}.pdf'; final out=share?await dispatchPdf(bytes:bytes,filename:filename):await savePdf(bytes:bytes,filename:filename); if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(out.message))); }

  Future<void> _delete(Map<String, dynamic> file) async {
    final response = await AppStore.instance.api?.post('/api/office-files/delete', {'id': '${file['id']}'});
    if (response != null && response.ok) await _load();
  }

  @override Widget build(BuildContext context)=>id==null?_library():_editor();
  Widget _library() {
    final query = search.text.trim().toLowerCase();
    final shown = query.isEmpty ? files : files.where((f) => '${f['title'] ?? ''}'.toLowerCase().contains(query)).toList();
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      PageHeader(title: 'Office Sheets', subtitle: 'Cloud spreadsheets with formulas, templates and export', icon: Icons.grid_on_outlined, actions: [
        PopupMenuButton<String>(tooltip: 'New spreadsheet', onSelected: (v) => _new(template: v), icon: const Icon(Icons.add), itemBuilder: (_) => const [
          PopupMenuItem(value: 'blank', child: Text('Blank sheet')), PopupMenuItem(value: 'stock', child: Text('Stock count template')),
          PopupMenuItem(value: 'expenses', child: Text('Expense tracker template'))]),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 10),
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search spreadsheets')),
      const SizedBox(height: 12),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : shown.isEmpty ? const EmptyHint('No matching spreadsheets') : Card(child: ListView.separated(
        itemCount: shown.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final file = shown[i]; return ListTile(
          leading: const Icon(Icons.table_chart_outlined), title: Text('${file['title']}'),
          subtitle: Text('Revision ${file['revision']} · ${file['updated_at']}'), onTap: () => _open(file),
          trailing: IconButton(tooltip: 'Delete', onPressed: () => _delete(file), icon: const Icon(Icons.delete_outline)));
        }))),
    ]));
  }

  Widget _editor() => Column(children: [
    Material(color: Theme.of(context).colorScheme.surfaceContainer, child: Padding(
      padding: const EdgeInsets.all(8), child: Column(children: [
        Row(children: [
          IconButton(onPressed: () { timer?.cancel(); _save(silent: true); setState(() => id = null); }, icon: const Icon(Icons.arrow_back)),
          Expanded(child: TextField(controller: title, onChanged: _changed,
            decoration: const InputDecoration(border: InputBorder.none),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          if (saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          Text(' Rev $revision'),
        ]),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          TextButton.icon(onPressed: _save, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Save')),
          TextButton.icon(onPressed: _csv, icon: const Icon(Icons.download_outlined), label: const Text('CSV')),
          TextButton.icon(onPressed: _pdf, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
          const SizedBox(width: 12), const Text('Formulas: =A2+B2, =A2*B2, =SUM(A2:A10)'),
        ])),
      ]),
    )),
    Expanded(child: SingleChildScrollView(child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(135),
        border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant),
        children: [
          TableRow(children: [
            const SizedBox(width: 42),
            for (var c = 0; c < cols; c++) Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(8),
              child: Center(child: Text(_name(c), style: const TextStyle(fontWeight: FontWeight.bold)))),
          ]),
          for (var r = 0; r < rows; r++) TableRow(children: [
            Container(width: 42, color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.all(8), child: Center(child: Text('${r + 1}'))),
            for (var c = 0; c < cols; c++) TextField(
              controller: cells[r][c], onChanged: _changed,
              decoration: InputDecoration(border: InputBorder.none, isDense: true,
                helperText: cells[r][c].text.startsWith('=') ? _value(r, c) : null)),
          ]),
        ],
      ),
    ))),
  ]);

}
