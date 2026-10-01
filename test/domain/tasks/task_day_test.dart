import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/task_day.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _t(
  String id, {
  List<TimeEntry> log = const [],
  String number = '',
  String description = '',
}) => Task(
  id: id,
  number: number,
  description: description,
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

TimeEntry _e(DateTime? start, DateTime? stop, {bool billable = true}) =>
    TimeEntry(start: start, stop: stop, billable: billable);

void main() {
  group('TaskDay.day / earliestStart', () {
    test('day is the local date of the earliest entry start', () {
      final task = _t(
        'a',
        log: [
          _e(DateTime(2026, 6, 10, 14), DateTime(2026, 6, 10, 15)),
          _e(DateTime(2026, 6, 9, 9), DateTime(2026, 6, 9, 10)), // earlier
        ],
      );
      expect(task.day, Date(2026, 6, 9));
      expect(task.earliestStart, DateTime(2026, 6, 9, 9));
    });

    test('null for empty log or all-null starts', () {
      expect(_t('a').day, isNull);
      expect(_t('b', log: [_e(null, null)]).day, isNull);
    });

    test('uses the LOCAL date of a UTC start, not the raw UTC fields', () {
      final start = DateTime.utc(2026, 6, 10, 23, 30);
      final task = _t(
        'a',
        log: [_e(start, start.add(const Duration(hours: 1)))],
      );
      final local = start.toLocal();
      expect(task.day, Date(local.year, local.month, local.day));
    });
  });

  group('entriesOnDay', () {
    test('returns entries on the day, sorted by start ascending', () {
      final t1 = _t(
        't1',
        log: [
          _e(DateTime(2026, 6, 10, 14), DateTime(2026, 6, 10, 15)),
          _e(DateTime(2026, 6, 11, 9), DateTime(2026, 6, 11, 10)),
        ],
      );
      final t2 = _t(
        't2',
        log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))],
      );
      final rows = entriesOnDay([t1, t2], Date(2026, 6, 10));
      expect(rows.map((r) => r.task.id), ['t2', 't1']);
    });

    test('a running entry started the prior day is not on today', () {
      final running = _t('r', log: [_e(DateTime(2026, 6, 9, 23), null)]);
      expect(entriesOnDay([running], Date(2026, 6, 10)), isEmpty);
      expect(entriesOnDay([running], Date(2026, 6, 9)).length, 1);
    });

    test('skips entries without a start', () {
      expect(
        entriesOnDay([
          _t('t', log: [_e(null, null)]),
        ], Date(2026, 6, 10)),
        isEmpty,
      );
    });
  });

  group('tasksByDay', () {
    test('groups by day and drops logless tasks', () {
      final a = _t(
        'a',
        log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))],
      );
      final b = _t(
        'b',
        log: [_e(DateTime(2026, 6, 10, 11), DateTime(2026, 6, 10, 12))],
      );
      final c = _t('c'); // no log
      final map = tasksByDay([a, b, c]);
      expect(map[Date(2026, 6, 10)]!.map((t) => t.id), containsAll(['a', 'b']));
      expect(
        map.values.expand((l) => l).map((t) => t.id),
        isNot(contains('c')),
      );
    });
  });

  group('taskPrimaryLabel', () {
    test('description wins, clipped to max', () {
      expect(
        taskPrimaryLabel(_t('x', description: 'Hello world')),
        'Hello world',
      );
      expect(
        taskPrimaryLabel(_t('x', description: 'abcdefghij'), max: 5),
        'abcde…',
      );
    });

    test('falls back to #number then dash', () {
      expect(taskPrimaryLabel(_t('x', number: '42')), '#42');
      expect(taskPrimaryLabel(_t('x')), '—');
    });

    test('strips HTML and collapses whitespace', () {
      expect(
        taskPrimaryLabel(_t('x', description: '<p>Hi   there</p>')),
        'Hi there',
      );
    });
  });

  // React #3378 — the month calendar places a task on every day it was
  // worked. Local wall-clock fixtures, so the result is the same in every
  // timezone (the helper converts each start to local).
  group('tasksByActiveDay', () {
    final from = Date(2026, 6, 1);
    final to = Date(2026, 6, 30);

    test('each entry\'s own day — never the first-to-last span', () {
      final task = _t(
        'a',
        log: [
          _e(DateTime(2026, 6, 3, 10), DateTime(2026, 6, 3, 12)),
          _e(DateTime(2026, 6, 17, 10), DateTime(2026, 6, 17, 11)),
        ],
      );
      final map = tasksByActiveDay([task], from: from, to: to);
      expect(map.keys.toSet(), {Date(2026, 6, 3), Date(2026, 6, 17)});
    });

    test('an entry past midnight sits on both of its days', () {
      final task = _t(
        'a',
        log: [_e(DateTime(2026, 6, 9, 22), DateTime(2026, 6, 10, 2))],
      );
      final map = tasksByActiveDay([task], from: from, to: to);
      expect(map.keys.toSet(), {Date(2026, 6, 9), Date(2026, 6, 10)});
    });

    test('an entry ending exactly at midnight stays on its own day', () {
      final task = _t(
        'a',
        log: [_e(DateTime(2026, 6, 9, 22), DateTime(2026, 6, 10))],
      );
      final map = tasksByActiveDay([task], from: from, to: to);
      expect(map.keys.toSet(), {Date(2026, 6, 9)});
    });

    test('a stop before its start still shows on the start day', () {
      final task = _t(
        'a',
        log: [_e(DateTime(2026, 6, 9, 14), DateTime(2026, 6, 9, 9))],
      );
      final map = tasksByActiveDay([task], from: from, to: to);
      expect(map.keys.toSet(), {Date(2026, 6, 9)});
    });

    test(
      'a running entry runs to now; days outside the window are dropped',
      () {
        final task = _t('a', log: [_e(DateTime(2026, 5, 30, 9), null)]);
        final map = tasksByActiveDay(
          [task],
          from: from,
          to: to,
          now: DateTime(2026, 6, 2, 12),
        );
        expect(map.keys.toSet(), {Date(2026, 6, 1), Date(2026, 6, 2)});
      },
    );

    test('a task worked twice on one day appears once on it', () {
      final task = _t(
        'a',
        log: [
          _e(DateTime(2026, 6, 5, 9), DateTime(2026, 6, 5, 10)),
          _e(DateTime(2026, 6, 5, 14), DateTime(2026, 6, 5, 15)),
        ],
      );
      final map = tasksByActiveDay([task], from: from, to: to);
      expect(map[Date(2026, 6, 5)], hasLength(1));
    });
  });
}
