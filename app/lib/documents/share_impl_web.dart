import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'share_service.dart';

/// Web/PWA implementation: share_plus cannot attach files to WhatsApp on
/// the web, so the fallback becomes the primary — trigger a browser
/// download of the PDF (goes to Downloads), user attaches it in the app
/// they choose. NO pre-filled text is ever generated (owner directive).
Future<ShareOutcome> dispatchPdfImpl({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
    return const ShareOutcome(ShareResult.savedOnly,
        'PDF downloaded — attach it in WhatsApp, Gmail or your chosen app.');
  } catch (e) {
    // Full detail goes to the console only — never onto a production screen.
    debugPrint('dispatchPdf (web) failed: $e');
    return const ShareOutcome(ShareResult.failed,
        'Could not download the PDF — please try again.');
  }
}

/// Web: an explicit "Download" is the same as the share fallback — trigger a
/// browser download of the PDF straight to the user's Downloads folder.
Future<ShareOutcome> savePdfImpl({
  required Uint8List bytes,
  required String filename,
}) =>
    dispatchPdfImpl(bytes: bytes, filename: filename);
