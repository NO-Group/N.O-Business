import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';

/// Drawn-signature pad (finger/mouse). Exported as PNG bytes so it can be
/// stamped onto receipts/invoices and (M3) uploaded to Supabase Storage.
class SignaturePad extends StatefulWidget {
  final ValueChanged<Uint8List?> onDone;
  const SignaturePad({super.key, required this.onDone});

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final _boundaryKey = GlobalKey();
  final List<List<Offset?>> _strokes = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: GestureDetector(
                onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
                onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
                onPanEnd: (_) => setState(() => _strokes.last.add(null)),
                child: CustomPaint(
                  painter: _SignaturePainter(_strokes),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _strokes.clear()),
              child: const Text('Clear'),
            ),
            const Spacer(),
            FilledButton.tonal(
              onPressed: _strokes.isEmpty ? null : _export,
              child: const Text('Use this signature'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _export() async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      // RepaintBoundary wraps the CustomPaint above via the key on a parent.
      final image = await boundary?.toImage(pixelRatio: 2);
      final bytes = await image?.toByteData(format: ui.ImageByteFormat.png);
      widget.onDone(bytes?.buffer.asUint8List());
    } catch (_) {
      widget.onDone(null);
    }
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0B1220)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      final path = Path();
      Offset? last;
      for (final p in stroke) {
        if (p == null) { last = null; continue; }
        if (last == null) { path.moveTo(p.dx, p.dy); } else { path.lineTo(p.dx, p.dy); }
        last = p;
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}

/// Convenience: base64 data-URL of drawn bytes.
String signatureDataUrl(Uint8List bytes) =>
    'data:image/png;base64,${base64Encode(bytes)}';
