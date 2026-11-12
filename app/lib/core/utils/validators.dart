/// Form validators. Each returns an error message or null.
///
/// These give fast feedback only; the database constraints and RPC checks
/// are the authority and reject anything that slips past the UI.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _e164 = RegExp(r'^\+[1-9][0-9]{7,14}$');

  static String? required(String? value, {String label = 'This field'}) =>
      (value == null || value.trim().isEmpty) ? '$label is required' : null;

  static String? email(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return optional ? null : 'Email is required';
    return _email.hasMatch(text) ? null : 'Enter a valid email address';
  }

  /// International format, e.g. +2348012345678.
  static String? phone(String? value, {bool optional = true}) {
    final text = normalizePhone(value ?? '');
    if (text.isEmpty) return optional ? null : 'Phone number is required';
    return _e164.hasMatch(text) ? null : 'Use international format, e.g. +2348012345678';
  }

  static String normalizePhone(String value) => value.trim().replaceAll(RegExp(r'[\s()\-]'), '');

  static String? password(String? value) {
    final text = value ?? '';
    if (text.length < 10) return 'Use at least 10 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(text) || !RegExp(r'[0-9]').hasMatch(text)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? length(
    String? value, {
    required int min,
    required int max,
    String label = 'This field',
  }) {
    final size = value?.trim().length ?? 0;
    if (size < min) {
      return min == 1 ? '$label is required' : '$label needs at least $min characters';
    }
    if (size > max) return '$label can be at most $max characters';
    return null;
  }

  static String? percentage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null || number < 0 || number > 100) return 'Enter a value from 0 to 100';
    return null;
  }

  static String? positiveNumber(String? value, {String label = 'Value'}) {
    final number = double.tryParse((value ?? '').replaceAll(',', '').trim());
    if (number == null || number <= 0) return '$label must be above zero';
    return null;
  }
}

/// Empty text becomes null so optional columns are stored as NULL, not ''.
String? nullIfBlank(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
