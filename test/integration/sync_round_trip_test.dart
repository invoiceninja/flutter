import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';

/// End-to-end test of the offline-create / outbox / sync / id_remap path
/// that every entity will depend on. If this test fails, no entity that
/// goes through [BaseEntityRepository] can sync correctly.
///
/// Scenario (CLAUDE.md "Offline-first" §):
///   1. The UI creates a client offline. The repo mints a `tmp_<uuid>` id and
///      enqueues a `create` outbox row.
///   2. `repo.watch(tmpId)` emits the optimistic row immediately so the
///      detail screen renders.
///   3. SyncRepository.drainOnce dispatches the outbox row. The fake API
///      returns a canonical entity with a real server id.
///   4. The repo writes an id_remap row, deletes the tmp row, upserts the
///      real row, and removes the outbox entry.
///   5. The same `watch(tmpId)` stream now resolves through id_remap and
///      emits the entity at the real id — the open detail screen survives
///      the swap without a route change.
///   6. A follow-up `save(client)` queued under the tmp id (e.g. the user
///      edited the just-created client while it was still pending) is
///      rewritten to point at the real id during drain.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  ClientApi apiClient(
    String id, {
    String name = 'Acme',
    int updatedAt = 1700000000,
  }) => ClientApi(id: id, name: name, updatedAt: updatedAt);

  test(
    'offline create → drain → id_remap → watch(tmpId) survives swap',
    () async {
      final api = _FakeClientsApi();
      // The server's response is the canonical row at the real id, derived
      // from the create payload but with a server-assigned id.
      api.createResponses['Acme'] = apiClient('real_001');

      final repo = ClientRepository(db: db, api: api);
      final dispatcher = BaseEntitySyncDispatcher<ClientItemApi, ClientApi>(
        api: api,
        repo: repo,
        dataOf: (item) => item.data,
      );
      final registry = EntityRegistry({
        EntityType.client: EntityHandlers(
          type: EntityType.client,
          wireName: 'client',
          apiPath: '/api/v1/clients',
          routePath: '/clients',
          icon: Icons.people,
          dispatcher: dispatcher,
        ),
      });
      final sync = SyncRepository(db: db, registry: registry);

      // (1) Create offline. Returns the locally-stored row with a tmp id.
      final draft = Client.fromApi(apiClient('', name: 'Acme'));
      final created = (await repo.create(companyId: 'co', draft: draft)).entity;
      expect(created.id.startsWith('tmp_'), isTrue);
      final tmpId = created.id;

      // (2) The detail screen opens watch(tmpId) — first emission is the
      // optimistic row.
      final emissions = <Client?>[];
      final sub = repo.watch(companyId: 'co', id: tmpId).listen(emissions.add);
      // Let the optimistic emission settle.
      await Future<void>.delayed(Duration.zero);
      expect(emissions, hasLength(greaterThanOrEqualTo(1)));
      expect(emissions.last?.id, tmpId);

      // (3 + 4) Drain the outbox. One dispatch → server assigns real_001.
      final successes = await sync.drainOnce(companyId: 'co');
      expect(successes, 1);

      // The id_remap row was recorded.
      final realId = await db.idRemapDao.resolve(
        entityType: 'client',
        tempId: tmpId,
      );
      expect(realId, 'real_001');

      // The outbox row is gone.
      final pending = await sync.pendingCountFor('co');
      expect(pending, 0);

      // (5) Drift now holds the row under the real id, and the tmp row was
      // deleted in the same transaction.
      final realRow = await db.clientDao
          .watchById(companyId: 'co', id: 'real_001')
          .first;
      expect(realRow, isNotNull);
      final tmpRow = await db.clientDao
          .watchById(companyId: 'co', id: tmpId)
          .first;
      expect(tmpRow, isNull);

      // The watch(tmpId) stream re-resolved through id_remap and emitted the
      // real row. The detail screen UI gets the swap for free.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(emissions.last?.id, 'real_001');

      await sub.cancel();
    },
  );

  test('create + edit drained in ONE pass: the edit dispatches against the '
      'real id, not the tmp id', () async {
    // Offline create + edit, then a single drain. The create remaps
    // tmp -> real in the still-pending update row (recordCreateSuccess ->
    // rewriteTempIdInPayloads); the drain loop re-reads each row by id
    // immediately before dispatch, so the update picks up the remap within
    // the same pass and targets the real id. Regression guard for the
    // stale-snapshot bug (the update would otherwise PUT /clients/tmp_xxx
    // -> 404 and park the edit as a bogus conflict).
    final api = _FakeClientsApi();
    api.createResponses['Acme'] = apiClient('real_002');

    final repo = ClientRepository(db: db, api: api);
    final dispatcher = BaseEntitySyncDispatcher<ClientItemApi, ClientApi>(
      api: api,
      repo: repo,
      dataOf: (item) => item.data,
    );
    final registry = EntityRegistry({
      EntityType.client: EntityHandlers(
        type: EntityType.client,
        wireName: 'client',
        apiPath: '/api/v1/clients',
        routePath: '/clients',
        icon: Icons.people,
        dispatcher: dispatcher,
      ),
    });
    final sync = SyncRepository(db: db, registry: registry);

    final draft = Client.fromApi(apiClient('', name: 'Acme'));
    final created = (await repo.create(companyId: 'co', draft: draft)).entity;
    final tmpId = created.id;

    // Edit the just-created client while the create is still pending. The
    // outbox now has two rows for the tmp id: create + update.
    final edited = created.copyWith(
      name: 'Acme renamed',
      displayName: 'Acme renamed',
    );
    await repo.save(companyId: 'co', client: edited);

    // Queue a response ONLY for the real id. The fake throws on an unknown
    // update id, so if the drain regressed to dispatching the tmp id this
    // test fails with "No update response queued for id=tmp_...".
    api.updateResponses['real_002'] = apiClient(
      'real_002',
      name: 'Acme renamed',
    );

    await sync.drainOnce(companyId: 'co');

    // After the drain, the outbox is empty and the entity exists at the
    // real id. The id_remap row was written.
    final pending = await sync.pendingCountFor('co');
    expect(pending, 0);
    final realRow = await db.clientDao
        .watchById(companyId: 'co', id: 'real_002')
        .first;
    expect(realRow, isNotNull, reason: 'entity should be at real id');
    expect(realRow?.name, 'Acme renamed');
    final tmpRow = await db.clientDao
        .watchById(companyId: 'co', id: tmpId)
        .first;
    expect(tmpRow, isNull, reason: 'tmp row should be deleted');
    final mapped = await db.idRemapDao.resolve(
      entityType: 'client',
      tempId: tmpId,
    );
    expect(mapped, 'real_002');

    // The update must have dispatched against the REAL id (proving the
    // pre-dispatch re-read observed the mid-pass remap), never the tmp id.
    expect(api.updateCallIds, contains('real_002'));
    expect(api.updateCallIds, isNot(contains(tmpId)));
  });

  test('422 round-trip: dead row carries fieldErrorsJson and is locatable '
      'via findDeadSaveForEntity for the edit-form replay', () async {
    final api = _FakeClientsApi();
    api.createValidationErrors['Bad'] = const ValidationException(
      'Validation failed',
      {
        'name': ['is too short'],
      },
    );

    final repo = ClientRepository(db: db, api: api);
    final dispatcher = BaseEntitySyncDispatcher<ClientItemApi, ClientApi>(
      api: api,
      repo: repo,
      dataOf: (item) => item.data,
    );
    final registry = EntityRegistry({
      EntityType.client: EntityHandlers(
        type: EntityType.client,
        wireName: 'client',
        apiPath: '/api/v1/clients',
        routePath: '/clients',
        icon: Icons.people,
        dispatcher: dispatcher,
      ),
    });
    final sync = SyncRepository(db: db, registry: registry);

    final draft = Client.fromApi(apiClient('', name: 'Bad'));
    final created = (await repo.create(companyId: 'co', draft: draft)).entity;
    final tmpId = created.id;

    await sync.drainOnce(companyId: 'co');

    // The row is dead, not pending, so the standard pending count is 0
    // — but a direct lookup by entity finds it for the edit form.
    expect(await sync.pendingCountFor('co'), 0);
    final dead = await db.outboxDao.findDeadSaveForEntity(
      companyId: 'co',
      entityType: 'client',
      entityId: tmpId,
    );
    expect(dead, isNotNull);
    expect(dead!.state, 'dead');
    expect(dead.lastStatusCode, 422);
    expect(dead.fieldErrorsJson, isNotNull);
    final errors = jsonDecode(dead.fieldErrorsJson!);
    expect(errors, {
      'name': ['is too short'],
    });
  });
}

