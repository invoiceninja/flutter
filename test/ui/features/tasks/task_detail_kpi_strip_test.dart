import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_kpi_strip.dart';

import '../shell/_shell_test_helpers.dart';

/// The detail KPI strip surfaces the 1-tap timer toggle only on a narrow
/// pane — on a wide pane the detail actions row already shows an inline
/// Start/Stop button, so the KPI toggle stays hidden to avoid a double-up.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _task({List<TimeEntry> log = const []}) => Task(
  id: 't1',
  number: '1',
  description: 'Task',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: '',
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

final _stopped = [
  TimeEntry(
    start: DateTime.utc(2026, 1, 1, 9),
    stop: DateTime.utc(2026, 1, 1, 10),
  ),
];

void main() {
  Future<void> pumpStrip(WidgetTester tester, double width) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Center(
          child: SizedBox(
            width: width,
            child: TaskDetailKpiStrip(
              task: _task(log: _stopped),
              companyId: 'co1',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('narrow pane shows the timer toggle', (tester) async {
    await pumpStrip(tester, 500);
    expect(find.byIcon(Icons.play_circle_outlined), findsOneWidget);
  });

  testWidgets('wide pane hides the timer toggle (actions row owns it)', (
    tester,
  ) async {
    await pumpStrip(tester, 1200);
    expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
  });
}
