/// Number / date / address / URL formatting. Ported from
/// `admin-portal/lib/utils/formatting.dart` with these cleanups:
///
/// 1. No global state. The old code read company + statics from Redux and
///    mutated `numberFormatSymbols['custom']` on every call. This file is
///    pure: stateless helpers + a `Formatter` class bound to one company's
///    settings + statics maps.
/// 2. The `formatNumber` mega-function is split into one method per intent
///    (`money`, `percent`, `integer`, `decimal`, `inputMoney`, `inputAmount`).
///    The `FormatNumberType` enum is gone.
/// 3. `Decimal` is the input type for money methods (per the project rule
///    "Money is `Decimal`, never `double`"). Conversion to `double` happens
///    only at the final string-formatting step.
/// 4. Number grouping is hand-rolled (`_formatGrouped`) so it can take
///    separators directly — no `intl`'s `numberFormatSymbols` hijack.
library;

import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart' show BuildContext, TimeOfDay;
import 'package:intl/intl.dart';

import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/utils/address_format.dart';

// ---------------------------------------------------------------------------
// Pure utilities (no app state, no statics).
// ---------------------------------------------------------------------------

/// Round a double to [precision] decimal places. Carries forward the
/// floating-point workaround from
/// `admin-portal/lib/utils/formatting.dart:22-38` — e.g. `35 * 1.107` ends up
/// `38.745000000000001` and naïve rounding produces `38.74` instead of
/// `38.75`. Money in this codebase is `Decimal` so this helper is for
/// non-money use (percentages, ratios) only.
double round(double? value, int precision) {
  if (value == null || value.isNaN) return 0;
  final fac = pow(10, precision) as int;
  var result = value * fac;
  if ('$result'.contains('999999')) result += 0.000001;
  return result.round() / fac;
}

/// Parse a messy user-input string to `int`. Strips every non-digit and
/// non-sign character before parsing. Returns `null` when the input parses
/// to zero and [zeroIsNull] is set.
int? parseInt(String? value, {bool zeroIsNull = false}) {
  if (value == null) return zeroIsNull ? null : 0;
  final stripped = value.replaceAll(RegExp(r'[^0-9\-]'), '');
  final n = int.tryParse(stripped) ?? 0;
  return (n == 0 && zeroIsNull) ? null : n;
}

/// Parse a messy user-input string to `Decimal`. Handles thousand separators
/// and the "comma as decimal place" company setting (`1.234,56` → `1234.56`).
Decimal? parseDecimal(
  String? value, {
  bool zeroIsNull = false,
  bool useCommaAsDecimalPlace = false,
}) {
  if (value == null) return zeroIsNull ? null : Decimal.zero;
  var v = value;
  if (useCommaAsDecimalPlace && v.contains(',')) {
    v = v.replaceAll('.', '').replaceAll(',', '.');
  }
  v = v.replaceAll(RegExp(r'[^0-9\.\-]'), '');
  final n = Decimal.tryParse(v) ?? Decimal.zero;
  return (n == Decimal.zero && zeroIsNull) ? null : n;
}

/// Renders a `Decimal` for an editable input field: empty string for zero,
/// otherwise `.toString()`. Use this — not `.toString()` directly — when
/// seeding a `TextField`/`EntityEditField` from a non-nullable `Decimal`, so
/// blank/new forms don't display a stray `0` the user has to clear.
String decimalInputText(Decimal value) =>
    value == Decimal.zero ? '' : value.toString();

/// Renders a `double` tax/exchange rate: no trailing `.0`, and the company's
/// decimal separator (so `19.0` shows as `19`, and comma-locale users see
/// `19,5`). The display analog of [parseDouble].
///
/// `blankZero` (default `true`) returns `''` for zero — right for seeding an
/// editable field (no stray `0` to clear). Pass `false` for read-only summary
/// text where a literal `0` is meaningful (a zero-rated "VAT 0%").
String rateInputText(
  double value, {
  bool useCommaAsDecimalPlace = false,
  bool blankZero = true,
}) {
  if (value == 0 && blankZero) return '';
  final s = value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
  return useCommaAsDecimalPlace ? s.replaceAll('.', ',') : s;
}

/// Same as [parseDecimal] but returns `double`. Used for non-money inputs
/// (tax rates, exchange rates) where `Decimal` is overkill.
double? parseDouble(
  String? value, {
  bool zeroIsNull = false,
  bool useCommaAsDecimalPlace = false,
}) {
  if (value == null) return zeroIsNull ? null : 0.0;
  var v = value;
  if (useCommaAsDecimalPlace && v.contains(',')) {
    v = v.replaceAll('.', '').replaceAll(',', '.');
  }
  v = v.replaceAll(RegExp(r'[^0-9\.\-]'), '');
  final n = double.tryParse(v) ?? 0.0;
  return (n == 0 && zeroIsNull) ? null : n;
}

/// Human-readable file size. Matches `admin-portal:74-78` — KB / MB only,
/// rounded to one decimal, then int-truncated.
String formatSize(int size) => size > 1000000
    ? '${round(size / 1000000, 1).toInt()} MB'
    : '${round(size / 1000, 0).toInt()} KB';

