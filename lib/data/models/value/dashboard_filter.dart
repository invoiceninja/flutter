import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/date_ranges.dart';

/// Date-range preset matching the React app's `GLOBAL_DATE_RANGES`. The
/// resolution to concrete `(start, end)` dates happens at request time so a
/// preset like `thisMonth` always means "today's month" rather than the month
/// the filter was originally created in.
enum DashboardDatePreset {
  last7,
  last30,
  last365,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisYear,
  lastYear,
  allTime;

  String get serverName {
    switch (this) {
      case DashboardDatePreset.last7:
        return 'last7_days';
      case DashboardDatePreset.last30:
        return 'last30_days';
      case DashboardDatePreset.last365:
        return 'last365_days';
      case DashboardDatePreset.thisMonth:
        return 'this_month';
      case DashboardDatePreset.lastMonth:
        return 'last_month';
      case DashboardDatePreset.thisQuarter:
        return 'this_quarter';
      case DashboardDatePreset.lastQuarter:
        return 'last_quarter';
      case DashboardDatePreset.thisYear:
        return 'this_year';
      case DashboardDatePreset.lastYear:
        return 'last_year';
      case DashboardDatePreset.allTime:
        return 'all_time';
    }
  }
}

/// Sealed sum type: a date range is either a preset or an explicit custom
/// `(start, end)` pair. The hash form encodes the kind + the resolved dates so
/// two filters with the same effective range share a cache row.
sealed class DashboardDateRange {
  const DashboardDateRange();

  /// Resolve to concrete `(start, end)` dates. `today` is passed in so unit
  /// tests can fix the calendar without monkey-patching `DateTime.now`.
  /// [firstMonthOfYear] (1=Jan..12=Dec) shifts the `thisYear` / `lastYear`
  /// presets onto the company's fiscal year; it's ignored by every other
  /// preset (quarters and months stay calendar-aligned).
  (Date start, Date end) resolve({Date? today, int firstMonthOfYear = 1}) {
    final t = today ?? Date.today();
    return _resolve(t, firstMonthOfYear);
  }

  (Date start, Date end) _resolve(Date today, int firstMonthOfYear);

  /// Canonical hash form — the kind plus the (final) resolved dates. Used by
  /// [DashboardFilter.filterHash] so a stale preset (e.g. "this month" cached
  /// last month) doesn't collide with the current one. The resolved dates fold
  /// in [firstMonthOfYear], so a fiscal-year change re-keys the cache.
  String hashSeed(Date today, int firstMonthOfYear) {
    final (start, end) = _resolve(today, firstMonthOfYear);
    return '$kind|${start.toIso()}|${end.toIso()}';
  }

  String get kind;
}

class DashboardPresetRange extends DashboardDateRange {
  const DashboardPresetRange(this.preset);
  final DashboardDatePreset preset;

  @override
  String get kind => 'preset:${preset.name}';

  @override
  (Date start, Date end) _resolve(Date today, int firstMonthOfYear) {
    final now = DateTime(today.year, today.month, today.day);
    switch (preset) {
      // Rolling windows use UTC date-space (Date.addDays) rather than
      // local-midnight − N×24h: the latter drifts across a spring-forward DST
      // day and resolves the start one calendar day early.
      case DashboardDatePreset.last7:
        return (today.addDays(-6), today);
      case DashboardDatePreset.last30:
        return (today.addDays(-29), today);
      case DashboardDatePreset.last365:
        return (today.addDays(-364), today);
      case DashboardDatePreset.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0);
        return _range(start, end);
      case DashboardDatePreset.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return _range(start, end);
      case DashboardDatePreset.thisQuarter:
        final q = ((now.month - 1) ~/ 3);
        final startMonth = q * 3 + 1;
        final start = DateTime(now.year, startMonth, 1);
        final end = DateTime(now.year, startMonth + 3, 0);
        return _range(start, end);
      case DashboardDatePreset.lastQuarter:
        final q = ((now.month - 1) ~/ 3) - 1;
        final yearOffset = q < 0 ? -1 : 0;
        final normalizedQ = q < 0 ? q + 4 : q;
        final startMonth = normalizedQ * 3 + 1;
        final start = DateTime(now.year + yearOffset, startMonth, 1);
        final end = DateTime(now.year + yearOffset, startMonth + 3, 0);
        return _range(start, end);
      case DashboardDatePreset.thisYear:
        // Fiscal-year aware: with firstMonthOfYear == 1 this is Jan 1 – Dec 31;
        // with e.g. 4 (April) it's Apr 1 – Mar 31. Quarters/months above stay
        // calendar-aligned (matches admin-portal + React).
        return (
          startOfFiscalYear(today, firstMonthOfYear),
          endOfFiscalYear(today, firstMonthOfYear),
        );
      case DashboardDatePreset.lastYear:
        // A day inside the previous fiscal year = this fiscal year's start − 1
        // (date-space, DST-safe — same idiom as endOfFiscalYear).
        final prev = startOfFiscalYear(today, firstMonthOfYear).addDays(-1);
        return (
          startOfFiscalYear(prev, firstMonthOfYear),
          endOfFiscalYear(prev, firstMonthOfYear),
        );
      case DashboardDatePreset.allTime:
        // 50-year window. The server tolerates this; React uses the same idiom.
        return _range(DateTime(now.year - 50, 1, 1), now);
    }
  }

  (Date start, Date end) _range(DateTime start, DateTime end) => (
    Date(start.year, start.month, start.day),
    Date(end.year, end.month, end.day),
  );
}

