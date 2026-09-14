import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/tasks/widgets/task_list_tile.dart';

import '../shell/_shell_test_helpers.dart';

/// The inline 1-tap timer toggle on task list rows: it renders play/stop by
/// state, and hides for tasks that can't be toggled (invoiced / unsynced /
/// deleted) or while multi-selecting. Verified in both wide + narrow layouts.
/// The leading assigned-user badge is covered separately, in
/// `task_list_tile_assignee_test.dart` — it resolves over a repo watch, which
/// this fixture's real Drift database can't serve inside a widget test.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _task({
  String id = 't1',
  String invoiceId = '',
  bool deleted = false,
  List<TimeEntry> log = const [],
  Date? dueDate,
  int estimatedSeconds = 0,
}) => Task(
  estimatedSeconds: estimatedSeconds,
  dueDate: dueDate,
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
  group('the booked-time slot (flutter#149)', () {
    // A booked-but-unstarted task renders WHEN in the slot the duration
    // normally occupies, never a second chip — the narrow row's identity
    // column has no width to give up.
    List<TimeEntry> blockAt(DateTime start, Duration length) => [
      TimeEntry(start: start, stop: start.add(length)),
    ];

    testWidgets('a booking later today shows its start time, not 0:00', (
      tester,
    ) async {
      final start = DateTime.now().add(const Duration(hours: 3));
      await pumpTile(
        tester,
        task: _task(log: blockAt(start, const Duration(hours: 2))),
        wide: false,
      );
      expect(find.text('0:00'), findsNothing);
      final hour12 = start.hour % 12 == 0 ? 12 : start.hour % 12;
      final mm = start.minute.toString().padLeft(2, '0');
      expect(
        find.text('$hour12:$mm ${start.hour >= 12 ? 'PM' : 'AM'}'),
        findsOneWidget,
      );
    });

    testWidgets('a booking whose window is open reads "Now"', (tester) async {
      await pumpTile(
        tester,
        task: _task(
          // Anchored: a block spanning `now` is only a booking when the task's
          // own due date says so — otherwise it is today's timesheet row.
          dueDate: Date.today(),
          log: blockAt(
            DateTime.now().subtract(const Duration(minutes: 20)),
            const Duration(hours: 2),
          ),
        ),
        wide: false,
      );
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('a passed booking on the due date reads how late it is', (
      tester,
    ) async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 2));
      await pumpTile(
        tester,
        task: _task(
          log: blockAt(start, const Duration(minutes: 30)),
          dueDate: Date(start.year, start.month, start.day),
          // `late` also requires the estimate to match the block — without
          // that clause a single real logged entry on its due date reads as an
          // unworked booking, and claiming offers to discard it.
          estimatedSeconds: const Duration(minutes: 30).inSeconds,
        ),
        wide: false,
      );
      // The exact lateness, not merely "something with a plus in it": measured
      // from the booked START, which is when the user promised to be there.
      expect(find.text('+2:00'), findsOneWidget);
    });

    testWidgets('a task with nothing booked is untouched', (tester) async {
      await pumpTile(tester, task: _task(log: _stopped), wide: false);
      // Unchanged from before this feature: the plain logged total,
      // seconds and all (the tile passes no `showSeconds: false`).
      expect(find.text('1:00:00'), findsOneWidget);
    });
  });
}
