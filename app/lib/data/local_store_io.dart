import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// IO implementation (Android/Windows/desktop): JSON file in the app
/// documents directory. Storage exceptions are guarded — an unreadable
/// cache behaves like a cold start (blueprint Part 3).
Future<String?> localRead(String key) async {
  try {
    final file = await _fileFor(key);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}

Future<void> localWrite(String key, String value) async {
  try {
    final file = await _fileFor(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(value, flush: true);
  } catch (_) {
    // storage full/permission denied — surface as toast via caller logs
  }
}

Future<File> _fileFor(String key) async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}${Platform.pathSeparator}mtek_$key.json');
}

String jsonEnc(Object? o) => json.encode(o);
