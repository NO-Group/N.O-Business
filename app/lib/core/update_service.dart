import '../data/api_client.dart';
import '../data/env.dart';
import 'app_update_info.dart';

/// Checks the public `GET /health` endpoint for a newer MFSL Office build.
///
/// Deliberately non-fatal: offline, timeout, malformed JSON and unexpected
/// HTTP statuses all return null. This must never sign a user out, block the
/// boot flow, or interrupt the 8-second data poll.
class AppUpdateService {
  AppUpdateService({ApiClient? client})
      : _client = client ?? ApiClient(baseUrl: Env.apiBase);

  final ApiClient _client;

  Future<AppUpdateInfo?> checkLatest() async {
    try {
      final res = await _client.get('/health');
      if (res == null || !res.ok) return null;
      return AppUpdateInfo.fromHealth(res.json);
    } catch (_) {
      return null;
    }
  }
}
