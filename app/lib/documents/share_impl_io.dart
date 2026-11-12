import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' hide ShareResult;

import 'share_service.dart';

/// IO implementation: cache the PDF with a timestamped name, then open the
/// system share sheet with the PDF FILE ONLY — never pre-filled text
/// (owner directive: the document speaks for itself; WhatsApp/Gmail/Drive
/// targets are picked by the user in the OS sheet). On failure, keep the
/// file and report savedOnly so the UI can toast its location.
Future<ShareOutcome> dispatchPdfImpl({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    try {
      final xfile = XFile(file.path, mimeType: 'application/pdf');
      await Share.shareXFiles([xfile], subject: filename);
      return const ShareOutcome(ShareResult.shared,
          'PDF attached — pick WhatsApp, Gmail or any app in the share sheet.');
    } catch (shareErr) {
      // Fallback: keep the file on the device. Never surface an internal
      // filesystem path on screen.
      return const ShareOutcome(ShareResult.savedOnly,
          'Share sheet unavailable — the PDF was saved on this device.');
    }
  } catch (e) {
    // Full detail goes to the console only — never onto a production screen.
    debugPrint('dispatchPdf (io) failed: $e');
    return const ShareOutcome(ShareResult.failed,
        'Could not save the PDF — please try again.');
  }
}

/// Explicit Download uses the platform Save As / Android document picker.
/// The previous Android fallback wrote into the private app sandbox and then
/// falsely reported a download that users could not find.
Future<ShareOutcome> savePdfImpl({
  required Uint8List bytes,
  required String filename,
}) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save MFSL PDF',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    if (path == null) {
      return const ShareOutcome(ShareResult.failed, 'Download cancelled.');
    }
    // Desktop returns a writable filesystem path. Android's Storage Access
    // Framework writes [bytes] itself and may return a content URI instead.
    if (!path.startsWith('content://')) {
      final file = File(path);
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      if (!await file.exists() || await file.length() == 0) {
        throw const FileSystemException('Saved PDF could not be verified');
      }
    }
    return ShareOutcome(ShareResult.savedOnly,
        'PDF saved successfully as $filename.');
  } catch (e) {
    debugPrint('savePdf (io) failed: $e');
    return const ShareOutcome(ShareResult.failed,
        'Could not save the PDF. Choose a folder and try again.');
  }
}
