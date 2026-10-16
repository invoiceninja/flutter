import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/date_ranges.dart';

/// The unit of a calendar-period token.
enum RelativePeriodUnit {
  week('w'),
  month('m'),
  quarter('q'),
  year('y');

  const RelativePeriodUnit(this.letter);

  final String letter;
}

/// A rolling date a list filter stores in place of a date, so a saved view
/// keeps meaning "this month" as time passes instead of freezing to the dates
/// it was made on. Resolved to an absolute value at query time — the server
/// and the database never see one (`resolveRelativeFilterTokens`).
///
/// **One token per bound.** A window is the ordinary three-part
/// `<column>,<start>,<end>` with a token in either slot — This month is
/// `date,rel:m0s,rel:m0e` — so the map-wide rewrite resolves it on the wire
/// unchanged, and every parser that reads a window's last two parts still
/// works. (A single period token in place of both would be read by those same
/// parsers as a two-part legacy window.)
///
/// | Token | Means |
/// |---|---|
/// | `rel:hN` | the instant N hours ago, written in UTC (`…Z`) |
/// | `rel:dN` | the date N days ago (`rel:d0` today) |
/// | `rel:<u><K><s\|e>[p]` | the first (`s`) or last (`e`) day of the week / month / quarter / year K periods ago — `0` this one, `1` the last, `-1` the next |
///
/// `p` is the period's calendar setting, captured when the chip is written:
/// the first day of the week (0 = Sunday … 6) for `w`, the first month of the
/// fiscal year (1 = January … 12) for `y`; omitted for the default, and not
/// allowed on `m` / `q`, which are always calendar months (the fiscal year
/// shifts the year only — `lib/utils/date_ranges.dart`). Capturing it keeps
/// resolution a pure function of the token, so the device and the server
/// read the same dates; the cost is that a chip made before the company
/// changed its fiscal year keeps the old one until it is picked again.
///
/// Day arithmetic goes through [Date.addDays], so a daylight-saving change in
/// the window cannot move a bound by a day.
sealed class RelativeDateToken {
  const RelativeDateToken();

  static final _pattern = RegExp(
    r'^rel:(?:([hd])(\d+)|([wmqy])(-?\d+)([se])(\d{1,2})?)$',
  );

  /// Matches anything shaped like a token inside a value, valid or not — so a
  /// value carrying a token this build cannot read is recognised and dropped
  /// rather than sent on as text.
  ///
  /// Only where a token can stand: the whole value (`rel:d0`), after an
  /// operator (`gte:rel:d7`), or as either bound of a window
  /// (`date,rel:m0s,rel:m0e`). Unanchored, it read `Laurel:north` — a client
  /// name or a custom value — as a token, failed to parse it, and dropped the
  /// filter from the fetch.
  static final inValue = RegExp(r'(?<=^|[:,])rel:[a-z0-9-]+(?=$|,)');

  /// Null when [token] is not a well-formed relative token.
  static RelativeDateToken? tryParse(String token) {
    final m = _pattern.firstMatch(token.trim());
    if (m == null) return null;
    final short = m.group(1);
    if (short != null) {
      final n = int.parse(m.group(2)!);
      return short == 'h' ? HoursAgoToken(n) : DaysAgoToken(n);
    }
    final unit = RelativePeriodUnit.values.firstWhere(
      (u) => u.letter == m.group(3),
    );
    final ago = int.parse(m.group(4)!);
    final end = m.group(5) == 'e';
    final param = m.group(6) == null ? null : int.parse(m.group(6)!);
    switch (unit) {
      case RelativePeriodUnit.week:
        if (param != null && param > 6) return null;
      case RelativePeriodUnit.year:
        if (param != null && (param < 1 || param > 12)) return null;
      case RelativePeriodUnit.month:
      case RelativePeriodUnit.quarter:
        if (param != null) return null;
    }
    return PeriodBoundToken(unit, ago: ago, end: end, param: param);
  }

  /// The token as it is stored.
  String get wire;

  /// The absolute value: an ISO `YYYY-MM-DD`, or for [HoursAgoToken] a UTC
  /// instant `YYYY-MM-DDTHH:mm:ssZ`.
  String resolve({DateTime? now});
}

/// `rel:hN`.
final class HoursAgoToken extends RelativeDateToken {
  const HoursAgoToken(this.hours);

  final int hours;

  @override
  String get wire => 'rel:h$hours';

  /// In UTC, with its `Z`: the server parses a time with no offset as UTC
  /// and binds it to SQL unconverted, so a local wall time was off by the
  /// device's UTC offset.
  @override
  String resolve({DateTime? now}) {
    final t = (now ?? DateTime.now()).toUtc().subtract(Duration(hours: hours));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}:${two(t.second)}Z';
  }
}

/// `rel:dN`.
final class DaysAgoToken extends RelativeDateToken {
  const DaysAgoToken(this.days);

  final int days;

  @override
  String get wire => 'rel:d$days';

  @override
  String resolve({DateTime? now}) => _today(now).addDays(-days).toIso();
}

/// `rel:<u><K><s|e>[p]`.
final class PeriodBoundToken extends RelativeDateToken {
  const PeriodBoundToken(
    this.unit, {
    required this.ago,
    required this.end,
    this.param,
  });

  final RelativePeriodUnit unit;

  /// Periods back from the current one; negative looks ahead.
  final int ago;

  /// The period's last day, else its first.
  final bool end;

