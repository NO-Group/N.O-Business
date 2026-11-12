import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

/// Small device-local preferences (which organization / workspace was open
/// last). Loaded once at start-up so reads are synchronous afterwards.
///
/// Kept in the OS credential store next to the session rather than in a
/// plain file: the values are tenant identifiers.
class AppPreferences {
  AppPreferences._(this._storage, this._values);

  /// In-memory only; used by tests and when the secure store is unavailable.
  AppPreferences.memory([Map<String, String>? initial]) : _storage = null, _values = {...?initial};

  static const _log = AppLogger('preferences');
  static const _organizationKey = 'nob.pref.organization';
  static const _workspacePrefix = 'nob.pref.workspace.';

  final FlutterSecureStorage? _storage;
  final Map<String, String> _values;

  static Future<AppPreferences> load(FlutterSecureStorage storage) async {
    try {
      final all = await storage.readAll();
      final values = <String, String>{
        for (final entry in all.entries)
          if (entry.key.startsWith('nob.pref.')) entry.key: entry.value,
      };
      return AppPreferences._(storage, values);
    } catch (error) {
      _log.warning('secure store unavailable; preferences will not persist', error: error);
      return AppPreferences.memory();
    }
  }

  String? get lastOrganizationId => _values[_organizationKey];

  String? lastWorkspaceId(String organizationId) => _values['$_workspacePrefix$organizationId'];

  Future<void> setLastOrganizationId(String id) => _write(_organizationKey, id);

  Future<void> setLastWorkspaceId(String organizationId, String workspaceId) =>
      _write('$_workspacePrefix$organizationId', workspaceId);

  /// Forgets every preference (sign-out on a shared device).
  Future<void> clear() async {
    final keys = _values.keys.toList();
    _values.clear();
    final storage = _storage;
    if (storage == null) return;
    for (final key in keys) {
      try {
        await storage.delete(key: key);
      } catch (error) {
        _log.warning('could not clear a preference', error: error);
      }
    }
  }

  Future<void> _write(String key, String value) async {
    _values[key] = value;
    try {
      await _storage?.write(key: key, value: value);
    } catch (error) {
      _log.warning('could not persist a preference', error: error);
    }
  }
}