/// Normalise a stored phone number into the RFC 3966 *global number* form a
/// `tel:` / `sms:` URI wants: an optional leading `+` followed by digits.
/// Returns `''` when nothing dialable is left, so callers can render plain
/// text instead of offering a dead tap.
///
/// Three rules, each of which exists because breaking it dials the WRONG
/// number rather than failing visibly:
///
///  * **A `+` before the first digit survives.** Without it `+1 415 555 2671`
///    is handed to the dialer as `14155552671`, which every carrier reads as a
///    *national* number. "Before the first digit", not "at position 0":
///    `(+1) 415-555-2671` and `Mobile: +44 20 7946 0018` are both ordinary
///    stored formats, and testing `startsWith('+')` drops the `+` from each.
///    (This function used to strip it unconditionally — it had no callers in
///    `lib/`, so that bug never shipped.)
///  * **An extension suffix is cut, not flattened.** `555-1234 x22` must not
///    become `555123422`. Dialers disagree on extension syntax (`,` pause,
///    `;ext=`, `w`), so the extension is dropped and the user dials it by
///    hand — a short call to the switchboard beats a wrong number.
///  * **A bracketed national trunk prefix after a country code is removed.**
///    `+44 (0)20 7946 0018` means "dial 020… domestically, +44 20… from
///    abroad"; keeping the `0` produces `+44020…`, which is not a number.
///
/// Finally, a result under [_minDialableDigits] digits is discarded. Free-text
/// in a phone field is common — `1-800-FLOWERS`, `Reception, dial 9 first` —
/// and stripping non-digits turns those into `1800` and `9`. That never
/// mattered while nothing dialled; now it would render an accent-coloured link
/// that hands the dialer a wrong number, so the floor is what keeps them
/// inert text.
String cleanPhoneNumber(String phoneNumber) {
  // `(0)` is only a trunk prefix when it follows a country code — a bare
  // `(0)` elsewhere is just punctuation and falls out with the rest below.
  final head = phoneNumber
      .trim()
      // `replaceFirstMapped`, not `replaceFirst` — Dart takes a String
      // replacement literally, so `r'$1'` would insert the two characters
      // `$1` and destroy the country code.
      .replaceFirstMapped(
        RegExp(r'^(\+\s*\d+)\s*\(\s*0\s*\)'),
        (m) => m.group(1)!,
      )
      // No `\b` before `x`: in `5551234x22` the digit and the `x` are both
      // word characters, so a boundary assertion never matches there.
      .split(RegExp(r'(?:ext\.?|x|#)\s*\d', caseSensitive: false))
      .first;
  final firstDigit = head.indexOf(RegExp(r'\d'));
  if (firstDigit < 0) return '';
  // A `+` anywhere ahead of the first digit is the international marker —
  // brackets, spaces and a `Mobile:` label all legitimately sit in front of it.
  final international = head.substring(0, firstDigit).contains('+');
  final digits = head.replaceAll(RegExp(r'\D'), '');
  if (digits.length < _minDialableDigits) return '';
  return international ? '+$digits' : digits;
}

/// Fewer digits than this and we assume the field holds prose, not a number.
///
/// Five is chosen to sit below every real subscriber number (the shortest
/// national ones run to six) and above what free text leaves behind once the
/// letters are stripped. It does mean a bare four-digit internal extension
/// won't be offered as a link — the right trade in a *client* phone field,
/// where dialling a truncated number is the worse outcome.
const int _minDialableDigits = 5;

/// Self-hosted users paste a base URL; this canonicalises it by stripping
/// trailing slashes and any pre-existing `/api/v1` suffix.
String cleanApiUrl(String? url) => (url ?? '')
    .trim()
    .replaceFirst(RegExp(r'/api/v1'), '')
    .replaceFirst(RegExp(r'/$'), '');

/// Build the full API base URL.
String formatApiUrl(String? url) {
  final clean = cleanApiUrl(url);
  return clean.isEmpty ? '' : '$clean/api/v1';
}

String convertDateTimeToSqlDate([DateTime? date]) =>
    (date ?? DateTime.now()).toIso8601String().split('T').first;

DateTime convertSqlDateToDateTime([String? date]) {
  final parts = (date ?? convertDateTimeToSqlDate()).split('-');
  // `parseInt` strips non-digit suffixes — admin-portal callers sometimes
  // feed timestamps like `'2024-05-11T15:42:00Z'` into this function, and
  // `int.parse` would throw on `parts[2]` whereas `parseInt` coerces.
  return DateTime.utc(
    parseInt(parts[0])!,
    parseInt(parts[1])!,
    parseInt(parts[2])!,
  );
}

DateTime convertTimestampToDate(int? timestamp) =>
    DateTime.fromMillisecondsSinceEpoch((timestamp ?? 0) * 1000, isUtc: true);

String convertTimestampToDateString(int? timestamp) => (timestamp ?? 0) == 0
    ? ''
    : convertTimestampToDate(timestamp).toIso8601String();

DateTime convertTimeOfDayToDateTime(
  TimeOfDay? timeOfDay, [
  DateTime? dateTime,
]) {
  final base = dateTime ?? DateTime.now();
  return DateTime(
    base.year,
    base.month,
    base.day,
    timeOfDay?.hour ?? 0,
    timeOfDay?.minute ?? 0,
  ).toUtc();
}

TimeOfDay convertDateTimeToTimeOfDay(DateTime? dateTime) =>
    TimeOfDay(hour: dateTime?.hour ?? 0, minute: dateTime?.minute ?? 0);

/// Format an hour/minute pair as a clock time, honoring [military] (24-hour
/// `HH:mm` vs 12-hour `h:mm AM/PM`).
///
/// Timezone-neutral by design: it renders the wall-clock fields exactly as
/// given, with NO UTC→local conversion. Use this for values that are already
/// local (a [TimeOfDay], or a local `DateTime`'s `.hour`/`.minute`). For a
/// server-UTC timestamp string, use `Formatter.date(value, showTime: true)`
/// instead — it does the UTC→local shift. Single source of truth for the
/// military-time choice across `InTimeField` and the task time-of-day displays.
String formatTimeOfDay(int hour, int minute, {required bool military}) {
  final mm = minute.toString().padLeft(2, '0');
  if (military) return '${hour.toString().padLeft(2, '0')}:$mm';
  final isPm = hour >= 12;
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$mm ${isPm ? 'PM' : 'AM'}';
}

