import 'package:decimal/decimal.dart';

/// Tolerant `Decimal` parser. Invoice Ninja's API returns money either as a
/// number (`100.00`) or a string (`"100.00"`), occasionally as an empty
/// string. Anything unparseable returns [Decimal.zero] — money is never null
/// in the domain model, so the parser never returns null.
///
/// **Never** parse money as `double`. Use this helper for every monetary
/// field; the CI lint test will fail the build if a `double` named like a
/// money field appears in `lib/data/models/`.
Decimal parseMoney(Object? raw) {
  if (raw == null) return Decimal.zero;
  if (raw is num) {
    return Decimal.parse(raw.toString());
  }
  if (raw is String) {
    if (raw.isEmpty) return Decimal.zero;
    return Decimal.tryParse(raw) ?? Decimal.zero;
  }
  return Decimal.zero;
}

/// Parse a possibly locale-FORMATTED money/number string, e.g. `"3,238.00"`,
/// `"3.238,00"`, `"3,238"`. The report export endpoint runs every numeric cell
/// through PHP `number_format` with the currency's thousand/decimal
/// separators, so `value` arrives grouped — and [parseMoney] delegates to
/// `Decimal.tryParse`, which returns 0 for ANY grouped string (silently
/// zeroing every report total/sort/filter for amounts ≥ 1,000 or comma-decimal
/// currencies).
///
/// Locale-agnostic: a plain machine number is returned as-is; otherwise the
/// decimal separator is inferred as the last `.`/`,` that is either the
/// rightmost of two different separators, or a lone separator followed by 1–2
/// digits (money precision). A lone separator followed by exactly 3 digits, or
/// any repeated separator, is grouping and stripped. Correct for every 0- and
/// 2-decimal currency and every both-separator case; the only residual is a
/// 3-decimal-currency value < 1000 with a single separator (e.g. BHD `"3,238"`),
/// which the server disambiguates with a grouping separator once ≥ 1000.
Decimal parseFormattedMoney(Object? raw) {
  if (raw == null) return Decimal.zero;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is! String) return Decimal.zero;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return Decimal.zero;
  // Fast path: an ungrouped machine number ("1234.00", "0.5", "-100") parses.
  final direct = Decimal.tryParse(trimmed);
  if (direct != null) return direct;
  final negative = trimmed.startsWith('-');
  final body = trimmed.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (body.isEmpty) return Decimal.zero;
  final dot = body.lastIndexOf('.');
  final comma = body.lastIndexOf(',');
  final lastSep = dot > comma ? dot : comma;
  var decSepAt = -1;
  if (lastSep >= 0) {
    final trailing = body.length - lastSep - 1;
    final bothPresent = dot >= 0 && comma >= 0;
    if (bothPresent || (trailing >= 1 && trailing <= 2)) decSepAt = lastSep;
  }
  final String intPart;
  final String fracPart;
  if (decSepAt < 0) {
    intPart = body.replaceAll(RegExp(r'[.,]'), '');
    fracPart = '';
  } else {
    intPart = body.substring(0, decSepAt).replaceAll(RegExp(r'[.,]'), '');
    fracPart = body.substring(decSepAt + 1).replaceAll(RegExp(r'[^0-9]'), '');
  }
  final normalized =
      '${negative ? '-' : ''}${intPart.isEmpty ? '0' : intPart}'
      '${fracPart.isEmpty ? '' : '.$fracPart'}';
  return Decimal.tryParse(normalized) ?? Decimal.zero;
}
