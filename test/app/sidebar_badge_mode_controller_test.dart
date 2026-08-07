import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/sidebar_badge_mode_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('persistence', () {
    test('a chosen mode survives a restore', () async {
      final controller = SidebarBadgeModeController(db: db);
      await controller.set(EntityType.invoice, 'overdue');

      final reloaded = SidebarBadgeModeController(db: db);
      await reloaded.restore();
      expect(reloaded.modeFor(EntityType.invoice), 'overdue');
    });

    test(
      'choosing total clears the stored entry rather than persisting it — '
      'defaults stay implicit so a mode added later needs no backfill',
      () async {
        final controller = SidebarBadgeModeController(db: db);
        await controller.set(EntityType.invoice, 'overdue');
        await controller.set(EntityType.invoice, kBadgeModeTotal);
        expect(controller.modesToJson(), isEmpty);
        expect(controller.hasOverrides, isFalse);
      },
    );

    test('resetAll puts every row back on total', () async {
      final controller = SidebarBadgeModeController(db: db);
      await controller.set(EntityType.invoice, 'overdue');
      await controller.set(EntityType.quote, 'draft');
      await controller.resetAll();

      final reloaded = SidebarBadgeModeController(db: db);
      await reloaded.restore();
      expect(reloaded.modeFor(EntityType.invoice), kBadgeModeTotal);
      expect(reloaded.modeFor(EntityType.quote), kBadgeModeTotal);
    });
  });

  group('notification', () {
    test('re-selecting the current mode does not notify', () async {
      final controller = SidebarBadgeModeController(db: db);
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.set(EntityType.invoice, 'overdue');
      expect(notifications, 1);
      await controller.set(EntityType.invoice, 'overdue');
      expect(notifications, 1);
    });

    test('resetAll with nothing to reset does not notify', () async {
      final controller = SidebarBadgeModeController(db: db);
      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.resetAll();
      expect(notifications, 0);
    });
  });

  group('defensive decoding', () {
    // A stored blob is user data from a previous release: it must never be
    // able to break boot, only to be ignored.
    test('garbage falls back to defaults', () {
      final controller = SidebarBadgeModeController();
      for (final blob in ['', 'not json', '[]', '{"invoice": 7}']) {
        controller.restoreFromJson(blob);
        expect(
          controller.modeFor(EntityType.invoice),
          kBadgeModeTotal,
          reason: 'blob: $blob',
        );
      }
    });

    test('an unknown mode id is dropped, not persisted forward', () {
      final controller = SidebarBadgeModeController()
        ..restoreFromJson('{"invoice": "mode_from_a_future_release"}');
      expect(controller.modeFor(EntityType.invoice), kBadgeModeTotal);
      expect(controller.modesToJson(), isEmpty);
    });

    test('an unknown entity name is dropped', () {
      final controller = SidebarBadgeModeController()
        ..restoreFromJson('{"a_module_that_went_away": "overdue"}');
      expect(controller.modesToJson(), isEmpty);
    });
  });

  group('availability', () {
    test(
      'a stored mode the company no longer offers falls back to total — a '
      'stock counter has to stop being selected when inventory is switched off',
      () {
        final controller = SidebarBadgeModeController()
          ..restoreFromJson('{"product": "low_stock"}');
        expect(controller.modeFor(EntityType.product), 'low_stock');
        expect(
          controller.modeFor(
            EntityType.product,
            available: availableBadgeModes(
              kProductBadgeModes,
              trackInventory: false,
            ),
          ),
          kBadgeModeTotal,
        );
        expect(
          controller.modeFor(
            EntityType.product,
            available: availableBadgeModes(
              kProductBadgeModes,
              trackInventory: true,
            ),
          ),
          'low_stock',
        );
      },
    );
  });
}
