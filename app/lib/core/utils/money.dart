import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Money helpers. Amounts travel and are stored as integer MINOR units
/// (kobo, cents); they are only converted to a decimal for display.
abstract final class Money {
  static final Map<String, NumberFormat> _formats = {};
  static final Map<String, NumberFormat> _compactFormats = {};

  static NumberFormat _format(String currencyCode) =>
      _formats.putIfAbsent(currencyCode, () => NumberFormat.simpleCurrency(name: currencyCode));

  /// Number of minor-unit digits for the currency (2 for NGN/USD, 0 for JPY).
  static int fractionDigits(String currencyCode) => _format(currencyCode).decimalDigits ?? 2;

  static int _factor(String currencyCode) => math.pow(10, fractionDigits(currencyCode)).toInt();

  /// "₦12,500.00"
  static String format(int minor, String currencyCode) =>
      _format(currencyCode).format(minor / _factor(currencyCode));

  /// "₦1.3M" — for dense cards and chart axes.
  static String compact(int minor, String currencyCode) {
    final format = _compactFormats.putIfAbsent(
      currencyCode,
      () => NumberFormat.compactSimpleCurrency(name: currencyCode),
    );
    return format.format(minor / _factor(currencyCode));
  }

  /// "NGN 12,500.00" — for printed documents, where the ISO code is
  /// unambiguous and never depends on a font having the currency glyph.
  static String formatIso(int minor, String currencyCode) {
    final digits = fractionDigits(currencyCode);
    final number = NumberFormat.decimalPatternDigits(decimalDigits: digits);
    return '$currencyCode ${number.format(minor / _factor(currencyCode))}';
  }

  /// Plain editable text for a form field: "12500.00".
  static String toInput(int minor, String currencyCode) {
    final digits = fractionDigits(currencyCode);
    return (minor / _factor(currencyCode)).toStringAsFixed(digits);
  }

  /// Parses what a person types ("12,500.50", " 1 000 ") into minor units.
  /// Returns null when the text is not a non-negative amount.
  static int? parse(String input, String currencyCode) {
    final cleaned = input.replaceAll(RegExp(r'[,\s]'), '');
    if (cleaned.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) return null;
    final value = double.tryParse(cleaned);
    if (value == null || !value.isFinite) return null;
    return (value * _factor(currencyCode)).round();
  }
}
