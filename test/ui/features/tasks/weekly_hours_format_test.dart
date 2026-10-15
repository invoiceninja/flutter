import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/weekly/weekly_grid.dart';

import '../../../_localization_helper.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Two and a quarter hours on Monday 2026-06-08 — local times, so the VM's
/// local-day bucketing puts it on that Monday in any timezone.
Task _task() => Task(
  id: 't1',
  number: '0001',
  description: 'Design review',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: 's1',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: [
    TimeEntry(
      start: DateTime(2026, 6, 8, 9).toUtc(),
      stop: DateTime(2026, 6, 8, 11, 15).toUtc(),
    ),
  ],
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

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
  group('hoursMinutesText', () {
    test('writes hours and zero-padded minutes', () {
      expect(hoursMinutesText(90 * 60), '1:30');
      expect(hoursMinutesText(2 * 3600 + 5 * 60), '2:05');
    });

    test('rounds to the nearest minute', () {
      expect(hoursMinutesText(89), '0:01');
      expect(hoursMinutesText(29), '0:00');
      expect(hoursMinutesText(3599), '1:00');
    });

    test('does not wrap at a day', () {
      expect(hoursMinutesText(41 * 3600 + 30 * 60), '41:30');
    });
  });

  group('weeklyHoursText', () {
    test('is empty for nothing logged, in both formats', () {
      expect(weeklyHoursText(0, null), '');
      expect(weeklyHoursText(0, null, hoursMinutes: true), '');
    });

    test('is decimal hours unless asked for H:MM', () {
      expect(weeklyHoursText(8100, null), '2.25');
      expect(weeklyHoursText(8100, null, hoursMinutes: true), '2:15');
    });
  });

  testWidgets('the Total row switch reformats every cell and total', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = StreamController<List<Task>>();
    addTearDown(controller.close);
    final vm = TaskWeeklyViewModel(
      repo: _FakeRepo(controller),
      companyId: 'co',
      firstDayOfWeek: 1,
      focus: Date(2026, 6, 10),
    );
    addTearDown(vm.dispose);
    controller.add([_task()]);

    var hoursMinutes = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: ChangeNotifierProvider<TaskWeeklyViewModel>.value(
            value: vm,
            child: StatefulBuilder(
              builder: (context, setState) => WeeklyGrid(
                hoursMinutes: hoursMinutes,
                onHoursMinutesChanged: (v) => setState(() => hoursMinutes = v),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The Monday cell, the task's week total, Monday's total and the grand
    // total.
    expect(find.text('2.25'), findsNWidgets(4));
    expect(find.text('2:15'), findsNothing);

    await tester.tap(find.text('1:30'));
    await tester.pump();

    expect(hoursMinutes, isTrue);
    expect(find.text('2:15'), findsNWidgets(4));
    expect(find.text('2.25'), findsNothing);

    await tester.tap(find.text('1.5'));
    await tester.pump();

    expect(hoursMinutes, isFalse);
    expect(find.text('2.25'), findsNWidgets(4));
  });

  testWidgets('no switch is drawn without a handler', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = StreamController<List<Task>>();
    addTearDown(controller.close);
    final vm = TaskWeeklyViewModel(
      repo: _FakeRepo(controller),
      companyId: 'co',
      focus: Date(2026, 6, 10),
    );
    addTearDown(vm.dispose);
    controller.add([_task()]);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: ChangeNotifierProvider<TaskWeeklyViewModel>.value(
            value: vm,
            child: const WeeklyGrid(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(HoursFormatSwitch), findsNothing);
  });
}
