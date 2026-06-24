/// Shared JSON-parsing resilience helpers for the api DTOs.
///
/// The Invoice Ninja server is not always consistent about wire types: a few
/// fields flip between number and string, and `line_items` (and similar
/// sub-structures) are emitted as **raw stored JSON** with no per-field
/// casting on the read path — only the save-time `CleanLineItems` cleaner
/// coerces them. So a value persisted as an integer (older invoices, CSV
/// imports, or third-party API writes that bypassed the cleaner) comes back as
/// a JSON number, and json_serializable's generated `json['x'] as String?`
/// throws "type 'int' is not a subtype of type 'String?' in type cast".
///
/// These two helpers harden the parse layer against that whole class of bug.
library;

import 'package:logging/logging.dart';

final _log = Logger('api.parse');

/// Coerce a JSON scalar the server may emit as a number **or** a string into a
/// Dart `String`. Returns `null` for `null`/absent so a freezed `@Default(...)`
/// still supplies the fallback.
///
/// Wire to a string field via `@JsonKey(fromJson: jsonScalarToString)`. Mirrors
/// the existing `_boolFromJson` converter pattern in
/// `login_response_api_model.dart`.
///
/// * `1` (int)      → `"1"`
/// * `1.0` (double) → `"1"`  (whole doubles drop the trailing `.0`)
/// * `1.5` (double) → `"1.5"`
/// * `"abc"`        → `"abc"`
/// * `null`         → `null`
String? jsonScalarToString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  // Whole doubles render as "1", not "1.0"; everything else (ints, fractional
  // doubles, bools) uses the canonical toString().
  if (value is double && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// Non-null variant of [jsonScalarToString] for a `String` field (non-nullable)
/// whose freezed `@Default` is the empty string.
///
/// json_serializable requires a `fromJson` converter's return type to match the
/// field type exactly and does **not** re-apply `@Default` after a custom
/// converter — so a non-null `String` field can't use the `String?`-returning
/// [jsonScalarToString]; it needs this (null/absent → `''`). Wire via
/// `@JsonKey(fromJson: jsonScalarToStringOrEmpty)`.
String jsonScalarToStringOrEmpty(Object? value) =>
    jsonScalarToString(value) ?? '';

/// Tolerant list parse: deserialize each element of [raw] with [parse],
/// **dropping and logging** any element that throws instead of failing the
/// entire page. Backstops unknown future type mismatches in list responses —
/// without it, one malformed row blanks the whole list view.
///
/// Returns an empty list when [raw] is not a JSON array. [label] names the
/// entity for the diagnostics log (e.g. `'invoice'`). The `WARNING` records are
/// captured by the on-disk diagnostics log (see `lib/app/diagnostics_log.dart`).
///
/// Each `*ListApi` envelope wires its `data` field to a one-line concrete
/// wrapper around this (the generic can't be referenced directly in a
/// `@JsonKey(fromJson:)` annotation), e.g.:
/// ```dart
/// List<InvoiceApi> _invoiceListData(Object? raw) =>
///     tolerantList(raw, InvoiceApi.fromJson, label: 'invoice');
/// ```
List<T> tolerantList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) parse, {
  required String label,
}) {
  if (raw is! List) return const [];
  final out = <T>[];
  var skipped = 0;
  for (final element in raw) {
    try {
      out.add(parse(element as Map<String, dynamic>));
    } catch (error, stackTrace) {
      skipped++;
      _log.warning('Skipped malformed $label list row', error, stackTrace);
    }
  }
  if (skipped > 0) {
    _log.warning(
      'Dropped $skipped malformed $label row(s) out of ${raw.length}',
    );
  }
  return out;
}
