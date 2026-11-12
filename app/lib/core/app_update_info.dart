/// Latest app release advertised by the public `GET /health` response.
///
/// Dependency-free on purpose so the version comparison can be unit tested
/// without a network client or a platform plugin. The repo is PRIVATE, so the
/// app cannot query the GitHub Releases API anonymously; the Edge Function
/// publishes the marker instead (see APP_INFO in data-api/index.ts).
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.build,
    required this.releaseUrl,
    required this.apkUrl,
    required this.windowsUrl,
  });

  final String version;
  final int build;
  final String releaseUrl;
  final String apkUrl;
  final String windowsUrl;

  /// Logical build number = the `+N` part of `X.Y.Z+N`.
  /// Returns 0 for anything unparseable (never throws).
  static int parseBuild(String version) {
    final plus = version.indexOf('+');
    if (plus < 0) return 0;
    return int.tryParse(version.substring(plus + 1).trim()) ?? 0;
  }

  /// Parse a decoded /health JSON body. Returns null on malformed or
  /// incomplete payloads — an update check must never break a signed-in app.
  static AppUpdateInfo? fromHealth(Object? body) {
    if (body is! Map) return null;
    if (body['ok'] != true) return null;
    final version = '${body['app_version'] ?? ''}'.trim();
    final rawBuild = body['app_build'];
    final build = rawBuild is int
        ? rawBuild
        : int.tryParse('${rawBuild ?? ''}') ?? 0;
    if (version.isEmpty || build <= 0) return null;
    return AppUpdateInfo(
      version: version,
      build: build,
      releaseUrl: '${body['app_release_url'] ?? ''}',
      apkUrl: '${body['app_apk_url'] ?? ''}',
      windowsUrl: '${body['app_windows_url'] ?? ''}',
    );
  }

  bool isNewerThan(int currentBuild) => build > currentBuild;

  /// Best download target for the current platform, falling back to the
  /// human-readable release page when a direct link is missing.
  String urlFor({required bool windows}) {
    final preferred = windows ? windowsUrl : apkUrl;
    return preferred.isNotEmpty ? preferred : releaseUrl;
  }
}
