import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/domain/entity_type.dart';

/// Catches drift between [kWiredEntityModules] and the runtime `wireEntity<…>`
/// calls in `lib/app/services.dart`. Two failure modes:
///
/// 1. A `wireEntity<…>()` call without a matching `kWiredEntityModules` entry
///    — the entity lands in the dispatcher map but never makes it into the
///    [EntityRegistry], so the router/sidebar/outbox can't see it.
/// 2. A `kWiredEntityModules` entry without a matching `wireEntity<…>()` call
///    — the spec→handler loop in services.dart trips its `assert(dispatcher
///    != null)` (debug) or the `dispatcher!` null-check (release).
///
/// We exercise case 1 by walking [EntityType] values, building [Services],
/// and asserting every entity that resolves to a real (non-disabled) handler
/// has a corresponding spec entry. Case 2 is structurally caught by
/// `Services.build` itself.
void main() {
  test('every EntityType with a real dispatcher in services.dart has a '
      'kWiredEntityModules entry', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final services = Services.build(
      db: db,
      tokenStorage: InMemoryTokenStorage(),
      connectivityWatcher: ConnectivityWatcher.fixed(online: false),
    );
    try {
      final wiredTypes = {for (final m in kWiredEntityModules) m.type};
      final disabledTypes = {for (final m in kDisabledEntityModules) m.type};
      // EntityTypes registered in services.dart as plain inline handlers
      // (no list/edit screens, sync-only registrations). These intentionally
      // live outside kWiredEntityModules — see the comment above each
      // override block in services.dart.
      const inlineSyncOnly = {EntityType.company, EntityType.user};

      final missing = <EntityType>[];
      for (final handler in services.entityRegistry.all) {
        final type = handler.type;
        if (inlineSyncOnly.contains(type)) continue;
        if (disabledTypes.contains(type)) continue;
        if (!wiredTypes.contains(type)) missing.add(type);
      }

      expect(
        missing,
        isEmpty,
        reason:
            'These EntityTypes are wired in services.dart but missing from '
            'kWiredEntityModules. Add an EntityModuleSpec entry in '
            'lib/app/entity_modules.dart for each:\n'
            '${missing.join('\n')}',
      );
    } finally {
      await services.auth.dispose();
      await db.close();
    }
  });

  // Designs and Tax Rates are edited from Settings while their specs sit in
  // kDisabledEntityModules. The registry used to hand them the throwing stub
  // regardless, so every save died in the outbox with "No sync dispatcher
  // for EntityType.design".
  test('a disabled spec with wired sync keeps its real dispatcher', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final services = Services.build(
      db: db,
      tokenStorage: InMemoryTokenStorage(),
      connectivityWatcher: ConnectivityWatcher.fixed(online: false),
    );
    try {
      for (final type in [EntityType.design, EntityType.taxRate]) {
        expect(
          services.entityRegistry[type]?.dispatcher,
          isNot(isA<DisabledEntityDispatcher>()),
          reason: '$type is edited from Settings, so its saves must sync',
        );
      }
    } finally {
      await services.auth.dispose();
      await db.close();
    }
  });
}
