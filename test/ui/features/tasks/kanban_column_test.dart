import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_board.dart'
    show kKanbanColumnWidth;
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_column.dart';

import '../shell/_shell_test_helpers.dart';

/// [KanbanColumn]'s two independent gates (invoiceninja/flutter#135).
///
/// `canEdit` is "may rearrange the board" — the board folds `!filtersActive`
/// into it, so it goes false the moment a Client / Project / Assignee filter is
/// applied. `canCreate` is "may start a new task" (`create_task`), and it is
/// filter-independent. They were one field until the kanban screen dropped its
/// FAB, which made the `+ New Task` footer the board's ONLY create path: with
/// the two conflated, filtering the board — or holding `create_task` without
/// `edit_task` — left no way to add a task at all.
///
/// Nothing about that is visible at the call site, and neither half fails
/// loudly: the wrong gate simply renders one widget fewer.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

final _status = TaskStatus(
  id: 's1',
  name: 'Backlog',
  color: '',
  statusOrder: 0,
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

void main() {
  /// Pumps a column with NO tasks, which keeps the body's `ListView.builder` at
  /// `itemCount: 0` — so no `KanbanCard` is built and nothing in the subtree
  /// reaches Drift. No `GoRouter` is needed either; the footer is only ever
  /// found, never tapped.
  Future<void> pumpColumn(
    WidgetTester tester, {
    required bool canEdit,
    required bool canCreate,
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
            width: kKanbanColumnWidth,
            height: 600,
            child: KanbanColumn(
              status: _status,
              tasks: const <Task>[],
              companyId: 'co1',
              canEdit: canEdit,
              canCreate: canCreate,
              onAcceptTask: (_, _) {},
              // The header drag handle needs BOTH `canEdit` and a non-null
              // `onAcceptStatus`, so a test asserting the handle's absence
              // proves nothing unless this is supplied. Always non-null: the
              // board derives both from one expression, so `canEdit: true`
              // alongside a null callback is unreachable in production.
              onAcceptStatus: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // `en.json`: new_task => 'New Task'. `find.text` is an exact match, so the
  // column's other strings (the status name, and 'New Task Status' elsewhere in
  // the app) cannot satisfy it.
  final footer = find.text('New Task');
  // With an empty column this is the header's handle — the only one left once
  // the per-card handles have nothing to attach to.
  final dragHandle = find.byIcon(Icons.drag_indicator);

  testWidgets('canCreate renders the + New Task footer', (tester) async {
    await pumpColumn(tester, canEdit: true, canCreate: true);
    expect(footer, findsOneWidget);
  });

  testWidgets('without canCreate there is no footer', (tester) async {
    await pumpColumn(tester, canEdit: true, canCreate: false);
    expect(footer, findsNothing);
    // ...and the reorder affordance is untouched, so a reader can see that the
    // absence above is the create gate and not a collapsed column.
    expect(dragHandle, findsOneWidget);
  });

  testWidgets('a filtered board keeps the footer but loses the drag handle', (
    tester,
  ) async {
    // What the board passes once any filter is active — and what a create-only
    // user (`create_task`, no `edit_task`) gets at every moment. This is the
    // case the split exists for.
    await pumpColumn(tester, canEdit: false, canCreate: true);
    expect(footer, findsOneWidget);
    expect(dragHandle, findsNothing);
  });

  testWidgets('neither gate leaves both affordances off', (tester) async {
    await pumpColumn(tester, canEdit: false, canCreate: false);
    expect(footer, findsNothing);
    expect(dragHandle, findsNothing);
  });
}
