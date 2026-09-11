@TestOn('vm')
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/domain/tasks/task_day_load.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';

/// Fixtures use the LOCAL `DateTime(...)` constructor on purpose: the local
/// date then equals the constructed date in every timezone, so these cases are
/// stable whether they run on a UTC+2 laptop or on CI in UTC (CLAUDE.md
/// § Strict rules). The one UTC case derives its expectation through
/// `.toLocal()` rather than hardcoding a day, the same shape
/// `task_day_test.dart` uses.
///
/// Check with `TZ=UTC flutter test test/domain/tasks/task_day_load_test.dart`
/// before pushing — green locally is not green on CI.

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _t(String id, {List<TimeEntry> log = const []}) => Task(
  id: id,
  number: id,
  description: id,
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: 's1',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: log,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

TimeEntry _e(DateTime? start, DateTime? stop) =>
    TimeEntry(start: start, stop: stop);

/// Anchored far from midnight so nothing here depends on the runner's zone.
final _now = DateTime(2026, 6, 15, 12);

class _FakeRepo implements TaskRepository {
  _FakeRepo(this.controller);
  final StreamController<List<Task>> controller;

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => controller.stream;

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  group('taskLoadByDay', () {
    test('sums every entry on a day, across tasks and within one task', () {
      final a = _t(
        'a',
        log: [
          _e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 11)), // 2h
          _e(DateTime(2026, 6, 10, 14), DateTime(2026, 6, 10, 15)), // 1h
        ],
      );
      final b = _t(
        'b',
        log: [_e(DateTime(2026, 6, 10, 16), DateTime(2026, 6, 10, 16, 30))],
      );
      final map = taskLoadByDay([a, b], now: _now);
      expect(map[Date(2026, 6, 10)], const Duration(hours: 3, minutes: 30));
    });

    test('a task spanning two days contributes to BOTH', () {
      // The whole reason this is per-entry: `tasksByDay` would place this task
      // on the 10th only, and the 12th would read as free.
      final task = _t(
        'a',
        log: [
          _e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 12)),
          _e(DateTime(2026, 6, 12, 9), DateTime(2026, 6, 12, 10)),
        ],
      );
      final map = taskLoadByDay([task], now: _now);
      expect(map[Date(2026, 6, 10)], const Duration(hours: 3));
      expect(map[Date(2026, 6, 12)], const Duration(hours: 1));
    });

    test('a day with nothing logged is absent, not zero', () {
      final map = taskLoadByDay([
        _t('a', log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))]),
      ], now: _now);
      expect(map.containsKey(Date(2026, 6, 11)), isFalse);
    });

    test('entries with no start are skipped', () {
      expect(
        taskLoadByDay([
          _t('a', log: [_e(null, null)]),
        ], now: _now),
        isEmpty,
      );
      expect(taskLoadByDay([_t('b')], now: _now), isEmpty);
    });

    test('a running entry is measured to the injected now', () {
      final map = taskLoadByDay([
        _t('a', log: [_e(DateTime(2026, 6, 15, 9), null)]),
      ], now: _now);
      expect(map[Date(2026, 6, 15)], const Duration(hours: 3));
    });

    test('a running entry started yesterday lands wholly on yesterday', () {
      // Start-keyed, matching the weekly timesheet. Documented, not a bug.
      final map = taskLoadByDay([
        _t('a', log: [_e(DateTime(2026, 6, 14, 22), null)]),
      ], now: _now);
      expect(map[Date(2026, 6, 14)], const Duration(hours: 14));
      expect(map.containsKey(Date(2026, 6, 15)), isFalse);
    });

    test('an overnight entry lands wholly on its start day', () {
      final map = taskLoadByDay([
        _t('a', log: [_e(DateTime(2026, 6, 10, 20), DateTime(2026, 6, 11, 4))]),
      ], now: _now);
      expect(map[Date(2026, 6, 10)], const Duration(hours: 8));
      expect(map.containsKey(Date(2026, 6, 11)), isFalse);
    });

    test('uses the LOCAL date of a UTC start, not the raw UTC fields', () {
      final start = DateTime.utc(2026, 6, 10, 23, 30);
      final map = taskLoadByDay([
        _t('a', log: [_e(start, start.add(const Duration(hours: 1)))]),
      ], now: _now);
      final local = start.toLocal();
      expect(map.keys.single, Date(local.year, local.month, local.day));
    });
  });

  // "from / to", not "window" — in this feature a *window* is the month range
  // the server fetch covers (`_loadedWindows`, `ensureMonthLoaded`), and these
  // are the visible-grid clamp on a pure function.
  group('from / to bounds', () {
    final tasks = [
      _t(
        'a',
        log: [
          _e(DateTime(2026, 6, 5, 9), DateTime(2026, 6, 5, 11)),
          _e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 11)),
          _e(DateTime(2026, 6, 20, 9), DateTime(2026, 6, 20, 11)),
        ],
      ),
    ];

    test('bounds are inclusive at both ends', () {
      final map = taskLoadByDay(
        tasks,
        now: _now,
        from: Date(2026, 6, 5),
        to: Date(2026, 6, 10),
      );
      expect(map.keys, containsAll([Date(2026, 6, 5), Date(2026, 6, 10)]));
      expect(map.containsKey(Date(2026, 6, 20)), isFalse);
    });

    test('unbounded still sees everything', () {
      expect(taskLoadByDay(tasks, now: _now), hasLength(3));
    });
  });

  group('dayLoadBucket', () {
    test('boundaries land on the documented side', () {
      expect(dayLoadBucket(Duration.zero), DayLoadBucket.free);
      expect(dayLoadBucket(const Duration(seconds: 1)), DayLoadBucket.light);
      expect(
        dayLoadBucket(const Duration(hours: 3, minutes: 59, seconds: 59)),
        DayLoadBucket.light,
      );
      expect(dayLoadBucket(const Duration(hours: 4)), DayLoadBucket.limited);
      expect(
        dayLoadBucket(const Duration(hours: 7, minutes: 59, seconds: 59)),
        DayLoadBucket.limited,
      );
      expect(dayLoadBucket(const Duration(hours: 8)), DayLoadBucket.full);
      expect(dayLoadBucket(const Duration(hours: 9)), DayLoadBucket.full);
    });

    test('a negative total reads as free, never as a bucket', () {
      expect(dayLoadBucket(const Duration(hours: -1)), DayLoadBucket.free);
    });

    test('the thresholds are derived from kFullDayLoad, not hardcoded', () {
      expect(dayLoadBucket(kFullDayLoad), DayLoadBucket.full);
      expect(dayLoadBucket(kFullDayLoad ~/ 2), DayLoadBucket.limited);
      expect(
        dayLoadBucket(kFullDayLoad ~/ 2 - const Duration(seconds: 1)),
        DayLoadBucket.light,
      );
    });
  });

  group('dayLoadFraction', () {
    test('scales linearly and clamps at a full day', () {
      expect(dayLoadFraction(Duration.zero), 0);
      expect(dayLoadFraction(const Duration(hours: 2)), closeTo(0.25, 1e-9));
      expect(dayLoadFraction(const Duration(hours: 4)), closeTo(0.5, 1e-9));
      expect(dayLoadFraction(const Duration(hours: 8)), 1);
      expect(dayLoadFraction(const Duration(hours: 14)), 1);
      expect(dayLoadFraction(const Duration(hours: -3)), 0);
    });
  });

  group('parity with the weekly timesheet', () {
    // The panel and the weekly grid must never disagree about the same day.
    // That is the whole reason the rule lives in a shared leaf rather than
    // being re-derived per surface, so it is asserted rather than assumed.
    //
    // Two known limits of the claim, both outside this fixture: `secondsFor`
    // truncates each entry to whole seconds and sums `int`s while this sums
    // `Duration`s and truncates once (N entries with sub-second parts can
    // differ by up to N−1 s), and it short-circuits to its pending-edit buffer
    // while the weekly grid is being typed into, where the two legitimately
    // disagree.
    test(
      'taskLoadByDay equals the sum of secondsFor over the same tasks',
      () async {
        final tasks = [
          _t(
            'a',
            log: [
              _e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 11, 30)),
              _e(DateTime(2026, 6, 10, 13), DateTime(2026, 6, 10, 14)),
              _e(DateTime(2026, 6, 12, 9), DateTime(2026, 6, 12, 10)),
            ],
          ),
          _t(
            'b',
            log: [_e(DateTime(2026, 6, 10, 16), DateTime(2026, 6, 10, 17))],
          ),
          _t('c', log: [_e(DateTime(2026, 6, 10, 20), null)]), // running
        ];

        final ctrl = StreamController<List<Task>>();
        final vm = TaskWeeklyViewModel(
          repo: _FakeRepo(ctrl),
          companyId: 'co',
          firstDayOfWeek: 1,
          focus: Date(2026, 6, 10),
          now: () => _now,
        );
        ctrl.add(tasks);
        await Future<void>.delayed(Duration.zero);

        // Asserted against the function production actually calls. This once
        // pinned a convenience sibling that nothing shipped, which let the
        // real path drift from the timesheet with this file green — the one
        // thing it exists to prevent.
        final byDay = taskLoadByDay(tasks, now: _now);
        for (final day in vm.weekDays) {
          final weekly = tasks.fold<int>(
            0,
            (sum, t) => sum + vm.secondsFor(t.id, day),
          );
          expect(
            (byDay[day] ?? Duration.zero).inSeconds,
            weekly,
            reason: 'disagreement on ${day.toIso()}',
          );
        }

        vm.dispose();
        await ctrl.close();
      },
    );
  });
}
