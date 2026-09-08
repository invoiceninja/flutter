import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';

void main() {
  group('DashboardCardConfig', () {
    test('the 19 field keys match the server allowlist exactly, in order', () {
      // Must stay in lockstep with `ShowCalculatedFieldRequest`'s `field` rule:
      // a field the server rejects is a 422 the picker happily lets you build,
      // and a field we omit is one the user simply cannot reach.
      expect(kDashboardCardFields, const [
        'active_invoices',
        'outstanding_invoices',
        'completed_payments',
        'refunded_payments',
        'active_quotes',
        'unapproved_quotes',
        'logged_tasks',
        'invoiced_tasks',
        'paid_tasks',
        'task_estimated_duration',
        'task_remaining_estimated_duration',
        'unestimated_tasks',
        'tasks_over_estimate',
        'overdue_tasks',
        'tasks_due',
        'logged_expenses',
        'pending_expenses',
        'invoiced_expenses',
        'invoice_paid_expenses',
      ]);
    });

    test('the field classes partition the task fields, and none overlap', () {
      for (final f in kTaskDurationCardFields) {
        expect(isDurationField(f), isTrue, reason: f);
        expect(isCountField(f), isFalse, reason: f);
        expect(isTaskField(f), isFalse, reason: '$f has a forced format');
      }
      for (final f in kTaskCountCardFields) {
        expect(isCountField(f), isTrue, reason: f);
        expect(isDurationField(f), isFalse, reason: f);
        // `overdue_tasks` and `unestimated_tasks` END IN `tasks` but are counts.
        // The old `endsWith('tasks')` heuristic called them task fields and
        // offered a format control, which the server rejects outright.
        expect(
          isTaskField(f),
          isFalse,
          reason: '$f is a count, not money/time',
        );
      }
    });

    test('forced format and calculation match the server rules', () {
      // TASK_DURATION_FIELDS: format must be `time`, calc must be sum|avg.
      for (final f in kTaskDurationCardFields) {
        expect(forcedFormatFor(f), CardFormat.time, reason: f);
        expect(allowedCalcsFor(f), const [
          CardCalc.sum,
          CardCalc.avg,
        ], reason: f);
        expect(forcedCalcFor(f), isNull, reason: '$f allows two calcs');
      }
      // TASK_COUNT_FIELDS: calc must be `count`, and `format` must be ABSENT —
      // which `CardFormat.none` encodes so the request builder omits the key.
      for (final f in kTaskCountCardFields) {
        expect(forcedFormatFor(f), CardFormat.none, reason: f);
        expect(forcedCalcFor(f), CardCalc.count, reason: f);
        expect(allowedCalcsFor(f), const [CardCalc.count], reason: f);
      }
      // Everything else is unconstrained.
      expect(forcedFormatFor('active_invoices'), isNull);
      expect(forcedCalcFor('active_invoices'), isNull);
      expect(allowedCalcsFor('active_invoices'), CardCalc.values);
    });

    test(
      'a stored key the server would now reject is repaired, not dropped',
      () {
        // A count field persisted with a money/sum tuple (only reachable from a
        // hand-edited nav_state, but it must not silently vanish).
        final count = DashboardCardConfig.tryParse(
          'overdue_tasks|current|sum|money',
        );
        expect(count, isNotNull);
        expect(count!.format, CardFormat.none);
        expect(count.calculate, CardCalc.count);
        expect(count.key, 'overdue_tasks|current|count|none');

        // A duration field must land on `time`, and `count` is not offered.
        final dur = DashboardCardConfig.tryParse(
          'task_estimated_duration|total|count|money',
        );
        expect(dur, isNotNull);
        expect(dur!.format, CardFormat.time);
        expect(dur.calculate, CardCalc.sum);
      },
    );

    test('a CardFormat.none card round-trips through the 4-part key', () {
      // The key's arity is load-bearing: `tryParse` rejects anything that is
      // not exactly four segments, so a count card must still encode a format
      // segment even though the wire request omits the field.
      const c = DashboardCardConfig(
        field: 'tasks_due',
        period: CardPeriod.previous,
        calculate: CardCalc.count,
        format: CardFormat.none,
      );
      expect(c.key.split('|'), hasLength(4));
      expect(c.key, 'tasks_due|previous|count|none');
      expect(DashboardCardConfig.tryParse(c.toJson()), c);
    });

    test('resolveFormatFor clears a sticky `none` off a money/time field', () {
      // The picker keeps `_format` across selections. Pick a count field
      // (format -> none), then pick `logged_tasks`: the naive
      // `forcedFormatFor(f) ?? (isTaskField(f) ? desired : money)` keeps the
      // `none`, because `isTaskField('logged_tasks')` is true. That builds
      // `logged_tasks|current|sum|none`, whose request omits `format` for a
      // field that requires it — a permanent 422 card that survives restart.
      expect(
        resolveFormatFor('logged_tasks', CardFormat.none),
        CardFormat.money,
      );
      // The user's real choice still survives on a money/time field.
      expect(
        resolveFormatFor('logged_tasks', CardFormat.time),
        CardFormat.time,
      );
      expect(
        resolveFormatFor('logged_tasks', CardFormat.money),
        CardFormat.money,
      );
      // Forced classes ignore the desired value entirely.
      expect(
        resolveFormatFor('overdue_tasks', CardFormat.time),
        CardFormat.none,
      );
      expect(
        resolveFormatFor('task_estimated_duration', CardFormat.money),
        CardFormat.time,
      );
      // A money-only field can never be anything else.
      for (final f in [CardFormat.time, CardFormat.none, CardFormat.money]) {
        expect(resolveFormatFor('active_invoices', f), CardFormat.money);
      }
    });

    test(
      'tryParse repairs a stored sticky-`none` key rather than keeping it',
      () {
        // Reachable from the picker bug above before it was fixed, so a real
        // user's nav_state can hold this.
        final c = DashboardCardConfig.tryParse('logged_tasks|current|sum|none');
        expect(c, isNotNull);
        expect(c!.format, CardFormat.money);
        expect(c.key, 'logged_tasks|current|sum|money');
      },
    );

    test('fieldLabelKey mirrors React FIELDS_LABELS (total_<field>)', () {
      expect(fieldLabelKey('active_invoices'), 'total_active_invoices');
      expect(
        fieldLabelKey('invoice_paid_expenses'),
        'total_invoice_paid_expenses',
      );
    });

    test('isTaskField only for the three money/time *_tasks fields', () {
      expect(isTaskField('logged_tasks'), isTrue);
      expect(isTaskField('invoiced_tasks'), isTrue);
      expect(isTaskField('paid_tasks'), isTrue);
      expect(isTaskField('active_invoices'), isFalse);
      expect(isTaskField('logged_expenses'), isFalse);
    });

    test('key round-trips through tryParse / toJson', () {
      const c = DashboardCardConfig(
        field: 'logged_tasks',
        period: CardPeriod.previous,
        calculate: CardCalc.avg,
        format: CardFormat.time,
      );
      expect(c.key, 'logged_tasks|previous|avg|time');
      expect(c.toJson(), c.key);
      final parsed = DashboardCardConfig.tryParse(c.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.key, c.key);
      expect(parsed == c, isTrue);
    });

    test('non-task field can never decode as time → coerced to money', () {
      final parsed = DashboardCardConfig.tryParse(
        'active_invoices|current|sum|time',
      );
      expect(parsed, isNotNull);
      expect(parsed!.format, CardFormat.money);
      expect(parsed.key, 'active_invoices|current|sum|money');
    });

    test('malformed / unknown inputs return null', () {
      expect(DashboardCardConfig.tryParse(null), isNull);
      expect(DashboardCardConfig.tryParse(42), isNull);
      expect(DashboardCardConfig.tryParse('a|b|c'), isNull); // wrong arity
      expect(
        DashboardCardConfig.tryParse('not_a_field|current|sum|money'),
        isNull,
      );
      expect(
        DashboardCardConfig.tryParse('active_invoices|bogus|sum|money'),
        isNull,
      );
    });

    test('equality + hashCode are key-based (dedupe works)', () {
      const a = DashboardCardConfig(
        field: 'active_invoices',
        period: CardPeriod.current,
        calculate: CardCalc.sum,
        format: CardFormat.money,
      );
      const b = DashboardCardConfig(
        field: 'active_invoices',
        period: CardPeriod.current,
        calculate: CardCalc.sum,
        format: CardFormat.money,
      );
      expect(a == b, isTrue);
      final deduped = <DashboardCardConfig>{};
      deduped.add(a);
      deduped.add(b);
      expect(deduped.length, 1);
    });
  });
}
