import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart'
    show emptyProject;
import 'package:admin/ui/features/projects/widgets/detail/project_detail_standing.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;
import 'package:admin/ui/features/tasks/widgets/detail/task_rate_context.dart';

/// What a task's time comes to on the record screens — the figure has to be
/// the line the Invoice action builds from the same task.
final _now = DateTime.utc(2026, 6, 1, 12);

TimeEntry _entry(int hours, {bool billable = true, int minutes = 0}) =>
    TimeEntry(
      start: DateTime.utc(2026, 5, 1, 9),
      stop: DateTime.utc(2026, 5, 1, 9 + hours, minutes),
      billable: billable,
    );

Task _task({
  String id = 't1',
  String rate = '0',
  String invoiceId = '',
  List<TimeEntry> log = const [],
  bool isDeleted = false,
}) => emptyTask().copyWith(
  id: id,
  rate: Decimal.parse(rate),
  invoiceId: invoiceId,
  timeLog: log,
  isDeleted: isDeleted,
);

void main() {
  final project = emptyProject().copyWith(
    id: 'p1',
    taskRate: Decimal.fromInt(100),
  );
  final rates = TaskRateContext(project: project);

  group('TaskRateContext', () {
    test('a task with no rate of its own bills at what it inherits', () {
      // The old KPI strip multiplied the task's own rate — zero on every
      // task that inherits one — and so priced this at nothing.
      expect(rates.rateFor(_task()), Decimal.fromInt(100));
      expect(rates.rateFor(_task(rate: '150')), Decimal.fromInt(150));
      expect(const TaskRateContext().rateFor(_task()), Decimal.zero);
    });

    test('the amount is rate × billable hours worked', () {
      final task = _task(log: [_entry(2)]);
      expect(rates.amountFor(task, _now), Decimal.fromInt(200));
    });

    test('non-billable time is worked but not billed', () {
      final task = _task(log: [_entry(2, billable: false)]);
      expect(task.workedTime(_now), const Duration(hours: 2));
      expect(rates.amountFor(task, _now), Decimal.zero);
    });

    test('a booking is a plan, and bills nothing', () {
      final task = _task(
        log: [
          TimeEntry(
            start: _now.add(const Duration(days: 1)),
            stop: _now.add(const Duration(days: 1, hours: 3)),
          ),
        ],
      );
      expect(rates.amountFor(task, _now), Decimal.zero);
    });

    test('hours are the invoice line\'s three decimals', () {
      // 100 minutes = 1.6666… h, which the line item carries as 1.667.
      final task = _task(log: [_entry(1, minutes: 40)]);
      expect(billableHours(task, _now), Decimal.parse('1.667'));
      expect(rates.amountFor(task, _now), Decimal.parse('166.7'));
    });
  });

  group('uninvoicedAmount', () {
    test('adds up what has been worked and not yet billed, each at its own '
        'rate', () {
      final tasks = [
        _task(log: [_entry(2)]),
        _task(id: 't2', rate: '200', log: [_entry(1, minutes: 30)]),
      ];
      expect(uninvoicedAmount(tasks, rates, _now), Decimal.fromInt(500));
    });

    test('an invoiced task is no longer owed, and a deleted one never was', () {
      final tasks = [
        _task(log: [_entry(2)]),
        _task(id: 't2', invoiceId: 'inv1', log: [_entry(5)]),
        _task(id: 't3', isDeleted: true, log: [_entry(5)]),
      ];
      expect(uninvoicedAmount(tasks, rates, _now), Decimal.fromInt(200));
    });

    test('nothing worked is zero, not an error', () {
      expect(uninvoicedAmount(const [], rates, _now), Decimal.zero);
    });
  });
}
