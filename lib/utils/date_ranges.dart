import 'package:admin/data/models/value/date.dart';

/// Pure calendar math for fiscal-year and week boundaries, parameterized by the
/// company's `first_month_of_year` (1=Jan..12=Dec) and `first_day_of_week`
/// (0=Sun..6=Sat).
///
/// The fiscal-year rule mirrors `admin-portal/lib/utils/dates.dart`: only the
/// *year* shifts to start on `first_month_of_year` — quarters and months stay
/// calendar-aligned (so there are deliberately no fiscal-quarter helpers here).
/// Week shifting has no admin-portal precedent (the setting was inert there), so
/// the convention is defined by this module.
///
/// None of these touch `DateTime.now()` / `Date.today()` — callers pass `today`
/// so the functions stay deterministic and unit-testable.

/// Clamp a raw first-month value into 1..12, treating unset / `0` / garbage as
/// January (calendar year) — the sensible default for companies that never set
/// a fiscal year. (admin-portal feeds `0` straight into `DateTime`, which
/// normalizes month 0 to the previous December; we avoid that edge.)
int normalizeFirstMonthOfYear(int firstMonthOfYear) =>
    (firstMonthOfYear >= 1 && firstMonthOfYear <= 12) ? firstMonthOfYear : 1;

/// Clamp a raw first-day value into 0..6 (0=Sun..6=Sat), defaulting to Sunday.
int normalizeFirstDayOfWeek(int firstDayOfWeek) =>
    (firstDayOfWeek >= 0 && firstDayOfWeek <= 6) ? firstDayOfWeek : 0;

/// First day of the fiscal year that [today] falls in. With
/// `firstMonthOfYear == 1` this is `Jan 1` of [today]'s year (calendar year).
///
/// Mirrors admin-portal: `year = today.year - (firstMonthOfYear > today.month
/// ? 1 : 0)`.
Date startOfFiscalYear(Date today, int firstMonthOfYear) {
  final fm = normalizeFirstMonthOfYear(firstMonthOfYear);
  final year = today.month >= fm ? today.year : today.year - 1;
  return Date(year, fm, 1);
}

/// First day of the fiscal year immediately after the one [today] falls in.
Date startOfNextFiscalYear(Date today, int firstMonthOfYear) {
  final start = startOfFiscalYear(today, firstMonthOfYear);
  return Date(start.year + 1, start.month, 1);
}

/// Last calendar day of the fiscal year that [today] falls in (next fiscal-year
/// start minus one day). With `firstMonthOfYear == 1` this is `Dec 31`.
///
/// Date-space math (`Date.addDays`, UTC-anchored) — local-midnight − 24h
/// lands a day short when a spring-forward transition abuts the fiscal-year
/// start (e.g. April fiscal years in Europe), same DST class `startOfWeek`
/// below already guards against.
Date endOfFiscalYear(Date today, int firstMonthOfYear) =>
    startOfNextFiscalYear(today, firstMonthOfYear).addDays(-1);

/// First day of the week containing [d], where weeks start on [firstDayOfWeek]
/// (0=Sun..6=Sat). With `firstDayOfWeek == 0` this returns the Sunday of `d`'s
/// week — matching the existing Sunday-based chart/report defaults.
Date startOfWeek(Date d, int firstDayOfWeek) {
  final fd = normalizeFirstDayOfWeek(firstDayOfWeek);
  // DateTime.weekday: Mon=1..Sun=7 → Sunday-based index Sun=0..Sat=6.
  // UTC anchor + Date.addDays: the weekday of a pure date is
  // timezone-independent, and local-midnight − N×24h drifts across DST
  // transitions (shifting the transition week's edges by a day).
  final sundayBased = DateTime.utc(d.year, d.month, d.day).weekday % 7;
  final diff = (sundayBased - fd + 7) % 7;
  return d.addDays(-diff);
}

/// Last day of the week containing [d] (start of week + 6 days). With
/// `firstDayOfWeek == 0` this is the Saturday — identical to the previous
/// hardcoded `_weekEnd` in `chart_series_math.dart`.
Date endOfWeek(Date d, int firstDayOfWeek) =>
    startOfWeek(d, firstDayOfWeek).addDays(6);

/// First cell of the month grid for [month] (only its year+month matter): the
/// start-of-week (honoring [firstDayOfWeek]) of the 1st of the month. The grid
/// therefore begins on a weekday boundary, spilling into the previous month
/// when the 1st isn't itself the first day of the week.
Date startOfMonthGrid(Date month, int firstDayOfWeek) =>
    startOfWeek(Date(month.year, month.month, 1), firstDayOfWeek);

/// The 42 days (6 weeks) of [month]'s calendar grid, starting at
/// [startOfMonthGrid]. Fixed at 6 rows so the grid height never jumps between
/// months — 42 is the upper bound covering every month/first-day combination.
List<Date> monthGridDays(Date month, int firstDayOfWeek) {
  final start = startOfMonthGrid(month, firstDayOfWeek);
  return [for (var i = 0; i < 42; i++) start.addDays(i)];
}