/// "2m ago" / "3h ago" / "5d ago" / "2w ago" style label for a positive
/// [Duration] elapsed since a past event. Wraps the same five translation
/// keys the dashboard activity feed and System Logs both consume
/// (`just_now`, `minutes_ago_short`, `hours_ago_short`, `days_ago_short`,
/// `weeks_ago_short`).
String formatRelativeTime(BuildContext context, Duration elapsed) {
  if (elapsed.inSeconds < 60) return context.tr('just_now').toLowerCase();
  if (elapsed.inMinutes < 60) {
    return context.tr('minutes_ago_short', {
      'count': elapsed.inMinutes.toString(),
    });
  }
  if (elapsed.inHours < 24) {
    return context.tr('hours_ago_short', {'count': elapsed.inHours.toString()});
  }
  if (elapsed.inDays < 7) {
    return context.tr('days_ago_short', {'count': elapsed.inDays.toString()});
  }
  return context.tr('weeks_ago_short', {
    'count': (elapsed.inDays ~/ 7).toString(),
  });
}

/// `0:13:42` style formatter for a [Duration]. Matches old behaviour.
///
/// `showSeconds: false` truncates to `H:MM`. `compactDays: true` switches to
/// `Xd HHh MMm` once the elapsed time exceeds 24h — keeps the running label
/// readable on long-running tasks instead of `123:45:67`.
String formatDuration(
  Duration? duration, {
  bool showSeconds = true,
  bool compactDays = false,
}) {
  final d = duration ?? Duration.zero;
  if (compactDays && d.inHours >= 24) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    return '${days}d ${hours.toString().padLeft(2, '0')}h '
        '${minutes.toString().padLeft(2, '0')}m';
  }
  final time = d.toString().split('.').first;
  if (showSeconds) return time;
  final parts = time.split(':');
  return '${parts[0]}:${parts[1]}';
}

/// Parse a free-form user-typed duration string. Accepted forms:
///   * `1:30:00` / `1:30` — colon-separated `[H:]M[:S]` (`H:M`, `H:M:S`,
///     or `M:S`; ambiguity below).
///   * `1h 30m`, `90m`, `45s` — unit suffixes (`d`, `h`, `m`, `s`).
///   * `1`, `1.5`, `0.5` — bare number is interpreted as **hours**. So
///     `1` = 60 minutes; `1.5` = 90 minutes; `0.5` = 30 minutes. Matches
///     the old admin-portal `DurationPicker` and the "I worked 2 hours
///     → type `2`" mental model. To enter minutes use the `90m` suffix
///     form or the `0:90` colon form.
///
/// Colon disambiguation: `1:30` is read as `H:M` (1 hour 30 minutes), not
/// `M:S`, mirroring the React app. Use a leading `0:` for sub-hour values
/// (`0:01:30` = 1m 30s) — the same convention `formatDuration` writes.
///
/// Returns null for completely unparsable input (so the field can keep the
/// user's last valid value).
Duration? parseDurationInput(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  // Unit-suffix form: `1h 30m`, `45s`, `90m`, `2d`. Match every <num><unit>
  // pair in the string and sum.
  final unitRe = RegExp(r'(\d+(?:\.\d+)?)\s*(d|h|m|s)', caseSensitive: false);
  final unitMatches = unitRe.allMatches(input).toList();
  if (unitMatches.isNotEmpty) {
    var seconds = 0.0;
    for (final m in unitMatches) {
      final n = double.tryParse(m.group(1)!) ?? 0;
      final unit = m.group(2)!.toLowerCase();
      final factor = switch (unit) {
        'd' => 86400.0,
        'h' => 3600.0,
        'm' => 60.0,
        _ => 1.0,
      };
      seconds += n * factor;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  // Colon form: `1:30:00` / `1:30` / `0:01:30`.
  if (input.contains(':')) {
    final parts = input.split(':').map((p) => p.trim()).toList();
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: h, minutes: m, seconds: s);
    } else if (parts.length == 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return Duration(hours: h, minutes: m);
    }
    return null;
  }

  // Bare numeric form → hours. Matches the old admin-portal
  // convention plus the user's mental model ("I worked 2 hours" →
  // type `2`). To enter minutes, use `90m` or `0:90`.
  final asNum = double.tryParse(input.replaceAll(',', '.'));
  if (asNum == null) return null;
  return Duration(milliseconds: (asNum * 3600 * 1000).round());
}

/// Parse a user-typed date string. Returns the calendar date with no time
/// component — the caller anchors it to whichever `TimeOfDay` makes sense
/// (typically the existing entry's start time-of-day).
///
/// Tries patterns in order so the dominant locale's format wins for
/// ambiguous strings: ISO `yyyy-MM-dd` first, then the optional
/// [activePattern] (the company's `date_format_id` rendering — pass
/// `formatter.dateFormats[formatter.settings.dateFormatId]?.format`), then
/// a small fallback set covering US / EU short forms and `MMM d, yyyy`.
/// Returns `null` for unparseable input — UI uses `null` to silently
/// revert the cell to its last valid render.
///
/// [now] is a test seam so relative shortcuts (`today`, `+1`, bare day
/// `14`) can resolve against a fixed anchor in unit tests. Production
/// callers should leave it unset — `DateTime.now()` is the default.
DateTime? parseDateInput(String raw, {String? activePattern, DateTime? now}) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  // 1. Shortcut keywords: `today`, `tomorrow`, `yesterday`. Case-insensitive.
  final shortcut = _tryDateShortcut(
    input,
    activePattern: activePattern,
    now: now,
  );
  if (shortcut != null) return shortcut;

  // 2. Strict format patterns. ISO `yyyy-MM-dd` first so it always wins
  // against an ambiguous numeric string; remaining patterns cover the
  // dominant short-form locales plus the long `MMM d, yyyy` shape.
  // `parseStrict` rejects overflow (`2026-13-40`) rather than
  // normalizing the way `DateTime.tryParse` would.
  final patterns = <String>[
    'yyyy-MM-dd',
    if (activePattern != null && activePattern.isNotEmpty) activePattern,
    'M/d/yyyy',
    'MM/dd/yyyy',
    'd/M/yyyy',
    'dd/MM/yyyy',
    'MMM d, yyyy',
    'MMM d yyyy',
    'd MMM yyyy',
  ];

  for (final pattern in patterns) {
    try {
      final parsed = DateFormat(pattern).parseStrict(input);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } on FormatException {
      // Try the next pattern.
    } on ArgumentError {
      // Pattern itself was invalid — shouldn't happen for our list.
    }
  }
  return null;
}

