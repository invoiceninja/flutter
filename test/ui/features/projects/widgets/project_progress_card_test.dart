import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_progress_card.dart';

// ---------------------------------------------------------------------------
// Fixture helpers — minimal stand-ins for Task / TimeEntry.
// ---------------------------------------------------------------------------

Task _task(List<TimeEntry> entries, {String id = 't1'}) => Task(
  id: id,
  number: '',
  description: '',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: 'p1',
  statusId: '',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: entries,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime.utc(2026, 5, 1),
  createdAt: DateTime.utc(2026, 5, 1),
  archivedAt: null,
  isDeleted: false,
);

TimeEntry _entry(DateTime start, DateTime? stop, {bool billable = true}) =>
    TimeEntry(start: start, stop: stop, billable: billable);

void main() {
  group('buildCumulativeSeries', () {
    test('empty input → empty series', () {
      expect(buildCumulativeSeries(const [], DateTime(2026, 5, 14)), isEmpty);
    });

    test('only non-billable entries are excluded', () {
      final tasks = [
        _task([
          _entry(
            DateTime(2026, 5, 10, 9),
            DateTime(2026, 5, 10, 11),
            billable: false,
          ),
        ]),
      ];
      expect(buildCumulativeSeries(tasks, DateTime(2026, 5, 14)), isEmpty);
    });

    test('single closed billable entry → one bucket at end-day', () {
      final tasks = [
        _task([
          _entry(DateTime(2026, 5, 10, 9), DateTime(2026, 5, 10, 11, 30)),
        ]),
      ];
      final series = buildCumulativeSeries(tasks, DateTime(2026, 5, 14));
      expect(series, hasLength(1));
      expect(series.first.t, DateTime(2026, 5, 10));
      expect(series.first.hours, closeTo(2.5, 1e-9));
    });

    test('UTC entries bucket by the user local calendar day', () {
      // Reproduces a real wire-format entry — TimeEntry.fromWire builds UTC
      // DateTimes via `epochSecondsToUtc`. A 9 PM local entry has a UTC
      // timestamp that crosses midnight in many zones; bucketing by .y/.m/.d
      // *without* .toLocal() would land it on the next day.
      final stop = DateTime(2026, 5, 14, 21).toUtc();
      final start = stop.subtract(const Duration(hours: 2));
      final tasks = [
        _task([_entry(start, stop)]),
      ];
      final series = buildCumulativeSeries(tasks, DateTime(2026, 5, 16));
      expect(series, hasLength(1));
      // Local-day bucket must be May 14 (local), not whichever date the UTC
      // y/m/d happen to resolve to.
      expect(series.first.t, DateTime(2026, 5, 14));
      expect(series.first.hours, closeTo(2.0, 1e-9));
    });

    test('running entry contributes (start..now)', () {
      final now = DateTime(2026, 5, 14, 12);
      final tasks = [
        _task([_entry(DateTime(2026, 5, 14, 10), null)]),
      ];
      final series = buildCumulativeSeries(tasks, now);
      expect(series, hasLength(1));
      expect(series.first.t, DateTime(2026, 5, 14));
      expect(series.first.hours, closeTo(2.0, 1e-9));
    });

    test('multiple tasks → sorted ascending, cumulative monotonic', () {
      final tasks = [
        _task([
          _entry(DateTime(2026, 5, 12, 9), DateTime(2026, 5, 12, 10)), // 1h
        ], id: 't1'),
        _task([
          _entry(DateTime(2026, 5, 10, 9), DateTime(2026, 5, 10, 12)), // 3h
        ], id: 't2'),
        _task([
          _entry(
            DateTime(2026, 5, 11, 9),
            DateTime(2026, 5, 11, 10, 30),
          ), // 1.5h
        ], id: 't3'),
      ];
      final series = buildCumulativeSeries(tasks, DateTime(2026, 5, 14));
      expect(series.map((p) => p.t).toList(), [
        DateTime(2026, 5, 10),
        DateTime(2026, 5, 11),
        DateTime(2026, 5, 12),
      ]);
      expect(series[0].hours, closeTo(3.0, 1e-9));
      expect(series[1].hours, closeTo(4.5, 1e-9));
      expect(series[2].hours, closeTo(5.5, 1e-9));
    });

    test('same-day entries merge into one bucket', () {
      final tasks = [
        _task([
          _entry(DateTime(2026, 5, 10, 9), DateTime(2026, 5, 10, 10)),
          _entry(DateTime(2026, 5, 10, 14), DateTime(2026, 5, 10, 16)),
        ]),
      ];
      final series = buildCumulativeSeries(tasks, DateTime(2026, 5, 14));
      expect(series, hasLength(1));
      expect(series.first.hours, closeTo(3.0, 1e-9));
    });

    test('long range (>60 days of activity) downsamples to weekly buckets', () {
      // One billable hour per day for 70 days = 70 daily buckets → triggers
      // the weekly downsample path. Expect ~10 weekly buckets.
      final entries = <TimeEntry>[];
      for (var i = 0; i < 70; i++) {
        final start = DateTime(2026, 3, 1, 9).add(Duration(days: i));
        entries.add(_entry(start, start.add(const Duration(hours: 1))));
      }
      final tasks = [_task(entries)];
      final series = buildCumulativeSeries(tasks, DateTime(2026, 6, 1));
      expect(series.length, lessThan(15));
      expect(series.last.hours, closeTo(70.0, 1e-6));
    });
  });

  group('computeProjected', () {
    test('null due date → null', () {
      expect(
        computeProjected(10, DateTime(2026, 5, 1), null, DateTime(2026, 5, 5)),
        isNull,
      );
    });

    test('zero hours logged → null (no signal to extrapolate)', () {
      expect(
        computeProjected(
          0,
          DateTime(2026, 5, 1),
          Date(2026, 5, 30),
          DateTime(2026, 5, 5),
        ),
        isNull,
      );
    });

    test('less than one day elapsed → null', () {
      expect(
        computeProjected(
          2,
          DateTime(2026, 5, 1, 10),
          Date(2026, 5, 30),
          DateTime(2026, 5, 1, 12),
        ),
        isNull,
      );
    });

    test('halfway through → roughly doubles current logged', () {
      // 14 days elapsed of a 28-day project, 10 h logged → projected ~20 h.
      final projected = computeProjected(
        10,
        DateTime(2026, 5, 1),
        Date(2026, 5, 28),
        DateTime(2026, 5, 15),
      );
      expect(projected, isNotNull);
      expect(projected!, closeTo(20.0, 0.5));
    });

    test('past the due date → null', () {
      // dueDt = 2026-05-11, total = 10 d, elapsed = 19 d. The ratio used to
      // run on below 1 and print "Projected 52.6 h" beside 100 logged: past
      // the finish there is nothing left to project.
      expect(
        computeProjected(
          100,
          DateTime(2026, 5, 1),
          Date(2026, 5, 10),
          DateTime(2026, 5, 20),
        ),
        isNull,
      );
      // The end of the due day is already past it.
      expect(
        computeProjected(
          100,
          DateTime(2026, 5, 1),
          Date(2026, 5, 10),
          DateTime(2026, 5, 11),
        ),
        isNull,
      );
    });

    test('on the due day → projected is at least what is logged', () {
      // Noon on the due day: 9.5 of 10 days gone.
      final projected = computeProjected(
        100,
        DateTime(2026, 5, 1),
        Date(2026, 5, 10),
        DateTime(2026, 5, 10, 12),
      );
      expect(projected, isNotNull);
      expect(projected!, greaterThanOrEqualTo(100));
    });
  });

  group('deriveStatus', () {
    final due = Date(2026, 5, 30);
    // Before [due]: the fixtures below are about pace, not lateness.
    final today = Date(2026, 5, 15);

    test('no budget → unknown', () {
      expect(
        deriveStatus(10, 0, 20, dueDate: due, today: today),
        ProgressStatus.unknown,
      );
    });

    test('logged exceeds budget → overBudget (even without due date)', () {
      expect(
        deriveStatus(50, 40, null, dueDate: due, today: today),
        ProgressStatus.overBudget,
      );
      expect(
        deriveStatus(40, 40, 40, dueDate: null, today: today),
        ProgressStatus.overBudget,
      );
    });

    test('no due date → unknown (no schedule to be on track against)', () {
      // The misleading-onTrack case the review surfaced: budget set, but
      // dueDate missing. Previously fell through to onTrack; must now route
      // to unknown so the StatusPill fallback shows pct% consumed.
      expect(
        deriveStatus(10, 40, null, dueDate: null, today: today),
        ProgressStatus.unknown,
      );
    });

    test('projected exceeds budget → offPace', () {
      expect(
        deriveStatus(10, 40, 60, dueDate: due, today: today),
        ProgressStatus.offPace,
      );
    });

    test('projected within budget → onTrack', () {
      expect(
        deriveStatus(10, 40, 30, dueDate: due, today: today),
        ProgressStatus.onTrack,
      );
    });

    test('past the due date → unknown, never onTrack beside "Past due"', () {
      // A past-due project read "On track" next to the red "Past due" pill.
      expect(
        deriveStatus(10, 40, null, dueDate: due, today: Date(2026, 5, 31)),
        ProgressStatus.unknown,
      );
      expect(
        deriveStatus(10, 40, 60, dueDate: due, today: Date(2026, 6, 15)),
        ProgressStatus.unknown,
      );
      // The due day itself still has time left.
      expect(
        deriveStatus(10, 40, 30, dueDate: due, today: due),
        ProgressStatus.onTrack,
      );
    });

    test('past the due date and over budget → overBudget', () {
      expect(
        deriveStatus(110, 100, null, dueDate: due, today: Date(2026, 6, 15)),
        ProgressStatus.overBudget,
      );
    });

    test('no projection yet, logged under budget, due date set → onTrack', () {
      expect(
        deriveStatus(10, 40, null, dueDate: due, today: today),
        ProgressStatus.onTrack,
      );
    });
  });

  group('fmtHours', () {
    test('whole numbers render as ints', () {
      expect(fmtHours(0), '0');
      expect(fmtHours(7), '7');
      expect(fmtHours(40), '40');
    });

    test('fractions render with one decimal', () {
      expect(fmtHours(2.5), '2.5');
      expect(fmtHours(2.456), '2.5');
    });
  });
}
