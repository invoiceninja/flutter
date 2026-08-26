import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/entity_type.dart';

/// Pins the persistence shape the saved-views feature relies on:
///   * snapshot envelope `{"v": 1, "data": {...}}`
///   * `apply` writes the snapshot into `nav_state.filters_json` at the
///     `companyId → entityType.name` slot
///   * corrupt / unknown rows are filtered out of the watch stream rather
///     than crashing the sidebar.
void main() {
  late AppDatabase db;
  late UserSettingsRepository userSettings;
  late SavedViewsRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    userSettings = UserSettingsRepository(db: db);
    repo = SavedViewsRepository(
      db: db,
      userSettings: userSettings,
      uuid: const Uuid(),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    // Seed the (companyId, userId) user_settings row that
    // UserSettingsRepository.setColumns expects to update — without it
    // setColumns silently no-ops, which would mask column-apply failures.
    await db.userSettingsDao.upsert(
      UserSettingsCompanion(
        companyId: const Value('co'),
        userId: const Value('user1'),
        tableColumnsJson: const Value('{}'),
        extraJson: const Value('{}'),
        updatedAt: const Value(0),
      ),
    );
  });
  tearDown(() async {
    await db.close();
  });

  group('create', () {
    test('round-trips name + entity + snapshot', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme US',
        snapshot: {
          'search': 'acme',
          'extraFilters': {
            'country_id': ['US'],
          },
        },
      );
      expect(view.companyId, 'co');
      expect(view.entityType, EntityType.client);
      expect(view.name, 'Acme US');
      expect(view.snapshot['search'], 'acme');
      expect(view.createdAt, 1000);

      final row = await db.savedViewsDao.byId(view.id);
      // Stored payload is wrapped in the schema-versioned envelope.
      final decoded = jsonDecode(row!.payloadJson) as Map<String, dynamic>;
      expect(decoded['v'], 1);
      expect(decoded['data'], isA<Map<String, dynamic>>());
      expect((decoded['data'] as Map)['search'], 'acme');
    });

    test('round-trips iconKey (defaults to null)', () async {
      final plain = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'No icon',
        snapshot: const {},
      );
      expect(plain.iconKey, isNull);
      expect((await db.savedViewsDao.byId(plain.id))!.icon, isNull);

      final withIcon = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Starred',
        snapshot: const {},
        iconKey: 'star',
      );
      expect(withIcon.iconKey, 'star');
      expect((await db.savedViewsDao.byId(withIcon.id))!.icon, 'star');
    });
  });

  group('setIcon', () {
    test('sets and clears the icon (null is a meaningful value)', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'V',
        snapshot: const {},
        iconKey: 'star',
      );

      await repo.setIcon(viewId: view.id, iconKey: 'flag');
      expect((await db.savedViewsDao.byId(view.id))!.icon, 'flag');

      await repo.setIcon(viewId: view.id, iconKey: null);
      expect((await db.savedViewsDao.byId(view.id))!.icon, isNull);

      // Other columns untouched by the icon write.
      expect((await db.savedViewsDao.byId(view.id))!.name, 'V');
    });

    test('on a missing id is a no-op', () async {
      await repo.setIcon(viewId: 'nope', iconKey: 'star');
      expect(await db.savedViewsDao.byId('nope'), isNull);
    });
  });

  group('apply', () {
    test('splices snapshot into nav_state.filters_json', () async {
      // Seed nav_state with an unrelated company entry so we can verify
      // the apply doesn't clobber other slots.
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co_other': {
            'client': {'search': 'keep me'},
          },
        }),
        now: 0,
      );
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme US',
        snapshot: {'search': 'acme', 'sortField': 'name'},
      );
      await repo.apply(view.id);

      final row = await db.navStateDao.current();
      final doc = jsonDecode(row!.filtersJson!) as Map<String, dynamic>;
      // Other company's slot is preserved.
      expect((doc['co_other'] as Map)['client']['search'], 'keep me');
      // Our slot landed.
      final ours = (doc['co'] as Map)['client'] as Map;
      expect(ours['search'], 'acme');
      expect(ours['sortField'], 'name');
    });

    // Regression: `savedViewSnapshot` strips grouping at capture time (it "must
    // not take part in Saved View identity"), and `apply` then spliced the
    // stripped map in as the WHOLE slot — deleting the live grouping. Applying
    // a view silently flattened a grouped Products list and lost which groups
    // were folded, with no way back but re-picking the dimension by hand.
    test('preserves the live grouping + collapsed set', () async {
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'product': {
              'search': 'old',
              'groupField': 'product1',
              'collapsedGroups': ['Hardware'],
            },
          },
        }),
        now: 0,
      );
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.product,
        name: 'Low stock',
        snapshot: {'search': 'widget'},
      );

      await repo.apply(view.id);

      final row = await db.navStateDao.current();
      final ours =
          (jsonDecode(row!.filtersJson!) as Map)['co']['product'] as Map;
      expect(ours['search'], 'widget', reason: "the view's filter applied");
      expect(ours['groupField'], 'product1');
      expect(ours['collapsedGroups'], ['Hardware']);
    });

    test('leaves an ungrouped slot alone', () async {
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'product': {'search': 'old'},
          },
        }),
        now: 0,
      );
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.product,
        name: 'Low stock',
        snapshot: {'search': 'widget'},
      );

      await repo.apply(view.id);

      final row = await db.navStateDao.current();
      final ours =
          (jsonDecode(row!.filtersJson!) as Map)['co']['product'] as Map;
      expect(ours.containsKey('groupField'), isFalse);
      expect(ours.containsKey('collapsedGroups'), isFalse);
    });

    test('on a missing id is a no-op (no nav_state mutation)', () async {
      await repo.apply('does-not-exist');
      final row = await db.navStateDao.current();
      expect(row?.filtersJson, anyOf(isNull, isEmpty));
    });

    test('writes columnIds through to UserSettings when present', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme minimal',
        snapshot: {
          'search': 'acme',
          'columnIds': ['name', 'balance'],
        },
      );
      await repo.apply(view.id);

      final cols = await userSettings.getColumns(
        companyId: 'co',
        entityType: EntityType.client,
      );
      expect(cols, equals(['name', 'balance']));

      // And nav_state's slot does NOT carry columnIds — that field belongs
      // to UserSettings, the slot stays at the six-field shape so the VM's
      // currentSnapshot equality check stays accurate.
      final nav = await db.navStateDao.current();
      final doc = jsonDecode(nav!.filtersJson!) as Map<String, dynamic>;
      final slot = (doc['co'] as Map)['client'] as Map;
      expect(slot.containsKey('columnIds'), isFalse);
      expect(slot['search'], 'acme');
    });

    test('legacy snapshot without columnIds leaves columns alone', () async {
      // Pre-set a column list that the apply must not clobber.
      await userSettings.setColumns(
        companyId: 'co',
        entityType: EntityType.client,
        columns: const ['name', 'number', 'balance'],
      );
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Filters only',
        snapshot: {'search': 'x'}, // no columnIds key
      );
      await repo.apply(view.id);

      final cols = await userSettings.getColumns(
        companyId: 'co',
        entityType: EntityType.client,
      );
      expect(cols, equals(['name', 'number', 'balance']));
    });

    test(
      'applying a view whose columns match the live layout enqueues nothing',
      () async {
        // The reported bug: a freshly-created view captured the current
        // columns, so opening it must not write a no-op user_settings PUT.
        await userSettings.setColumns(
          companyId: 'co',
          entityType: EntityType.client,
          columns: const ['name', 'balance'],
        );
        // Clear the (legitimate) row from that setup write.
        for (final r in await db.outboxDao.nextReady(
          companyId: 'co',
          now: DateTime.now().millisecondsSinceEpoch,
        )) {
          await db.outboxDao.deleteRow(r.id);
        }

        final view = await repo.create(
          companyId: 'co',
          entityType: EntityType.client,
          name: 'Same as live',
          snapshot: {
            'search': 'acme',
            'columnIds': ['name', 'balance'],
          },
        );
        await repo.apply(view.id);

        final rows = await db.outboxDao.nextReady(
          companyId: 'co',
          now: DateTime.now().millisecondsSinceEpoch,
        );
        expect(rows, isEmpty);
      },
    );

    test('applying a view with different columns still enqueues one', () async {
      await userSettings.setColumns(
        companyId: 'co',
        entityType: EntityType.client,
        columns: const ['name', 'balance'],
      );
      for (final r in await db.outboxDao.nextReady(
        companyId: 'co',
        now: DateTime.now().millisecondsSinceEpoch,
      )) {
        await db.outboxDao.deleteRow(r.id);
      }

      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Different cols',
        snapshot: {
          'columnIds': ['name', 'number', 'balance'],
        },
      );
      await repo.apply(view.id);

      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: DateTime.now().millisecondsSinceEpoch,
      );
      expect(rows, hasLength(1));
    });
  });

  group('watchAll', () {
    test('filters out rows referencing unknown entity types', () async {
      // Forge a row with an entity_type the build doesn't know — would
      // otherwise blank out the sidebar via a stray throw.
      await db.savedViewsDao.insertView(
        SavedViewsCompanion(
          id: const Value('bad'),
          companyId: const Value('co'),
          entityType: const Value('mythical_beast'),
          name: const Value('Bad row'),
          payloadJson: const Value('{"v":1,"data":{}}'),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );
      // And one good row alongside it.
      await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Good',
        snapshot: const {},
      );

      final views = await repo.watchAll('co').first;
      expect(views.length, 1);
      expect(views.first.name, 'Good');
    });

    test('decodes legacy bare-snapshot payloads', () async {
      // Forge a row written without the {v,data} envelope (forward-compat
      // lane — never produced today but the repo must accept it).
      await db.savedViewsDao.insertView(
        SavedViewsCompanion(
          id: const Value('legacy'),
          companyId: const Value('co'),
          entityType: const Value('client'),
          name: const Value('Legacy'),
          payloadJson: Value(jsonEncode({'search': 'old'})),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );
      final views = await repo.watchAll('co').first;
      expect(views.length, 1);
      expect(views.first.snapshot['search'], 'old');
    });
  });

  group('delete', () {
    test('removes the row', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'X',
        snapshot: const {},
      );
      await repo.delete(view.id);
      final views = await repo.watchAll('co').first;
      expect(views, isEmpty);
    });
  });

  group('matchingView', () {
    test(
      'emits the view whose snapshot deep-matches and null otherwise',
      () async {
        final acme = await repo.create(
          companyId: 'co',
          entityType: EntityType.client,
          name: 'Acme US',
          snapshot: {
            'search': 'acme',
            'extraFilters': {
              'country_id': ['US'],
            },
          },
        );
        await repo.create(
          companyId: 'co',
          entityType: EntityType.client,
          name: 'Top 10',
          snapshot: {'sortField': 'balance'},
        );
        // Snapshot matches the first view exactly.
        final hits = await repo
            .matchingView(
              companyId: 'co',
              entityType: EntityType.client,
              currentSnapshot: {
                'search': 'acme',
                'extraFilters': {
                  'country_id': ['US'],
                },
              },
            )
            .first;
        expect(hits, isNotNull);
        expect(hits!.id, acme.id);
        // A snapshot that matches nothing emits null.
        final miss = await repo
            .matchingView(
              companyId: 'co',
              entityType: EntityType.client,
              currentSnapshot: {'search': 'something else'},
            )
            .first;
        expect(miss, isNull);
      },
    );
  });

  group('watchActiveView', () {
    test('emits the view whose applied slot reflects the live state', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme US',
        snapshot: {
          'search': 'acme',
          'extraFilters': {
            'country_id': ['US'],
          },
        },
      );

      // No nav_state slot yet → nothing is active.
      expect(
        await repo
            .watchActiveView(companyId: 'co', entityType: EntityType.client)
            .first,
        isNull,
      );

      // After applying, the live slot reflects the view.
      await repo.apply(view.id);
      final active = await repo
          .watchActiveView(companyId: 'co', entityType: EntityType.client)
          .first;
      expect(active, isNotNull);
      expect(active!.id, view.id);

      // Mutate one field of the slot → highlight clears.
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'client': {
              'search': 'something else',
              'extraFilters': {
                'country_id': ['US'],
              },
            },
          },
        }),
        now: 2,
      );
      expect(
        await repo
            .watchActiveView(companyId: 'co', entityType: EntityType.client)
            .first,
        isNull,
      );
    });

    test('matches a column-customized view (columnIds stripped)', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Minimal cols',
        snapshot: {
          'search': 'acme',
          'columnIds': ['name', 'balance'],
        },
      );
      // apply writes the six-field slot (no columnIds); watchActiveView
      // must still recognise it as active.
      await repo.apply(view.id);
      final active = await repo
          .watchActiveView(companyId: 'co', entityType: EntityType.client)
          .first;
      expect(active?.id, view.id);
    });

    test('stays active after the user groups or folds a group', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme',
        snapshot: {'search': 'acme'},
      );
      await repo.apply(view.id);

      // Grouping and its collapsed set ride in the same nav_state slot as the
      // filters, but they are a display preference — including them in view
      // identity would silently drop the sidebar highlight (and disable
      // clearAppliedViewFilters) the moment a user folded a group.
      final nav = await db.navStateDao.current();
      final doc = jsonDecode(nav!.filtersJson!) as Map<String, dynamic>;
      final company = Map<String, dynamic>.from(doc['co'] as Map);
      final slot = Map<String, dynamic>.from(
        company[EntityType.client.name] as Map,
      );
      slot['groupField'] = 'custom1';
      slot['collapsedGroups'] = ['Hardware'];
      company[EntityType.client.name] = slot;
      doc['co'] = company;
      await db.navStateDao.saveFilters(filtersJson: jsonEncode(doc), now: 1);

      final active = await repo
          .watchActiveView(companyId: 'co', entityType: EntityType.client)
          .first;
      expect(active?.id, view.id);

      // ...and the sidebar's "clear" affordance still works.
      await repo.clearAppliedViewFilters(
        companyId: 'co',
        entityType: EntityType.client,
      );
      final after = await repo
          .watchActiveView(companyId: 'co', entityType: EntityType.client)
          .first;
      expect(after, isNull);
    });

    test(
      'scoped to the entity — a different entity slot is not a match',
      () async {
        final clientView = await repo.create(
          companyId: 'co',
          entityType: EntityType.client,
          name: 'Acme',
          snapshot: {'search': 'acme'},
        );
        await repo.apply(clientView.id);

        // The product branch has no matching slot.
        expect(
          await repo
              .watchActiveView(companyId: 'co', entityType: EntityType.product)
              .first,
          isNull,
        );
      },
    );
  });

  group('clearAppliedViewFilters', () {
    test('removes only the matched slot, preserves the rest', () async {
      // Other company + another entity in the same company must survive.
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'product': {'search': 'p'},
          },
          'co_other': {
            'client': {'search': 'keep'},
          },
        }),
        now: 0,
      );
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme',
        snapshot: {'search': 'acme'},
      );
      await repo.apply(view.id);

      await repo.clearAppliedViewFilters(
        companyId: 'co',
        entityType: EntityType.client,
      );

      final doc =
          jsonDecode((await db.navStateDao.current())!.filtersJson!)
              as Map<String, dynamic>;
      expect((doc['co'] as Map).containsKey('client'), isFalse);
      expect((doc['co'] as Map)['product']['search'], 'p');
      expect((doc['co_other'] as Map)['client']['search'], 'keep');

      // Highlight follows: nothing is active anymore.
      expect(
        await repo
            .watchActiveView(companyId: 'co', entityType: EntityType.client)
            .first,
        isNull,
      );
    });

    test('drops the company key when its last slot is removed', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Acme',
        snapshot: {'search': 'acme'},
      );
      await repo.apply(view.id);

      await repo.clearAppliedViewFilters(
        companyId: 'co',
        entityType: EntityType.client,
      );

      final doc =
          jsonDecode((await db.navStateDao.current())!.filtersJson!)
              as Map<String, dynamic>;
      expect(doc.containsKey('co'), isFalse);
    });

    test('a manual (non-saved-view) filter set is preserved', () async {
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'client': {'search': 'manual'},
          },
        }),
        now: 0,
      );
      await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Different',
        snapshot: {'search': 'other'},
      );

      await repo.clearAppliedViewFilters(
        companyId: 'co',
        entityType: EntityType.client,
      );

      final doc =
          jsonDecode((await db.navStateDao.current())!.filtersJson!)
              as Map<String, dynamic>;
      expect((doc['co'] as Map)['client']['search'], 'manual');
    });

    test('no slot is a no-op', () async {
      await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'V',
        snapshot: {'search': 'x'},
      );
      await repo.clearAppliedViewFilters(
        companyId: 'co',
        entityType: EntityType.client,
      );
      final row = await db.navStateDao.current();
      expect(row?.filtersJson, anyOf(isNull, isEmpty));
    });

    test('recognizes a column-customized view (columnIds stripped)', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'Minimal cols',
        snapshot: {
          'search': 'acme',
          'columnIds': ['name', 'balance'],
        },
      );
      await repo.apply(view.id); // writes the six-field slot

      await repo.clearAppliedViewFilters(
        companyId: 'co',
        entityType: EntityType.client,
      );

      final doc =
          jsonDecode((await db.navStateDao.current())!.filtersJson!)
              as Map<String, dynamic>;
      expect(doc.containsKey('co'), isFalse);
    });
  });

  group('updateSnapshot', () {
    test('overwrites payload while preserving id and name', () async {
      final view = await repo.create(
        companyId: 'co',
        entityType: EntityType.client,
        name: 'X',
        snapshot: {'search': 'old'},
      );
      await repo.updateSnapshot(viewId: view.id, snapshot: {'search': 'new'});
      final reloaded = (await repo.watchAll('co').first).single;
      expect(reloaded.id, view.id);
      expect(reloaded.name, 'X');
      expect(reloaded.snapshot['search'], 'new');
    });
  });
}
