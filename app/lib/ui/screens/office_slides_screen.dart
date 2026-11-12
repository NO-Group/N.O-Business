import 'dart:async';
import 'dart:convert';

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

class _Slide {
  final title=TextEditingController(),body=TextEditingController(),notes=TextEditingController();
  String image='';
  _Slide({String title='',String body='',String notes='',this.image=''}){this.title.text=title;this.body.text=body;this.notes.text=notes;}
  factory _Slide.fromJson(Map x)=>_Slide(title:'${x['title']??''}',body:'${x['body']??''}',notes:'${x['notes']??''}',image:'${x['image']??''}');
  Map<String,dynamic> toJson()=>{'title':title.text,'body':body.text,'notes':notes.text,'image':image};
  void dispose(){title.dispose();body.dispose();notes.dispose();}
}

class OfficeSlidesScreen extends StatefulWidget { const OfficeSlidesScreen({super.key}); @override State<OfficeSlidesScreen> createState()=>_OfficeSlidesScreenState(); }
class _OfficeSlidesScreenState extends State<OfficeSlidesScreen>{
  final title=TextEditingController(), search=TextEditingController(); final slides=<_Slide>[]; List<Map<String,dynamic>> files=[];
  String? id; int revision=0,selected=0; bool loading=true,saving=false; Timer? timer;
  @override void initState(){super.initState();_load();}
  @override void dispose(){timer?.cancel();title.dispose();search.dispose();for(final s in slides)s.dispose();super.dispose();}
  Future<void> _load()async{if(mounted)setState(()=>loading=true);final r=await AppStore.instance.api?.get('/api/office-files?kind=slide');if(r!=null&&r.ok&&r.json is Map)files=[for(final x in ((r.json as Map)['files'] as List? ?? const[]))if(x is Map)x.cast<String,dynamic>()];if(mounted)setState(()=>loading=false);}
  void _reset(){for(final s in slides)s.dispose();slides.clear();}
  void _new(String template){_reset();id='slide-${DateTime.now().microsecondsSinceEpoch}';revision=0;selected=0;title.text=template=='pitch'?'Company Presentation':'Untitled presentation';if(template=='pitch'){slides.addAll([_Slide(title:'M-Tek Fire & Safety Ltd',body:'Professional fire protection solutions'),_Slide(title:'Our Services',body:'• Fire extinguisher supply\n• Inspection and maintenance\n• Safety training\n• Fire risk assessment'),_Slide(title:'Why M-Tek',body:'Reliable service\nQualified personnel\nQuality equipment\nResponsive support'),_Slide(title:'Contact Us',body:'mtekfiresafetyltd@gmail.com\n+2348033498452')]);}else slides.add(_Slide(title:'Presentation title',body:'Subtitle'));setState((){});}
  void _open(Map<String,dynamic> f){_reset();id='${f['id']}';revision=(f['revision'] as num? ?? 1).toInt();selected=0;title.text='${f['title']??'Untitled presentation'}';for(final x in ((f['content'] as Map?)?['slides'] as List? ?? const[]))if(x is Map)slides.add(_Slide.fromJson(x));if(slides.isEmpty)slides.add(_Slide());setState((){});}
  void _changed([String? _]){timer?.cancel();timer=Timer(const Duration(milliseconds:1000),()=>_save(silent:true));setState((){});}
  Future<bool> _save({bool silent=false})async{if(id==null||saving)return false;setState(()=>saving=true);final r=await AppStore.instance.api?.post('/api/office-files/save',{'id':id,'kind':'slide','title':title.text.trim(),'content':{'slides':[for(final s in slides)s.toJson()]},'base_revision':revision});final ok=r!=null&&r.ok;if(ok&&r.json is Map)revision=((r.json as Map)['revision']as num? ?? revision).toInt();if(mounted){setState(()=>saving=false);if(!silent||!ok)ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor:ok?Mtek.success:Mtek.danger,content:Text(ok?'Presentation saved.':'Presentation could not be saved.')));}if(ok)unawaited(_load());return ok;}
  Future<void> _image()async{final r=await FilePicker.platform.pickFiles(type:FileType.image,withData:true);final f=r?.files.single;if(f?.bytes==null)return;final ext=(f!.extension??'jpg').toLowerCase();slides[selected].image='data:image/${ext=='png'?'png':'jpeg'};base64,${base64Encode(f.bytes!)}';_changed();}
  Future<void> _pdf({bool share = false}) async {
    if (!await _save()) return;
    await MtekPdfFonts.load();
    final logo = pw.MemoryImage((await rootBundle.load('assets/branding/logo.png')).buffer.asUint8List());
    final pdf = pw.Document();
    for (var i = 0; i < slides.length; i++) {
      final slide = slides[i];
      final widgets = <pw.Widget>[
        pw.Row(children: [pw.Image(logo, width: 72), pw.Spacer(),
          pw.Text('${i + 1} / ${slides.length}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))]),
        pw.Spacer(),
        pw.Text(slide.title.text, style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
        pw.SizedBox(height: 18),
        pw.Text(slide.body.text, style: const pw.TextStyle(fontSize: 17, lineSpacing: 5)),
      ];
      if (slide.image.isNotEmpty) {
        try {
          widgets.addAll([pw.SizedBox(height: 16), pw.Center(child: pw.Image(
            pw.MemoryImage(base64Decode(slide.image.split(',').last)), height: 180, fit: pw.BoxFit.contain))]);
        } catch (_) { /* skip an invalid image */ }
      }
      widgets.addAll([pw.Spacer(), pw.Text('M-TEK FIRE & SAFETY LTD',
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700))]);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(34),
        theme: pw.ThemeData.withFont(base: MtekPdfFonts.base, bold: MtekPdfFonts.bold),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blueGrey800, width: 2)),
          padding: const pw.EdgeInsets.all(24), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: widgets)),
      ));
    }
    final bytes = await pdf.save();
    final filename = '${title.text.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')}.pdf';
    final out = share ? await dispatchPdf(bytes: bytes, filename: filename)
      : await savePdf(bytes: bytes, filename: filename);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(out.message)));
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final response = await AppStore.instance.api?.post('/api/office-files/delete', {'id': '${file['id']}'});
    if (response != null && response.ok) await _load();
  }

  @override Widget build(BuildContext context)=>id==null?_library():_editor();
  Widget _library() {
    final query = search.text.trim().toLowerCase();
    final shown = query.isEmpty ? files : files.where((f) => '${f['title'] ?? ''}'.toLowerCase().contains(query)).toList();
    return Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      PageHeader(title: 'Office Slides', subtitle: 'Create branded cloud presentations and export to PDF', icon: Icons.slideshow_outlined, actions: [
        PopupMenuButton<String>(tooltip: 'New presentation', onSelected: _new, icon: const Icon(Icons.add), itemBuilder: (_) => const [
          PopupMenuItem(value: 'blank', child: Text('Blank presentation')), PopupMenuItem(value: 'pitch', child: Text('Company profile template'))]),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      const SizedBox(height: 10),
      TextField(controller: search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search presentations')),
      const SizedBox(height: 12),
      Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : shown.isEmpty ? const EmptyHint('No matching presentations') : Card(child: ListView.separated(
        itemCount: shown.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) { final file = shown[i]; return ListTile(
          leading: const Icon(Icons.slideshow), title: Text('${file['title']}'), subtitle: Text('Revision ${file['revision']} · ${file['updated_at']}'),
          onTap: () => _open(file), trailing: IconButton(tooltip: 'Delete', onPressed: () => _delete(file), icon: const Icon(Icons.delete_outline)));
        }))),
    ]));
  }

  Widget _editor() {
    final slide = slides[selected];
    return Column(children: [
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
            TextButton.icon(onPressed: () { slides.add(_Slide(title: 'New slide')); selected = slides.length - 1; _changed(); }, icon: const Icon(Icons.add), label: const Text('Slide')),
            TextButton.icon(onPressed: _image, icon: const Icon(Icons.image_outlined), label: const Text('Image')),
            TextButton.icon(onPressed: _save, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Save')),
            TextButton.icon(onPressed: () => _pdf(), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('PDF')),
            TextButton.icon(onPressed: () => _pdf(share: true), icon: const Icon(Icons.share_outlined), label: const Text('Share')),
            IconButton(tooltip: 'Move up', onPressed: selected == 0 ? null : () { final x = slides.removeAt(selected); slides.insert(--selected, x); _changed(); }, icon: const Icon(Icons.arrow_upward)),
            IconButton(tooltip: 'Move down', onPressed: selected == slides.length - 1 ? null : () { final x = slides.removeAt(selected); slides.insert(++selected, x); _changed(); }, icon: const Icon(Icons.arrow_downward)),
            IconButton(tooltip: 'Delete slide', onPressed: slides.length == 1 ? null : () { slides.removeAt(selected).dispose(); if (selected >= slides.length) selected = slides.length - 1; _changed(); }, icon: const Icon(Icons.delete_outline)),
          ])),
        ]),
      )),
      Expanded(child: LayoutBuilder(builder: (context, constraints) {
        final thumbnails = ListView.builder(
          scrollDirection: constraints.maxWidth < 700 ? Axis.horizontal : Axis.vertical,
          itemCount: slides.length,
          itemBuilder: (_, i) => SizedBox(
            width: constraints.maxWidth < 700 ? 160 : null,
            child: Card(
              color: i == selected ? Theme.of(context).colorScheme.secondaryContainer : null,
              child: ListTile(title: Text('${i + 1}. ${slides[i].title.text}', maxLines: 2),
                onTap: () => setState(() => selected = i))),
          ),
        );
        if (constraints.maxWidth < 700) {
          return Column(children: [SizedBox(height: 88, child: thumbnails),
            const Divider(height: 1), Expanded(child: _canvas(slide))]);
        }
        return Row(children: [SizedBox(width: 190, child: thumbnails),
          const VerticalDivider(width: 1), Expanded(child: _canvas(slide))]);
      })),
    ]);
  }

  Widget _canvas(_Slide slide) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: slide.title, onChanged: _changed,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: 'Slide title', border: InputBorder.none)),
              Expanded(child: TextField(
                controller: slide.body, onChanged: _changed, maxLines: null,
                decoration: const InputDecoration(hintText: 'Slide content', border: InputBorder.none))),
              if (slide.image.isNotEmpty)
                AppImage(source: slide.image, title: slide.title.text, width: 240, height: 140),
              TextField(
                controller: slide.notes, onChanged: _changed, maxLines: 2,
                decoration: const InputDecoration(labelText: 'Speaker notes (not shown in PDF)')),
            ]),
          ),
        ),
      ),
    )),
  );

}
