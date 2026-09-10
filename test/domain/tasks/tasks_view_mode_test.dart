import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/tasks/tasks_view_mode.dart';

/// The two pure halves of invoiceninja/flutter#133's fix. Both are tested here
/// rather than by pumping `TaskListScreen`, which needs a real `Services`, a
/// router and four async loads to reach a decision that is arithmetic.
void main() {
  group('tasksViewModeFromQuery', () {
    test('maps every mode name to its mode', () {
      for (final mode in TasksViewMode.values) {
        expect(tasksViewModeFromQuery(mode.name), mode, reason: mode.name);
      }
    });

    test(
      "'full' is the master-detail PANE flag, not a layout — it must resolve to "
      'null so an open editor falls back to the remembered view',
      () {
        // `MasterDetailLayout` auto-promotes an editor to `?view=full` one
        // frame after it opens, and the tasks list is rebuilt from that same
        // GoRouterState. Mapping it onto `list` would say the URL had chosen
        // the list; mapping it onto a layout would make the pane flag a layout.
        expect(tasksViewModeFromQuery('full'), isNull);
      },
    );

    test('no opinion: null, empty, unknown and wrong-case all yield null', () {
      expect(tasksViewModeFromQuery(null), isNull);
      expect(tasksViewModeFromQuery(''), isNull);
      expect(tasksViewModeFromQuery('bogus'), isNull);
      expect(tasksViewModeFromQuery('Kanban'), isNull);
    });
  });

  group('resolveTasksViewMode', () {
    test(
      'the bug: a bare /tasks after cancelling a create keeps the board',
      () {
        // Exactly the state the reporter hit — the FAB dropped `?view=kanban`
        // on the way in and the close target is the bare list path.
        expect(
          resolveTasksViewMode(
            urlView: null,
            remembered: TasksViewMode.kanban,
            locked: false,
          ),
          TasksViewMode.kanban,
        );
      },
    );

    test('an explicit URL view outranks the remembered one', () {
      expect(
        resolveTasksViewMode(
          urlView: TasksViewMode.list,
          remembered: TasksViewMode.kanban,
          locked: false,
        ),
        TasksViewMode.list,
      );
    });

    test('locked outranks both — a pane, an intent or a scoped list', () {
      expect(
        resolveTasksViewMode(
          urlView: TasksViewMode.calendar,
          remembered: TasksViewMode.kanban,
          locked: true,
        ),
        TasksViewMode.list,
      );
    });

    test('nothing chosen anywhere falls back to the list', () {
      expect(
        resolveTasksViewMode(urlView: null, remembered: null, locked: false),
        TasksViewMode.list,
      );
    });
  });
}
