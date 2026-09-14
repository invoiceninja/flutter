import 'package:admin/app/hide_unverified_users_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests target the HideUnverifiedUsersController persistence contract:
///   * defaults to OFF — the opposite of its two bool siblings, because this
///     one removes people from a form rather than adding chrome to one
///     (invoiceninja/flutter#150; `email_verified_at` conflates four states,
///     BACKEND.md § F4)
///   * set() writes to nav_state.hide_unverified_users
///   * restore() round-trips the stored value on next launch
///   * restore() on a database that has never written keeps the default
///
/// They don't re-test Drift or ValueNotifier itself.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  test(
    'defaults to off — hiding colleagues is not a safe thing to switch on for\n      a user who never opened Settings',
    () {
      expect(HideUnverifiedUsersController(db: db).value, isFalse);
    },
  );

  test('restore() keeps the default when nothing was ever written', () async {
    final controller = HideUnverifiedUsersController(db: db);
    await controller.restore();
    expect(controller.value, isFalse);
  });

  test('set(true) persists and restores on the next launch', () async {
    final controller = HideUnverifiedUsersController(db: db);
    await controller.set(true);

    final row = await db.navStateDao.current();
    expect(row?.hideUnverifiedUsers, isTrue);

    final fresh = HideUnverifiedUsersController(db: db);
    expect(fresh.value, isFalse, reason: 'before restore');
    await fresh.restore();
    expect(fresh.value, isTrue);
  });

  test('set() leaves the other nav_state fields alone', () async {
    // The partial write must not clobber a sibling column — the whole reason
    // saveHideUnverifiedUsers exists instead of widening save().
    await db.navStateDao.saveRoute(route: '/clients', now: 1);
    await db.navStateDao.saveStatusTabs(enabled: false, now: 1);
    await HideUnverifiedUsersController(db: db).set(true);

    final row = await db.navStateDao.current();
    expect(row?.currentRoute, '/clients');
    expect(row?.statusTabs, isFalse);
    expect(row?.hideUnverifiedUsers, isTrue);
  });

  test('set() does not notify when the same value is chosen twice', () async {
    final controller = HideUnverifiedUsersController(db: db);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(false);
    expect(notifications, 0, reason: 'already off');

    await controller.set(true);
    expect(notifications, 1);
  });
}