/// Quick-shortcut paths checked first by [parseDateInput]: keywords,
/// signed offsets, bare day numbers, compact digit strings. Returns
/// `null` if no shortcut matched — the caller falls through to the
/// strict-pattern parser.
///
/// Mirrors the keyword/offset/compact set in
/// `admin-portal/lib/ui/app/forms/date_picker.dart:148-276` so users
/// who learned the shortcuts in the old app keep them in the new app.
DateTime? _tryDateShortcut(
  String input, {
  String? activePattern,
  DateTime? now,
}) {
  final today = _stripTime(now ?? DateTime.now());
  // Calendar-day offsets must be computed in date-space, not by adding
  // 24h multiples to a LOCAL midnight: across a fall-back DST transition
  // `local midnight + N×24h` lands at 23:00 of day N−1, so `+30` /
  // `tomorrow` resolved (and silently persisted) a date one day short.
  // UTC days are always exactly 24h; only the y/m/d of the result is used.
  DateTime addDays(int days) {
    final t = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).add(Duration(days: days));
    return DateTime(t.year, t.month, t.day);
  }

  // Keywords
  final lower = input.toLowerCase();
  if (lower == 'today' || lower == 'now') return today;
  if (lower == 'tomorrow') return addDays(1);
  if (lower == 'yesterday') return addDays(-1);

  // Signed integer offset — `+1`, `-7`, `+0`. Caps at ±9999 days.
  if (input.startsWith('+') || input.startsWith('-')) {
    final digits = input.substring(1);
    final n = int.tryParse(digits);
    if (n != null && n >= 0 && n <= 9999) {
      final sign = input.startsWith('-') ? -1 : 1;
      return addDays(sign * n);
    }
    return null;
  }

  // From here on, we need a pure-digit string (or one with a single
  // slash). Reject anything else so we don't accidentally swallow input
  // the strict patterns would prefer to handle.
  final monthFirst = (activePattern ?? '').startsWith('M');

  // Slash form: `D/M` or `M/D` with 1-2 digit parts, current year.
  if (input.contains('/') && !input.contains(' ')) {
    final parts = input.split('/');
    if (parts.length == 2 &&
        parts.every((p) => p.isNotEmpty && p.length <= 2)) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a != null && b != null) {
        final month = monthFirst ? a : b;
        final day = monthFirst ? b : a;
        return _safeDate(today.year, month, day);
      }
    }
  }

  // Pure-digit strings. Bare 1-2 digit = day of current month.
  if (RegExp(r'^\d+$').hasMatch(input)) {
    if (input.length <= 2) {
      final d = int.parse(input);
      return _safeDate(today.year, today.month, d);
    }
    if (input.length == 4) {
      // MMDD or DDMM, current year.
      final a = int.parse(input.substring(0, 2));
      final b = int.parse(input.substring(2, 4));
      final month = monthFirst ? a : b;
      final day = monthFirst ? b : a;
      return _safeDate(today.year, month, day);
    }
    if (input.length == 6) {
      // MMDDYY / DDMMYY. 2-digit year: <30 → 2000+yy, else 1900+yy.
      final a = int.parse(input.substring(0, 2));
      final b = int.parse(input.substring(2, 4));
      final yy = int.parse(input.substring(4, 6));
      final month = monthFirst ? a : b;
      final day = monthFirst ? b : a;
      final year = yy < 30 ? 2000 + yy : 1900 + yy;
      return _safeDate(year, month, day);
    }
    if (input.length == 8) {
      // MMDDYYYY / DDMMYYYY.
      final a = int.parse(input.substring(0, 2));
      final b = int.parse(input.substring(2, 4));
      final year = int.parse(input.substring(4, 8));
      final month = monthFirst ? a : b;
      final day = monthFirst ? b : a;
      return _safeDate(year, month, day);
    }
  }
  return null;
}

DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

/// Build a `DateTime` only when the given Y/M/D forms a real calendar
/// date. Out-of-range months/days return null instead of silently
/// overflowing (Dart's `DateTime(y, m, d)` normalizes invalid inputs).
DateTime? _safeDate(int year, int month, int day) {
  if (month < 1 || month > 12) return null;
  if (day < 1 || day > 31) return null;
  final candidate = DateTime(year, month, day);
  if (candidate.year != year ||
      candidate.month != month ||
      candidate.day != day) {
    return null;
  }
  return candidate;
}

