import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests only permissions the app actually consumes. Storage is provided
/// by Android's Storage Access Framework and printing by the system print
/// service, so neither storage nor Bluetooth is requested unnecessarily.
abstract final class PermissionGate {
  static bool _checked = false;

  static Future<bool> enforce(BuildContext context) async {
    if (_checked || !Platform.isAndroid) return true;
    _checked = true;

    final results = await <Permission>[
      Permission.camera,
      Permission.notification,
    ].request();
    final denied = results.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key == Permission.camera ? 'Camera' : 'Notifications')
        .toList();
    if (denied.isEmpty) return true;
    if (!context.mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Permissions required'),
          content: Text(
            '${denied.join(' and ')} permission${denied.length == 1 ? ' is' : 's are'} required '
            'for site evidence and critical business alerts. The app will now close. '
            'Enable the permissions in Android Settings before reopening it.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close app'),
            ),
          ],
        ),
      ),
    );
    await SystemNavigator.pop();
    return false;
  }
}
