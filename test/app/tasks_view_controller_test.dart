import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/tasks_view_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';

/// The persistence contract for the Tasks layout preference
/// (invoiceninja/flutter#133):
///   * null until the user picks something — `resolveTasksViewMode` owns the
///     `list` default, so "fresh install", "cleared" and "unreadable" are one
///     state rather than three
///   * set() writes nav_state.tasks_view without clobbering a sibling column
///   * restore() round-trips it on the next launch
///   * a stored value this build doesn't know must not throw — restore() runs
///     inside main()'s boot Future.wait
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  test('starts null — never chosen, which resolves to the list', () {
    expect(TasksViewController(db: db).value, isNull);
  });

  test('restore() keeps null when nothing was ever written', () async {
    final controller = TasksViewController(db: db);
    await controller.restore();
    expect(controller.value, isNull);
  });

  test('set() persists and restores on the next launch', () async {
    final controller = TasksViewController(db: db);
    await controller.set(TasksViewMode.kanban);

    final row = await db.navStateDao.current();
    expect(row?.tasksView, 'kanban');

    final fresh = TasksViewController(db: db);
    expect(fresh.value, isNull, reason: 'before restore');
    await fresh.restore();
    expect(fresh.value, TasksViewMode.kanban);
  });

  test('set() leaves the other nav_state fields alone', () async {
    // The partial write must not clobber a sibling column — the whole reason
    // saveTasksView exists instead of widening save().
    await db.navStateDao.saveRoute(route: '/clients', now: 1);
    await TasksViewController(db: db).set(TasksViewMode.calendar);

    final row = await db.navStateDao.current();
    expect(row?.currentRoute, '/clients');
    expect(row?.tasksView, 'calendar');
  });

  test('set() does not notify when the same view is chosen twice', () async {
    final controller = TasksViewController(db: db);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(TasksViewMode.weekly);
    expect(notifications, 1);

    await controller.set(TasksViewMode.weekly);
    expect(notifications, 1, reason: 'already weekly');
  });

  test('resetInMemory() drops the choice without touching the row', () async {
    // The logout fan-out's job: `nav_state` is wiped separately, but this
    // controller is built once in `Services.build` and outlives the logout, and
    // restore() early-returns on a null stored value — so without this a second
    // user signing in without relaunching opens Tasks on the first one's board.
    final controller = TasksViewController(db: db);
    await controller.set(TasksViewMode.kanban);

    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.resetInMemory();
    expect(controller.value, isNull);
    expect(notifications, 1);
    controller.resetInMemory();
    expect(notifications, 1, reason: 'already cleared');
  });

  test(
    'a stored name this build no longer knows restores to the default rather '
    'than throwing',
    () async {
      // Downgrade after a newer build wrote a mode that has since been renamed
      // or removed. restore() runs inside main()'s boot Future.wait, so a throw
      // here would take the whole launch down.
      await db.navStateDao.saveTasksView(name: 'gantt', now: 1);
      final controller = TasksViewController(db: db);
      await controller.restore();
      expect(controller.value, isNull);
    },
  );
}
