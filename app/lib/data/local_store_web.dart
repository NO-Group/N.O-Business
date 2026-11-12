// Web/PWA implementation: browser localStorage (synchronous).
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;

Future<String?> localRead(String key) async {
  try {
    return html.window.localStorage['mtek_$key'];
  } catch (_) {
    return null;
  }
}

Future<void> localWrite(String key, String value) async {
  try {
    html.window.localStorage['mtek_$key'] = value;
  } catch (_) {
    // storage full/blocked — cache is best-effort on web
  }
}

String jsonEnc(Object? o) => json.encode(o);
