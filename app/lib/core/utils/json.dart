/// Defensive JSON readers.
///
/// Rows come from the network; a missing or oddly-typed field must degrade
/// to a default instead of throwing a cast error in the middle of a build.
typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<JsonMap> asJsonList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String) item,
  ];
}

String asString(Object? value, [String fallback = '']) => value is String ? value : fallback;

String? asStringOrNull(Object? value) => value is String && value.isNotEmpty ? value : null;

/// Integers, including `bigint` money columns. Fractions are rounded.
int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.round() ?? fallback;
  return fallback;
}

/// `numeric` columns (quantities, rates), which may arrive as number or text.
double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(Object? value, [bool fallback = false]) => value is bool ? value : fallback;

/// Timestamps (`timestamptz`) and calendar dates (`date`).
DateTime? asDateTime(Object? value) => value is String ? DateTime.tryParse(value) : null;
