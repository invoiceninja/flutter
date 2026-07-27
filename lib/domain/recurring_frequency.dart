import 'package:admin/data/models/value/date.dart';

/// Recurring schedule frequency ids. Mirrors admin-portal
/// `constants.dart:1234-1247` (`kFrequencies`). Stored on the server as
/// a string in `frequency_id`.
const String kRecurringFrequencyDaily = '1';
const String kRecurringFrequencyWeekly = '2';
const String kRecurringFrequencyTwoWeeks = '3';
const String kRecurringFrequencyFourWeeks = '4';
const String kRecurringFrequencyMonthly = '5';
const String kRecurringFrequencyTwoMonths = '6';
const String kRecurringFrequencyThreeMonths = '7';
const String kRecurringFrequencyFourMonths = '8';
const String kRecurringFrequencySixMonths = '9';
const String kRecurringFrequencyAnnually = '10';
const String kRecurringFrequencyTwoYears = '11';
const String kRecurringFrequencyThreeYears = '12';

/// Localization keys for each frequency — `context.tr(kRecurringFrequencyLabelKey[id]!)`.
const Map<String, String> kRecurringFrequencyLabelKey = <String, String>{
  kRecurringFrequencyDaily: 'freq_daily',
  kRecurringFrequencyWeekly: 'freq_weekly',
  kRecurringFrequencyTwoWeeks: 'freq_two_weeks',
  kRecurringFrequencyFourWeeks: 'freq_four_weeks',
  kRecurringFrequencyMonthly: 'freq_monthly',
  kRecurringFrequencyTwoMonths: 'freq_two_months',
  kRecurringFrequencyThreeMonths: 'freq_three_months',
  kRecurringFrequencyFourMonths: 'freq_four_months',
  kRecurringFrequencySixMonths: 'freq_six_months',
  kRecurringFrequencyAnnually: 'freq_annually',
  kRecurringFrequencyTwoYears: 'freq_two_years',
  kRecurringFrequencyThreeYears: 'freq_three_years',
};

/// Convenient ordered list (matches the dropdown order users expect).
const List<String> kRecurringFrequencyOrdered = <String>[
  kRecurringFrequencyDaily,
  kRecurringFrequencyWeekly,
  kRecurringFrequencyTwoWeeks,
  kRecurringFrequencyFourWeeks,
  kRecurringFrequencyMonthly,
  kRecurringFrequencyTwoMonths,
  kRecurringFrequencyThreeMonths,
  kRecurringFrequencyFourMonths,
  kRecurringFrequencySixMonths,
  kRecurringFrequencyAnnually,
  kRecurringFrequencyTwoYears,
  kRecurringFrequencyThreeYears,
];

/// Compute the n-th send date for the UX preview chip on the edit screen.
///
/// Returns the date `n` recurrences after [start] for the given
/// [frequencyId]. Uses `DateTime` math; falls back to a single-day step
/// when the id is unknown so the UI degrades gracefully.
Date? nextSendAfter(Date start, String frequencyId, int n) {
  if (n < 0) return null;
  if (n == 0) return start;
  final dt = start.toDateTime();
  DateTime next;
  switch (frequencyId) {
    // Day-multiple steps use Date.addDays (UTC date-space) — local-midnight +
    // Duration(days:) lands at 23:00 of the prior day across a fall-back DST
    // transition, so the preview chip showed a send date one day early (L2).
    case kRecurringFrequencyDaily:
      next = start.addDays(n).toDateTime();
    case kRecurringFrequencyWeekly:
      next = start.addDays(7 * n).toDateTime();
    case kRecurringFrequencyTwoWeeks:
      next = start.addDays(14 * n).toDateTime();
    case kRecurringFrequencyFourWeeks:
      next = start.addDays(28 * n).toDateTime();
    // Month-based steps are applied ONE PERIOD AT A TIME, feeding each result
    // back in — never `start + (step × n)`. That's what the server does for
    // the MONTHLY family (the yearly ones differ — see below).
    // `RecurringInvoice::recurringDates()` loops
    // `$next_send_date = nextDateByFrequencyNoOffset($next_send_date)` over
    // Carbon's `addMonthNoOverflow`, which makes the month-end clamp STICKY:
    // Jan 31 monthly → Feb 28 → Mar 28 → Apr 28. Multiplying from the original
    // start let the day climb back (… → Mar 31), so every preview chip from the
    // third one on disagreed with the dates the server would actually send.
    case kRecurringFrequencyMonthly:
      next = _addMonthsRepeated(dt, 1, n);
    case kRecurringFrequencyTwoMonths:
      next = _addMonthsRepeated(dt, 2, n);
    case kRecurringFrequencyThreeMonths:
      next = _addMonthsRepeated(dt, 3, n);
    case kRecurringFrequencyFourMonths:
      next = _addMonthsRepeated(dt, 4, n);
    case kRecurringFrequencySixMonths:
      next = _addMonthsRepeated(dt, 6, n);
    // Yearly steps OVERFLOW rather than clamp — the server uses Carbon's
    // `addYear()` / `addYears(n)` for these three (NOT the `NoOverflow`
    // variants it uses for months), so Feb 29 + 1 year is Mar 1, not Feb 28.
    // Dart's `DateTime` normalizes out-of-range days the same way.
    case kRecurringFrequencyAnnually:
      next = DateTime(dt.year + n, dt.month, dt.day);
    case kRecurringFrequencyTwoYears:
      next = DateTime(dt.year + 2 * n, dt.month, dt.day);
    case kRecurringFrequencyThreeYears:
      next = DateTime(dt.year + 3 * n, dt.month, dt.day);
    default:
      return null;
  }
  return Date(next.year, next.month, next.day);
}

/// Apply a [step]-month advance [times] times, each from the PREVIOUS result.
/// The repetition is what makes the month-end clamp sticky, matching the
/// server's iterative `addMonthNoOverflow` loop — see [nextSendAfter].
DateTime _addMonthsRepeated(DateTime dt, int step, int times) {
  var out = dt;
  for (var i = 0; i < times; i++) {
    out = _addMonths(out, step);
  }
  return out;
}

/// Add [months] to [dt], clamping to the last valid day of the target
/// month. e.g. Jan 31 + 1 month → Feb 28/29 (avoids the DateTime
/// "rolls forward to March" surprise).
DateTime _addMonths(DateTime dt, int months) {
  final totalMonths = dt.month - 1 + months;
  // Floor division, not truncation: Dart's `%` is non-negative for a positive
  // divisor but `~/` truncates toward zero, so a negative [months] would land
  // in December of the SAME year instead of the previous one.
  final newYear = dt.year + ((totalMonths - (totalMonths % 12)) ~/ 12);
  final newMonth = (totalMonths % 12) + 1;
  // Last day of the new month — use the Day 0 of next-month trick.
  final lastDay = DateTime(newYear, newMonth + 1, 0).day;
  final clampedDay = dt.day > lastDay ? lastDay : dt.day;
  return DateTime(newYear, newMonth, clampedDay);
}
