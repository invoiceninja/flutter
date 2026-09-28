import 'package:intl/intl.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/formatting.dart';

/// Expands the server's reserved date keywords for *display*.
///
/// A product description or a document's terms can carry
/// `[MONTHYEAR|MONTHYEAR+12]`, which the server turns into "August 2026 -
/// August 2027" when it renders the invoice (`Helpers::processReservedKeywords`,
/// `app/Utils/Helpers.php`). Until then the raw token is what a list row shows,
/// and it reads as noise to anyone who didn't write it (invoiceninja/flutter#93).
///
/// **Display only.** Never run this over text bound to an editable field — the
/// token is the value there, and expanding it would hand the user the rendered
/// string to save back.
///
/// Mirrors the server as of `fd8cd8ad6c` (Sep 1 2026, released in v5.13.37),
/// which fixed five of the six defects BACKEND.md § Reserved date keywords
/// recorded. Covered:
///
///  * `[MONTHYEAR|MONTHYEAR]` and `[MONTHYEAR|MONTHYEAR±n]` ranges
///  * the bare literals `:MONTHYEAR`, `:MONTH`, `:YEAR`, `:QUARTER`
///  * the fixed-window ranges `:WEEK`, `:WEEK_BEFORE`, `:WEEK_AHEAD`,
///    `:MONTH_BEFORE`, `:MONTH_AFTER`, `:YEAR_BEFORE`, `:YEAR_AFTER`
///  * `±n` arithmetic on `:MONTHYEAR`, `:MONTH`, `:YEAR` and `:QUARTER`
///
/// **Everything else is left exactly as written**, because upstream still gets
/// it wrong and a wrong date reads as fact where a token reads as a token:
/// `:YEAR/4` renders `506.5` (defect 4, still open), `:WEEK+2` renders `2` and
/// `:MONTH_BEFORE-1` a bare month number (`strtr` finds no numeric entry for
/// those keys), and `*` / `/` on the other keys compute a month or quarter
/// *number* rather than an offset. Upstream's pinned expectations are in
/// `tests/Unit/HelpersTest.php`.
///
/// [separator] matches the server's untranslated `-`, which it now uses for the
/// bracket ranges and the literal windows alike. Deliberately *not* `tr('to')`:
/// that key is the email recipient label ("An" in German, "宛先" in Japanese),
/// which is exactly why upstream dropped it. A self-hosted server older than the
/// fix still renders `to` on its PDFs — accepted; hosted is the reference.
String expandDatePlaceholders(
  String text, {
  Formatter? formatter,
  DateTime? now,
  String separator = '-',
}) {
  if (text.isEmpty) return text;
  // Cheap bail-out before any regex work — the overwhelming majority of
  // descriptions carry no keyword at all. Mirrors the server's own early exit.
  if (!text.contains(':') && !text.contains('[')) return text;

  final at = now ?? DateTime.now();
  // `CompanyFormatSettings.locale` is a non-nullable String that is `''` both in
  // `.fallback` and for any unrecognised `language_id`; `DateFormat` throws on
  // an empty locale rather than falling back, so normalise here — once, for
  // every caller — exactly as `Formatter` does internally.
  final localeName = formatter?.settings.locale;
  final locale = (localeName == null || localeName.isEmpty) ? null : localeName;

  // The server builds this as `translatedFormat('F') . ' ' . $year`, not as a
  // locale-ordered year-month pattern — `DateFormat.yMMMM` would reorder it in
  // ja/zh and stop matching the PDF.
  String monthYear(DateTime d) =>
      '${DateFormat.MMMM(locale).format(d)} ${d.year}';

  // Day-1 arithmetic, like upstream's `startOfMonth()` anchor: a month offset
  // can never overflow into the following month.
  DateTime monthsFromNow(int months) => DateTime(at.year, at.month + months);

  final today = Date(at.year, at.month, at.day);
  String window(Date from, Date to) =>
      '${formatter?.date(from.toIso()) ?? from.toIso()} $separator '
      '${formatter?.date(to.toIso()) ?? to.toIso()}';

  var out = text;

  // Ranges first, so a `[MONTHYEAR|…]` isn't half-eaten by the passes below
  // (the server orders it the same way, for the same reason).
  out = out.replaceAllMapped(
    _rangePattern,
    (m) =>
        '${monthYear(monthsFromNow(0))} $separator '
        '${monthYear(monthsFromNow(_signed(m.group(1), m.group(2))))}',
  );

  out = out.replaceAllMapped(_arithmeticPattern, (m) {
    final n = _signed(m.group(2), m.group(3));
    switch (m.group(1)!) {
      case 'MONTHYEAR':
        return monthYear(monthsFromNow(n));
      case 'MONTH':
        // `Carbon::create()->month($m ± n)` — `create()` with no arguments is
        // 0000-01-01, so this is day 1 too and wraps without overflowing.
        return DateFormat.MMMM(locale).format(monthsFromNow(n));
      case 'YEAR':
        return '${at.year + n}';
      default:
        // `addQuarters` / `subQuarters` on the *current* date — Carbon's
        // month overflow included (Mar 31 + 1 quarter is Jul 1, so Q3), which
        // Dart's `DateTime` normalisation reproduces exactly.
        final d = DateTime(at.year, at.month + 3 * n, at.day);
        return 'Q${((d.month - 1) ~/ 3) + 1}';
    }
  });

  out = out.replaceAllMapped(_literalPattern, (m) {
    switch (m.group(1)!) {
      case 'MONTH_BEFORE':
        return window(_addMonths(today, -1), today.addDays(-1));
      case 'MONTH_AFTER':
        return window(today, _addMonths(today, 1).addDays(-1));
      case 'YEAR_BEFORE':
        return window(_addYears(today, -1), today.addDays(-1));
      case 'YEAR_AFTER':
        return window(today, _addYears(today, 1).addDays(-1));
      case 'WEEK_BEFORE':
        return window(today.addDays(-7), today.addDays(-1));
      case 'WEEK_AHEAD':
        return window(today.addDays(7), today.addDays(13));
      case 'WEEK':
        return window(today, today.addDays(6));
      case 'MONTHYEAR':
        return monthYear(monthsFromNow(0));
      case 'MONTH':
        return DateFormat.MMMM(locale).format(at);
      case 'YEAR':
        return '${at.year}';
      default:
        // Hardcoded ASCII `Q` upstream too — never localized.
        return 'Q${((at.month - 1) ~/ 3) + 1}';
    }
  });

  return out;
}

