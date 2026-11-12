import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../design_system/components/feedback.dart';
import 'commercial_pdf.dart';

/// Builds the PDF for [data] and opens the system print dialog (which also
/// offers "Save as PDF" on Android and Windows).
Future<void> printCommercialPdf(BuildContext context, CommercialPdfData data) async {
  try {
    final fonts = await PdfFonts.load();
    final bytes = await buildCommercialPdf(data, fonts: fonts);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: data.fileName);
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

/// Builds the PDF for [data] and hands the file to the system share sheet
/// (Android) or a save dialog (Windows).
Future<void> shareCommercialPdf(BuildContext context, CommercialPdfData data) async {
  try {
    final fonts = await PdfFonts.load();
    final bytes = await buildCommercialPdf(data, fonts: fonts);
    await Printing.sharePdf(bytes: bytes, filename: data.fileName);
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

/// "Print" and "Share" buttons for a document.
class PdfActions extends StatelessWidget {
  const PdfActions({super.key, required this.data});

  /// Called when the user asks for the PDF, so it reflects current data.
  final CommercialPdfData Function() data;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: () => printCommercialPdf(context, data()),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: const Text('Print'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => shareCommercialPdf(context, data()),
          icon: const Icon(Icons.ios_share_rounded, size: 18),
          label: const Text('Share PDF'),
        ),
      ],
    );
  }
}
