import 'package:intl/intl.dart';

final NumberFormat _naira = NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: 0,
);

final NumberFormat _compact = NumberFormat.compact(locale: 'en_NG');

/// ₦4,021,000
String naira(num amount) => _naira.format(amount);

/// ₦4.02M — for tight cards/chips
String nairaCompact(num amount) => '₦${_compact.format(amount)}';

/// 29 Aug 2026
String fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

/// 29 Aug
String fmtDateShort(DateTime d) => DateFormat('d MMM').format(d);

/// 29 Aug 2026, 14:05
String fmtDateTime(DateTime d) => DateFormat('d MMM yyyy, HH:mm').format(d);

int daysUntil(DateTime d) =>
    DateTime(d.year, d.month, d.day).difference(DateTime.now()).inDays;
