import 'package:intl/intl.dart';

final DateFormat _date = DateFormat('d MMM yyyy');
final DateFormat _dateTime = DateFormat('d MMM yyyy, HH:mm');
final DateFormat _shortDay = DateFormat('d MMM');
final DateFormat _isoDate = DateFormat('yyyy-MM-dd');
final NumberFormat _quantity = NumberFormat('#,##0.###');

/// 29 Aug 2026
String formatDate(DateTime value) => _date.format(value.toLocal());

/// 29 Aug 2026, 14:05
String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());

/// 29 Aug
String formatShortDay(DateTime value) => _shortDay.format(value);

/// 2026-08-29 — the wire format for SQL `date` columns.
String toIsoDate(DateTime value) => _isoDate.format(value);

/// 1,250 or 2.5 — trailing zeros dropped.
String formatQuantity(num value) => _quantity.format(value);

/// "Bank transfer" from "bank_transfer".
String humanize(String value) {
  if (value.isEmpty) return value;
  final words = value.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

/// Up to two initials for an avatar.
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
