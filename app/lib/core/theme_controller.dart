import 'package:flutter/material.dart';

import '../data/local_store.dart';

/// Persistent app-wide theme preference. System is the safe default and the
/// controller is loaded before the first frame to avoid a light-theme flash.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final value = await localRead('theme_mode');
    _mode = ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await localWrite('theme_mode', mode.name);
    notifyListeners();
  }
}
