import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../data/auth_store.dart';
import '../data/store.dart';

/// Export & dispatch pipeline (owner directive 2026-08-30):
///   PDF bytes → timestamped local cache file → native share sheet with the
///   PDF FILE ONLY (no pre-filled text — the OS picker offers WhatsApp, Gmail,
///   Drive, Bluetooth…). Fallback: save to device storage + toast.
///
/// Platform split via conditional imports:
///   io: path_provider + share_plus (Android/Windows/iOS/desktop)
///   web: browser download (fallback) — share_plus is limited on web.
import 'share_impl_io.dart' if (dart.library.html) 'share_impl_web.dart';
export 'share_impl_io.dart' if (dart.library.html) 'share_impl_web.dart';

enum ShareResult { shared, savedOnly, failed }

class ShareOutcome {
  final ShareResult result;
  final String message; // user-facing toast text
  const ShareOutcome(this.result, this.message);
}

/// Calls the platform implementation selected by the conditional export above.
Future<bool> archivePdfToCloud({required Uint8List bytes, required String filename,
    String description = ''}) async {
  final api = AppStore.instance.api;
  if (api == null || AuthStore.instance.accessToken == null) return false;
  try {
    final response = await api.post('/api/cloud-documents/upload', {
      'filename': filename, 'mime_type': 'application/pdf',
      'description': description, 'base64': base64Encode(bytes),
    });
    return response != null && response.ok;
  } catch (_) {
    return false;
  }
}

/// Starts cloud backup without delaying a print, download, share sheet, or
/// ready dialog. Network availability must never make a local PDF action look
/// unresponsive.
void archivePdfInBackground({required Uint8List bytes, required String filename,
    String description = ''}) {
  unawaited(() async {
    await archivePdfToCloud(bytes: bytes, filename: filename, description: description);
  }());
}

Future<ShareOutcome> dispatchPdf({
  required Uint8List bytes,
  required String filename,
}) async {
  final outcome = await dispatchPdfImpl(bytes: bytes, filename: filename);
  if (outcome.result != ShareResult.failed) {
    archivePdfInBackground(bytes: bytes, filename: filename);
  }
  return outcome;
}

/// Saves the PDF to a user-accessible location WITHOUT opening the share
/// sheet — the explicit "Download" action (owner request): Downloads folder
/// on desktop, the app's documents area on Android, a browser download on
/// web. Returns a user-safe outcome (never a raw filesystem path).
Future<ShareOutcome> savePdf({
  required Uint8List bytes,
  required String filename,
}) async {
  final outcome = await savePdfImpl(bytes: bytes, filename: filename);
  if (outcome.result != ShareResult.failed) {
    archivePdfInBackground(bytes: bytes, filename: filename);
  }
  return outcome;
}
