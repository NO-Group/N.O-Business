import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Structured application logger.
///
/// Every record is a single JSON line (`ts`, `level`, `logger`, `message`,
/// plus caller-supplied fields) so it can be shipped to a log pipeline
/// unchanged. Values under credential-like keys are redacted before they are
/// written anywhere.
class AppLogger {
  const AppLogger(this.name);

  final String name;

  static const _redacted = '[redacted]';
  static final _sensitiveKey = RegExp(
    r'(password|secret|token|authorization|api[_-]?key|anon[_-]?key|session|cookie)',
    caseSensitive: false,
  );

  /// Minimum level written in release builds.
  static LogLevel releaseThreshold = LogLevel.info;

  /// Test hook: receives every record that passes the threshold.
  @visibleForTesting
  static void Function(Map<String, Object?> record)? sink;

  void debug(String message, {Map<String, Object?> fields = const {}}) =>
      _write(LogLevel.debug, message, fields);

  void info(String message, {Map<String, Object?> fields = const {}}) =>
      _write(LogLevel.info, message, fields);

  void warning(String message, {Map<String, Object?> fields = const {}, Object? error}) =>
      _write(LogLevel.warning, message, fields, error: error);

  void error(
    String message, {
    Map<String, Object?> fields = const {},
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _write(LogLevel.error, message, fields, error: error, stackTrace: stackTrace);

  /// Returns a copy of [fields] that is safe to persist.
  static Map<String, Object?> redact(Map<String, Object?> fields) {
    return fields.map((key, value) {
      if (_sensitiveKey.hasMatch(key)) return MapEntry(key, _redacted);
      if (value is Map<String, Object?>) return MapEntry(key, redact(value));
      return MapEntry(key, value);
    });
  }

  void _write(
    LogLevel level,
    String message,
    Map<String, Object?> fields, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kReleaseMode && level.index < releaseThreshold.index) return;
    final record = <String, Object?>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'level': level.name,
      'logger': name,
      'message': message,
      ...redact(fields),
      if (error != null) 'error_type': error.runtimeType.toString(),
    };
    sink?.call(record);
    developer.log(
      jsonEncode(record, toEncodable: (value) => value.toString()),
      name: name,
      level: 500 + level.index * 200,
      error: kReleaseMode ? null : error,
      stackTrace: stackTrace,
    );
  }
}