/// `+` / `-` and a digit run as a signed offset; no operator is zero.
int _signed(String? operator, String? digits) {
  final n = int.tryParse(digits ?? '') ?? 0;
  return operator == '-' ? -n : n;
}

/// Month offset with Carbon's overflow semantics (Jan 31 + 1 month → Mar 3),
/// so a `_BEFORE` / `_AFTER` window lands on the same day the PDF will show —
/// those windows still step from today, not from the 1st, upstream.
Date _addMonths(Date d, int months) {
  final t = DateTime(d.year, d.month + months, d.day);
  return Date(t.year, t.month, t.day);
}

Date _addYears(Date d, int years) {
  final t = DateTime(d.year + years, d.month, d.day);
  return Date(t.year, t.month, t.day);
}

/// `[MONTHYEAR|MONTHYEAR]` or `[MONTHYEAR|MONTHYEAR±n]` — exactly upstream's
/// right-hand grammar (`^MONTHYEAR(?<operator>[+-])(?<months>\d+)$`). Anything
/// else in the brackets (`/2`, `*2`, `[MONTH|MONTH+2]`) the server now skips,
/// and so does this.
final RegExp _rangePattern = RegExp(
  r'\[MONTHYEAR\|MONTHYEAR(?:([+-])(\d+))?\]',
);

/// `±n` on the four keys whose arithmetic upstream now gets right. `MONTHYEAR`
/// precedes `MONTH` for the same leftmost-first reason as [_literalPattern],
/// and the operator has to follow the key directly, so `:YEAR_BEFORE+1` (which
/// upstream renders as a bare number) never matches. The lookahead keeps
/// `:MONTH+2x` raw rather than rendering "Octoberx".
final RegExp _arithmeticPattern = RegExp(
  r':(MONTHYEAR|MONTH|YEAR|QUARTER)([+-])(\d+)(?![A-Za-z0-9_+\-*/])',
);

/// A bare literal keyword and nothing else.
///
/// Alternation order is load-bearing — a regex alternation is leftmost-first,
/// not longest-first, so every `_BEFORE` / `_AFTER` / `_AHEAD` variant and
/// `MONTHYEAR` must precede the prefix it extends. (Upstream depends on the
/// same ordering, via the declaration order of its `literal` array.)
///
/// The lookahead is what keeps this honest: without it `:MONTH*2` expanded to
/// "August*2" and `:MONTHLY` to "AugustLY" — output that looks like data rather
/// than like the unhandled token it actually is.
final RegExp _literalPattern = RegExp(
  r':(MONTH_BEFORE|MONTH_AFTER|MONTHYEAR|MONTH'
  r'|YEAR_BEFORE|YEAR_AFTER|YEAR|QUARTER'
  r'|WEEK_BEFORE|WEEK_AHEAD|WEEK)(?![A-Za-z0-9_+\-*/])',
);