/// Minimal fake of `ClientsApi` covering only the methods the sync engine
/// invokes during create/update round-trips. Each method returns a queued
/// response keyed by an identifier that's easy to set up per test.
class _FakeClientsApi implements ClientsApi {
  /// Keyed by `name` from the create payload.
  final Map<String, ClientApi> createResponses = {};

  /// Validation failures keyed by `name`. Take precedence over [createResponses]
  /// so a test can drive the 422 path without needing to also queue a success.
  final Map<String, ValidationException> createValidationErrors = {};

  /// Keyed by the id supplied to `update` (can be tmp_ or real).
  final Map<String, ClientApi> updateResponses = {};

  final List<String> updateCallIds = [];

  @override
  Future<ClientItemApi> create({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    bool requiresPassword = false,
    Map<String, String>? query,
  }) async {
    final name = payload['name'] as String? ?? '';
    final err = createValidationErrors[name];
    if (err != null) throw err;
    final response = createResponses[name];
    if (response == null) {
      throw StateError('No create response queued for name="$name"');
    }
    return ClientItemApi(data: response);
  }

  @override
  Future<ClientItemApi> update({
    required String id,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    Map<String, String>? query,
    bool requiresPassword = false,
  }) async {
    updateCallIds.add(id);
    final response = updateResponses[id];
    if (response == null) {
      throw StateError('No update response queued for id="$id"');
    }
    return ClientItemApi(data: response);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '_FakeClientsApi.${invocation.memberName} not implemented',
  );
}
