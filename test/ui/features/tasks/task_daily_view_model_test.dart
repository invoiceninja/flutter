import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_daily_view_model.dart';

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

TimeEntry _e(DateTime start, DateTime? stop, {bool billable = true}) =>
    TimeEntry(start: start, stop: stop, billable: billable);

class _FakeRepo implements TaskRepository {
  _FakeRepo(this._tasks);
  final List<Task> _tasks;

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => Stream.value(_tasks);

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

TaskDailyViewModel _build(List<Task> tasks, {Date? day}) => TaskDailyViewModel(
  repo: _FakeRepo(tasks),
  companyId: 'co',
  focusDay: day ?? Date(2026, 6, 10),
  now: () => _now,
);

void main() {
  test('rows returns entries on the focused day, sorted by start', () async {
    final vm = _build([
      _t('a', log: [_e(DateTime(2026, 6, 10, 14), DateTime(2026, 6, 10, 15))]),
      _t('b', log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))]),
      _t('c', log: [_e(DateTime(2026, 6, 11, 9), DateTime(2026, 6, 11, 10))]),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.rows.map((r) => r.task.id), ['b', 'a']);
  });

  test('total and billable sum the focused day', () async {
    final vm = _build([
      _t('a', log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 11))]),
      _t(
        'b',
        log: [
          _e(
            DateTime(2026, 6, 10, 12),
            DateTime(2026, 6, 10, 13),
            billable: false,
          ),
        ],
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(vm.total, const Duration(hours: 3));
    expect(vm.billable, const Duration(hours: 2));
  });

  test('prev/next day shift the focus', () async {
    final vm = _build(const []);
    await Future<void>.delayed(Duration.zero);
    vm.nextDay();
    expect(vm.day, Date(2026, 6, 11));
    vm
      ..prevDay()
      ..prevDay();
    expect(vm.day, Date(2026, 6, 9));
  });

  test('duplicate-yesterday guard blocks a re-tap (M2)', () async {
    // Focus on the real "today" so isToday (which reads Date.today()) holds.
    final vm = _build(const [], day: Date.today());
    await Future<void>.delayed(Duration.zero);
    expect(vm.isToday, isTrue);
    expect(vm.canDuplicateYesterday, isTrue);

    // First begin wins and flips the in-flight flag; a concurrent begin (a
    // double-tap before the first completes) is refused.
    expect(vm.beginDuplicate(), isTrue);
    expect(vm.isDuplicating, isTrue);
    expect(vm.canDuplicateYesterday, isFalse);
    expect(vm.beginDuplicate(), isFalse);

    // A run that created tasks latches the day, so a re-tap after the toast
    // is still refused — no second batch.
    vm.endDuplicate(created: true);
    expect(vm.isDuplicating, isFalse);
    expect(vm.canDuplicateYesterday, isFalse);
    expect(vm.beginDuplicate(), isFalse);
  });

  test(
    'duplicate-yesterday with nothing created stays available (M2)',
    () async {
      final vm = _build(const [], day: Date.today());
      await Future<void>.delayed(Duration.zero);
      expect(vm.beginDuplicate(), isTrue);
      vm.endDuplicate(created: false);
      // Nothing was created, so the affordance stays available for a retry.
      expect(vm.canDuplicateYesterday, isTrue);
    },
  );

  test('project filter narrows rows', () async {
    final vm = _build([
      _t(
        'a',
        projectId: 'p1',
        log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))],
      ),
      _t(
        'b',
        projectId: 'p2',
        log: [_e(DateTime(2026, 6, 10, 11), DateTime(2026, 6, 10, 12))],
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    vm.setProjectFilter('p1');
    expect(vm.rows.map((r) => r.task.id), ['a']);
  });

  group('hasFilteredOutRows — the empty state must not lie', () {
    test('true when the day has entries a filter is hiding', () async {
      final vm = _build([
        _t(
          'a',
          projectId: 'p1',
          log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))],
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      vm.setProjectFilter('p2');

      expect(vm.rows, isEmpty);
      expect(vm.hasFilteredOutRows, isTrue);
    });

    test('false on a day that is empty with or without the filter', () async {
      // The regression this predicate exists for: gating the empty state on
      // `filtersActive` alone tells someone who simply logged nothing today to
      // "Clear filters" — which reveals nothing — and takes away the `Log time`
      // action they actually came for.
      final vm = _build([
        _t(
          'a',
          projectId: 'p1',
          log: [_e(DateTime(2026, 6, 3, 9), DateTime(2026, 6, 3, 10))],
        ),
      ]);
      await Future<void>.delayed(Duration.zero);
      vm.setProjectFilter('p1');

      expect(vm.rows, isEmpty, reason: 'the entry is on another day');
      expect(vm.filtersActive, isTrue);
      expect(vm.hasFilteredOutRows, isFalse);
    });

    test('false with no filter applied at all', () async {
      final vm = _build([_t('a')]);
      await Future<void>.delayed(Duration.zero);
      expect(vm.hasFilteredOutRows, isFalse);
    });
  });
}