/// Parse a user-typed time-of-day string. Accepts `HH:mm`, `H:mm`,
/// `h:mm a` (case-insensitive), and `h:mma` (no space before AM/PM).
/// Returns `null` for unparseable input.
TimeOfDay? parseTimeInput(String raw) {
  final input = raw.trim();
  if (input.isEmpty) return null;

  // 1. Strict format patterns first — `9:00 AM`, `09:30`, `14:30` etc.
  final normalized = input.toUpperCase();
  for (final pattern in const ['HH:mm', 'H:mm', 'h:mm a', 'h:mma']) {
    try {
      final parsed = DateFormat(pattern).parseStrict(normalized);
      return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    } on FormatException {
      // Try the next pattern.
    } on ArgumentError {
      // Try the next pattern.
    }
  }

  // 2. Compact digit shortcuts. Mirrors
  // `admin-portal/lib/ui/app/forms/time_picker.dart:136-214` — strip
  // everything but digits + `:`, take the AM/PM intent from the
  // presence of `a` / `p` (case-insensitive, before stripping), derive
  // HH:MM from the digit count.
  final lower = input.toLowerCase();
  final hasA = lower.contains('a');
  final hasP = lower.contains('p');
  final digits = lower.replaceAll(RegExp(r'[^\d:]'), '');
  if (digits.isEmpty) return null;

  int? hour;
  int? minute;
  if (digits.contains(':')) {
    final parts = digits.split(':');
    if (parts.length != 2) return null;
    hour = int.tryParse(parts[0]);
    minute = int.tryParse(parts[1]);
  } else if (digits.length == 1 || digits.length == 2) {
    // `9` / `12` → top of the hour.
    hour = int.tryParse(digits);
    minute = 0;
  } else if (digits.length == 3) {
    // `930` → 9:30.
    hour = int.tryParse(digits.substring(0, 1));
    minute = int.tryParse(digits.substring(1, 3));
  } else if (digits.length == 4) {
    // `0930` → 9:30.
    hour = int.tryParse(digits.substring(0, 2));
    minute = int.tryParse(digits.substring(2, 4));
  } else {
    return null;
  }

  if (hour == null || minute == null) return null;
  if (minute < 0 || minute >= 60) return null;
  if (hour < 0 || hour > 23) return null;

  // Apply AM/PM intent if the user typed a suffix letter. Without a
  // suffix, bare digits are interpreted as 24-hour (so `2` is 2 AM, not
  // 2 PM — matches the old app's behavior).
  if (hasP && !hasA && hour < 12) {
    hour += 12;
  } else if (hasA && !hasP && hour == 12) {
    hour = 0;
  }
  return TimeOfDay(hour: hour, minute: minute);
}

// ---------------------------------------------------------------------------
// Address.
// ---------------------------------------------------------------------------

/// Address bag passed to [Formatter.address]. Either billing or shipping —
/// the caller picks which set of fields belongs here.
class Address {
  const Address({
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.countryId = '',
  });

  final String address1;
  final String address2;
  final String city;
  final String state;
  final String postalCode;
  final String countryId;
}

// ---------------------------------------------------------------------------
// Formatter — bound to one company's settings + the cached statics maps.
// ---------------------------------------------------------------------------

/// Default ID for Euro in the Invoice Ninja statics bundle — used by
/// [Formatter.money] to apply the country-driven separator override that
/// admin-portal documents at `formatting.dart:160-169`.
const String _kCurrencyEuro = '3';

/// "All currencies" sentinel used in admin-portal filters; the formatter
/// treats it as "use company default" (`formatting.dart:122-123`).
const String kCurrencyAll = '-1';

class Formatter {
  Formatter({
    required this.settings,
    required this.currencies,
    required this.countries,
    required this.dateFormats,
  });

  final CompanyFormatSettings settings;
  final Map<String, Currency> currencies;
  final Map<String, Country> countries;
  final Map<String, DatetimeFormat> dateFormats;

  /// Memo for [money]'s currency+separator resolution, keyed by
  /// `'<resolvedCurrencyId>|<resolvedCountryId>'`. Safe because every
  /// field above is `final`/immutable for this instance's lifetime, and a
  /// `Formatter` is rebuilt per screen/company. `null` value = unknown
  /// currency (formats to `''`), cached so the miss isn't re-walked.
  final Map<String, (Currency, String, String, bool)?> _moneyResolveMemo = {};

  // -------------------------------------------------------------------------
  // Currency / country resolution.
  // -------------------------------------------------------------------------

  /// Resolve which currency to format with. Mirrors the cascade at
  /// `admin-portal/lib/utils/formatting.dart:122-134`: explicit override →
  /// client → vendor → group → company default.
  String _resolveCurrencyId({
    String? currencyId,
    String? clientCurrencyId,
    String? vendorCurrencyId,
    String? groupCurrencyId,
  }) {
    if (currencyId == kCurrencyAll) return settings.currencyId;
    if (currencyId != null && currencyId.isNotEmpty) return currencyId;
    if (clientCurrencyId != null && clientCurrencyId.isNotEmpty) {
      return clientCurrencyId;
    }
    if (vendorCurrencyId != null && vendorCurrencyId.isNotEmpty) {
      return vendorCurrencyId;
    }
    if (groupCurrencyId != null && groupCurrencyId.isNotEmpty) {
      return groupCurrencyId;
    }
    return settings.currencyId;
  }

  String _resolveCountryId({String? clientCountryId, String? vendorCountryId}) {
    if (clientCountryId != null && clientCountryId.isNotEmpty) {
      return clientCountryId;
    }
    if (vendorCountryId != null && vendorCountryId.isNotEmpty) {
      return vendorCountryId;
    }
    return settings.countryId;
  }

  /// Decimal precision of the resolved currency (client → vendor → group →
  /// company cascade), defaulting to 2 when the currency is unknown. Feed to
  /// `computeTotals` so its rounding matches what `money()` renders.
  int precisionFor({
    String? currencyId,
    String? clientCurrencyId,
    String? vendorCurrencyId,
    String? groupCurrencyId,
  }) {
    final id = _resolveCurrencyId(
      currencyId: currencyId,
      clientCurrencyId: clientCurrencyId,
      vendorCurrencyId: vendorCurrencyId,
      groupCurrencyId: groupCurrencyId,
    );
    return currencies[id]?.precision ?? 2;
  }

