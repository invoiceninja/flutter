import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/recurring_frequency.dart';

/// First coverage for `nextSendAfter` — the date math behind the "next sends"
/// preview chips on both the recurring-invoice and recurring-expense edit
/// screens.
///
/// Two things worth pinning:
///   * `_addMonths` clamps to the last valid day of the target month, so
///     Jan 31 + 1 month is Feb 28/29 rather than DateTime's roll-forward into
///     March. Month-end and leap-year handling is the classic failure mode.
///   * day-multiple steps deliberately go through `Date.addDays` (UTC
///     date-space) instead of local-midnight + `Duration(days:)`, which landed
///     at 23:00 of the prior day across a fall-back DST transition and showed
///     the send date one day early. The DST cases below are calendar-correct
///     under any host timezone; they additionally fail on a DST-observing
///     machine if that fix is ever reverted.
void main() {
  group('guard clauses', () {
    test('n == 0 returns the start date unchanged', () {
      const start = Date(2026, 3, 15);
      expect(nextSendAfter(start, kRecurringFrequencyMonthly, 0), start);
    });

    test('a negative n returns null', () {
      expect(nextSendAfter(const Date(2026, 3, 15), '1', -1), isNull);
    });

    test('an unknown frequency id returns null', () {
      expect(
        nextSendAfter(const Date(2026, 3, 15), 'not-a-frequency', 1),
        isNull,
      );
    });

    test('every id in kRecurringFrequencyOrdered resolves to a date', () {
      for (final id in kRecurringFrequencyOrdered) {
        expect(
          nextSendAfter(const Date(2026, 1, 15), id, 1),
          isNotNull,
          reason: 'frequency $id fell through to the null default',
        );
      }
    });
  });

  group('day-multiple steps', () {
    const start = Date(2026, 3, 15);

    test('daily', () {
      expect(
        nextSendAfter(start, kRecurringFrequencyDaily, 1),
        Date(2026, 3, 16),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyDaily, 10),
        Date(2026, 3, 25),
      );
    });

    test('weekly / two weeks / four weeks', () {
      expect(
        nextSendAfter(start, kRecurringFrequencyWeekly, 1),
        Date(2026, 3, 22),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyTwoWeeks, 1),
        Date(2026, 3, 29),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyFourWeeks, 1),
        Date(2026, 4, 12),
      );
    });

    test('day steps roll across a month boundary', () {
      expect(
        nextSendAfter(const Date(2026, 1, 30), kRecurringFrequencyDaily, 3),
        Date(2026, 2, 2),
      );
    });

    test('n > 1 multiplies the step', () {
      expect(
        nextSendAfter(start, kRecurringFrequencyWeekly, 3),
        Date(2026, 4, 5),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyFourWeeks, 2),
        Date(2026, 5, 10),
      );
    });
  });

  group('DST transitions do not shift the calendar date', () {
    test('across US spring-forward (Mar 8 2026)', () {
      expect(
        nextSendAfter(const Date(2026, 3, 7), kRecurringFrequencyDaily, 1),
        Date(2026, 3, 8),
      );
      expect(
        nextSendAfter(const Date(2026, 3, 7), kRecurringFrequencyWeekly, 1),
        Date(2026, 3, 14),
      );
    });

    test('across US fall-back (Nov 1 2026)', () {
      expect(
        nextSendAfter(const Date(2026, 10, 31), kRecurringFrequencyDaily, 1),
        Date(2026, 11, 1),
      );
      expect(
        nextSendAfter(const Date(2026, 10, 28), kRecurringFrequencyWeekly, 1),
        Date(2026, 11, 4),
      );
    });
  });

  group('month-multiple steps clamp to the last valid day', () {
    test('Jan 31 + 1 month lands on Feb 28 in a common year', () {
      expect(
        nextSendAfter(const Date(2026, 1, 31), kRecurringFrequencyMonthly, 1),
        Date(2026, 2, 28),
      );
    });

    test('Jan 31 + 1 month lands on Feb 29 in a leap year', () {
      expect(
        nextSendAfter(const Date(2028, 1, 31), kRecurringFrequencyMonthly, 1),
        Date(2028, 2, 29),
      );
    });

    test('Mar 31 + 1 month lands on Apr 30, not May 1', () {
      expect(
        nextSendAfter(const Date(2026, 3, 31), kRecurringFrequencyMonthly, 1),
        Date(2026, 4, 30),
      );
    });

    test('clamping does not stick — Jan 31 + 2 months is Mar 31', () {
      expect(
        nextSendAfter(const Date(2026, 1, 31), kRecurringFrequencyMonthly, 2),
        Date(2026, 3, 31),
      );
    });

    test('two / three / four / six months', () {
      const start = Date(2026, 1, 15);
      expect(
        nextSendAfter(start, kRecurringFrequencyTwoMonths, 1),
        Date(2026, 3, 15),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyThreeMonths, 1),
        Date(2026, 4, 15),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyFourMonths, 1),
        Date(2026, 5, 15),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencySixMonths, 1),
        Date(2026, 7, 15),
      );
    });
  });

  group('year rollover', () {
    test('Dec + 1 month crosses into the next January', () {
      expect(
        nextSendAfter(const Date(2026, 12, 15), kRecurringFrequencyMonthly, 1),
        Date(2027, 1, 15),
      );
    });

    test('six months from October crosses the year', () {
      expect(
        nextSendAfter(const Date(2026, 10, 5), kRecurringFrequencySixMonths, 1),
        Date(2027, 4, 5),
      );
    });

    test('annually / two years / three years', () {
      const start = Date(2026, 6, 30);
      expect(
        nextSendAfter(start, kRecurringFrequencyAnnually, 1),
        Date(2027, 6, 30),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyTwoYears, 1),
        Date(2028, 6, 30),
      );
      expect(
        nextSendAfter(start, kRecurringFrequencyThreeYears, 1),
        Date(2029, 6, 30),
      );
    });

    test('annually from Feb 29 clamps to Feb 28 in the following year', () {
      expect(
        nextSendAfter(const Date(2028, 2, 29), kRecurringFrequencyAnnually, 1),
        Date(2029, 2, 28),
      );
    });

    test('n > 1 on a yearly step', () {
      expect(
        nextSendAfter(const Date(2026, 6, 30), kRecurringFrequencyAnnually, 3),
        Date(2029, 6, 30),
      );
    });
  });
}
