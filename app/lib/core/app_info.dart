/// Compile-time app metadata for the Settings → About card.
///
/// Kept dependency-free on purpose: the version is baked in at build time
/// via `--dart-define=APP_VERSION=…` exactly like [Env], so the About screen
/// never has to query a platform plugin (package_info_plus) at runtime. BOTH
/// build scripts now pass that define (it used to be Android-only, so Windows
/// reported the stale 0.1.0+1 fallback). If it is not supplied the fallback
/// tracks `pubspec.yaml`.
import 'app_update_info.dart';

abstract final class AppInfo {
  /// Product name shown to users.
  static const appName = 'MFSL Office';

  /// Publisher / vendor line (matches the Windows/MSIX publisher identity).
  static const publisher = 'N.O Group';

  /// Release version, overridable at build time.
  static const version =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.4.0+7');

  /// Logical build (`+N`) used by the in-app update checker. Must stay in
  /// sync with `app_build` in data-api/index.ts; ci/build-android.sh fails
  /// the build when the two version strings drift.
  static int get buildNumber => AppUpdateInfo.parseBuild(version);

  /// One-line "AppName · vX.Y.Z" label for the About card.
  static const String aboutLine = '$appName · v$version';
}
