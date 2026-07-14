import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/features/tasks/widgets/task_list_tile.dart';

import '../shell/_shell_test_helpers.dart';

/// The inline 1-tap timer toggle on task list rows: it renders play/stop by
/// state, and hides for tasks that can't be toggled (invoiced / unsynced /
/// deleted) or while multi-selecting. Verified in both wide + narrow layouts.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _task({
  String id = 't1',
  String invoiceId = '',
  bool deleted = false,
  List<TimeEntry> log = const [],
}) => Task(
  id: id,
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
  isDeleted: deleted,
);

final _running = [TimeEntry(start: DateTime.utc(2026, 1, 1, 9), stop: null)];
final _stopped = [
  TimeEntry(
    start: DateTime.utc(2026, 1, 1, 9),
    stop: DateTime.utc(2026, 1, 1, 10),
  ),
];

void main() {
  Future<void> pumpTile(
    WidgetTester tester, {
    required Task task,
    required bool wide,
    bool selecting = false,
  }) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        // No onAction: the ⋮ EntityActionsPopupButton is irrelevant to the
        // toggle assertions and overflows its fixed slot under the plain
        // test font — the toggle button renders independently of it.
        TaskListTile(
          task: task,
          companyId: 'co1',
          columns: const [],
          wide: wide,
          selecting: selecting,
          onTap: () {},
          onSelectTap: () {},
        ),
      ),
    );
    await tester.pump();
  }

  for (final wide in [true, false]) {
    final mode = wide ? 'wide' : 'narrow';

    testWidgets('$mode: running task shows the stop toggle', (tester) async {
      await pumpTile(
        tester,
        task: _task(log: _running),
        wide: wide,
      );
      expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
      // Unmount so the narrow layout's RunningDurationLabel ticker/timer is
      // disposed before the pending-timer check.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$mode: stopped task shows the start toggle', (tester) async {
      await pumpTile(
        tester,
        task: _task(log: _stopped),
        wide: wide,
      );
      expect(find.byIcon(Icons.play_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });

    testWidgets('$mode: invoiced task hides the toggle', (tester) async {
      await pumpTile(
        tester,
        task: _task(invoiceId: 'inv1', log: _stopped),
        wide: wide,
      );
      expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
      expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    });

    testWidgets('$mode: unsynced tmp_ task hides the toggle', (tester) async {
      await pumpTile(
        tester,
        task: _task(id: 'tmp_1', log: _stopped),
        wide: wide,
      );
      expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
    });

    testWidgets('$mode: deleted task hides the toggle', (tester) async {
      await pumpTile(
        tester,
        task: _task(deleted: true, log: _stopped),
        wide: wide,
      );
      expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
    });

    testWidgets('$mode: multi-select hides the toggle', (tester) async {
      await pumpTile(
        tester,
        task: _task(log: _stopped),
        wide: wide,
        selecting: true,
      );
      expect(find.byIcon(Icons.play_circle_outlined), findsNothing);
    });
  }
}
