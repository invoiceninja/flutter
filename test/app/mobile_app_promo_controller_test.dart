import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/mobile_app_promo_controller.dart';
import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/release_notes.dart';

/// The promo's schedule (docs/mobile-app-promo.md): never before the third
/// day of use, at most three automatic opens, +7 then +30 days apart, and
/// nothing more once the user said no for good or took the app.
void main() {
  // Mid-day UTC, so the same calendar day from UTC−11 to UTC+10 (CLAUDE.md
  // § Strict rules — CI runs in UTC).
  final noon = DateTime.utc(2026, 10, 14, 12);
  const day1 = Date(2026, 10, 14);

  late DevicePrefsStore prefs;

  setUp(() => prefs = DevicePrefsStore(null));

  MobileAppPromoController controller() {
    final c = MobileAppPromoController(prefs: prefs, promote: true);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> useOn(MobileAppPromoController c, int days) async {
    for (var i = 0; i < days; i++) {
      await c.recordUseDay(day1.addDays(i));
    }
  }

  test('a new device is not due before its third day of use', () async {
    final c = controller();
    expect(c.isDue(noon), isFalse);
    await useOn(c, 2);
    expect(c.isDue(noon), isFalse);
    await c.recordUseDay(day1.addDays(2));
    expect(c.state.daysSeen, 3);
    expect(c.isDue(noon), isTrue);
  });

  test('a day is counted once, however many times it is recorded', () async {
    final c = controller();
    await c.recordUseDay(day1);
    await c.recordUseDay(day1);
    expect(c.state.daysSeen, 1);
  });

  test('closing snoozes 7 days, then 30, then stops for good', () async {
    final c = controller();
    await useOn(c, 3);

    expect(c.isLastReminder, isFalse);
    await c.snooze(noon);
    expect(c.isDue(noon.add(const Duration(days: 6))), isFalse);
    expect(c.isDue(noon.add(const Duration(days: 7))), isTrue);

    final second = noon.add(const Duration(days: 7));
    await c.snooze(second);
    expect(c.isLastReminder, isTrue);
    expect(c.isDue(second.add(const Duration(days: 29))), isFalse);
    expect(c.isDue(second.add(const Duration(days: 30))), isTrue);
    expect(c.showsSidebarCard, isTrue);

    await c.snooze(second.add(const Duration(days: 30)));
    expect(c.isDue(noon.add(const Duration(days: 3650))), isFalse);
    expect(
      c.showsSidebarCard,
      isFalse,
      reason: 'every reminder went by — the card goes with them',
    );
  });

  test('taking the app ends the automatic opens and the card', () async {
    final c = controller();
    await useOn(c, 3);
    await c.markEngaged();
    expect(c.isDue(noon), isFalse);
    expect(c.showsSidebarCard, isFalse);
  });

  test("don't show again ends the automatic opens and the card", () async {
    final c = controller();
    await useOn(c, 3);
    await c.finish();
    expect(c.isDue(noon), isFalse);
    expect(c.showsSidebarCard, isFalse);
  });

  test('the schedule survives a restart and a sign-out wipe', () async {
    final c = controller();
    await useOn(c, 3);
    await c.snooze(noon);
    await c.finish();

    final next = controller();
    expect(next.state, c.state);

    prefs.forgetWiped();
    expect(next.state.done, isTrue, reason: 'a device preference');
    expect(
      prefs.read(DevicePrefKeys.mobileAppPromo),
      isNotNull,
      reason: 'kept on disk too',
    );
  });

  test('an unreadable row is a device that has not been told yet', () async {
    for (final raw in ['not json', '[1]', '{"closes": "x", "nextAt": "y"}']) {
      await prefs.write(DevicePrefKeys.mobileAppPromo, raw);
      final c = controller();
      expect(c.state, const MobileAppPromoState(), reason: raw);
    }
  });

  test('built before the store loads, it reads the stored schedule when the '
      'store does', () async {
    // `Services.build` runs before `devicePrefs.load()` at boot: decoding
    // only at construction would see the defaults, and "Don't show again"
    // would never stick.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final seeded = DevicePrefsStore(db);
    await seeded.load();
    await seeded.write(
      DevicePrefKeys.mobileAppPromo,
      const MobileAppPromoState(daysSeen: 5, done: true).encode(),
    );

    final cold = DevicePrefsStore(db);
    final c = MobileAppPromoController(prefs: cold, promote: true);
    addTearDown(c.dispose);
    expect(c.isDue(noon), isFalse, reason: 'nothing is due before the load');
    // And a use recorded before the load must not overwrite the real row.
    await c.recordUseDay(day1);

    await cold.load();
    expect(c.state.done, isTrue);
    expect(c.state.daysSeen, 5);
  });

  test('a day behind the What\'s New dialog: never while it may still open '
      'on its own, nor within a day of it opening', () async {
    final whatsNew = WhatsNewController(
      prefs: prefs,
      currentVersion: '2.0.1',
      catalog: const [
        ReleaseNotes(version: '2.0.1', items: [ReleaseNoteItem('Added: x')]),
      ],
      surfaces: const {},
      isDemoBuild: false,
      demoMode: false,
    );
    addTearDown(whatsNew.dispose);
    final c = MobileAppPromoController(
      prefs: prefs,
      promote: true,
      whatsNew: whatsNew,
    );
    addTearDown(c.dispose);
    await useOn(c, 3);
    expect(c.isDue(noon), isTrue, reason: 'nothing pending yet');

    await whatsNew.noteLaunch(existingInstall: true);
    expect(c.isDue(noon), isFalse, reason: 'the update goes first');

    await whatsNew.noteOpened(noon);
    await whatsNew.markSeen();
    expect(c.isDue(noon.add(const Duration(hours: 23))), isFalse);
    expect(c.isDue(noon.add(const Duration(days: 1))), isTrue);
  });
}
