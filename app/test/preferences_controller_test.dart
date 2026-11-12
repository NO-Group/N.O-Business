import 'package:flutter_test/flutter_test.dart';
import 'package:mtek_inventory/core/preferences_controller.dart';

void main() {
  final preferences = PreferencesController.instance;

  setUp(() {
    preferences
      ..nativeNotifications = true
      ..transactionAlerts = true
      ..documentAlerts = true
      ..stockAlerts = true
      ..staffAlerts = true
      ..reduceMotion = false
      ..compactLists = false;
  });

  test('master notification preference blocks every category', () {
    preferences.nativeNotifications = false;
    for (final kind in ['transaction', 'document', 'stock', 'approval', 'staff', 'announcement', 'general']) {
      expect(preferences.permits(kind), isFalse, reason: kind);
    }
  });

  test('each notification category is enforced independently', () {
    preferences.transactionAlerts = false;
    expect(preferences.permits('transaction'), isFalse);
    expect(preferences.permits('document'), isTrue);

    preferences.documentAlerts = false;
    expect(preferences.permits('document'), isFalse);

    preferences.stockAlerts = false;
    expect(preferences.permits('stock'), isFalse);
    expect(preferences.permits('approval'), isFalse);

    preferences.staffAlerts = false;
    expect(preferences.permits('staff'), isFalse);
    expect(preferences.permits('announcement'), isFalse);
  });
}
