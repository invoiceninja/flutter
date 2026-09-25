import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/group_setting_api_model.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/data/services/group_settings_api.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

/// Covers the universal `BaseEntityRepository` contract via the shared
/// harness and a small set of group-specific assertions for behavior the
/// contract doesn't probe (cascade-override settings map, watchAll
/// ordering, withCascadeOverride remove-on-empty semantics).
class _GroupSettingFixture
    extends EntityRepositoryContractFixture<GroupSetting, GroupSettingApi> {
  @override
  String get entityType => 'group';

  @override
  GroupSettingRepository buildRepo(AppDatabase db) =>
      GroupSettingRepository(db: db, api: _FakeGroupSettingsApi());

  @override
  GroupSettingApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) => GroupSettingApi(id: id, name: displayValue ?? id, updatedAt: updatedAt);

  @override
  GroupSetting fromApi(GroupSettingApi api) => GroupSetting.fromApi(api);

  @override
  GroupSetting editCopy(GroupSetting item, {required String displayValue}) =>
      item.copyWith(name: displayValue);

  @override
  String idOf(GroupSetting item) => item.id;

  @override
  bool isDirtyOf(GroupSetting item) => item.isDirty;

  @override
  Future<SaveResult<GroupSetting>> create(
    BaseEntityRepository<GroupSetting, GroupSettingApi> repo, {
    required String companyId,
    required GroupSetting draft,
  }) => (repo as GroupSettingRepository).create(
    companyId: companyId,
    draft: draft,
  );

  @override
  Future<SaveResult<GroupSetting>> save(
    BaseEntityRepository<GroupSetting, GroupSettingApi> repo, {
    required String companyId,
    required GroupSetting entity,
  }) => (repo as GroupSettingRepository).save(
    companyId: companyId,
    group: entity,
  );

  @override
  Future<void> delete(
    BaseEntityRepository<GroupSetting, GroupSettingApi> repo, {
    required String companyId,
    required String id,
  }) => (repo as GroupSettingRepository).delete(companyId: companyId, id: id);
}

