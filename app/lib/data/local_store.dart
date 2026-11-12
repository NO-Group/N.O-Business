import 'local_store_io.dart' if (dart.library.html) 'local_store_web.dart' as impl;

/// Local persistence for the app cache + offline queue.
/// Implementation is conditional: dart:io file (Android/Windows) or
/// localStorage (web/PWA). Values are JSON strings keyed by [key].
Future<String?> localRead(String key) => impl.localRead(key);
Future<void> localWrite(String key, String value) => impl.localWrite(key, value);
