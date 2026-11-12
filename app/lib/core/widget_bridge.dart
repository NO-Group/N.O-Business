import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges the Android home-screen widget + launcher shortcuts to Flutter.
///
/// Two channels (mirrored by `MainActivity.kt`):
///   - "mtek/launch" : the platform pushes a tapped screen ("openScreen");
///     we can also pull a screen requested while the app was cold-started.
///   - "mtek/widget" : we push the three headline figures shown on the
///     home widget so it displays live numbers without opening the app.
///
/// Everything here is defensive: on non-Android platforms (Windows/desktop)
/// the channels simply don't answer, so every call degrades to a no-op.
class WidgetBridge {
  WidgetBridge._();

  static const _launch = MethodChannel('mtek/launch');
  static const _widget = MethodChannel('mtek/widget');

  /// Destination id a widget/shortcut tap asked to open. [AppShell] listens
  /// to this and jumps to the matching screen once it is mounted.
  static final ValueNotifier<String?> requestedScreen =
      ValueNotifier<String?>(null);

  static Future<void> init() async {
    _launch.setMethodCallHandler((call) async {
      if (call.method == 'openScreen') {
        final screen = call.arguments as String?;
        if (screen != null && screen.isNotEmpty) {
          requestedScreen.value = screen;
        }
      }
    });

    // A shortcut tapped while the app was fully closed arrives via the
    // launch intent, not the channel — pull it once at startup.
    final pending = await _consumePendingScreen();
    if (pending != null && pending.isNotEmpty) {
      requestedScreen.value = pending;
    }
  }

  static Future<String?> _consumePendingScreen() async {
    try {
      return await _launch.invokeMethod<String>('consumePendingScreen');
    } catch (_) {
      return null; // not Android / channel unavailable
    }
  }

  /// Push the three headline figures onto the home widget.
  static Future<void> updateStats({
    required String todaySales,
    required String receipts,
    required String invoices,
  }) async {
    if (kIsWeb) return;
    try {
      await _widget.invokeMethod('updateStats', <String, String>{
        'todaySales': todaySales,
        'receipts': receipts,
        'invoices': invoices,
      });
    } catch (_) {
      // No widget on this platform / install — safe to ignore.
    }
  }
}
