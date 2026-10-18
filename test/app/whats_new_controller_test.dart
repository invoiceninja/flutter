import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/device_prefs_dao.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/release_notes.dart';

/// A store whose preference rows can't be read — the boot `load` that
/// failed, leaving every read a default.
class _WedgedDatabase extends AppDatabase {
  _WedgedDatabase() : super(NativeDatabase.memory());

  @override
  DevicePrefsDao get devicePrefsDao => throw StateError('wedged');
}

/// The What's New schedule (docs/whats-new-dialog.md): who is told about an
/// update, what is remembered, and how long the mobile-app promo keeps away.
void main() {
  final noon = DateTime.utc(2026, 10, 14, 12);
  const catalog = [
    ReleaseNotes(version: '2.0.2', items: [ReleaseNoteItem('Added: two')]),
    ReleaseNotes(version: '2.0.1', items: [ReleaseNoteItem('Fixed: one')]),
  ];

  late DevicePrefsStore prefs;

  setUp(() => prefs = DevicePrefsStore(null));

  WhatsNewController controller({
    String current = '2.0.2',
    bool isDemoBuild = false,
    DevicePrefsStore? store,
  }) {
    final c = WhatsNewController(
      prefs: store ?? prefs,
      currentVersion: current,
      catalog: catalog,
      surfaces: const {},
      isDemoBuild: isDemoBuild,
      demoMode: false,
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> seen(String version) => prefs.write(
    DevicePrefKeys.whatsNew,
    WhatsNewState(seenVersion: version).encode(),
  );

  group('noteLaunch', () {
    test('a new install is told nothing, and remembers its version', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: false);
      expect(c.pending, isEmpty);
      expect(c.state.seenVersion, '2.0.2');
      expect(c.holdsBackPromptsAt(noon), isFalse);
    });

    test('a device that ran a build from before the record gets this '
        "release's notes", () async {
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      expect([for (final r in c.pending) r.version], ['2.0.2']);
      expect(c.autoOpens, isTrue);
      expect(c.state.seenVersion, isNull, reason: 'written once read');
    });

    test('an update shows every release since the one last seen', () async {
      await seen('2.0.0');
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      expect([for (final r in c.pending) r.version], ['2.0.2', '2.0.1']);
    });

    test('the same version, or an older build, is told nothing', () async {
      await seen('2.0.2');
      final same = controller();
      await same.noteLaunch(existingInstall: true);
      expect(same.pending, isEmpty);

      await seen('3.0.0');
      final downgraded = controller();
      await downgraded.noteLaunch(existingInstall: true);
      expect(downgraded.pending, isEmpty);
      expect(downgraded.state.seenVersion, '3.0.0');
    });

    test('an update with no notes writes nothing, so the next build that '
        'has some still covers it', () async {
      await seen('2.0.2');
      final c = controller(current: '2.0.3');
      await c.noteLaunch(existingInstall: true);
      expect(c.pending, isEmpty);
      expect(c.state.seenVersion, '2.0.2');
    });

    test('a demo build is never told', () async {
      final c = controller(isDemoBuild: true);
      await c.noteLaunch(existingInstall: true);
      expect(c.pending, isEmpty);
      expect(prefs.read(DevicePrefKeys.whatsNew), isNull);
    });

    test('a store whose rows could not be read is left alone — a baseline '
        'written then would overwrite the real record', () async {
      final db = _WedgedDatabase();
      addTearDown(db.close);
      final broken = DevicePrefsStore(db);
      await expectLater(broken.load(), throwsStateError);
      expect(broken.isLoaded, isTrue);
      expect(broken.loadSucceeded, isFalse);

      final c = controller(store: broken);
      await c.noteLaunch(existingInstall: false);
      expect(c.state.seenVersion, isNull);
      expect(broken.read(DevicePrefKeys.whatsNew), isNull);
    });
  });

  group('reading the notes', () {
    test('marking them seen records the version and ends the open', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      await c.noteOpened(noon);
      await c.markSeen();
      expect(c.pending, isEmpty);
      expect(c.autoOpens, isFalse);
      expect(c.state.seenVersion, '2.0.2');

      // The next launch of the same build is told nothing.
      final next = controller();
      await next.noteLaunch(existingInstall: true);
      expect(next.pending, isEmpty);
    });

    test('three launches with no quiet moment stop the automatic open, but '
        'the notes stay for About', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      for (var i = 0; i < WhatsNewController.maxAttempts; i++) {
        expect(c.autoOpens, isTrue);
        await c.noteGaveUp();
      }
      expect(c.autoOpens, isFalse);
      expect(c.holdsBackPromptsAt(noon), isFalse);
      expect(c.onRequest, isNotEmpty);
    });

    test('attempts count per version — a release that never found a quiet '
        "moment doesn't silence the next", () async {
      final old = controller(current: '2.0.1');
      await old.noteLaunch(existingInstall: true);
      for (var i = 0; i < WhatsNewController.maxAttempts; i++) {
        await old.noteGaveUp();
      }
      expect(old.autoOpens, isFalse);

      final next = controller();
      await next.noteLaunch(existingInstall: true);
      expect(next.autoOpens, isTrue);
    });

    test('About opens this release when no update is waiting', () async {
      await seen('2.0.2');
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      expect(c.pending, isEmpty);
      expect([for (final r in c.onRequest) r.version], ['2.0.2']);
    });
  });

  group('holdsBackPromptsAt — the mobile-app promo keeps a day away', () {
    test('while the dialog may still open on its own', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      expect(c.holdsBackPromptsAt(noon), isTrue);
    });

    test('for a day after it opened, then not', () async {
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      await c.noteOpened(noon);
      await c.markSeen();
      expect(c.holdsBackPromptsAt(noon.add(const Duration(hours: 23))), isTrue);
      expect(c.holdsBackPromptsAt(noon.add(const Duration(days: 1))), isFalse);
    });

    test('a clock moved back holds nothing', () async {
      final c = controller();
      await c.noteOpened(noon);
      expect(
        c.holdsBackPromptsAt(noon.subtract(const Duration(days: 30))),
        isFalse,
      );
    });
  });

  test('the record survives a restart and a sign-out wipe', () async {
    final c = controller();
    await c.noteLaunch(existingInstall: true);
    await c.noteOpened(noon);
    await c.markSeen();

    final next = controller();
    expect(next.state, c.state);

    prefs.forgetWiped();
    expect(next.state.seenVersion, '2.0.2', reason: 'a device preference');
    expect(
      prefs.read(DevicePrefKeys.whatsNew),
      isNotNull,
      reason: 'kept on disk too',
    );
  });

  test('built before the store loads, it reads the stored record when the '
      'store does', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final seeded = DevicePrefsStore(db);
    await seeded.load();
    await seeded.write(
      DevicePrefKeys.whatsNew,
      WhatsNewState(seenVersion: '2.0.1', shownAt: noon).encode(),
    );

    final cold = DevicePrefsStore(db);
    final c = controller(store: cold);
    expect(c.state.seenVersion, isNull);
    await cold.load();
    expect(c.state.seenVersion, '2.0.1');
    expect(c.state.shownAt, noon);
  });

  test('an unreadable row is an install that predates the record', () {
    expect(WhatsNewState.decode('not json'), const WhatsNewState());
    expect(WhatsNewState.decode('[1]'), const WhatsNewState());
    expect(
      WhatsNewState.decode('{"seenVersion": 3, "attempts": -1}'),
      const WhatsNewState(),
    );
  });
}
