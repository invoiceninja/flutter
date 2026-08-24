import 'package:intl/intl.dart';

/// Expands the server's reserved date keywords for *display*.
///
/// A product description can carry `[MONTHYEAR|MONTHYEAR+12]`, which the
/// server turns into "August 2026 to August 2027" when it renders the invoice
/// (`Helpers::processReservedKeywords`). Until then the raw token is what a
/// list row shows, and it reads as noise to anyone who didn't write it
/// (invoiceninja/flutter#93).
///
/// **Display only.** Never run this over text bound to an editable field — the
/// token is the value there, and expanding it would hand the user the rendered
/// string to save back.
///
/// Deliberately covers only the unambiguous half of the server's grammar:
///
///  * `[MONTHYEAR|MONTHYEAR]` and `[MONTHYEAR|MONTHYEAR+n]` ranges
///  * the bare literals `:MONTHYEAR`, `:MONTH`, `:YEAR`, `:QUARTER`
///
/// Arithmetic literals (`:MONTH+2`), `:WEEK`, and the `_BEFORE` / `_AFTER`
/// variants are left exactly as written. Their upstream handling has enough
/// edge cases (integer month math that doesn't wrap the year, quarter
/// wrapping added later) that a half-right expansion here would be worse than
/// the raw token: a wrong date reads as fact, a token reads as a token.
String expandDatePlaceholders(
  String text, {
  required String rangeSeparator,
  DateTime? now,
  String? locale,
}) {
  if (text.isEmpty) return text;
  // Cheap bail-out before any regex work — the overwhelming majority of
  // descriptions carry no keyword at all. Mirrors the server's own early exit.
  if (!text.contains(':') && !text.contains('[')) return text;

  final at = now ?? DateTime.now();
  final monthYear = DateFormat.yMMMM(locale).format(at);
  String monthYearPlus(int months) =>
      DateFormat.yMMMM(locale).format(DateTime(at.year, at.month + months));

  var out = text;

  // Ranges first, so a `[MONTHYEAR|…]` isn't half-eaten by the literal pass
  // below (the server orders it the same way, for the same reason).
  out = out.replaceAllMapped(
    _rangePattern,
    (m) =>
        '$monthYear $rangeSeparator '
        '${monthYearPlus(int.tryParse(m.group(1) ?? '') ?? 0)}',
  );

  out = out.replaceAllMapped(_literalPattern, (m) {
    switch (m.group(1)) {
      case 'MONTHYEAR':
        return monthYear;
      case 'MONTH':
        return DateFormat.MMMM(locale).format(at);
      case 'YEAR':
        return '${at.year}';
      default:
        return 'Q${((at.month - 1) ~/ 3) + 1}';
    }
  });

  return out;
}

/// `[MONTHYEAR|MONTHYEAR]` or `[MONTHYEAR|MONTHYEAR+n]`. The offset group is
/// absent for the no-arithmetic form, which the server renders as the current
/// month on both sides.
final RegExp _rangePattern = RegExp(r'\[MONTHYEAR\|MONTHYEAR(?:\+(\d+))?\]');

/// A bare literal keyword and nothing else.
///
/// `MONTHYEAR` leads the alternation because `MONTH` is a prefix of it, and
/// the lookahead is what keeps this honest: without it `:MONTH+2` expanded to
/// "August+2" and `:MONTH_BEFORE` to "August_BEFORE" — output that looks like
/// data rather than like the unhandled token it actually is.
final RegExp _literalPattern = RegExp(
  r':(MONTHYEAR|MONTH|YEAR|QUARTER)(?![A-Za-z0-9_+\-*/])',
);