  // -------------------------------------------------------------------------
  // Money / numbers.
  // -------------------------------------------------------------------------

  /// Format a money amount. Returns `''` for null, and also for zero when
  /// [zeroIsNull] is set. Pass [clientCurrencyId] / [vendorCurrencyId] /
  /// [groupCurrencyId] to honour per-entity currency overrides.
  ///
  /// When [compact] is true, render the magnitude with a SI-style suffix
  /// (`12.3K`, `4.5M`) — used by the dashboard chart axis. The currency
  /// symbol / code prefix or suffix follows the same rules as the normal
  /// form. Compact display ignores [roundToPrecision].
  String money(
    Decimal? amount, {
    String? currencyId,
    String? clientCurrencyId,
    String? vendorCurrencyId,
    String? groupCurrencyId,
    String? clientCountryId,
    String? vendorCountryId,
    bool? showCurrencyCode,
    bool roundToPrecision = true,
    bool zeroIsNull = false,
    bool compact = false,
  }) {
    if (amount == null) return '';
    if (zeroIsNull && amount == Decimal.zero) return '';

    final resolvedCurrencyId = _resolveCurrencyId(
      currencyId: currencyId,
      clientCurrencyId: clientCurrencyId,
      vendorCurrencyId: vendorCurrencyId,
      groupCurrencyId: groupCurrencyId,
    );
    final resolvedCountryId = _resolveCountryId(
      clientCountryId: clientCountryId,
      vendorCountryId: vendorCountryId,
    );
    // Currency + separator resolution depends only on the resolved
    // currency/country ids (never on `amount`), and every `Formatter`
    // field is immutable for the instance's lifetime — so memoize it.
    // A money-heavy list page renders this block ~150×/scroll-frame
    // (50 rows × 3 columns) and would otherwise re-walk the currency map
    // + recompute separators each time (perf plan 6B counter-tension).
    final memo = _moneyResolveMemo.putIfAbsent(
      '$resolvedCurrencyId|$resolvedCountryId',
      () {
        final c = currencies[resolvedCurrencyId];
        if (c == null) return null;
        final (t, d, s) = _separators(
          currency: c,
          companyCurrency: currencies[settings.currencyId],
          country: countries[resolvedCountryId],
        );
        return (c, t, d, s);
      },
    );
    if (memo == null) return '';
    final (currency, thousandSep, decimalSep, swap) = memo;

    String body;
    String prefixSign;
    if (compact) {
      final (compactBody, compactSign) = _formatCompact(
        amount,
        decimal: decimalSep,
      );
      body = compactBody;
      prefixSign = compactSign;
    } else {
      final rounded = roundToPrecision
          ? Decimal.parse(amount.toStringAsFixed(currency.precision))
          : amount;
      // Trail up to 3 decimals beyond `precision` when we aren't rounding, to
      // preserve any extra precision in the input. Matches the old patterns
      // `#,##0.00###` etc.
      final maxDecimals = roundToPrecision
          ? currency.precision
          : currency.precision + 3;
      body = _formatGrouped(
        rounded.abs().toDouble(),
        minDecimals: currency.precision,
        maxDecimals: maxDecimals,
        thousand: thousandSep,
        decimal: decimalSep,
      );
      prefixSign = _signPrefix(rounded, body);
    }

    final showCode = showCurrencyCode ?? settings.showCurrencyCode;
    if (showCode || currency.symbol.isEmpty) {
      return '$prefixSign$body ${currency.code}';
    }
    if (swap) {
      return '$prefixSign$body ${currency.symbol.trim()}';
    }
    return '$prefixSign${currency.symbol}$body';
  }

  /// Compact body: `12.3K`, `4.5M`, `1.2B`. Returns `(body, signPrefix)`.
  /// Decimal separator is honored so European locales render `12,3K`.
  ///
  /// Implemented locally rather than via `NumberFormat.compactCurrency` so we
  /// keep the per-currency separator + swap-symbol cascade that `money`
  /// already resolves above.
  (String, String) _formatCompact(Decimal amount, {required String decimal}) {
    final value = amount.toDouble();
    final abs = value.abs();
    final sign = value < 0 ? '-' : '';
    String body;
    if (abs < 1000) {
      body = abs.toStringAsFixed(0);
    } else if (abs < 1000000) {
      body = '${(abs / 1000).toStringAsFixed(1).replaceFirst('.', decimal)}K';
    } else if (abs < 1000000000) {
      body =
          '${(abs / 1000000).toStringAsFixed(1).replaceFirst('.', decimal)}M';
    } else {
      body =
          '${(abs / 1000000000).toStringAsFixed(1).replaceFirst('.', decimal)}B';
    }
    // Strip trailing `.0` / `,0` for round magnitudes (`1.0K` → `1K`).
    if (body.length > 3 &&
        body.substring(body.length - 3, body.length - 1) == '${decimal}0') {
      body = '${body.substring(0, body.length - 3)}${body[body.length - 1]}';
    }
    // Don't prefix `-` if the rounded body collapsed to zero.
    final showSign = sign == '-' && !_isZeroString(body);
    return (body, showSign ? '-' : '');
  }

  /// Format a percentage value (the value is the percentage itself — pass
  /// `15.5` for "15.5%"). Always grouped, up to 5 fractional digits.
  String percent(num? value, {bool zeroIsNull = false}) {
    if (value == null) return '';
    if (zeroIsNull && value == 0) return '';
    final (thousand, decimal, _) = _separators(
      currency: currencies[settings.currencyId],
      companyCurrency: currencies[settings.currencyId],
      country: countries[settings.countryId],
    );
    final body = _formatGrouped(
      value.abs().toDouble(),
      minDecimals: 0,
      maxDecimals: 5,
      thousand: thousand,
      decimal: decimal,
    );
    final prefix = value < 0 && !_isZeroString(body) ? '-' : '';
    return '$prefix$body%';
  }

