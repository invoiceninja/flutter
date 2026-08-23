import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests target the ConfirmActionsController persistence contract:
///   * defaults to ON (invoiceninja/flutter#49 ships the guard enabled)
///   * set() writes to nav_state.confirm_actions
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

  test('defaults to on', () {
    expect(ConfirmActionsController(db: db).value, isTrue);
  });

  test('restore() keeps the default when nothing was ever written', () async {
    final controller = ConfirmActionsController(db: db);
    await controller.restore();
    expect(controller.value, isTrue);
  });

  test('set(false) persists and restores on the next launch', () async {
    final controller = ConfirmActionsController(db: db);
    await controller.set(false);

    final row = await db.navStateDao.current();
    expect(row?.confirmActions, isFalse);

    final fresh = ConfirmActionsController(db: db);
    expect(fresh.value, isTrue, reason: 'before restore');
    await fresh.restore();
    expect(fresh.value, isFalse);
  });

  test('set() leaves the other nav_state fields alone', () async {
    // The partial write must not clobber a sibling column — the whole reason
    // saveConfirmActions exists instead of widening save().
    await db.navStateDao.saveRoute(route: '/clients', now: 1);
    await ConfirmActionsController(db: db).set(false);

    final row = await db.navStateDao.current();
    expect(row?.currentRoute, '/clients');
    expect(row?.confirmActions, isFalse);
  });

  test('set() does not notify when the same value is chosen twice', () async {
    final controller = ConfirmActionsController(db: db);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(true);
    expect(notifications, 0, reason: 'already on');

    await controller.set(false);
    expect(notifications, 1);
  });
}
