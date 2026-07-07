import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/date_ranges.dart';

Date _d(String iso) => Date.tryParse(iso)!;

void main() {
  group('startOfFiscalYear / endOfFiscalYear', () {
    test('firstMonthOfYear = 1 → calendar year', () {
      final today = _d('2026-06-03');
      expect(startOfFiscalYear(today, 1).toIso(), '2026-01-01');
      expect(endOfFiscalYear(today, 1).toIso(), '2026-12-31');
    });

    test('April fiscal year, today AFTER the fiscal start', () {
      final today = _d('2026-06-03'); // June ≥ April
      expect(startOfFiscalYear(today, 4).toIso(), '2026-04-01');
      expect(endOfFiscalYear(today, 4).toIso(), '2027-03-31');
    });

    test('April fiscal year, today BEFORE the fiscal start', () {
      final today = _d('2026-02-15'); // Feb < April → prior fiscal year
      expect(startOfFiscalYear(today, 4).toIso(), '2025-04-01');
      expect(endOfFiscalYear(today, 4).toIso(), '2026-03-31');
    });

    test('boundary: today is exactly the first day of the fiscal month', () {
      final today = _d('2026-04-01');
      expect(startOfFiscalYear(today, 4).toIso(), '2026-04-01');
    });

    test('July fiscal year', () {
      expect(startOfFiscalYear(_d('2026-06-03'), 7).toIso(), '2025-07-01');
      expect(endOfFiscalYear(_d('2026-06-03'), 7).toIso(), '2026-06-30');
      expect(startOfFiscalYear(_d('2026-07-01'), 7).toIso(), '2026-07-01');
    });

    test('endOfFiscalYear is date-space math — a March fiscal-year end must '
        'not come back a day short (the local-midnight − 24h idiom drifted '
        'across spring-forward when the transition abuts the FY start)', () {
      // March FY ends across a leap Feb and a non-leap Feb.
      expect(endOfFiscalYear(_d('2027-06-15'), 3).toIso(), '2028-02-29');
      expect(endOfFiscalYear(_d('2025-06-15'), 3).toIso(), '2026-02-28');
      // April FY end lands exactly on the last of March (the European
      // spring-forward month).
      expect(endOfFiscalYear(_d('2026-07-01'), 4).toIso(), '2027-03-31');
    });

    test('startOfNextFiscalYear', () {
      expect(startOfNextFiscalYear(_d('2026-06-03'), 4).toIso(), '2027-04-01');
      expect(startOfNextFiscalYear(_d('2026-06-03'), 1).toIso(), '2027-01-01');
    });

    test('unset / out-of-range first month falls back to January', () {
      final today = _d('2026-06-03');
      expect(startOfFiscalYear(today, 0).toIso(), '2026-01-01');
      expect(startOfFiscalYear(today, 13).toIso(), '2026-01-01');
      expect(startOfFiscalYear(today, -5).toIso(), '2026-01-01');
    });
  });

  group('startOfWeek / endOfWeek', () {
    // 2026-06-03 is a Wednesday.
    final wed = _d('2026-06-03');

    test('firstDayOfWeek = 0 (Sunday) → Sun..Sat, matches legacy _weekEnd', () {
      expect(startOfWeek(wed, 0).toIso(), '2026-05-31'); // Sunday
      expect(endOfWeek(wed, 0).toIso(), '2026-06-06'); // Saturday
    });

    test('firstDayOfWeek = 1 (Monday) → Mon..Sun', () {
      expect(startOfWeek(wed, 1).toIso(), '2026-06-01'); // Monday
      expect(endOfWeek(wed, 1).toIso(), '2026-06-07'); // Sunday
    });

    test('firstDayOfWeek = 6 (Saturday) → Sat..Fri', () {
      expect(startOfWeek(wed, 6).toIso(), '2026-05-30'); // Saturday
      expect(endOfWeek(wed, 6).toIso(), '2026-06-05'); // Friday
    });

    test('a date that is itself the week-start stays put', () {
      final sunday = _d('2026-05-31');
      expect(startOfWeek(sunday, 0).toIso(), '2026-05-31');
      final monday = _d('2026-06-01');
      expect(startOfWeek(monday, 1).toIso(), '2026-06-01');
    });

    test('out-of-range first day falls back to Sunday', () {
      expect(startOfWeek(wed, 7).toIso(), startOfWeek(wed, 0).toIso());
      expect(startOfWeek(wed, -1).toIso(), startOfWeek(wed, 0).toIso());
    });
  });

  group('normalizers', () {
    test('normalizeFirstMonthOfYear', () {
      expect(normalizeFirstMonthOfYear(1), 1);
      expect(normalizeFirstMonthOfYear(12), 12);
      expect(normalizeFirstMonthOfYear(0), 1);
      expect(normalizeFirstMonthOfYear(13), 1);
    });

    test('normalizeFirstDayOfWeek', () {
      expect(normalizeFirstDayOfWeek(0), 0);
      expect(normalizeFirstDayOfWeek(6), 6);
      expect(normalizeFirstDayOfWeek(7), 0);
      expect(normalizeFirstDayOfWeek(-1), 0);
    });
  });
}
