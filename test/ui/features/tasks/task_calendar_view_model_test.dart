import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _t(String id, {List<TimeEntry> log = const [], String invoiceId = ''}) =>
    Task(
      id: id,
      number: id,
      description: id,
      rate: Decimal.zero,
      invoiceId: invoiceId,
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

TimeEntry _e(DateTime start, DateTime stop) =>
    TimeEntry(start: start, stop: stop);

class _FakeRepo implements TaskRepository {
  _FakeRepo(this._tasks);
  final List<Task> _tasks;

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => Stream.value(_tasks);

  // The VM fires a best-effort month window fetch from its constructor; this
  // fake answers "no more pages" so no test here depends on the network.
  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    states = const {},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async => false;

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  test('gridDays has 42 days; tasks group by day', () async {
    final vm = TaskCalendarViewModel(
      repo: _FakeRepo([
        _t('a', log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))]),
      ]),
      companyId: 'co',
      focusMonth: Date(2026, 6, 1),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.gridDays.length, 42);
    expect(vm.tasksByDayFiltered()[Date(2026, 6, 10)]!.map((t) => t.id), ['a']);
  });

  test('prevMonth normalizes across the year boundary', () async {
    final vm = TaskCalendarViewModel(
      repo: _FakeRepo(const []),
      companyId: 'co',
      focusMonth: Date(2026, 1, 1),
    );
    await Future<void>.delayed(Duration.zero);
    vm.prevMonth();
    expect(vm.month, Date(2025, 12, 1));
    vm.nextMonth();
    expect(vm.month, Date(2026, 1, 1));
  });

  test('invoiced tasks appear on the calendar', () async {
    final vm = TaskCalendarViewModel(
      repo: _FakeRepo([
        _t(
          'inv',
          invoiceId: 'i1',
          log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))],
        ),
      ]),
      companyId: 'co',
      focusMonth: Date(2026, 6, 1),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vm.tasksByDayFiltered()[Date(2026, 6, 10)]!.map((t) => t.id), [
      'inv',
    ]);
  });

  test('filters narrow the grouped tasks', () async {
    final vm = TaskCalendarViewModel(
      repo: _FakeRepo([
        _t('a', log: [_e(DateTime(2026, 6, 10, 9), DateTime(2026, 6, 10, 10))]),
      ]),
      companyId: 'co',
      focusMonth: Date(2026, 6, 1),
    );
    await Future<void>.delayed(Duration.zero);
    vm.setClientFilter('nope');
    expect(vm.tasksByDayFiltered()[Date(2026, 6, 10)], isNull);
  });
}
