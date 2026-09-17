import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests target the HideEmptyPanelsController persistence contract
/// (invoiceninja/flutter#161):
///   * null means automatic — the stored column starts null and a fresh
///     controller carries no choice of its own
///   * [HideEmptyPanelsController.effectiveFor] turns automatic into the
///     device answer (on for a phone) and lets an explicit choice win
///   * set() writes to nav_state.hide_empty_panels and restore() reads it back
///   * set() stores automatic (null) when the choice is what the device would
///     pick anyway, so a foldable or split-screen window keeps adapting
///   * resetInMemory() forgets the choice without touching the database
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

  test('starts on automatic — no choice of its own', () {
    expect(HideEmptyPanelsController(db: db).value, isNull);
  });

  group('effectiveFor', () {
    test('automatic hides on a phone and shows everywhere else', () {
      final controller = HideEmptyPanelsController(db: db);
      expect(controller.effectiveFor(isPhone: true), isTrue);
      expect(controller.effectiveFor(isPhone: false), isFalse);
    });

    test('an explicit choice wins on either device', () {
      final off = HideEmptyPanelsController(db: db, initial: false);
      expect(
        off.effectiveFor(isPhone: true),
        isFalse,
        reason: 'a phone user who switched it off must see empty panels',
      );
      final on = HideEmptyPanelsController(db: db, initial: true);
      expect(on.effectiveFor(isPhone: false), isTrue);
    });
  });

  test('restore() stays on automatic when nothing was ever written', () async {
    final controller = HideEmptyPanelsController(db: db);
    await controller.restore();
    expect(controller.value, isNull);

    // A row written by some other preference leaves this column null too.
    await db.navStateDao.saveStatusTabs(enabled: false, now: 1);
    await controller.restore();
    expect(controller.value, isNull);
  });

  test('set(false) persists and restores on the next launch', () async {
    // The case the nullable column exists for: an explicit "off" on a phone,
    // where automatic would have said "on".
    final controller = HideEmptyPanelsController(db: db);
    await controller.set(false, isPhone: true);

    final row = await db.navStateDao.current();
    expect(row?.hideEmptyPanels, isFalse);

    final fresh = HideEmptyPanelsController(db: db);
    expect(fresh.value, isNull, reason: 'before restore');
    await fresh.restore();
    expect(fresh.value, isFalse);
    expect(fresh.effectiveFor(isPhone: true), isFalse);
  });

  test('set() leaves the other nav_state fields alone', () async {
    // The partial write must not clobber a sibling column — the whole reason
    // saveHideEmptyPanels exists instead of widening save().
    await db.navStateDao.saveRoute(route: '/dashboard', now: 1);
    await db.navStateDao.saveHideUnverifiedUsers(enabled: true, now: 1);
    // On a desktop, where automatic says off, so "on" is an override.
    await HideEmptyPanelsController(db: db).set(true, isPhone: false);

    final row = await db.navStateDao.current();
    expect(row?.currentRoute, '/dashboard');
    expect(row?.hideUnverifiedUsers, isTrue);
    expect(row?.hideEmptyPanels, isTrue);
  });

  test('set() does not notify when the same value is chosen twice', () async {
    final controller = HideEmptyPanelsController(db: db, initial: true);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(true, isPhone: false);
    expect(notifications, 0, reason: 'already an explicit on');

    await controller.set(false, isPhone: false);
    expect(notifications, 1);
  });

  group('choosing what the device would pick returns to automatic', () {
    test('a phone switched off and back on is automatic again', () async {
      final controller = HideEmptyPanelsController(db: db);
      await controller.set(false, isPhone: true);
      expect(controller.value, isFalse);

      await controller.set(true, isPhone: true);
      expect(controller.value, isNull);
      expect((await db.navStateDao.current())?.hideEmptyPanels, isNull);
    });

    test('a desktop switched on and back off is automatic again', () async {
      final controller = HideEmptyPanelsController(db: db);
      await controller.set(true, isPhone: false);
      expect(controller.value, isTrue);

      await controller.set(false, isPhone: false);
      expect(controller.value, isNull);
    });

    test('a foldable keeps adapting until the user overrides it', () async {
      // Folded (a phone) the default is on, open (a tablet) it is off. Picking
      // each default where it applies stores nothing, so both halves keep
      // their own answer.
      final controller = HideEmptyPanelsController(db: db);
      await controller.set(true, isPhone: true);
      expect(controller.effectiveFor(isPhone: true), isTrue);
      expect(controller.effectiveFor(isPhone: false), isFalse);

      // A real override — "on" while open — applies to both halves.
      await controller.set(true, isPhone: false);
      expect(controller.effectiveFor(isPhone: true), isTrue);
      expect(controller.effectiveFor(isPhone: false), isTrue);
    });
  });

  test(
    'resetInMemory() returns to automatic without touching the database',
    () async {
      final controller = HideEmptyPanelsController(db: db);
      await controller.set(false, isPhone: true);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.resetInMemory();
      expect(controller.value, isNull);
      expect(notifications, 1);

      // Idempotent: already automatic, so no second notification.
      controller.resetInMemory();
      expect(notifications, 1);

      // The row is the wipe's job, not this method's.
      final row = await db.navStateDao.current();
      expect(row?.hideEmptyPanels, isFalse);
    },
  );
}
