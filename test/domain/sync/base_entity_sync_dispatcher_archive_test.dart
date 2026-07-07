import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services_entity_wiring.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';
import 'package:admin/domain/sync/mutation.dart';

/// L8: archive/restore call `bulkActionOne`, which returns null when the
/// server's re-query finds zero rows for the id (e.g. it was purged
/// elsewhere). The optimistic flip left the local row `is_dirty=true`; without
/// reconciliation it stays dirty forever and every `/refresh` skips it (a
/// lingering "unsynced" badge). The dispatcher must clear the dirty flag.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  OutboxRow rowWith({required String kind, required String entityId}) =>
      OutboxRow(
        id: 1,
        companyId: 'co',
        entityType: 'client',
        entityId: entityId,
        mutationKind: kind,
        payload: jsonEncode({'id': entityId}),
        idempotencyKey: 'idk',
        state: 'pending',
        attempts: 0,
        nextAttemptAt: 0,
        createdAt: 0,
        requiresPassword: false,
      );

  for (final action in const ['archive', 'restore']) {
    test('$action: a null (no-entity) bulk response clears the optimistic '
        'dirty flag so the row is not refresh-skipped forever (L8)', () async {
      final api = _NullBulkClientsApi();
      final repo = ClientRepository(db: db, api: api);
      final dispatcher = BaseEntitySyncDispatcher<ClientItemApi, ClientApi>(
        api: api,
        repo: repo,
        dataOf: (item) => item.data,
      );

      // Seed a clean row, then flip the optimistic archive state
      // (archived_at + is_dirty=true) the way repo.archive()/restore() does.
      await repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const ClientApi(id: 'c1', name: 'Acme'),
      );
      await db.clientDao.setArchived(
        companyId: 'co',
        id: 'c1',
        atEpochSeconds: 1700000000,
      );
      final before = await repo.watchByRealId(companyId: 'co', id: 'c1').first;
      expect(before!.isDirty, isTrue);

      await dispatcher.dispatch(
        row: rowWith(kind: action, entityId: 'c1'),
        kind: MutationKind.values.firstWhere((k) => k.wireName == action),
      );

      final after = await repo.watchByRealId(companyId: 'co', id: 'c1').first;
      expect(
        after!.isDirty,
        isFalse,
        reason: 'dirty flag must be cleared on a null bulk response',
      );
    });
  }

  _defineBulkUpdateTest();
}

/// The custom-action sibling of L8: `bulk_update` writes its optimistic patch
/// with `is_dirty=true` too, and its handler (extracted as
/// `clientBulkUpdateHandler` precisely so this is testable) must clear the
/// flag on a null echo — the generic custom-action path can't do it blanket
/// (other null-returning handlers would clobber unrelated pending edits).
void _defineBulkUpdateTest() {
  group('clientBulkUpdateHandler', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('bulk_update: a null (no-entity) bulk response clears the optimistic '
        'dirty flag so the row is not refresh-skipped forever', () async {
      final api = _NullBulkClientsApi();
      final repo = ClientRepository(db: db, api: api);
      final handler = clientBulkUpdateHandler(api, repo);

      await repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const ClientApi(id: 'c1', name: 'Acme'),
      );
      // The optimistic mass-edit patch marks the row dirty.
      final seeded = await repo.watchByRealId(companyId: 'co', id: 'c1').first;
      await repo.bulkUpdate(
        companyId: 'co',
        client: seeded!,
        column: 'industry_id',
        newValue: '5',
      );
      final before = await repo.watchByRealId(companyId: 'co', id: 'c1').first;
      expect(before!.isDirty, isTrue);

      final result = await handler(
        row: OutboxRow(
          id: 2,
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
          mutationKind: MutationKind.bulkUpdate.wireName,
          payload: jsonEncode({
            'id': 'c1',
            'column': 'industry_id',
            'new_value': '5',
          }),
          idempotencyKey: 'idk2',
          state: 'pending',
          attempts: 0,
          nextAttemptAt: 0,
          createdAt: 0,
          requiresPassword: false,
        ),
        payload: const {'id': 'c1', 'column': 'industry_id', 'new_value': '5'},
      );

      expect(result, isNull);
      final after = await repo.watchByRealId(companyId: 'co', id: 'c1').first;
      expect(after!.isDirty, isFalse);
    });
  });
}

/// Fake whose `bulkActionOne` always returns null (the empty-data case).
class _NullBulkClientsApi implements ClientsApi {
  @override
  Future<ClientItemApi?> bulkActionOne({
    required String id,
    required String action,
    required String idempotencyKey,
    Map<String, dynamic>? extra,
    Map<String, String>? query,
    bool requiresPassword = false,
  }) async => null;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '_NullBulkClientsApi.${invocation.memberName} not implemented',
  );
}
