import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/local_store.dart';

/// Durable device preferences that affect real application behaviour.
/// Business-authority settings remain server-owned; these are intentionally
/// per-device so each phone/PC can choose its own alert and accessibility UX.
class PreferencesController extends ChangeNotifier {
  PreferencesController._();
  static final PreferencesController instance = PreferencesController._();

  bool nativeNotifications = true;
  bool transactionAlerts = true;
  bool documentAlerts = true;
  bool stockAlerts = true;
  bool staffAlerts = true;
  bool reduceMotion = false;
  bool compactLists = false;
  bool biometricsEnabled = false;

  Future<void> load() async {
    final raw = await localRead('app_preferences');
    if (raw == null || raw.isEmpty) return;
    try {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      nativeNotifications = value['native_notifications'] != false;
      transactionAlerts = value['transaction_alerts'] != false;
      documentAlerts = value['document_alerts'] != false;
      stockAlerts = value['stock_alerts'] != false;
      staffAlerts = value['staff_alerts'] != false;
      reduceMotion = value['reduce_motion'] == true;
      compactLists = value['compact_lists'] == true;
      biometricsEnabled = value['biometrics_enabled'] == true;
    } catch (_) {
      // Corrupt preferences never prevent startup; defaults are safe.
    }
  }

  bool permits(String kind) {
    if (!nativeNotifications) return false;
    return switch (kind) {
      'transaction' => transactionAlerts,
      'document' => documentAlerts,
      'stock' || 'approval' || 'stockApproval' => stockAlerts,
      'staff' || 'announcement' => staffAlerts,
      _ => true,
    };
  }

  Future<void> update({
    bool? nativeNotifications,
    bool? transactionAlerts,
    bool? documentAlerts,
    bool? stockAlerts,
    bool? staffAlerts,
    bool? reduceMotion,
    bool? compactLists,
    bool? biometricsEnabled,
  }) async {
    this.nativeNotifications = nativeNotifications ?? this.nativeNotifications;
    this.transactionAlerts = transactionAlerts ?? this.transactionAlerts;
    this.documentAlerts = documentAlerts ?? this.documentAlerts;
    this.stockAlerts = stockAlerts ?? this.stockAlerts;
    this.staffAlerts = staffAlerts ?? this.staffAlerts;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.compactLists = compactLists ?? this.compactLists;
    this.biometricsEnabled = biometricsEnabled ?? this.biometricsEnabled;
    await localWrite('app_preferences', jsonEncode({
      'native_notifications': this.nativeNotifications,
      'transaction_alerts': this.transactionAlerts,
      'document_alerts': this.documentAlerts,
      'stock_alerts': this.stockAlerts,
      'staff_alerts': this.staffAlerts,
      'reduce_motion': this.reduceMotion,
      'compact_lists': this.compactLists,
      'biometrics_enabled': this.biometricsEnabled,
    }));
    notifyListeners();
  }
}
