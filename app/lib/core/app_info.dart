/// Compile-time app metadata for the Settings → About card.
///
/// Kept dependency-free on purpose: the version is baked in at build time
/// via `--dart-define=APP_VERSION=…` exactly like [Env], so the About screen
/// never has to query a platform plugin (package_info_plus) at runtime. If
/// `APP_VERSION` is not supplied the fallback tracks `pubspec.yaml`.
abstract final class AppInfo {
  /// Product name shown to users.
  static const appName = 'MFSL Office';

  /// Publisher / vendor line (matches the Windows/MSIX publisher identity).
  static const publisher = 'N.O Group';

  /// Release version, overridable at build time.
  static const version =
      String.fromEnvironment('APP_VERSION', defaultValue: '0.1.0+1');

  /// One-line "AppName · vX.Y.Z" label for the About card.
  static const String aboutLine = '$appName · v$version';
}
