// Web HTTP implementation. Uses raw XMLHttpRequest events instead of the
// convenience request() Future because that helper throws for HTTP 401/403
// and discards the status/body needed by the token-refresh layer.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Future<RestJsonResponse?> httpJson({
  required String method,
  required String url,
  required Map<String, String> headers,
  Object? body,
}) async {
  final request = html.HttpRequest();
  final completer = Completer<RestJsonResponse?>();
  Timer? timer;
  try {
    request.open(method, url, async: true);
    headers.forEach(request.setRequestHeader);
    request.onLoadEnd.first.then((_) {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(RestJsonResponse(
          status: request.status,
          text: request.responseText ?? '',
        ));
      }
    });
    request.onError.first.then((_) {
      timer?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    });
    timer = Timer(const Duration(seconds: 20), () {
      request.abort();
      if (!completer.isCompleted) completer.complete(null);
    });
    request.send(body == null ? null : jsonEncode(body));
    return await completer.future;
  } catch (_) {
    timer?.cancel();
    return null;
  }
}

Future<bool> httpRequest({
  required String method,
  required String url,
  required Map<String, String> headers,
  required List<Map<String, dynamic>> body,
}) async {
  final res = await httpJson(method: method, url: url, headers: headers, body: body);
  return res != null && res.ok;
}

class RestJsonResponse {
  final int status;
  final String text;
  const RestJsonResponse({required this.status, required this.text});
  bool get ok => status >= 200 && status < 300;
  dynamic get json {
    try {
      final clean = text.startsWith('\uFEFF') ? text.substring(1) : text;
      return clean.trim().isEmpty ? null : jsonDecode(clean);
    } catch (_) {
      return null;
    }
  }
}
