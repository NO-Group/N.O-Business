import 'package:flutter_test/flutter_test.dart';
import 'package:mtek_inventory/core/app_update_info.dart';

void main() {
  group('AppUpdateInfo.parseBuild', () {
    test('reads the logical build after the plus', () {
      expect(AppUpdateInfo.parseBuild('0.4.0+7'), 7);
      expect(AppUpdateInfo.parseBuild('1.12.3+42'), 42);
    });
    test('is safe on malformed versions', () {
      expect(AppUpdateInfo.parseBuild('0.4.0'), 0);
      expect(AppUpdateInfo.parseBuild('0.4.0+abc'), 0);
      expect(AppUpdateInfo.parseBuild(''), 0);
    });
  });

  group('AppUpdateInfo.fromHealth', () {
    const health = <String, dynamic>{
      'ok': true,
      'version': '2026-09-19-office-suite1',
      'storage': 'supabase-postgres',
      'app_version': '0.4.0+7',
      'app_build': 7,
      'app_release_url': 'https://example.test/releases/tag/ci',
      'app_apk_url': 'https://example.test/MFSL.Inventory.apk',
      'app_windows_url': 'https://example.test/MFSL.Inventory.Setup.msix',
    };

    test('parses a real health payload', () {
      final info = AppUpdateInfo.fromHealth(health);
      expect(info, isNotNull);
      expect(info!.version, '0.4.0+7');
      expect(info.build, 7);
      expect(info.apkUrl, contains('MFSL.Inventory.apk'));
    });

    test('accepts a string build number', () {
      final info = AppUpdateInfo.fromHealth(
          <String, dynamic>{...health, 'app_build': '8'});
      expect(info?.build, 8);
    });

    test('rejects junk without throwing', () {
      expect(AppUpdateInfo.fromHealth(null), isNull);
      expect(AppUpdateInfo.fromHealth('not a map'), isNull);
      expect(AppUpdateInfo.fromHealth(<String, dynamic>{'ok': false}), isNull);
      expect(AppUpdateInfo.fromHealth(<String, dynamic>{'ok': true}), isNull);
      expect(AppUpdateInfo.fromHealth(
          <String, dynamic>{...health, 'app_build': 0}), isNull);
    });

    test('compares build numbers and picks a platform URL', () {
      final info = AppUpdateInfo.fromHealth(health)!;
      expect(info.isNewerThan(6), isTrue);
      expect(info.isNewerThan(7), isFalse);
      expect(info.isNewerThan(8), isFalse);
      expect(info.urlFor(windows: false), contains('.apk'));
      expect(info.urlFor(windows: true), contains('.msix'));
    });

    test('falls back to the release page when a direct link is missing', () {
      final info = AppUpdateInfo.fromHealth(<String, dynamic>{
        ...health,
        'app_apk_url': '',
        'app_windows_url': '',
      })!;
      expect(info.urlFor(windows: false), contains('/releases/tag/ci'));
      expect(info.urlFor(windows: true), contains('/releases/tag/ci'));
    });
  });
}
