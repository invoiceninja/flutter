import 'package:intl/intl.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/formatting.dart';

/// Expands the server's reserved date keywords for *display*.
///
/// A product description or a document's terms can carry
/// `[MONTHYEAR|MONTHYEAR+12]`, which the server turns into "August 2026 to
/// August 2027" when it renders the invoice (`Helpers::processReservedKeywords`,
/// `app/Utils/Helpers.php:152-397`). Until then the raw token is what a list row
/// shows, and it reads as noise to anyone who didn't write it
/// (invoiceninja/flutter#93).
///
/// **Display only.** Never run this over text bound to an editable field — the
/// token is the value there, and expanding it would hand the user the rendered
/// string to save back.
///
/// Covers the half of the server's grammar that has one unambiguous reading:
///
///  * `[MONTHYEAR|MONTHYEAR]` and `[MONTHYEAR|MONTHYEAR+n]` ranges
///  * the bare literals `:MONTHYEAR`, `:MONTH`, `:YEAR`, `:QUARTER`
///  * the fixed-window ranges `:WEEK`, `:WEEK_BEFORE`, `:WEEK_AHEAD`,
///    `:MONTH_BEFORE`, `:MONTH_AFTER`, `:YEAR_BEFORE`, `:YEAR_AFTER`
///
/// **Arithmetic (`:MONTH+2`, `:QUARTER-1`, …) is left exactly as written**, and
/// not because upstream can't do the math — it wraps years and quarters
/// correctly. It's that the answers are wrong in ways we'd have to reproduce:
/// `:QUARTER+1` renders a bare `4` rather than `Q4` (`Helpers.php:370-388`,
/// contradicting the app's own help text, and pinned by upstream's unit test),
/// `:YEAR/4` renders `506.5`, `:WEEK+2` renders `2` and `:MONTH_BEFORE-1`
/// renders `7` (`:332-338` — `strtr` finds no numeric entry for those keys), and
/// `:MONTH+3` in November renders "February" with no year at all. A wrong date
/// reads as fact; a token reads as a token.
///
/// [separator] matches the server's own hardcoded, untranslated `' to '`
/// (`Helpers.php:289`). Deliberately *not* `tr('to')`: that key is the email
/// recipient label ("An" in German, "宛先" in Japanese).
String expandDatePlaceholders(
  String text, {
  Formatter? formatter,
  DateTime? now,
  String separator = 'to',
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

  // Day-1 arithmetic: unlike Carbon's, a month offset here can never overflow
  // into the following month (see BACKEND.md).
  DateTime monthsFromNow(int months) => DateTime(at.year, at.month + months);

  final today = Date(at.year, at.month, at.day);
  String window(Date from, Date to) =>
      '${formatter?.date(from.toIso()) ?? from.toIso()} $separator '
      '${formatter?.date(to.toIso()) ?? to.toIso()}';

  var out = text;

  // Ranges first, so a `[MONTHYEAR|…]` isn't half-eaten by the literal pass
  // below (the server orders it the same way, for the same reason).
  out = out.replaceAllMapped(
    _rangePattern,
    (m) =>
        '${monthYear(monthsFromNow(0))} $separator '
        '${monthYear(monthsFromNow(int.tryParse(m.group(1) ?? '') ?? 0))}',
  );

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

/// Month offset with Carbon's overflow semantics (Jan 31 + 1 month → Mar 3),
/// so a `_BEFORE` / `_AFTER` window lands on the same day the PDF will show.
Date _addMonths(Date d, int months) {
  final t = DateTime(d.year, d.month + months, d.day);
  return Date(t.year, t.month, t.day);
}

Date _addYears(Date d, int years) {
  final t = DateTime(d.year + years, d.month, d.day);
  return Date(t.year, t.month, t.day);
}

/// `[MONTHYEAR|MONTHYEAR]` or `[MONTHYEAR|MONTHYEAR+n]`. The offset group is
/// absent for the no-arithmetic form, which the server renders as the current
/// month on both sides.
///
/// Deliberately stricter than upstream, which accepts any right-hand side: its
/// `-` / `*` branch falls through and leaves the right side *empty*
/// ("August 2026 to "), and `[MONTHYEAR|MONTHYEAR/2]` builds a malformed
/// pattern that makes `preg_replace` return null and destroys the whole
/// description. Leaving those raw beats reproducing them.
final RegExp _rangePattern = RegExp(r'\[MONTHYEAR\|MONTHYEAR(?:\+(\d+))?\]');

/// A bare literal keyword and nothing else.
///
/// Alternation order is load-bearing — a regex alternation is leftmost-first,
/// not longest-first, so every `_BEFORE` / `_AFTER` / `_AHEAD` variant and
/// `MONTHYEAR` must precede the prefix it extends. (Upstream depends on the
/// same ordering, via the declaration order of its `literal` array.)
///
/// The lookahead is what keeps this honest: without it `:MONTH+2` expanded to
/// "August+2" and `:MONTHLY` to "AugustLY" — output that looks like data rather
/// than like the unhandled token it actually is.
final RegExp _literalPattern = RegExp(
  r':(MONTH_BEFORE|MONTH_AFTER|MONTHYEAR|MONTH'
  r'|YEAR_BEFORE|YEAR_AFTER|YEAR|QUARTER'
  r'|WEEK_BEFORE|WEEK_AHEAD|WEEK)(?![A-Za-z0-9_+\-*/])',
);
