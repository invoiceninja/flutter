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
///
/// **Pass [style] whenever the writer's format is known.** The report export
/// formats with the *company* currency (`BaseExport::formatFloatsForCsv`), so
/// the caller can name the separators and the precision, and the inference
/// above stops being a guess. It matters for a currency with no decimals and
/// a `.` grouping separator (CLP, and several others): the server writes one
/// thousand two hundred and thirty-four as `"1.234"`, which the fast path
/// below reads as a little over one.
Decimal parseFormattedMoney(Object? raw, {FormattedNumberStyle? style}) {
  if (raw == null) return Decimal.zero;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is! String) return Decimal.zero;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return Decimal.zero;
  if (style != null) {
    final styled = style.tryParse(trimmed);
    if (styled != null) return styled;
  }
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

/// How a number was written by PHP's `number_format`: the two separators and
/// the number of decimals. Used to read a formatted amount back exactly —
/// see [parseFormattedMoney].
class FormattedNumberStyle {
  FormattedNumberStyle({
    required this.thousandSeparator,
    required this.decimalSeparator,
    required this.precision,
  }) : _shape = _shapeFor(thousandSeparator, decimalSeparator, precision);

  final String thousandSeparator;
  final String decimalSeparator;
  final int precision;

  /// Exactly what `number_format(value, precision, decimal, thousand)` can
  /// produce — digits in groups of three, then the decimals if there are any.
  final RegExp _shape;

  static RegExp _shapeFor(String thousand, String decimal, int precision) {
    final t = RegExp.escape(thousand);
    final d = RegExp.escape(decimal);
    final integer = thousand.isEmpty ? r'\d+' : '\\d{1,3}(?:$t\\d{3})*';
    final fraction = precision > 0 ? '$d\\d{$precision}' : '';
    return RegExp('^-?$integer$fraction\$');
  }

  /// [text] as a number, or null when it is not in this style's exact shape.
  ///
  /// Null rather than a best effort, and that is the point: not every numeric
  /// cell is formatted. A float is, but a decimal column the export hands
  /// over as a string arrives raw (`"4544.000000"` on the recurring-invoice
  /// report). Stripping the `.` from that as a grouping separator would turn
  /// four and a half thousand into four and a half billion; six decimals do
  /// not fit a two-decimal shape, so it falls through to the plain parse.
  Decimal? tryParse(String text) {
    if (!_shape.hasMatch(text)) return null;
    var plain = text;
    if (thousandSeparator.isNotEmpty) {
      plain = plain.replaceAll(thousandSeparator, '');
    }
    if (precision > 0 && decimalSeparator != '.') {
      plain = plain.replaceAll(decimalSeparator, '.');
    }
    return Decimal.tryParse(plain);
  }

  @override
  bool operator ==(Object other) =>
      other is FormattedNumberStyle &&
      other.thousandSeparator == thousandSeparator &&
      other.decimalSeparator == decimalSeparator &&
      other.precision == precision;

  @override
  int get hashCode =>
      Object.hash(thousandSeparator, decimalSeparator, precision);
}
