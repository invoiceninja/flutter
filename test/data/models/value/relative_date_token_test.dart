import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/relative_date_token.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures sit at local noon, far from a day boundary in any zone.
DateTime _at(int y, int m, int d) => DateTime(y, m, d, 12);

String? _r(String token, DateTime now) =>
    RelativeDateToken.tryParse(token)?.resolve(now: now);

void main() {
  group('grammar', () {
    test('every token reads back as itself', () {
      for (final t in const [
        'rel:h1',
        'rel:h24',
        'rel:d0',
        'rel:d30',
        'rel:w0s',
        'rel:w1e1',
        'rel:w-1s6',
        'rel:m0s',
        'rel:m12e',
        'rel:q1s',
        'rel:y0s',
        'rel:y1e4',
        'rel:y-1s12',
      ]) {
        expect(RelativeDateToken.tryParse(t)?.wire, t, reason: t);
      }
    });

    test('a malformed token is no token', () {
      for (final t in const [
        'rel:x9',
        'rel:m0x',
        'rel:m0s3', // months take no setting
        'rel:q0s3',
        'rel:w0s9', // there is no ninth weekday
        'rel:y0s13',
        'rel:y0s0',
        'rel:h',
        '2026-01-01',
        '',
      ]) {
        expect(RelativeDateToken.tryParse(t), isNull, reason: t);
      }
    });
  });

  group('resolution', () {
    final now = _at(2026, 10, 16); // a Friday

    test('days', () {
      expect(_r('rel:d0', now), '2026-10-16');
      expect(_r('rel:d7', now), '2026-10-09');
    });

    // Run under TZ=Europe/London to see it: clocks went forward on 29 March,
    // and 7 × 24 h back from 00:30 the next night lands on the 22nd.
    test('a day count does not slip across a daylight-saving change', () {
      expect(_r('rel:d7', DateTime(2026, 3, 30, 0, 30)), '2026-03-23');
    });

    test('hours are a UTC instant', () {
      final utc = DateTime.utc(2026, 10, 16, 12);
      expect(_r('rel:h1', utc), '2026-10-16T11:00:00Z');
    });

    test('weeks start on the captured day', () {
      expect(_r('rel:w0s', now), '2026-10-11'); // Sunday
      expect(_r('rel:w0e', now), '2026-10-17');
      expect(_r('rel:w0s1', now), '2026-10-12'); // Monday
      expect(_r('rel:w0e1', now), '2026-10-18');
      expect(_r('rel:w1s1', now), '2026-10-05');
      expect(_r('rel:w-1e1', now), '2026-10-25');
    });

    test('months roll over the year', () {
      final january = _at(2026, 1, 10);
      expect(_r('rel:m1s', january), '2025-12-01');
      expect(_r('rel:m1e', january), '2025-12-31');
      expect(_r('rel:m-1e', january), '2026-02-28');
    });

    test('a leap February', () {
      expect(_r('rel:m0e', _at(2028, 2, 10)), '2028-02-29');
    });

    test('quarters roll over the year', () {
      final february = _at(2026, 2, 10);
      expect(_r('rel:q1s', february), '2025-10-01');
      expect(_r('rel:q1e', february), '2025-12-31');
      expect(_r('rel:q-1s', _at(2026, 11, 1)), '2027-01-01');
    });

    test('a fiscal year starts on its captured month', () {
      expect(_r('rel:y0s4', now), '2026-04-01');
      expect(_r('rel:y0e4', now), '2027-03-31');
      expect(_r('rel:y0s4', _at(2026, 2, 1)), '2025-04-01');
      expect(_r('rel:y1s4', now), '2025-04-01');
      expect(_r('rel:y1e4', now), '2026-03-31');
    });

    test('this / last month, quarter and year agree with the dashboard', () {
      final pairs = <RollingDatePreset, DashboardDatePreset>{
        RollingDatePreset.thisMonth: DashboardDatePreset.thisMonth,
        RollingDatePreset.lastMonth: DashboardDatePreset.lastMonth,
        RollingDatePreset.thisQuarter: DashboardDatePreset.thisQuarter,
        RollingDatePreset.lastQuarter: DashboardDatePreset.lastQuarter,
        RollingDatePreset.thisYear: DashboardDatePreset.thisYear,
        RollingDatePreset.lastYear: DashboardDatePreset.lastYear,
      };
      for (final day in [
        _at(2026, 1, 1),
        _at(2026, 3, 31),
        _at(2026, 4, 15),
        _at(2026, 12, 31),
        _at(2028, 2, 29),
      ]) {
        for (final fy in const [1, 4, 7]) {
          for (final MapEntry(key: rolling, value: dashboard)
              in pairs.entries) {
            final (s, e) = rolling.bounds(firstMonthOfYear: fy);
            final (ds, de) = DashboardPresetRange(dashboard).resolve(
              today: Date(day.year, day.month, day.day),
              firstMonthOfYear: fy,
            );
            final label = '$rolling on $day, fiscal $fy';
            expect(_r(s, day), ds.toIso(), reason: label);
            expect(_r(e, day), de.toIso(), reason: label);
          }
        }
      }
    });
  });

  group('presets', () {
    test('a stored window names its preset, whatever setting it captured', () {
      final (s, e) = RollingDatePreset.lastWeek.bounds(firstDayOfWeek: 1);
      expect(s, 'rel:w1s1');
      expect(RollingDatePreset.of(s, e), RollingDatePreset.lastWeek);
      expect(
        RollingDatePreset.of('rel:y0s4', 'rel:y0e4'),
        RollingDatePreset.thisYear,
      );
      expect(RollingDatePreset.of('rel:d0', 'rel:d0'), RollingDatePreset.today);
      expect(RollingDatePreset.of('rel:d6', 'rel:d0'), isNull);
      expect(RollingDatePreset.of('2026-01-01', '2026-01-31'), isNull);
    });

    test('the defaults are left out of the token', () {
      expect(RollingDatePreset.thisWeek.bounds(), ('rel:w0s', 'rel:w0e'));
      expect(RollingDatePreset.thisYear.bounds(), ('rel:y0s', 'rel:y0e'));
    });
  });
}
