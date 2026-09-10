import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
final _now = DateTime(2026, 6, 15, 12);

Task _t(String id, {List<TimeEntry> log = const [], String projectId = ''}) =>
    Task(
      id: id,
      number: id,
      description: id,
      rate: Decimal.zero,
      invoiceId: '',
      clientId: '',
      projectId: projectId,
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

TimeEntry _e(DateTime start, DateTime? stop) =>
    TimeEntry(start: start, stop: stop);

int _secondsOn(List<TimeEntry> log, Date day) {
  var total = 0;
  for (final e in log) {
    final start = e.start;
    final stop = e.stop;
    if (start == null || stop == null) continue;
    final local = start.toLocal();
    if (Date(local.year, local.month, local.day) == day) {
      total += stop.difference(start).inSeconds;
    }
  }
  return total;
}

class _FakeRepo implements TaskRepository {
  _FakeRepo(this.controller);
  final StreamController<List<Task>> controller;
  final List<Task> savedTasks = [];

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => controller.stream;

  @override
  Future<SaveResult<Task>> save({
    required String companyId,
    required Task task,
  }) async {
    savedTasks.add(task);
    return SaveResult(entity: task, outboxRowId: 0);
  }

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

// firstDayOfWeek=1 (Monday) with focus 2026-06-10 (Wed) → week starts Mon Jun 8.
TaskWeeklyViewModel _build(_FakeRepo repo) => TaskWeeklyViewModel(
  repo: repo,
  companyId: 'co',
  firstDayOfWeek: 1,
  focus: Date(2026, 6, 10),
  now: () => _now,
  flushDelay: const Duration(milliseconds: 20),
);

void main() {
  test('week starts on Monday for a mid-week focus', () async {
    final ctrl = StreamController<List<Task>>();
    final vm = _build(_FakeRepo(ctrl));
    ctrl.add(const []);
    await Future<void>.delayed(Duration.zero);
    expect(vm.weekStart, Date(2026, 6, 8));
    expect(vm.weekDays.first, Date(2026, 6, 8));
    expect(vm.weekDays.last, Date(2026, 6, 14));
    await ctrl.close();
  });

  test('multiple edits to one task in the window → exactly ONE save', () async {
    final ctrl = StreamController<List<Task>>();
    final repo = _FakeRepo(ctrl);
    final vm = _build(repo);
    ctrl.add([
      _t('a', log: [_e(DateTime(2026, 6, 8, 9), DateTime(2026, 6, 8, 10))]),
    ]);
    await Future<void>.delayed(Duration.zero);

    final days = vm.weekDays;
    vm.editCell('a', days[0], duration: '1');
    vm.editCell('a', days[0], duration: '2'); // overrides within the window
    vm.editCell('a', days[1], duration: '3');

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repo.savedTasks.length, 1);
    final log = repo.savedTasks.single.timeLog;
    expect(
      _secondsOn(log, Date(2026, 6, 8)),
      const Duration(hours: 2).inSeconds,
    );
    expect(
      _secondsOn(log, Date(2026, 6, 9)),
      const Duration(hours: 3).inSeconds,
    );
    await ctrl.close();
  });

  test(
    'note-only edit on a multi-entry day preserves total hours through the '
    'save (regression: was collapsing 2 entries → losing the 2nd\'s time)',
    () async {
      final ctrl = StreamController<List<Task>>();
      final repo = _FakeRepo(ctrl);
      final vm = _build(repo);
      // Two stopped entries on Monday Jun 8 (1h + 1h = 2h).
      ctrl.add([
        _t(
          'a',
          log: [
            _e(DateTime(2026, 6, 8, 9), DateTime(2026, 6, 8, 10)),
            _e(DateTime(2026, 6, 8, 14), DateTime(2026, 6, 8, 15)),
          ],
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      final mon = vm.weekDays[0];
      expect(vm.secondsFor('a', mon), const Duration(hours: 2).inSeconds);

      // A note-only edit (no duration) must NOT collapse the day to one entry.
      vm.editCell('a', mon, description: 'standup');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(repo.savedTasks.length, 1);
      final log = repo.savedTasks.single.timeLog;
      expect(
        _secondsOn(log, mon),
        const Duration(hours: 2).inSeconds,
        reason: 'a note-only edit must preserve every same-day entry\'s hours',
      );
      expect(
        log.where((e) => e.start!.toLocal().day == 8).length,
        2,
        reason: 'both Monday entries survive a note-only edit',
      );
      await ctrl.close();
    },
  );

  test('a second window produces a second save', () async {
    final ctrl = StreamController<List<Task>>();
    final repo = _FakeRepo(ctrl);
    final vm = _build(repo);
    ctrl.add([_t('a')]);
    await Future<void>.delayed(Duration.zero);

    final days = vm.weekDays;
    vm.editCell('a', days[0], duration: '1');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    vm.editCell('a', days[1], duration: '2');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repo.savedTasks.length, 2);
    await ctrl.close();
  });

  test('clearing a cell deletes that day\'s entry', () async {
    final ctrl = StreamController<List<Task>>();
    final repo = _FakeRepo(ctrl);
    final vm = _build(repo);
    ctrl.add([
      _t('a', log: [_e(DateTime(2026, 6, 8, 9), DateTime(2026, 6, 8, 10))]),
    ]);
    await Future<void>.delayed(Duration.zero);

    vm.editCell('a', vm.weekDays[0], duration: '');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repo.savedTasks.length, 1);
    expect(_secondsOn(repo.savedTasks.single.timeLog, Date(2026, 6, 8)), 0);
    await ctrl.close();
  });

  test('a running task is read-only — no save', () async {
    final ctrl = StreamController<List<Task>>();
    final repo = _FakeRepo(ctrl);
    final vm = _build(repo);
    ctrl.add([
      _t('a', log: [_e(DateTime(2026, 6, 8, 9), null)]),
    ]); // running
    await Future<void>.delayed(Duration.zero);

    vm.editCell('a', vm.weekDays[0], duration: '5');
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(repo.savedTasks, isEmpty);
    await ctrl.close();
  });

  test('dispose flushes pending edits (durable, offline-safe)', () async {
    final ctrl = StreamController<List<Task>>();
    final repo = _FakeRepo(ctrl);
    final vm = _build(repo);
    ctrl.add([_t('a')]);
    await Future<void>.delayed(Duration.zero);

    vm.editCell('a', vm.weekDays[0], duration: '2');
    vm.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(repo.savedTasks.length, 1);
    await ctrl.close();
  });

  test('one invalid cell does not discard valid sibling edits', () async {
    final ctrl = StreamController<List<Task>>();
    final repo = _FakeRepo(ctrl);
    final vm = _build(repo);
    ctrl.add([_t('a')]);
    await Future<void>.delayed(Duration.zero);

    final days = vm.weekDays;
    vm.editCell('a', days[0], duration: '2'); // valid
    vm.editCell('a', days[1], duration: '.'); // unparseable
    await Future<void>.delayed(const Duration(milliseconds: 40));

    // The valid Monday edit still saves once; the bad cell is dropped, and the
    // error nonce bumped so the screen can toast.
    expect(repo.savedTasks.length, 1);
    final log = repo.savedTasks.single.timeLog;
    expect(_secondsOn(log, days[0]), const Duration(hours: 2).inSeconds);
    expect(_secondsOn(log, days[1]), 0);
    expect(vm.errorNonce, greaterThan(0));
    await ctrl.close();
  });

  test(
    'unparseable pending duration keeps the persisted value (no 0 flash)',
    () async {
      final ctrl = StreamController<List<Task>>();
      final repo = _FakeRepo(ctrl);
      final vm = _build(repo);
      ctrl.add([
        _t('a', log: [_e(DateTime(2026, 6, 8, 9), DateTime(2026, 6, 8, 11))]),
      ]);
      await Future<void>.delayed(Duration.zero);

      final mon = vm.weekDays[0];
      expect(vm.secondsFor('a', mon), const Duration(hours: 2).inSeconds);
      vm.editCell('a', mon, duration: '.'); // mid-typing, doesn't parse yet
      expect(vm.secondsFor('a', mon), const Duration(hours: 2).inSeconds);
      await ctrl.close();
    },
  );

  group('hasFilteredOutRows — the empty state must not lie', () {
    test('true when the week has activity a filter is hiding', () async {
      final ctrl = StreamController<List<Task>>();
      final vm = _build(_FakeRepo(ctrl));
      ctrl.add([
        _t(
          'a',
          projectId: 'p1',
          log: [_e(DateTime(2026, 6, 8, 9), DateTime(2026, 6, 8, 11))],
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      vm.setProjectFilter('p2');
      expect(vm.rows, isEmpty);
      expect(vm.hasFilteredOutRows, isTrue);
      await ctrl.close();
    });

    test('false on a week that is empty with or without the filter', () async {
      // Gating the empty state on `filtersActive` alone points someone whose
      // week simply has nothing logged at "Clear filters", which reveals
      // nothing.
      final ctrl = StreamController<List<Task>>();
      final vm = _build(_FakeRepo(ctrl));
      ctrl.add([
        _t(
          'a',
          projectId: 'p1',
          log: [_e(DateTime(2026, 5, 4, 9), DateTime(2026, 5, 4, 11))],
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      vm.setProjectFilter('p1');
      expect(vm.rows, isEmpty, reason: 'the log is in another week');
      expect(vm.filtersActive, isTrue);
      expect(vm.hasFilteredOutRows, isFalse);
      await ctrl.close();
    });
  });
}