void main() {
  runEntityRepositoryContract(_GroupSettingFixture());

  group('GroupSettingRepository — entity-specific', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    GroupSettingRepository makeRepo() =>
        GroupSettingRepository(db: db, api: _FakeGroupSettingsApi());

    test('withCascadeOverride sets a key when given a non-empty value', () {
      final g = GroupSetting.fromApi(const GroupSettingApi(name: 'Premium'));
      final next = g.withCascadeOverride('currency_id', '1');
      expect(next.settings, {'currency_id': '1'});
      expect(next.currencyId, '1');
    });

    test('withCascadeOverride removes a key when given null', () {
      final g = GroupSetting.fromApi(
        const GroupSettingApi(name: 'Premium', settings: {'currency_id': '1'}),
      );
      final next = g.withCascadeOverride('currency_id', null);
      expect(next.settings, isNull);
      expect(next.currencyId, isNull);
    });

    test('withCascadeOverride removes a key when given empty string', () {
      final g = GroupSetting.fromApi(
        const GroupSettingApi(
          name: 'Premium',
          settings: {'currency_id': '1', 'language_id': '2'},
        ),
      );
      final next = g.withCascadeOverride('currency_id', '');
      expect(next.settings, {'language_id': '2'});
      expect(next.currencyId, isNull);
      expect(next.languageId, '2');
    });

    test('toApiJson drops empty settings map', () {
      final g = GroupSetting.fromApi(
        const GroupSettingApi(id: 'g_1', name: 'Premium'),
      );
      final json = g.toApiJson();
      expect(json.containsKey('settings'), isFalse);
      expect(json['name'], 'Premium');
    });

    test('toApiJson emits non-empty settings map', () {
      final g = GroupSetting.fromApi(
        const GroupSettingApi(
          id: 'g_1',
          name: 'Premium',
          settings: {'currency_id': '1'},
        ),
      );
      final json = g.toApiJson();
      expect(json['settings'], {'currency_id': '1'});
    });

    test('watchAll returns active groups sorted by name ascending', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_b',
        serverResponse: const GroupSettingApi(
          id: 'g_b',
          name: 'Beta',
          updatedAt: 1700000000,
        ),
      );
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_a',
        serverResponse: const GroupSettingApi(
          id: 'g_a',
          name: 'Alpha',
          updatedAt: 1700000001,
        ),
      );
      final groups = await repo.watchAll(companyId: 'co').first;
      expect(groups.map((g) => g.name).toList(), ['Alpha', 'Beta']);
    });

    test('watchAll excludes archived rows', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_active',
        serverResponse: const GroupSettingApi(
          id: 'g_active',
          name: 'Active',
          updatedAt: 1700000000,
        ),
      );
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_archived',
        serverResponse: const GroupSettingApi(
          id: 'g_archived',
          name: 'Archived',
          updatedAt: 1700000000,
          archivedAt: 1700000000,
        ),
      );
      final groups = await repo.watchAll(companyId: 'co').first;
      expect(groups.map((g) => g.id).toList(), ['g_active']);
    });

    test(
      '_fromRow overlays is_dirty so an offline create reads as dirty',
      () async {
        final repo = makeRepo();
        final draft = GroupSetting.fromApi(
          const GroupSettingApi(name: 'New Group', updatedAt: 1700000000),
        );
        await repo.create(companyId: 'co', draft: draft);
        final groups = await repo.watchAll(companyId: 'co').first;
        expect(groups, hasLength(1));
        expect(groups.first.isDirty, isTrue);
      },
    );

    test('save enqueues a set_default_design row at group scope — in the same '
        'transaction as the update — carrying design + entity + '
        'group_settings_id', () async {
      final repo = makeRepo();
      final g = GroupSetting.fromApi(
        const GroupSettingApi(id: 'g_1', name: 'Premium'),
      );

      await repo.save(
        companyId: 'co',
        group: g,
        designDefaultUpdates: const [
          {'design_id': 'design_9', 'entity': 'invoice'},
        ],
      );

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(
        pending.where((r) => r.mutationKind == MutationKind.update.wireName),
        hasLength(1),
      );
      final designRows = pending
          .where(
            (r) => r.mutationKind == MutationKind.setDefaultDesign.wireName,
          )
          .toList();
      expect(designRows, hasLength(1));
      expect(designRows.single.entityType, 'group');
      expect(designRows.single.entityId, 'g_1');
      final payload =
          jsonDecode(designRows.single.payload) as Map<String, dynamic>;
      expect(payload['design_id'], 'design_9');
      expect(payload['entity'], 'invoice');
      expect(payload['settings_level'], 'group_settings');
      expect(payload['group_settings_id'], 'g_1');
    });

    test(
      'applyBundle upserts every row and advances the cursor to max updatedAt',
      () async {
        final repo = makeRepo();
        await repo.applyBundle(
          companyId: 'co',
          bundle: const [
            GroupSettingApi(id: 'g_a', name: 'Alpha', updatedAt: 1700000100),
            GroupSettingApi(id: 'g_b', name: 'Beta', updatedAt: 1700000200),
          ],
        );
        final rows = await repo.watchAll(companyId: 'co').first;
        expect(rows.map((g) => g.id).toList(), ['g_a', 'g_b']);
        final cursor = await db.syncStateDao.read(
          companyId: 'co',
          entityType: 'group',
        );
        expect(cursor.updatedAt, 1700000200);
        expect(cursor.id, 'g_b');
      },
    );

    test('applyBundle is a no-op when the bundle is empty', () async {
      final repo = makeRepo();
      await repo.applyBundle(companyId: 'co', bundle: const []);
      final cursor = await db.syncStateDao.read(
        companyId: 'co',
        entityType: 'group',
      );
      expect(cursor.isEmpty, isTrue);
    });

    test('watchAllIncludingArchived returns active + archived, not '
        'deleted', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_active',
        serverResponse: const GroupSettingApi(
          id: 'g_active',
          name: 'Active',
          updatedAt: 1700000000,
        ),
      );
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_arch',
        serverResponse: const GroupSettingApi(
          id: 'g_arch',
          name: 'Archived',
          updatedAt: 1700000000,
          archivedAt: 1700000000,
        ),
      );
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_del',
        serverResponse: const GroupSettingApi(
          id: 'g_del',
          name: 'Deleted',
          updatedAt: 1700000000,
        ),
      );
      await repo.applyDeleteResponse(companyId: 'co', id: 'g_del');

      final all = await repo.watchAllIncludingArchived(companyId: 'co').first;
      expect(all.map((g) => g.id).toSet(), {'g_active', 'g_arch'});
      // The active-only stream still excludes the archived row.
      final active = await repo.watchAll(companyId: 'co').first;
      expect(active.map((g) => g.id).toList(), ['g_active']);
    });

    test(
      'applyCreateResponse stores documents; _fromRow overlays them',
      () async {
        final repo = makeRepo();
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'g_1',
          serverResponse: const GroupSettingApi(
            id: 'g_1',
            name: 'Docs',
            updatedAt: 1700000000,
            documents: [DocumentApi(id: 'd1', name: 'Contract.pdf')],
          ),
        );
        final group = (await repo.watchAll(companyId: 'co').first).single;
        expect(group.documents.single.id, 'd1');
        expect(group.documents.single.name, 'Contract.pdf');
      },
    );

    test('applyDocumentChanged inserts then replaces by id', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_1',
        serverResponse: const GroupSettingApi(
          id: 'g_1',
          name: 'Docs',
          updatedAt: 1700000000,
        ),
      );
      await repo.applyDocumentChanged(
        companyId: 'co',
        entityId: 'g_1',
        document: const DocumentApi(id: 'd1', name: 'First.pdf'),
      );
      var group = (await repo.watchAll(companyId: 'co').first).single;
      expect(group.documents.single.name, 'First.pdf');

      await repo.applyDocumentChanged(
        companyId: 'co',
        entityId: 'g_1',
        document: const DocumentApi(id: 'd1', name: 'Renamed.pdf'),
      );
      group = (await repo.watchAll(companyId: 'co').first).single;
      expect(group.documents, hasLength(1));
      expect(group.documents.single.name, 'Renamed.pdf');
    });

    test('applyDocumentDeleted drops the matching document', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_1',
        serverResponse: const GroupSettingApi(
          id: 'g_1',
          name: 'Docs',
          updatedAt: 1700000000,
          documents: [
            DocumentApi(id: 'd1'),
            DocumentApi(id: 'd2'),
          ],
        ),
      );
      await repo.applyDocumentDeleted(
        companyId: 'co',
        entityId: 'g_1',
        documentId: 'd1',
      );
      final group = (await repo.watchAll(companyId: 'co').first).single;
      expect(group.documents.map((d) => d.id).toList(), ['d2']);
    });

    test('domain save preserves the documents column (no clobber)', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'g_1',
        serverResponse: const GroupSettingApi(
          id: 'g_1',
          name: 'Docs',
          updatedAt: 1700000000,
          documents: [DocumentApi(id: 'd1', name: 'Contract.pdf')],
        ),
      );
      // Mirror the frozen edit-VM: a domain copy with no documents (the
      // default empty list) — saving name/currency must NOT wipe the column.
      final stale = GroupSetting.fromApi(
        const GroupSettingApi(
          id: 'g_1',
          name: 'Renamed',
          updatedAt: 1700000000,
        ),
      );
      expect(stale.documents, isEmpty);
      await repo.save(companyId: 'co', group: stale);
      final after = (await repo.watchAll(companyId: 'co').first).single;
      expect(after.name, 'Renamed');
      expect(
        after.documents.map((d) => d.id).toList(),
        ['d1'],
        reason: '_domainToCompanion must leave documents untouched',
      );
    });

    test('applyBundle preserves the local payload of an is_dirty row '
        'so an offline edit is not clobbered by a re-bundle', () async {
      final repo = makeRepo();
      final draft = GroupSetting.fromApi(
        const GroupSettingApi(name: 'My Custom'),
      );
      await repo.create(companyId: 'co', draft: draft);
      final dirtyBefore = (await repo.watchAll(companyId: 'co').first).single;
      expect(dirtyBefore.isDirty, isTrue);

      await repo.applyBundle(
        companyId: 'co',
        bundle: const [
          GroupSettingApi(
            id: 'g_server',
            name: 'Server Group',
            updatedAt: 1700000500,
          ),
        ],
      );
      final all = await repo.watchAll(companyId: 'co').first;
      expect(all, hasLength(2));
      expect(all.map((g) => g.name).toSet(), {'My Custom', 'Server Group'});
      final stillDirty = all.firstWhere((g) => g.name == 'My Custom');
      expect(stillDirty.isDirty, isTrue);
    });
  });

  test('refreshByIds re-fetches even a cached group setting — what Check on an '
      'unconfirmed group setting change relies on', () async {
    // The base default is a no-op, so Check's refresh of a group setting whose
    // document upload may have gone through fetched nothing, and the user
    // could not tell before choosing Resend.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = _GetGroupSettingsApi()
      ..byId['x1'] = const GroupSettingApi(id: 'x1', name: 'VIP');
    final repo = GroupSettingRepository(db: db, api: api);
    await repo.refreshByIds(companyId: 'co', ids: ['x1']);
    api.byId['x1'] = const GroupSettingApi(id: 'x1', name: 'VIP Gold');

    await repo.refreshByIds(companyId: 'co', ids: ['x1']);

    final row = await repo.watch(companyId: 'co', id: 'x1').first;
    expect(row?.name, 'VIP Gold');
  });
}

class _FakeGroupSettingsApi implements GroupSettingsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Serves single-id GETs from a map the test can change between calls.
class _GetGroupSettingsApi implements GroupSettingsApi {
  final Map<String, GroupSettingApi> byId = {};

  @override
  Future<GroupSettingItemApi> get(String id) async =>
      GroupSettingItemApi(data: byId[id]!);

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
