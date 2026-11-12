import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'preferences_controller.dart';
import 'widget_bridge.dart';

/// Native Android/Windows notification bridge. In-app records remain the
/// durable source of truth; this service adds an OS-visible alert and never
/// lets a platform notification failure block a sale or stock operation.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  final Set<String> _shownKeys = <String>{};

  Future<void> initialize() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      final windows = WindowsInitializationSettings(
        appName: 'MFSL Office',
        appUserModelId: 'NOGroup.MFSL.Inventory',
        guid: 'c51c7c21-36f2-4a15-83fb-b74b643f49e7',
      );
      await _plugin.initialize(
        settings: InitializationSettings(
          android: android,
          windows: windows,
        ),
        onDidReceiveNotificationResponse: (_) {
          // All business alerts are durable in the Notifications workspace;
          // opening a native alert takes the user to its actionable record.
          WidgetBridge.requestedScreen.value = 'notifications';
        },
      );
      _ready = true;
    } catch (error) {
      debugPrint('Native notifications unavailable: $error');
    }
  }

  Future<bool> show({
    required String key,
    required String title,
    required String body,
    String? payload,
    String kind = 'general',
    bool critical = false,
  }) async {
    if (!_ready || !PreferencesController.instance.permits(kind) || !_shownKeys.add(key)) {
      return false;
    }
    try {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          critical ? 'mfsl_critical' : 'mfsl_activity',
          critical ? 'Critical business alerts' : 'Business activity',
          channelDescription: critical
              ? 'Low stock, pending approvals and urgent operational events'
              : 'Documents, sales and staff activity',
          importance: critical ? Importance.max : Importance.high,
          priority: critical ? Priority.max : Priority.high,
          category: critical ? AndroidNotificationCategory.alarm : null,
        ),
        windows: const WindowsNotificationDetails(),
      );
      await _plugin.show(
        id: key.hashCode & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      return true;
    } catch (error) {
      _shownKeys.remove(key); // allow a retry after a transient OS failure
      debugPrint('Native notification failed: $error');
      return false;
    }
  }

  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);
}