class DashboardCustomRange extends DashboardDateRange {
  const DashboardCustomRange({required this.start, required this.end});
  final Date start;
  final Date end;

  @override
  String get kind => 'custom';

  @override
  (Date start, Date end) _resolve(Date today, int firstMonthOfYear) =>
      (start, end);
}

/// Sentinel currency id for "All currencies" — matches the Invoice Ninja
/// admin-portal convention (`999` in the chart endpoints).
const int kDashboardCurrencyAll = 999;

/// Immutable bag of every choice the user can make on the dashboard. Hashed
/// to a stable id so cache rows survive process restarts.
class DashboardFilter {
  const DashboardFilter({
    required this.range,
    this.currencyId = kDashboardCurrencyAll,
    this.includeDrafts = false,
    this.firstMonthOfYear = 1,
  });

  factory DashboardFilter.defaults() => const DashboardFilter(
    range: DashboardPresetRange(DashboardDatePreset.thisMonth),
    currencyId: kDashboardCurrencyAll,
    includeDrafts: false,
  );

  final DashboardDateRange range;
  final int currencyId;
  final bool includeDrafts;

  /// Company `first_month_of_year` (1=Jan..12=Dec), stamped onto the filter by
  /// the dashboard VM from the active `Formatter`. Drives the fiscal-year
  /// shift of the `thisYear` / `lastYear` presets. NOT serialized (it's a
  /// company setting, re-injected each session) — but it IS folded into
  /// [filterHash] via the resolved dates, so changing the fiscal year re-keys
  /// the dashboard cache.
  final int firstMonthOfYear;

  /// Resolve the date range to concrete dates. The same `today` is used to
  /// derive [filterHash], so callers should pass the same value to both.
  (Date start, Date end) resolveDates({Date? today}) =>
      range.resolve(today: today, firstMonthOfYear: firstMonthOfYear);

  /// Stable, process-restart-safe hash. `v1|` prefix lets us evolve the
  /// filter schema without re-using cached entries.
  String filterHash({Date? today}) {
    final t = today ?? Date.today();
    final seed =
        'v1|${range.hashSeed(t, firstMonthOfYear)}|c=$currencyId|d=$includeDrafts';
    return sha1.convert(utf8.encode(seed)).toString().substring(0, 12);
  }

  DashboardFilter copyWith({
    DashboardDateRange? range,
    int? currencyId,
    bool? includeDrafts,
    int? firstMonthOfYear,
  }) {
    return DashboardFilter(
      range: range ?? this.range,
      currencyId: currencyId ?? this.currencyId,
      includeDrafts: includeDrafts ?? this.includeDrafts,
      firstMonthOfYear: firstMonthOfYear ?? this.firstMonthOfYear,
    );
  }

  Map<String, dynamic> toJson() => {
    'range': _rangeJson(range),
    'currencyId': currencyId,
    'includeDrafts': includeDrafts,
  };

  static DashboardFilter? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      final range = _rangeFromJson(raw['range']);
      if (range == null) return null;
      final cid = raw['currencyId'];
      final drafts = raw['includeDrafts'];
      return DashboardFilter(
        range: range,
        currencyId: cid is int
            ? cid
            : int.tryParse('$cid') ?? kDashboardCurrencyAll,
        includeDrafts: drafts is bool ? drafts : false,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _rangeJson(DashboardDateRange r) {
    if (r is DashboardPresetRange) {
      return {'kind': 'preset', 'preset': r.preset.name};
    }
    if (r is DashboardCustomRange) {
      return {'kind': 'custom', 'start': r.start.toIso(), 'end': r.end.toIso()};
    }
    throw StateError('Unknown range type: ${r.runtimeType}');
  }

  static DashboardDateRange? _rangeFromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['kind'];
    if (kind == 'preset') {
      final name = raw['preset'];
      final preset = DashboardDatePreset.values.firstWhere(
        (p) => p.name == name,
        orElse: () => DashboardDatePreset.thisMonth,
      );
      return DashboardPresetRange(preset);
    }
    if (kind == 'custom') {
      final start = Date.tryParse(raw['start']?.toString());
      final end = Date.tryParse(raw['end']?.toString());
      if (start == null || end == null) return null;
      return DashboardCustomRange(start: start, end: end);
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DashboardFilter &&
        other.currencyId == currencyId &&
        other.includeDrafts == includeDrafts &&
        other.firstMonthOfYear == firstMonthOfYear &&
        _rangesEqual(other.range, range);
  }

  @override
  int get hashCode => Object.hash(
    currencyId,
    includeDrafts,
    firstMonthOfYear,
    _rangeHashCode(range),
  );

  static bool _rangesEqual(DashboardDateRange a, DashboardDateRange b) {
    if (a is DashboardPresetRange && b is DashboardPresetRange) {
      return a.preset == b.preset;
    }
    if (a is DashboardCustomRange && b is DashboardCustomRange) {
      return a.start == b.start && a.end == b.end;
    }
    return false;
  }

  static int _rangeHashCode(DashboardDateRange r) {
    if (r is DashboardPresetRange) return Object.hash('preset', r.preset);
    if (r is DashboardCustomRange) return Object.hash('custom', r.start, r.end);
    return r.runtimeType.hashCode;
  }
}