  /// The week's first day or the fiscal year's first month; null for the
  /// default (Sunday, January).
  final int? param;

  @override
  String get wire => 'rel:${unit.letter}$ago${end ? 'e' : 's'}${param ?? ''}';

  @override
  String resolve({DateTime? now}) {
    final today = _today(now);
    final (start, last) = periodOf(today);
    return (end ? last : start).toIso();
  }

  /// The `[first, last]` days of the period this token's bound belongs to,
  /// relative to [today].
  (Date, Date) periodOf(Date today) {
    switch (unit) {
      case RelativePeriodUnit.week:
        final start = startOfWeek(today, param ?? 0).addDays(-7 * ago);
        return (start, start.addDays(6));
      case RelativePeriodUnit.month:
        return (
          _fromDateTime(DateTime.utc(today.year, today.month - ago, 1)),
          _fromDateTime(DateTime.utc(today.year, today.month - ago + 1, 0)),
        );
      case RelativePeriodUnit.quarter:
        final first = ((today.month - 1) ~/ 3) * 3 + 1 - 3 * ago;
        return (
          _fromDateTime(DateTime.utc(today.year, first, 1)),
          _fromDateTime(DateTime.utc(today.year, first + 3, 0)),
        );
      case RelativePeriodUnit.year:
        final current = startOfFiscalYear(today, param ?? 1);
        final start = Date(current.year - ago, current.month, 1);
        return (start, Date(start.year + 1, start.month, 1).addDays(-1));
    }
  }

  static Date _fromDateTime(DateTime d) => Date(d.year, d.month, d.day);
}

Date _today(DateTime? now) {
  final n = now ?? DateTime.now();
  return Date(n.year, n.month, n.day);
}

/// The calendar presets a date filter offers as rolling windows, by the label
/// key the menu shows them under.
enum RollingDatePreset {
  today('today'),
  yesterday('yesterday'),
  thisWeek('this_week'),
  lastWeek('last_week'),
  nextWeek('next_week'),
  thisMonth('this_month'),
  lastMonth('last_month'),
  nextMonth('next_month'),
  thisQuarter('this_quarter'),
  lastQuarter('last_quarter'),
  thisYear('this_year'),
  lastYear('last_year');

  const RollingDatePreset(this.labelKey);

  final String labelKey;

  /// The window's two bounds. [firstDayOfWeek] and [firstMonthOfYear] are
  /// written into the tokens that use them (see [PeriodBoundToken.param]).
  (String start, String end) bounds({
    int firstDayOfWeek = 0,
    int firstMonthOfYear = 1,
  }) {
    final week = normalizeFirstDayOfWeek(firstDayOfWeek);
    final fy = normalizeFirstMonthOfYear(firstMonthOfYear);
    (String, String) period(RelativePeriodUnit unit, int ago, [int? param]) => (
      PeriodBoundToken(unit, ago: ago, end: false, param: param).wire,
      PeriodBoundToken(unit, ago: ago, end: true, param: param).wire,
    );
    final weekParam = week == 0 ? null : week;
    final yearParam = fy == 1 ? null : fy;
    return switch (this) {
      RollingDatePreset.today => ('rel:d0', 'rel:d0'),
      RollingDatePreset.yesterday => ('rel:d1', 'rel:d1'),
      RollingDatePreset.thisWeek => period(
        RelativePeriodUnit.week,
        0,
        weekParam,
      ),
      RollingDatePreset.lastWeek => period(
        RelativePeriodUnit.week,
        1,
        weekParam,
      ),
      RollingDatePreset.nextWeek => period(
        RelativePeriodUnit.week,
        -1,
        weekParam,
      ),
      RollingDatePreset.thisMonth => period(RelativePeriodUnit.month, 0),
      RollingDatePreset.lastMonth => period(RelativePeriodUnit.month, 1),
      RollingDatePreset.nextMonth => period(RelativePeriodUnit.month, -1),
      RollingDatePreset.thisQuarter => period(RelativePeriodUnit.quarter, 0),
      RollingDatePreset.lastQuarter => period(RelativePeriodUnit.quarter, 1),
      RollingDatePreset.thisYear => period(
        RelativePeriodUnit.year,
        0,
        yearParam,
      ),
      RollingDatePreset.lastYear => period(
        RelativePeriodUnit.year,
        1,
        yearParam,
      ),
    };
  }

  /// The preset a stored window's bounds spell, whatever calendar setting
  /// they captured; null for any other window.
  static RollingDatePreset? of(String start, String end) {
    for (final preset in values) {
      final (s, e) = preset._shape();
      if (_sameShape(start, s) && _sameShape(end, e)) return preset;
    }
    return null;
  }

  (String, String) _shape() => bounds();

  /// Two bounds are the same preset bound when they differ at most in the
  /// captured calendar setting.
  static bool _sameShape(String stored, String preset) {
    final a = RelativeDateToken.tryParse(stored);
    final b = RelativeDateToken.tryParse(preset);
    if (a == null || b == null) return false;
    return switch ((a, b)) {
      (DaysAgoToken(:final days), DaysAgoToken(days: final other)) =>
        days == other,
      (
        PeriodBoundToken(unit: final u1, ago: final k1, end: final e1),
        PeriodBoundToken(unit: final u2, ago: final k2, end: final e2),
      ) =>
        u1 == u2 && k1 == k2 && e1 == e2,
      _ => false,
    };
  }
}
