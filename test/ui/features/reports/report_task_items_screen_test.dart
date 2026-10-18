import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';

import '_report_screen_harness.dart';

/// The Task Items report on screen — built on the device, so its export menu,
/// its empty state and the way in from the Tasks report differ from a report
/// the server answers.

class _Source implements LocalReportSource {
  _Source(this.rows);

  ReportPreview rows;
  final List<ReportQuery> refreshes = [];

  @override
  Future<ReportPreview> fromDevice(ReportQuery query) async => rows;

  @override
  Future<ReportPreview> refresh(
    ReportQuery query, {
    bool Function()? isCancelled,
  }) async {
    refreshes.add(query);
    return rows;
  }
}

ReportPreview _entries(int n) => ReportPreview(
  columns: const [
    ReportColumn(
      identifier: 'task.start_date',
      displayLabel: 'Date',
      type: ReportColumnType.date,
    ),
    ReportColumn(
      identifier: 'task.duration',
      displayLabel: 'Duration',
      type: ReportColumnType.duration,
    ),
    ReportColumn(
      identifier: 'task.description',
      displayLabel: 'Task',
      type: ReportColumnType.string,
    ),
  ],
  rows: [
    for (var i = 0; i < n; i++)
      ReportRow(
        recordWire: 'task',
        recordId: 't$i',
        cells: [
          ReportDateCell(value: Date(2026, 10, 12 + i)),
          const ReportDurationCell(seconds: 5400),
          ReportStringCell(value: 'Task $i', displayValue: 'Task $i'),
        ],
      ),
  ],
);

/// The Tasks report as the server answers it: one task.
ReportPreview _tasks() => ReportPreview(
  columns: [
    reportTestColumn('task.number', 'Number'),
    reportTestColumn('task.duration', 'Duration'),
  ],
  rows: const [
    ReportRow(
      cells: [
        ReportStringCell(value: '0001', displayValue: '0001'),
        ReportDurationCell(seconds: 3600, displayValue: '3600'),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReportTestFonts);

  testWidgets('it lists the entries, in hours, from the device source', (
    tester,
  ) async {
    final source = _Source(_entries(3));
    final h = await pumpReports(
      tester,
      preview: _tasks(),
      location: '/reports/task_item',
      localSourceFor: (id) => id == 'task_item' ? source : null,
    );
    expect(source.refreshes, isNotEmpty);
    expect(h.repo.requests, isEmpty, reason: 'the server is never asked');
    // In the table, and in the chart of the largest above it.
    expect(find.text('Task 0'), findsWidgets);
    // Decimal hours, as the weekly timesheet prints them.
    expect(find.text('1.5'), findsWidgets);
    // Opens as a list, not grouped.
    expect(h.vm.group, isNull);
  }, variant: kDesktop);

  testWidgets('its export menu offers only what the device can write, and '
      'says why', (tester) async {
    final source = _Source(_entries(2));
    await pumpReports(
      tester,
      preview: _tasks(),
      location: '/reports/task_item',
      localSourceFor: (id) => id == 'task_item' ? source : null,
    );
    final rulesBefore = find.byType(Divider).evaluate().length;
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.text('Download this view'), findsOneWidget);
    expect(find.textContaining('built on your device'), findsOneWidget);
    expect(find.text('Download full report'), findsNothing);
    expect(find.text('Email it to me'), findsNothing);
    expect(find.text('Schedule'), findsNothing);
    // The note ends the menu; no rule is left hanging under it. (The menu is
    // an overlay, not a descendant of its anchor, so its rules are counted
    // as the ones that came with it.)
    expect(find.byType(Divider).evaluate().length, rulesBefore);
  }, variant: kDesktop);

  testWidgets(
    "a server report's menu still divides its two kinds of file",
    (tester) async {
      // The count above is not vacuous: here the menu brings its rule.
      await pumpReports(tester, preview: _tasks(), location: '/reports/task');
      final rulesBefore = find.byType(Divider).evaluate().length;
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('Download full report'), findsOneWidget);
      expect(find.byType(Divider).evaluate().length, greaterThan(rulesBefore));
    },
    variant: kDesktop,
  );

  testWidgets('an empty range says no time was logged, and offers no "All '
      'time"', (tester) async {
    final source = _Source(_entries(0));
    await pumpReports(
      tester,
      preview: _tasks(),
      location: '/reports/task_item',
      localSourceFor: (id) => id == 'task_item' ? source : null,
    );
    expect(find.text('No time was logged in this range.'), findsOneWidget);
    // "All time" is every task the company has, fetched page by page.
    expect(find.widgetWithText(OutlinedButton, 'All Time'), findsNothing);
  }, variant: kDesktop);

  testWidgets("a server report's empty range does offer All time", (
    tester,
  ) async {
    // The check above is not vacuous: here the button is drawn.
    await pumpReports(
      tester,
      preview: invoiceReportFixture(rows: 0),
      location: '/reports/invoice',
    );
    expect(find.widgetWithText(OutlinedButton, 'All Time'), findsOneWidget);
  }, variant: kDesktop);

  testWidgets('on a phone with large text the hint keeps its message and its '
      'action', (tester) async {
    final h = await pumpReports(
      tester,
      preview: _tasks(),
      location: '/reports/task',
      size: const Size(360, 780),
      textScale: 1.3,
      tasksCrossRange: (query) async => true,
    );
    h.vm.setPayload(
      h.vm.payload.copyWith(datePreset: ReportDatePreset.lastMonth),
    );
    await settleReports(tester);
    expect(tester.takeException(), isNull);
    final message = find.textContaining('Tasks are listed by their first');
    expect(message, findsOneWidget);
    // Beside a long action the message was squeezed to a sliver.
    expect(tester.getSize(message).width, greaterThan(200));
    final action = find.text('Show task items in this range');
    expect(action, findsOneWidget);
    expect(tester.getRect(action).right, lessThanOrEqualTo(360));
    // A finger's target.
    expect(
      tester
          .getSize(
            find.widgetWithText(
              TextButton,
              'Show task items in '
              'this range',
            ),
          )
          .height,
      greaterThanOrEqualTo(44),
    );
  }, variant: kPhone);

  testWidgets('the Tasks report offers Task Items for the same range when a '
      'task has time outside it', (tester) async {
    final source = _Source(_entries(1));
    final h = await pumpReports(
      tester,
      preview: _tasks(),
      location: '/reports/task',
      localSourceFor: (id) => id == 'task_item' ? source : null,
      tasksCrossRange: (query) async => true,
    );
    h.vm.setPayload(
      h.vm.payload.copyWith(
        datePreset: ReportDatePreset.custom,
        startDate: () => Date(2026, 10, 12),
        endDate: () => Date(2026, 10, 18),
      ),
    );
    await settleReports(tester);
    expect(
      find.textContaining('Tasks are listed by their first time entry'),
      findsOneWidget,
    );
    await tester.tap(find.text('Show task items in this range'));
    await settleReports(tester);
    expect(h.vm.reportIdentifier, 'task_item');
    expect(h.vm.payload.startDate, Date(2026, 10, 12));
    expect(h.vm.payload.endDate, Date(2026, 10, 18));
    expect(source.refreshes.last.start, Date(2026, 10, 12));
  }, variant: kDesktop);

  testWidgets('no hint when no task crosses the range', (tester) async {
    await pumpReports(
      tester,
      preview: _tasks(),
      location: '/reports/task',
      tasksCrossRange: (query) async => false,
    );
    expect(
      find.textContaining('Tasks are listed by their first time entry'),
      findsNothing,
    );
  }, variant: kDesktop);
}
