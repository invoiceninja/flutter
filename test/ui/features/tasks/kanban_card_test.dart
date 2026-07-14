import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_card.dart';

import '../shell/_shell_test_helpers.dart';

/// The kanban card's inline timer toggle: present for an eligible task,
/// absent on the drag-feedback ghost (showTimerButton:false) and for an
/// invoiced task.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _task({String invoiceId = '', List<TimeEntry> log = const []}) => Task(
  id: 't1',
  number: '1',
  description: 'Task',
  rate: Decimal.zero,
  invoiceId: invoiceId,
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
  Future<void> pumpCard(
    WidgetTester tester, {
    required Task task,
    bool showTimerButton = true,
  }) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Center(
          child: SizedBox(
            width: 304,
            child: KanbanCard(
              task: task,
              companyId: 'co1',
              showTimerButton: showTimerButton,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('eligible task renders the toggle', (tester) async {
    await pumpCard(tester, task: _task(log: _stopped));
    expect(find.byIcon(Icons.play_circle_outlined), findsOneWidget);
  });

  testWidgets('drag-feedback ghost (showTimerButton:false) has no toggle', (
    tester,
  ) async {
    await pumpCard(tester, task: _task(log: _stopped), showTimerButton: false);
    expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
  });

  testWidgets('invoiced task hides the toggle', (tester) async {
    await pumpCard(
      tester,
      task: _task(invoiceId: 'inv1', log: _stopped),
    );
    expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
  });
}
