// Small, defensive JSON readers. The API returns `decimal` as JSON number, dates as
// ISO-8601 / `yyyy-MM-dd` strings, and is occasionally loose about int-vs-number, so we
// coerce rather than hard-cast (a hard cast would throw on a perfectly valid payload).
double? asDouble(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

int? asInt(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

bool asBool(Object? v, {bool fallback = false}) => v is bool ? v : fallback;

String? asString(Object? v) => v?.toString();

DateTime? asDate(Object? v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString());
}

/// Read a JSON array as a typed list, mapping each element through [map].
List<T> asList<T>(Object? v, T Function(Map<String, dynamic>) map) {
  if (v is! List) return const [];
  return v
      .whereType<Map<String, dynamic>>()
      .map(map)
      .toList(growable: false);
}
