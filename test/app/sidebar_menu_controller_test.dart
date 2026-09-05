import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/sidebar_menu_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/sidebar_menu.dart';

/// Tests target the SidebarMenuController persistence contract
/// (invoiceninja/flutter#125):
///   * defaults to the list layout in the app's own order, everything shown
///   * writes land in nav_state.sidebar_menu_json and nowhere else
///   * restore() round-trips on the next launch, and survives a corrupt blob
///   * the "nothing customised" state writes null, so Reset really resets
///
/// They don't re-test Drift, ChangeNotifier, or resolveMenuEntries (which has
/// its own test in test/domain/sidebar_menu_test.dart).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  const defaults = ['dashboard', 'client', 'invoice'];

  test('defaults to the list layout in the app order, nothing hidden', () {
    final controller = SidebarMenuController(db: db);
    expect(controller.layout, SidebarMenuLayout.list);
    expect(controller.hasCustomEntries, isFalse);
    expect([for (final e in controller.entriesFor(defaults)) e.id], defaults);
  });

  test('restore() keeps the defaults when nothing was ever written', () async {
    final controller = SidebarMenuController(db: db);
    await controller.restore();
    expect(controller.layout, SidebarMenuLayout.list);
    expect(controller.hasCustomEntries, isFalse);
  });

  test('layout persists and restores on the next launch', () async {
    await SidebarMenuController(db: db).setLayout(SidebarMenuLayout.grid);

    final restored = SidebarMenuController(db: db);
    await restored.restore();
    expect(restored.layout, SidebarMenuLayout.grid);
  });

  test('order + visibility persist and restore on the next launch', () async {
    await SidebarMenuController(db: db).setEntries(const [
      SidebarMenuEntryPref(id: 'invoice'),
      SidebarMenuEntryPref(id: 'client', visible: false),
      SidebarMenuEntryPref(id: 'dashboard'),
    ]);

    final restored = SidebarMenuController(db: db);
    await restored.restore();
    expect(restored.hasCustomEntries, isTrue);
    final entries = restored.entriesFor(defaults);
    expect([for (final e in entries) e.id], ['invoice', 'client', 'dashboard']);
    expect(entries[1].visible, isFalse);
  });

  test('the write leaves the other nav_state fields alone', () async {
    // The partial write is the whole reason saveSidebarMenu exists instead of
    // widening save().
    await db.navStateDao.saveRoute(route: '/clients', now: 1);
    await SidebarMenuController(db: db).setLayout(SidebarMenuLayout.grid);

    final row = await db.navStateDao.current();
    expect(row?.currentRoute, '/clients');
    expect(row?.sidebarMenuJson, isNotNull);
  });

  test('resetEntries() returns the row to its never-touched state', () async {
    // Null, not an empty envelope: "never customised" and "customised back to
    // the default" have to be the same stored state, or a later release that
    // adds a destination would treat the second as an explicit exclusion.
    final controller = SidebarMenuController(db: db);
    await controller.setEntries(const [SidebarMenuEntryPref(id: 'invoice')]);
    expect((await db.navStateDao.current())?.sidebarMenuJson, isNotNull);

    await controller.resetEntries();
    expect(controller.hasCustomEntries, isFalse);
    expect((await db.navStateDao.current())?.sidebarMenuJson, isNull);
  });

  test('resetEntries() leaves the layout alone', () async {
    // The layout control sits right beside Reset; flipping it from under the
    // user would read as a bug.
    final controller = SidebarMenuController(db: db);
    await controller.setLayout(SidebarMenuLayout.grid);
    await controller.setEntries(const [SidebarMenuEntryPref(id: 'invoice')]);
    await controller.resetEntries();
    expect(controller.layout, SidebarMenuLayout.grid);
    expect((await db.navStateDao.current())?.sidebarMenuJson, isNotNull);
  });

  test('does not notify when nothing changed', () async {
    final controller = SidebarMenuController(db: db);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setLayout(SidebarMenuLayout.list);
    await controller.resetEntries();
    expect(notifications, 0);

    await controller.setLayout(SidebarMenuLayout.grid);
    expect(notifications, 1);
    await controller.setEntries(const [SidebarMenuEntryPref(id: 'invoice')]);
    expect(notifications, 2);
    await controller.setEntries(const [SidebarMenuEntryPref(id: 'invoice')]);
    expect(notifications, 2);
  });

  test('resetInMemory() drops the preference without writing', () async {
    // The logout fan-out calls this *before* the Drift wipe. It must not
    // persist (that row is about to be deleted) and it must actually clear, or
    // a second user signing in without restarting the app inherits the first
    // one's menu — and their first menu interaction writes that array into
    // their own fresh row.
    final controller = SidebarMenuController(db: db);
    await controller.setLayout(SidebarMenuLayout.grid);
    await controller.setEntries(const [
      SidebarMenuEntryPref(id: 'invoice', visible: false),
    ]);
    final before = await db.navStateDao.current();

    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.resetInMemory();

    expect(controller.layout, SidebarMenuLayout.list);
    expect(controller.hasCustomEntries, isFalse);
    expect(notifications, 1);
    // Untouched — the wipe, not this, is what clears the row.
    expect(
      (await db.navStateDao.current())?.sidebarMenuJson,
      before?.sidebarMenuJson,
    );

    // Idempotent: a second logout in the same process must not notify again.
    controller.resetInMemory();
    expect(notifications, 1);
  });

  group('restoreFromJson', () {
    test('drops unparsable entries but keeps the rest', () {
      final controller = SidebarMenuController()
        ..restoreFromJson(
          '{"layout":"grid","entries":["invoice|1","client|","dashboard|0",7]}',
        );
      expect(controller.layout, SidebarMenuLayout.grid);
      final entries = controller.entriesFor(defaults);
      // `client|` was dropped, so it re-defaults at its own index, visible.
      expect(
        [for (final e in entries) e.id],
        ['invoice', 'client', 'dashboard'],
      );
      expect(entries.firstWhere((e) => e.id == 'client').visible, isTrue);
      expect(entries.firstWhere((e) => e.id == 'dashboard').visible, isFalse);
    });

    test('a corrupt blob leaves the menu on its defaults, never throws', () {
      for (final raw in <String?>[
        null,
        '',
        'not json at all',
        '[]',
        '{"layout":"grid"}',
        '{"layout":"grid","entries":"nope"}',
        '{"entries":["invoice|1"]}',
      ]) {
        final controller = SidebarMenuController()..restoreFromJson(raw);
        expect(
          controller.layout,
          raw != null && raw.contains('"layout":"grid"')
              ? SidebarMenuLayout.grid
              : SidebarMenuLayout.list,
          reason: 'layout for $raw',
        );
        expect(
          [for (final e in controller.entriesFor(defaults)) e.id],
          // A layout-only blob and a corrupt one both leave the order at the
          // default. `{"entries":["invoice|1"]}` is not corrupt — it is a
          // partial preference, and the two missing ids splice back in at
          // their own default indices, which happens to reproduce the default
          // order exactly.
          defaults,
          reason: 'entries for $raw',
        );
      }
    });

    test('a second restore replaces rather than accumulates', () {
      final controller = SidebarMenuController()
        ..restoreFromJson('{"layout":"grid","entries":["invoice|0"]}')
        ..restoreFromJson(null);
      expect(controller.layout, SidebarMenuLayout.list);
      expect(controller.hasCustomEntries, isFalse);
    });
  });
}