  /// Integer with thousand separators (e.g. `1,234`).
  String integer(num value) {
    final (thousand, decimal, _) = _separators(
      currency: currencies[settings.currencyId],
      companyCurrency: currencies[settings.currencyId],
      country: countries[settings.countryId],
    );
    final body = _formatGrouped(
      value.abs().toDouble(),
      minDecimals: 0,
      maxDecimals: 0,
      thousand: thousand,
      decimal: decimal,
    );
    final prefix = value < 0 && !_isZeroString(body) ? '-' : '';
    return '$prefix$body';
  }

  /// The company currency's display symbol (`$`, `€`, `CHF`), or `''` when the
  /// statics haven't resolved one. For chrome that sits *beside* a number
  /// rather than formatting it — a money field's `prefixText`, say — where
  /// [money] would fight the user's own typing.
  String get currencySymbol {
    final currency = currencies[settings.currencyId];
    final symbol = currency?.symbol.trim() ?? '';
    return symbol.isNotEmpty ? symbol : (currency?.code ?? '');
  }

  /// Decimal number with thousand separators. Defaults to natural precision
  /// (0–5 fraction digits); pass [minDecimals]/[maxDecimals] for a fixed
  /// money-style rendering without a currency symbol (e.g. 2/2 on the
  /// product detail figures, so a 10.00 price doesn't render as "10").
  String decimal(num value, {int minDecimals = 0, int maxDecimals = 5}) {
    final (thousand, decimal, _) = _separators(
      currency: currencies[settings.currencyId],
      companyCurrency: currencies[settings.currencyId],
      country: countries[settings.countryId],
    );
    final body = _formatGrouped(
      value.abs().toDouble(),
      minDecimals: minDecimals,
      maxDecimals: maxDecimals,
      thousand: thousand,
      decimal: decimal,
    );
    final prefix = value < 0 && !_isZeroString(body) ? '-' : '';
    return '$prefix$body';
  }

  /// Money formatted for an `<input>` field — no thousand separator, decimal
  /// separator follows the company's `use_comma_as_decimal_place` flag, and
  /// zero renders as `''`.
  String inputMoney(Decimal? value, {String? currencyId}) {
    if (value == null || value == Decimal.zero) return '';
    final resolved = _resolveCurrencyId(currencyId: currencyId);
    final currency = currencies[resolved] ?? currencies[settings.currencyId];
    final precision = currency?.precision ?? 2;
    final decimalSep = settings.useCommaAsDecimalPlace ? ',' : '.';
    final body = _formatGrouped(
      value.abs().toDouble(),
      minDecimals: precision,
      maxDecimals: precision,
      thousand: '',
      decimal: decimalSep,
    );
    final prefix = value < Decimal.zero && !_isZeroString(body) ? '-' : '';
    return '$prefix$body';
  }

  /// Generic numeric input — no thousand separator, no forced precision.
  String inputAmount(num? value) {
    if (value == null || value == 0) return '';
    final decimalSep = settings.useCommaAsDecimalPlace ? ',' : '.';
    final body = _formatGrouped(
      value.abs().toDouble(),
      minDecimals: 0,
      maxDecimals: 5,
      thousand: '',
      decimal: decimalSep,
    );
    final prefix = value < 0 && !_isZeroString(body) ? '-' : '';
    return '$prefix$body';
  }

  // -------------------------------------------------------------------------
  // Dates.
  // -------------------------------------------------------------------------

  /// Format an ISO date(time) string. Pattern is whichever the company's
  /// `date_format_id` resolves to in the statics bundle; falls back to
  /// `yyyy-MM-dd` if missing. Mirrors `admin-portal:421-470`, including the
  /// "double period" fix on line 469.
  String date(
    String? value, {
    bool showDate = true,
    bool showTime = false,
    bool showSeconds = true,
  }) {
    if (value == null || value.isEmpty) return '';

    final timeFormat = showSeconds
        ? (settings.enableMilitaryTime ? 'H:mm:ss' : 'h:mm:ss a')
        : (settings.enableMilitaryTime ? 'H:mm' : 'h:mm a');

    final datePattern = dateFormats[settings.dateFormatId]?.format;

    String? pattern;
    DateTime? parsed;
    if (showTime) {
      pattern = showDate
          ? '${datePattern ?? 'yyyy-MM-dd'} $timeFormat'
          : timeFormat;
      // Time values are server UTC; suffix `Z` if missing so DateTime.parse
      // doesn't treat them as local.
      parsed = DateTime.tryParse(
        value.endsWith('Z') ? value : '${value}Z',
      )?.toLocal();
    } else {
      pattern = datePattern ?? 'yyyy-MM-dd';
      parsed = DateTime.tryParse(value);
    }
    if (parsed == null) return '';

    final formatted = DateFormat(
      pattern,
      settings.locale.isEmpty ? null : settings.locale,
    ).format(parsed);
    // Foreign-language month abbreviations can produce `..` — see
    // admin-portal #527 / formatting.dart:469.
    return formatted.replaceFirst('..', '.');
  }

  /// `MMM d - MMM d, yyyy` range, year suppressed for the current year.
  String dateRange(String startIso, String endIso) {
    final start = DateTime.tryParse(startIso)?.toLocal();
    final end = DateTime.tryParse(endIso)?.toLocal();
    if (start == null || end == null) return '';
    final today = DateTime.now();
    final startPattern = today.year == start.year ? 'MMM d' : 'MMM d, yyyy';
    final endPattern = today.year == end.year ? 'MMM d' : 'MMM d, yyyy';
    final locale = settings.locale.isEmpty ? null : settings.locale;
    final s = DateFormat(startPattern, locale).format(start);
    final e = DateFormat(endPattern, locale).format(end);
    return '$s - $e';
  }

