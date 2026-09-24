import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/tasks_view_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';

/// The persistence contract for the Tasks layout preference
/// (invoiceninja/flutter#133):
///   * null until the user picks something — `resolveTasksViewMode` owns the
///     `list` default, so "fresh install", "cleared" and "unreadable" are one
///     state rather than three
///   * set() writes `DevicePrefKeys.tasksView`, and a relaunch reads it
///   * a stored value this build doesn't know reads as never chosen
///   * a data wipe forgets it
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  test('starts null — never chosen, which resolves to the list', () {
    expect(TasksViewController(prefs: DevicePrefsStore(db)).value, isNull);
  });

  test('set() persists and survives a relaunch', () async {
    await TasksViewController(
      prefs: DevicePrefsStore(db),
    ).set(TasksViewMode.kanban);
    expect(
      (await db.devicePrefsDao.readAll())[DevicePrefKeys.tasksView.name],
      'kanban',
    );

    final prefs = DevicePrefsStore(db);
    final fresh = TasksViewController(prefs: prefs);
    expect(fresh.value, isNull, reason: 'before the boot load');
    await prefs.load();
    expect(fresh.value, TasksViewMode.kanban);
  });

  test('set() does not notify when the same view is chosen twice', () async {
    final controller = TasksViewController(prefs: DevicePrefsStore(db));
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(TasksViewMode.weekly);
    expect(notifications, 1);

    await controller.set(TasksViewMode.weekly);
    expect(notifications, 1, reason: 'already weekly');
  });

  test('a data wipe forgets the choice', () async {
    // An account preference: a second user signing in without relaunching
    // must not open Tasks on the first one's board.
    final prefs = DevicePrefsStore(db);
    final controller = TasksViewController(prefs: prefs);
    await controller.set(TasksViewMode.kanban);

    var notifications = 0;
    controller.addListener(() => notifications++);
    prefs.forgetWiped();
    expect(controller.value, isNull);
    expect(notifications, 1);
  });

  test('a stored name this build no longer knows loads as never chosen rather '
      'than throwing', () async {
    // Downgrade after a newer build wrote a mode that has since been renamed
    // or removed. The load runs inside main()'s boot Future.wait, so a throw
    // here would cost every preference for the launch.
    await db.devicePrefsDao.put(DevicePrefKeys.tasksView.name, 'gantt', now: 1);
    final prefs = DevicePrefsStore(db);
    final controller = TasksViewController(prefs: prefs);
    await prefs.load();
    expect(controller.value, isNull);
  });
}