  /// Parse a user-entered date string using the company's date pattern,
  /// returning an ISO `yyyy-MM-dd` for storage. Returns `''` on bad input.
  String parseDate(String value) {
    if (value.isEmpty) return '';
    final pattern = dateFormats[settings.dateFormatId]?.format ?? 'yyyy-MM-dd';
    try {
      return convertDateTimeToSqlDate(
        DateFormat(
          pattern,
          settings.locale.isEmpty ? null : settings.locale,
        ).parse(value),
      );
    } catch (_) {
      return '';
    }
  }

  /// Parse a user-entered time string using the company's military-time
  /// preference. Pinned to `2000-01-01` so callers get just a time of day.
  DateTime? parseTime(String value) {
    if (value.isEmpty) return null;
    final showSeconds = ':'.allMatches(value).length >= 2;
    final fmt = showSeconds
        ? (settings.enableMilitaryTime ? 'H:mm:ss' : 'h:mm:ss a')
        : (settings.enableMilitaryTime ? 'H:mm' : 'h:mm a');
    try {
      return DateFormat(
        'y-M-d $fmt',
        settings.locale.isEmpty ? null : settings.locale,
      ).parse('2000-01-01 $value');
    } catch (_) {
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Address.
  // -------------------------------------------------------------------------

  /// Render a postal address. The country line is suppressed when it matches
  /// the company's default country (matches the old code at
  /// `formatting.dart:306-313`).
  String address(Address addr, {String delimiter = '\n'}) {
    final country = countries[addr.countryId];
    // Suppress the country line when it matches the company's default country.
    final showCountry =
        addr.countryId.isNotEmpty && addr.countryId != settings.countryId;
    return formatAddressLines(
      address1: addr.address1,
      address2: addr.address2,
      city: addr.city,
      state: addr.state,
      postalCode: addr.postalCode,
      swapPostalCode: country?.swapPostalCode ?? false,
      countryName: showCountry ? (country?.name ?? '') : '',
    ).join(delimiter);
  }

  /// Format a custom-field value. Type is one of `switch`, `date`, or
  /// anything else (returned as-is). Caller supplies `yes`/`no` strings
  /// already localised — this file doesn't depend on l10n.
  String? customValue({
    String? value,
    String? fieldType,
    required String yes,
    required String no,
  }) {
    switch (fieldType) {
      case 'switch':
        return value == 'yes' ? yes : no;
      case 'date':
        return date(value);
      default:
        return value;
    }
  }

  // -------------------------------------------------------------------------
  // Internals.
  // -------------------------------------------------------------------------

  /// Pick thousand / decimal separators and the swap-symbol flag for the
  /// *display* currency. Mirrors `admin-portal/lib/utils/formatting.dart:156-169`:
  ///
  /// - Thousand / decimal separators come from the display currency itself.
  /// - The initial `swap` flag comes from the *company's* default currency
  ///   (not the display currency). Admin-portal does this deliberately so a
  ///   foreign-currency display inherits the company's symbol-placement
  ///   convention.
  /// - For EUR specifically, the country's `swap_currency_symbol` /
  ///   separators override (EUR in Germany formats `1.234,56`; in Ireland
  ///   `1,234.56`).
  (String thousand, String decimal, bool swap) _separators({
    Currency? currency,
    Currency? companyCurrency,
    Country? country,
  }) {
    if (currency == null) return ('', '.', false);
    var thousand = currency.thousandSeparator;
    var decimal = currency.decimalSeparator;
    var swap =
        companyCurrency?.swapCurrencySymbol ?? currency.swapCurrencySymbol;
    if (currency.id == _kCurrencyEuro && country != null) {
      swap = country.swapCurrencySymbol;
      if (country.thousandSeparator.isNotEmpty) {
        thousand = country.thousandSeparator;
      }
      if (country.decimalSeparator.isNotEmpty) {
        decimal = country.decimalSeparator;
      }
    }
    return (thousand, decimal, swap);
  }

  String _signPrefix(Decimal rounded, String body) {
    if (rounded >= Decimal.zero) return '';
    // Prevent `-0.00` style display when rounding produced zero.
    if (_isZeroString(body)) return '';
    return '-';
  }
}

/// Group [value] with [thousand] every three digits and write [decimal]
/// before the fractional part. Always renders the absolute value — callers
/// add the sign themselves. [minDecimals] forces trailing zeros up to that
/// count; [maxDecimals] caps any extra precision.
String _formatGrouped(
  double value, {
  required int minDecimals,
  required int maxDecimals,
  required String thousand,
  required String decimal,
}) {
  final decimals = max(minDecimals, maxDecimals);
  final fixed = value.toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final intPart = dot < 0 ? fixed : fixed.substring(0, dot);
  var fracPart = dot < 0 ? '' : fixed.substring(dot + 1);
  while (fracPart.length > minDecimals && fracPart.endsWith('0')) {
    fracPart = fracPart.substring(0, fracPart.length - 1);
  }

  final buf = StringBuffer();
  final len = intPart.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(thousand);
    buf.write(intPart[i]);
  }
  if (fracPart.isNotEmpty) {
    buf.write(decimal);
    buf.write(fracPart);
  }
  return buf.toString();
}

/// True if [s] contains only `0`, `.`, or `,` — i.e. its numeric value is
/// zero. Used to suppress `-0.00` displays after rounding.
bool _isZeroString(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c != '0' && c != '.' && c != ',') return false;
  }
  return true;
}
