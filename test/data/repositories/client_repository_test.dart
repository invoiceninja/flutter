import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/api/location_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '_base_entity_repository_contract.dart';

/// These tests target ClientRepository's behavioral contracts that other
/// layers depend on:
///   * mutations land in the outbox with a fresh idempotency key
///   * delete needs requiresPassword=true (server policy)
///   * offline create assigns a tmp id and tracks it
///   * watch(tmpId) survives the tmp→real swap
///   * page-by-page loading advances the cursor and stops at hasMore=false
///   * search routes to the API's `filter` param
/// They do NOT test Drift, http, or the freezed-generated code.

class _FakeClientsApi implements ClientsApi {
  _FakeClientsApi(this._pages);

  /// Pages by their requested page number (1-indexed).
  final Map<int, List<ClientApi>> _pages;

  final List<
    ({
      int page,
      String? search,
      int? since,
      String? sinceId,
      Map<String, String> filters,
    })
  >
  calls = [];

  @override
  Future<({ClientListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add((
      page: page,
      search: search,
      since: sinceUpdatedAt,
      sinceId: sinceId,
      filters: Map<String, String>.from(filters),
    ));
    final rows = _pages[page] ?? <ClientApi>[];
    return (
      data: ClientListApi(data: rows),
      cursorUpdatedAt: rows.isNotEmpty ? rows.last.updatedAt : null,
      cursorId: rows.isNotEmpty ? rows.last.id : null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _ClientFixture
    extends EntityRepositoryContractFixture<Client, ClientApi> {
  @override
  String get entityType => 'client';

  @override
  ClientRepository buildRepo(AppDatabase db) =>
      ClientRepository(db: db, api: _FakeClientsApi(const {}));

  @override
  ClientApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) => ClientApi(id: id, name: displayValue ?? id, updatedAt: updatedAt);

  @override
  Client fromApi(ClientApi api) => Client.fromApi(api);

  @override
  Client editCopy(Client item, {required String displayValue}) =>
      item.copyWith(name: displayValue, displayName: displayValue);

  @override
  String idOf(Client item) => item.id;

  @override
  bool isDirtyOf(Client item) => item.isDirty;

  @override
  DateTime Function(Client item)? get updatedAtOf =>
      (item) => item.updatedAt;

  @override
  Future<SaveResult<Client>> create(
    BaseEntityRepository<Client, ClientApi> repo, {
    required String companyId,
    required Client draft,
  }) => (repo as ClientRepository).create(companyId: companyId, draft: draft);

  @override
  Future<SaveResult<Client>> save(
    BaseEntityRepository<Client, ClientApi> repo, {
    required String companyId,
    required Client entity,
  }) => (repo as ClientRepository).save(companyId: companyId, client: entity);

  @override
  Future<void> delete(
    BaseEntityRepository<Client, ClientApi> repo, {
    required String companyId,
    required String id,
  }) => (repo as ClientRepository).delete(companyId: companyId, id: id);
}

/// Configurable fake for the refreshByIds tests: returns a canned client per
/// id (or throws) via `get`, and records which ids were fetched.
class _RefreshClientsApi implements ClientsApi {
  _RefreshClientsApi({this.responses = const {}, this.errors = const {}});
  final Map<String, ClientApi> responses;
  final Map<String, Object> errors;
  final List<String> fetched = [];

  @override
  Future<ClientItemApi> get(String id) async {
    fetched.add(id);
    final err = errors[id];
    if (err != null) throw err;
    return ClientItemApi(data: responses[id]!);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  runEntityRepositoryContract(_ClientFixture());

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  /// Build a repo with a fake API and deterministic uuid + clock so we can
  /// assert outbox row fields exactly.
  ({ClientRepository repo, _FakeClientsApi api}) makeRepo({
    Map<int, List<ClientApi>> pages = const {},
  }) {
    final api = _FakeClientsApi(pages);
    final repo = ClientRepository(
      db: db,
      api: api,
      uuid: const Uuid(),
      now: () => DateTime.utc(2026, 5, 11, 12),
    );
    return (repo: repo, api: api);
  }

  ClientApi apiClient(
    String id, {
    String name = '',
    int updatedAt = 1700000000,
  }) => ClientApi(id: id, name: name.isEmpty ? id : name, updatedAt: updatedAt);

  group('save', () {
    test(
      'writes locally with is_dirty=true and enqueues an update outbox row',
      () async {
        final (:repo, :api) = makeRepo();
        final c = Client.fromApi(
          apiClient('c1', name: 'Acme'),
        ).copyWith(name: 'Acme Renamed');

        await repo.save(companyId: 'co', client: c);

        final row = await db.clientDao
            .watchById(companyId: 'co', id: 'c1')
            .first;
        expect(row, isNotNull);
        expect(row!.name, 'Acme Renamed');
        expect(row.isDirty, isTrue);

        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(pending, hasLength(1));
        expect(pending.single.mutationKind, MutationKind.update.wireName);
        expect(pending.single.entityType, 'client');
        expect(pending.single.idempotencyKey, isNotEmpty);
        expect(pending.single.requiresPassword, isFalse);
      },
    );
  });

  group('delete', () {
    test('flags requiresPassword=true per server policy', () async {
      final (:repo, :api) = makeRepo();
      await repo.delete(companyId: 'co', id: 'c1');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending.single.mutationKind, 'delete');
      expect(
        pending.single.requiresPassword,
        isTrue,
        reason: 'delete must surface ConfirmPasswordSheet',
      );
    });
  });

  group('optimistic archive/restore/delete local state (Finding 27)', () {
    // Seed a clean, active local row (is_dirty=false) the way a sync pull does.
    Future<void> seedActive(ClientRepository repo, String id) => repo
        .applyUpdateResponse(companyId: 'co', serverResponse: apiClient(id));

    test('archive flips archived_at + is_dirty locally AND enqueues — so '
        'offline the row leaves the active list immediately', () async {
      final (:repo, :api) = makeRepo();
      await seedActive(repo, 'c1');

      await repo.archive(companyId: 'co', id: 'c1');

      final row = await db.clientDao.watchById(companyId: 'co', id: 'c1').first;
      expect(row!.archivedAt, isNotNull);
      expect(row.archivedAt, greaterThan(0));
      expect(row.isDeleted, isFalse);
      expect(row.isDirty, isTrue, reason: 'dirty so /refresh skips the flip');
      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending.single.mutationKind, MutationKind.archive.wireName);
    });

    test(
      'delete soft-flags is_deleted + is_dirty locally AND enqueues',
      () async {
        final (:repo, :api) = makeRepo();
        await seedActive(repo, 'c1');

        await repo.delete(companyId: 'co', id: 'c1');

        final row = await db.clientDao
            .watchById(companyId: 'co', id: 'c1')
            .first;
        expect(row!.isDeleted, isTrue);
        expect(row.isDirty, isTrue);
        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(pending.single.mutationKind, MutationKind.delete.wireName);
      },
    );

    test('restore clears archived_at AND is_deleted (inverse of both) + '
        'is_dirty', () async {
      final (:repo, :api) = makeRepo();
      await seedActive(repo, 'c1');
      await repo.archive(companyId: 'co', id: 'c1'); // archived + dirty first

      await repo.restore(companyId: 'co', id: 'c1');

      final row = await db.clientDao.watchById(companyId: 'co', id: 'c1').first;
      expect(row!.archivedAt, isNull);
      expect(row.isDeleted, isFalse);
      expect(row.isDirty, isTrue);
      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(
        pending.last.mutationKind,
        MutationKind.restore.wireName,
        reason: 'archive then restore both enqueue; restore is last (FIFO)',
      );
    });
  });

  group('bulkUpdate (mass-edit)', () {
    test('patches a denormalized column + is_dirty locally AND enqueues a '
        'bulk_update row carrying column + new_value', () async {
      final (:repo, :api) = makeRepo();
      final c = Client.fromApi(apiClient('c1', name: 'Acme'));

      await repo.bulkUpdate(
        companyId: 'co',
        client: c,
        column: 'industry_id',
        newValue: '5',
      );

      final row = await db.clientDao.watchById(companyId: 'co', id: 'c1').first;
      expect(row!.industryId, '5');
      expect(row.isDirty, isTrue, reason: 'dirty so /refresh skips the patch');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending, hasLength(1));
      expect(pending.single.mutationKind, MutationKind.bulkUpdate.wireName);
      expect(pending.single.entityType, 'client');
      expect(pending.single.entityId, 'c1');
      expect(pending.single.idempotencyKey, isNotEmpty);
      expect(
        pending.single.requiresPassword,
        isFalse,
        reason: 'bulk_update is an edit, not a destructive op',
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['id'], 'c1');
      expect(payload['column'], 'industry_id');
      expect(payload['new_value'], '5');
    });

    test('patches public_notes — a payload-only field with no dedicated '
        'column — so the displayed client reflects it immediately', () async {
      final (:repo, :api) = makeRepo();
      final c = Client.fromApi(apiClient('c1', name: 'Acme'));

      await repo.bulkUpdate(
        companyId: 'co',
        client: c,
        column: 'public_notes',
        newValue: 'VIP',
      );

      final updated = await repo.watch(companyId: 'co', id: 'c1').first;
      expect(updated!.publicNotes, 'VIP');
      expect(updated.isDirty, isTrue);
    });

    test('does NOT dedup — two updates of different columns on one client both '
        'stay queued (each carries its own column)', () async {
      final (:repo, :api) = makeRepo();
      final c = Client.fromApi(apiClient('c1', name: 'Acme'));

      await repo.bulkUpdate(
        companyId: 'co',
        client: c,
        column: 'industry_id',
        newValue: '5',
      );
      await repo.bulkUpdate(
        companyId: 'co',
        client: c,
        column: 'size_id',
        newValue: '2',
      );

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(
        pending
            .where((r) => r.mutationKind == MutationKind.bulkUpdate.wireName)
            .length,
        2,
        reason: 'deduping would silently drop the first column update',
      );
    });
  });

  group('setDefaultDesign (Invoice Design "Update all records")', () {
    test(
      'save enqueues a set_default_design row at client scope — in the same '
      'transaction as the update — carrying design + entity + client_id',
      () async {
        final (:repo, :api) = makeRepo();
        final c = Client.fromApi(apiClient('c1', name: 'Acme'));

        await repo.save(
          companyId: 'co',
          client: c,
          designDefaultUpdates: const [
            {'design_id': 'design_7', 'entity': 'invoice'},
          ],
        );

        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        // The settings update rides the same transaction as the retro-apply.
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
        expect(designRows.single.entityType, 'client');
        expect(designRows.single.entityId, 'c1');
        expect(designRows.single.idempotencyKey, isNotEmpty);
        expect(
          designRows.single.requiresPassword,
          isFalse,
          reason:
              'set_default_design is a settings retro-apply, not destructive',
        );
        final payload =
            jsonDecode(designRows.single.payload) as Map<String, dynamic>;
        expect(payload['design_id'], 'design_7');
        expect(payload['entity'], 'invoice');
        expect(payload['settings_level'], 'client');
        expect(payload['client_id'], 'c1');
      },
    );

    test(
      'one set_default_design row per directive (invoice + quote)',
      () async {
        final (:repo, :api) = makeRepo();
        final c = Client.fromApi(apiClient('c1', name: 'Acme'));

        await repo.save(
          companyId: 'co',
          client: c,
          designDefaultUpdates: const [
            {'design_id': 'd1', 'entity': 'invoice'},
            {'design_id': 'd2', 'entity': 'quote'},
          ],
        );

        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(
          pending
              .where(
                (r) => r.mutationKind == MutationKind.setDefaultDesign.wireName,
              )
              .length,
          2,
        );
      },
    );

    test('no directives → save enqueues only the update row', () async {
      final (:repo, :api) = makeRepo();
      final c = Client.fromApi(apiClient('c1', name: 'Acme'));

      await repo.save(companyId: 'co', client: c);

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(
        pending.where(
          (r) => r.mutationKind == MutationKind.setDefaultDesign.wireName,
        ),
        isEmpty,
      );
    });
  });

  group('purge', () {
    test('enqueues a purge outbox row with requiresPassword=true so the sync '
        'engine prompts before hitting POST /clients/:id/purge', () async {
      final (:repo, :api) = makeRepo();
      await repo.purge(companyId: 'co', id: 'c1');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending.single.mutationKind, MutationKind.purge.wireName);
      expect(pending.single.entityType, 'client');
      expect(pending.single.idempotencyKey, isNotEmpty);
      expect(
        pending.single.requiresPassword,
        isTrue,
        reason: 'purge must surface ConfirmPasswordSheet',
      );
    });

    test(
      'applyPurgeResponse hard-deletes the local row — purge is irreversible '
      'so the row should not linger like applyDeleteResponse leaves it',
      () async {
        final (:repo, :api) = makeRepo();
        await repo.save(
          companyId: 'co',
          client: Client.fromApi(apiClient('c1', name: 'Acme')),
        );

        await repo.applyPurgeResponse(companyId: 'co', id: 'c1');

        final byId = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(byId, isNull, reason: 'detail watcher should emit null');

        final visible = await repo
            .watchPage(
              companyId: 'co',
              loadedPages: 1,
              states: EntityState.values.toSet(),
            )
            .first;
        expect(
          visible,
          isEmpty,
          reason: 'every state filter should stop surfacing the row',
        );
      },
    );
  });

  group('merge', () {
    test('enqueues a merge outbox row (entityId = absorbed client) with '
        'requiresPassword=true and the into/from payload', () async {
      final (:repo, :api) = makeRepo();
      await repo.merge(
        companyId: 'co',
        mergeIntoId: 'survivor',
        mergeFromId: 'absorbed',
      );

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending.single.mutationKind, MutationKind.merge.wireName);
      expect(pending.single.entityType, 'client');
      expect(
        pending.single.entityId,
        'absorbed',
        reason: 'the row belongs to the client being deleted',
      );
      expect(pending.single.idempotencyKey, isNotEmpty);
      expect(
        pending.single.requiresPassword,
        isTrue,
        reason: 'merge is password-gated like delete/purge',
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['merge_into_id'], 'survivor');
      expect(payload['merge_from_id'], 'absorbed');
    });
  });

  group('locations', () {
    Future<Map<String, dynamic>> drainPayload() async {
      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      return jsonDecode(pending.single.payload) as Map<String, dynamic>;
    }

    test(
      'createLocation enqueues a location_create row keyed to the client',
      () async {
        final (:repo, :api) = makeRepo();
        await repo.createLocation(
          companyId: 'co',
          clientId: 'cl1',
          body: const {'name': 'HQ', 'client_id': 'cl1'},
        );
        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(
          pending.single.mutationKind,
          MutationKind.locationCreate.wireName,
        );
        expect(pending.single.entityId, 'cl1');
        expect(pending.single.idempotencyKey, isNotEmpty);
        final payload = await drainPayload();
        expect(payload['client_id'], 'cl1');
        expect((payload['body'] as Map)['name'], 'HQ');
      },
    );

    test('updateLocation carries the location id + body', () async {
      final (:repo, :api) = makeRepo();
      await repo.updateLocation(
        companyId: 'co',
        clientId: 'cl1',
        locationId: 'loc9',
        body: const {'name': 'Warehouse'},
      );
      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending.single.mutationKind, MutationKind.locationUpdate.wireName);
      expect(pending.single.entityId, 'cl1');
      final payload = await drainPayload();
      expect(payload['location_id'], 'loc9');
      expect((payload['body'] as Map)['name'], 'Warehouse');
    });

    test(
      'read-embedded locations survive the Drift payload round-trip',
      () async {
        final (:repo, :api) = makeRepo();
        final apiWithLoc = ClientApi(
          id: 'c1',
          name: 'Acme',
          updatedAt: 1700000000,
          locations: const [
            LocationApi(
              id: 'L1',
              clientId: 'c1',
              name: 'HQ',
              address1: '1 Main St',
              countryId: '840',
              isShippingLocation: true,
            ),
          ],
        );
        await repo.save(companyId: 'co', client: Client.fromApi(apiWithLoc));

        // Reconstructed via the repo's Drift `_fromRow` (payload JSON),
        // NOT just inline Client.fromApi — proves persistence.
        final back = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(back, isNotNull);
        expect(back!.locations, hasLength(1));
        expect(back.locations.single.name, 'HQ');
        expect(back.locations.single.isShippingLocation, isTrue);

        // A later server response that still embeds `locations` (the real,
        // probe-verified server behavior) keeps them after upsert — this is
        // the path the location* dispatcher handlers feed.
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: apiWithLoc.copyWith(
            locations: const [
              LocationApi(id: 'L1', clientId: 'c1', name: 'HQ'),
              LocationApi(id: 'L2', clientId: 'c1', name: 'Warehouse'),
            ],
          ),
        );
        final after = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(after!.locations, hasLength(2));
        expect(after.locations[1].name, 'Warehouse');

        // The exact bug scenario: a local client edit-save (e.g. rename)
        // must NOT wipe server-sourced locations. `Client.toApiJson` omits
        // locations from the outbound wire, so without the dedicated column
        // they'd vanish locally until the next refresh.
        await repo.save(
          companyId: 'co',
          client: after.copyWith(name: 'Acme Renamed'),
        );
        final edited = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(edited!.name, 'Acme Renamed');
        expect(
          edited.locations,
          hasLength(2),
          reason: 'editing the client must preserve its locations locally',
        );
        expect(edited.locations[1].name, 'Warehouse');
      },
    );

    test(
      'contact is_locked / last_login survive a local edit-save (the '
      'contacts-card "unsubscribed" icon must not blank until next sync)',
      () async {
        final (:repo, :api) = makeRepo();
        final apiWithContact = ClientApi(
          id: 'c1',
          name: 'Acme',
          updatedAt: 1700000000,
          contacts: const [
            ContactApi(
              id: 'ct1',
              firstName: 'Pat',
              email: 'pat@acme.test',
              isPrimary: true,
              isLocked: true,
              lastLogin: 1699000000,
            ),
          ],
        );
        await repo.save(
          companyId: 'co',
          client: Client.fromApi(apiWithContact),
        );

        final back = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(back!.contacts.single.isLocked, isTrue);
        expect(back.contacts.single.lastLogin, isNotNull);

        // A local rename must NOT blank the read-only contact metadata.
        // `Contact.toApiJson` omits is_locked/last_login, so without the
        // payload re-injection in `_domainToCompanion` they'd reset to defaults
        // locally until the next server sync re-embedded them.
        await repo.save(
          companyId: 'co',
          client: back.copyWith(name: 'Acme Renamed'),
        );
        final edited = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(edited!.name, 'Acme Renamed');
        expect(
          edited.contacts.single.isLocked,
          isTrue,
          reason: 'editing the client must preserve contact is_locked locally',
        );
        expect(edited.contacts.single.lastLogin, isNotNull);
      },
    );

    test('deleteLocation enqueues a location_delete row', () async {
      final (:repo, :api) = makeRepo();
      await repo.deleteLocation(
        companyId: 'co',
        clientId: 'cl1',
        locationId: 'loc9',
      );
      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending.single.mutationKind, MutationKind.locationDelete.wireName);
      expect(pending.single.entityId, 'cl1');
      final payload = await drainPayload();
      expect(payload['location_id'], 'loc9');
    });
  });

  group('create (offline)', () {
    test('mints a tmp_ id, stores it, and outbox payload omits id', () async {
      final (:repo, :api) = makeRepo();
      final draft = Client.fromApi(apiClient('', name: 'New Co'));

      final created = (await repo.create(companyId: 'co', draft: draft)).entity;
      expect(created.id, startsWith('tmp_'));

      final stored = await db.clientDao
          .watchById(companyId: 'co', id: created.id)
          .first;
      expect(stored, isNotNull);
      expect(stored!.name, 'New Co');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(
        payload.containsKey('id'),
        isFalse,
        reason: 'server allocates the real id — never send a tmp_',
      );
      expect(payload['name'], 'New Co');
    });

    test(
      'watch(tmpId) keeps emitting after the sync engine remaps the id',
      () async {
        final (:repo, :api) = makeRepo();
        final created = (await repo.create(
          companyId: 'co',
          draft: Client.fromApi(apiClient('', name: 'New Co')),
        )).entity;

        // Sync lands: the sync engine receives the server's response
        // (canonical entity with real id) and calls applyCreateResponse.
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: created.id,
          serverResponse: apiClient('real_xyz', name: 'New Co'),
        );

        // The detail screen was opened with `tmp_...`; the URL never changes.
        final stream = repo.watch(companyId: 'co', id: created.id);
        final landed = await stream.first;
        expect(
          landed?.id,
          'real_xyz',
          reason: 'watch must resolve through id_remap',
        );
      },
    );

    test(
      're-creating with existingTempId replaces the prior pending outbox row '
      '(synchronous-when-online retry path — without this, two pending CREATE '
      'rows would drain as duplicate server-side inserts)',
      () async {
        final (:repo, :api) = makeRepo();
        final first = (await repo.create(
          companyId: 'co',
          draft: Client.fromApi(apiClient('', name: 'First name')),
        )).entity;
        expect(first.id, startsWith('tmp_'));

        // User got a transient error, edits the form, hits Save again.
        // The VM reuses the prior tmpId via `existingTempId`.
        final second = (await repo.create(
          companyId: 'co',
          draft: Client.fromApi(apiClient('', name: 'Second name')),
          existingTempId: first.id,
        )).entity;
        expect(second.id, first.id, reason: 'tmpId must be reused');

        // Exactly one pending CREATE row should remain — the second attempt's
        // payload. The first attempt's row was dropped by dedupPendingMutations.
        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(pending, hasLength(1));
        expect(pending.single.entityId, first.id);
        expect(pending.single.mutationKind, 'create');
        final payload =
            jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['name'], 'Second name');
      },
    );
  });

  group('stale tmp-id save after create drained (#1 ghost duplicate)', () {
    test('saving a draft still keyed to a remapped tmp id updates the REAL row '
        'instead of resurrecting the deleted tmp row as a ghost', () async {
      final (:repo, :api) = makeRepo();
      // 1) Offline create → tmp id assigned, create queued.
      final created = await repo.create(
        companyId: 'co',
        draft: Client.fromApi(apiClient('', name: 'Acme')),
      );
      final tmpId = created.entity.id;
      expect(tmpId, startsWith('tmp_'));

      // 2) The create drains: server echoes the real id. applyCreateResponse
      // records the id_remap and deletes the tmp row.
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: tmpId,
        serverResponse: apiClient('c_real', name: 'Acme'),
      );

      // 3) The edit form is still open holding the STALE tmp-keyed draft;
      // the user edits a field and saves.
      final stale = created.entity.copyWith(
        name: 'Acme Edited',
        displayName: 'Acme Edited',
      );
      expect(stale.id, tmpId, reason: 'the open form still holds the tmp id');
      await repo.save(companyId: 'co', client: stale);

      // No ghost: nothing is stored under the raw tmp id anymore.
      final ghost = await db.clientDao
          .watchById(companyId: 'co', id: tmpId)
          .first;
      expect(ghost, isNull, reason: 'the tmp row must not be resurrected');

      // The edit landed on the real row.
      final real = await repo.watch(companyId: 'co', id: 'c_real').first;
      expect(real, isNotNull);
      expect(real!.name, 'Acme Edited');

      // And the queued update targets the real id, not the tmp id.
      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      final updateRow = pending.firstWhere(
        (p) => p.mutationKind == MutationKind.update.wireName,
      );
      expect(updateRow.entityId, 'c_real');
    });
  });

  group('optimistic delete/archive overlay (#15/#47)', () {
    // Seed a synced (clean) row, then run the offline lifecycle action and
    // read the domain back through watch → _fromRow. The optimistic flip lives
    // only in the Drift COLUMN (payload JSON is untouched), so this fails
    // unless _fromRow overlays is_deleted / archived_at from the row.
    Future<Client?> seedThenReadAfter(
      ClientRepository repo,
      Future<void> Function() action,
    ) async {
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'c1',
        serverResponse: apiClient('c1', name: 'Acme'),
      );
      await action();
      return repo.watch(companyId: 'co', id: 'c1').first;
    }

    test('offline delete → domain.isDeleted is true', () async {
      final (:repo, :api) = makeRepo();
      final after = await seedThenReadAfter(
        repo,
        () => repo.delete(companyId: 'co', id: 'c1'),
      );
      expect(after, isNotNull, reason: 'soft-delete keeps the local row');
      expect(after!.isDeleted, isTrue);
    });

    test('offline archive → domain.archivedAt is set', () async {
      final (:repo, :api) = makeRepo();
      final after = await seedThenReadAfter(
        repo,
        () => repo.archive(companyId: 'co', id: 'c1'),
      );
      expect(after!.archivedAt, isNotNull);
    });

    test('restore after delete → both flags cleared in the domain', () async {
      final (:repo, :api) = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'c1',
        serverResponse: apiClient('c1', name: 'Acme'),
      );
      await repo.delete(companyId: 'co', id: 'c1');
      await repo.restore(companyId: 'co', id: 'c1');
      final after = await repo.watch(companyId: 'co', id: 'c1').first;
      expect(after!.isDeleted, isFalse);
      expect(after.archivedAt, isNull);
    });
  });

  group('pagination', () {
    test(
      'ensurePageLoaded upserts a page and advances cursor; hasMore reflects '
      'page size',
      () async {
        final fullPage = [for (var i = 0; i < 50; i++) apiClient('c$i')];
        final partialPage = [apiClient('c50')];
        final (:repo, :api) = makeRepo(pages: {1: fullPage, 2: partialPage});

        final hasMore1 = await repo.ensurePageLoaded(companyId: 'co', page: 1);
        expect(hasMore1, isTrue);

        final cursor1 = await db.syncStateDao.read(
          companyId: 'co',
          entityType: 'client',
        );
        expect(cursor1.id, 'c49');

        final hasMore2 = await repo.ensurePageLoaded(companyId: 'co', page: 2);
        expect(hasMore2, isFalse, reason: 'partial page means end of list');

        // Page >= 2 is a continuation of the offset sweep — the cursor's
        // `updated_at >=` filter must NOT narrow it (the server applies it
        // as a WHERE on top of offset paging, so a filtered page 2 mostly
        // re-returns page 1's rows → near-empty → pagination, search, and
        // full resync silently cap at one page).
        expect(
          api.calls.last.sinceId,
          isNull,
          reason: 'page >= 2 must not send the delta cursor',
        );
        final cursor2 = await db.syncStateDao.read(
          companyId: 'co',
          entityType: 'client',
        );
        expect(
          cursor2.id,
          'c49',
          reason:
              'a page >= 2 fetch must not move the watermark '
              '(deeper pages carry older rows under id DESC)',
        );

        // A fresh page-1 fetch IS the delta probe — it sends the cursor.
        await repo.ensurePageLoaded(companyId: 'co', page: 1);
        expect(api.calls.last.sinceId, isNotNull);
      },
    );

    test('a warm page-1 fetch that applied the delta cursor and got a PARTIAL '
        'page still reports hasMore=true — a thin `updated_at >=` delta is not '
        'end-of-list; the local cache holds rows 51+ reachable only via the '
        'cursorless page 2 (#10)', () async {
      // Seed the shared cursor as an earlier full sweep would have.
      await db.syncStateDao.writeCursor(
        companyId: 'co',
        entityType: 'client',
        updatedAt: 1700000000,
        id: 'c49',
        now: 1700000000,
      );
      // A later warm open: only a handful of rows changed since the cursor,
      // so the `updated_at >=` delta returns a partial page even though the
      // account (and the local cache) hold far more than one page.
      final thinDelta = [for (var i = 0; i < 3; i++) apiClient('d$i')];
      final (:repo, :api) = makeRepo(pages: {1: thinDelta});

      final hasMore = await repo.ensurePageLoaded(companyId: 'co', page: 1);

      expect(
        api.calls.single.since,
        isNotNull,
        reason: 'page 1 applied the seeded delta cursor',
      );
      expect(
        hasMore,
        isTrue,
        reason:
            'a partial delta page must not latch hasMore=false — that '
            'permanently capped warm-session lists at ~50 rows',
      );
    });

    test(
      'a client-scoped fetch neither reads nor advances the shared cursor '
      '(an embedded detail tab must not corrupt the standalone list)',
      () async {
        final (:repo, :api) = makeRepo(
          pages: {
            1: [apiClient('c1', updatedAt: 111)],
          },
        );

        // 1) An unscoped fetch advances the shared (company, entity) cursor.
        await repo.ensurePageLoaded(companyId: 'co', page: 1);
        final cursor = await db.syncStateDao.read(
          companyId: 'co',
          entityType: 'client',
        );
        expect(cursor.id, 'c1', reason: 'unscoped fetch advances the cursor');

        // 2) A client-scoped fetch must NOT read the cursor — it offset-
        //    paginates its narrowed view from page 1 instead.
        await repo.ensurePageLoaded(
          companyId: 'co',
          page: 1,
          extraFilters: const {
            'client_id': {'c1'},
          },
        );
        expect(
          api.calls.last.since,
          isNull,
          reason: 'scoped fetch must not read the shared cursor',
        );
        expect(api.calls.last.sinceId, isNull);

        // 3) ...and must NOT have advanced it: the next unscoped fetch still
        //    reads the step-1 high-water mark.
        await repo.ensurePageLoaded(companyId: 'co', page: 1);
        expect(
          api.calls.last.sinceId,
          'c1',
          reason: 'scoped fetch left the unscoped cursor intact',
        );
      },
    );

    test(
      'a vendor- or bank-integration-scoped fetch also skips the shared cursor '
      '(hasParentScope covers every server-narrowing embedded scope, exercised '
      'here through the generic ensurePageLoadedTemplate)',
      () async {
        const scopes = <Map<String, Set<String>>>[
          {
            'vendor_id': {'v1'},
          },
          {
            'bank_integration_ids': {'acct_1'},
          },
        ];
        for (final scope in scopes) {
          final (:repo, :api) = makeRepo(
            pages: {
              1: [apiClient('c1', updatedAt: 222)],
            },
          );
          // Seed the shared cursor with an unscoped fetch.
          await repo.ensurePageLoaded(companyId: 'co', page: 1);
          // A parent-scoped fetch must not read the cursor — and since read
          // and advance share the same `hasParentScope` gate, not reading
          // proves not advancing too.
          await repo.ensurePageLoaded(
            companyId: 'co',
            page: 1,
            extraFilters: scope,
          );
          expect(
            api.calls.last.since,
            isNull,
            reason: 'scoped fetch must not read the cursor: $scope',
          );
          expect(api.calls.last.sinceId, isNull);
        }
      },
    );

    test(
      'search term routes to the API filter param (server-side search)',
      () async {
        final (:repo, :api) = makeRepo(
          pages: {
            1: [apiClient('c1', name: 'Acme')],
          },
        );

        await repo.ensurePageLoaded(companyId: 'co', page: 1, search: 'acme');

        expect(
          api.calls.single.search,
          'acme',
          reason: 'local LIKE alone misses pages we have not fetched yet',
        );
      },
    );

    test('ensurePageLoaded passes the lifecycle `status` filter for '
        'non-default state sets', () async {
      final (:repo, :api) = makeRepo(pages: {1: const <ClientApi>[]});

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        states: {EntityState.archived, EntityState.deleted},
      );

      expect(
        api.calls.single.filters['status'],
        'archived,deleted',
        reason: 'lifecycle is the `status` param, not `client_status`',
      );
      expect(
        api.calls.single.filters.containsKey('client_status'),
        isFalse,
        reason: 'lifecycle must not leak onto the computed-status param',
      );
    });

    test(
      'ensurePageLoaded omits `status` when every state is requested',
      () async {
        final (:repo, :api) = makeRepo(pages: {1: const <ClientApi>[]});

        await repo.ensurePageLoaded(
          companyId: 'co',
          page: 1,
          states: EntityState.values.toSet(),
        );

        expect(api.calls.single.filters.containsKey('status'), isFalse);
      },
    );

    test(
      'ensurePageLoaded threads extraFilters as flat query params (not bracketed)',
      () async {
        final (:repo, :api) = makeRepo(pages: {1: const <ClientApi>[]});

        await repo.ensurePageLoaded(
          companyId: 'co',
          page: 1,
          extraFilters: {
            // Multi-value: comma-joined deterministically (sorted).
            'country_id': {'840', '124'},
            'group_settings_id': {'g1'},
          },
        );

        // The v2 API takes flat snake_case keys, NOT `filter[country_id]=…`.
        expect(api.calls.single.filters['country_id'], '124,840');
        expect(api.calls.single.filters['group_settings_id'], 'g1');
      },
    );

    test('ensurePageLoaded drops empty extraFilter sets', () async {
      final (:repo, :api) = makeRepo(pages: {1: const <ClientApi>[]});

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {'country_id': <String>{}},
      );

      expect(api.calls.single.filters.containsKey('country_id'), isFalse);
    });

    test('ensurePageLoaded remaps the date-between window slots to the '
        'server-honored created_between / updated_between params', () async {
      final (:repo, :api) = makeRepo(pages: {1: const <ClientApi>[]});

      await repo.ensurePageLoaded(
        companyId: 'co',
        page: 1,
        extraFilters: const {
          // `DateColumnFilterKey` stores the 3-part `<column>,<start>,<end>`
          // window; the server has no `*_at_range` handler.
          'created_at_range': {'created_at,2026-01-01,2026-03-31'},
          'updated_at_range': {'updated_at,2026-02-01,2026-02-28'},
        },
      );

      final filters = api.calls.single.filters;
      // Re-keyed to the honored param, leading column token stripped → 2-part.
      expect(filters['created_between'], '2026-01-01,2026-03-31');
      expect(filters['updated_between'], '2026-02-01,2026-02-28');
      // The silently-ignored `*_at_range` names must NOT reach the wire.
      expect(filters.containsKey('created_at_range'), isFalse);
      expect(filters.containsKey('updated_at_range'), isFalse);
    });

    test('ensurePageLoaded preserves is_dirty=true rows so a paged refresh '
        "doesn't clobber the user's pending offline edit", () async {
      // Seed a clean row, then dirty it via save() (simulating an offline
      // edit), then refresh page 1 with a stale server payload for the same
      // id. The dirty row must survive — both the local edit (`name`) and
      // the dirty flag.
      const id = 'c_persist';
      final (:repo, :api) = makeRepo(
        pages: {
          1: [apiClient(id, name: 'Server Name')],
        },
      );

      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: id,
        serverResponse: apiClient(id, name: 'Server Name'),
      );
      final loaded = await db.clientDao
          .watchById(companyId: 'co', id: id)
          .first;
      expect(loaded!.isDirty, isFalse);

      await repo.save(
        companyId: 'co',
        client: Client.fromApi(
          apiClient(id, name: 'Server Name'),
        ).copyWith(name: 'User Edit'),
      );
      final dirty = await db.clientDao.watchById(companyId: 'co', id: id).first;
      expect(dirty!.isDirty, isTrue);
      expect(dirty.name, 'User Edit');

      await repo.ensurePageLoaded(companyId: 'co', page: 1);

      final after = await db.clientDao.watchById(companyId: 'co', id: id).first;
      expect(
        after!.isDirty,
        isTrue,
        reason: 'page refresh must not clear the dirty flag',
      );
      expect(
        after.name,
        'User Edit',
        reason: "page refresh must not overwrite the user's local edit",
      );
    });

    test(
      'refreshAll pulls every state so the local cache covers archived/deleted '
      'without the user pulling-to-refresh again',
      () async {
        final (:repo, :api) = makeRepo(pages: {1: const <ClientApi>[]});

        await repo.refreshAll(companyId: 'co');

        // No lifecycle filter — every state requested, server returns all.
        expect(api.calls.first.filters.containsKey('status'), isFalse);
        expect(api.calls.first.filters.containsKey('client_status'), isFalse);
      },
    );

    test(
      'refreshAll(full: true) clears the cursor and re-pulls from page 1',
      () async {
        await db.syncStateDao.writeCursor(
          companyId: 'co',
          entityType: 'client',
          updatedAt: 100,
          id: 'old',
          now: 0,
        );
        final (:repo, :api) = makeRepo(pages: {1: <ClientApi>[]});

        await repo.refreshAll(companyId: 'co', full: true);

        expect(api.calls.first.since, isNull);
        expect(api.calls.first.sinceId, isNull);
      },
    );
  });

  group('Drift row round-trip', () {
    test(
      'email column projects the primary contact for fast filtering',
      () async {
        final (:repo, :api) = makeRepo();
        final c = Client.fromApi(
          ClientApi.fromJson({
            'id': 'c1',
            'name': 'Acme',
            'balance': '0',
            'contacts': [
              {'id': 'a', 'email': 'secondary@a.test', 'is_primary': false},
              {'id': 'b', 'email': 'primary@a.test', 'is_primary': true},
            ],
          }),
        );

        await repo.save(companyId: 'co', client: c);
        final row = await db.clientDao
            .watchById(companyId: 'co', id: 'c1')
            .first;
        expect(
          row!.email,
          'primary@a.test',
          reason: 'list filters use the projected email — must be the primary',
        );
      },
    );

    test(
      'email column drops a server-minted portal placeholder — and the API and '
      'local-save writers agree (invoiceninja/flutter#116)',
      () async {
        Map<String, dynamic> json() => {
          'id': 'c1',
          'name': 'Acme',
          'balance': '0',
          'contacts': [
            {
              'id': 'b',
              'first_name': 'Jimmy',
              'email': 'dq9GHaI6Dncm0Zd@example.com',
              'is_primary': true,
            },
          ],
        };

        // The API path: `_apiToCompanion` projects straight from `ClientApi`,
        // which never passes through `Contact.fromApi` — so the scrub has to
        // live in the shared `_primaryEmailOf` walk, not only at the model
        // seam. Otherwise the list's free-text search matches "example" and
        // the `contact_email` sort orders by a value the cell no longer shows.
        final fromApi = makeRepo(
          pages: {
            1: [ClientApi.fromJson(json())],
          },
        );
        await fromApi.repo.ensurePageLoaded(companyId: 'co', page: 1);
        final apiRow = await db.clientDao
            .watchById(companyId: 'co', id: 'c1')
            .first;
        expect(apiRow!.email, isEmpty);

        // The local-save path, which passes the already-blanked domain.
        final (:repo, :api) = makeRepo();
        await repo.save(
          companyId: 'co',
          client: Client.fromApi(ClientApi.fromJson(json())),
        );
        final savedRow = await db.clientDao
            .watchById(companyId: 'co', id: 'c1')
            .first;
        expect(
          savedRow!.email,
          apiRow.email,
          reason: 'the two writers to clients.email must not disagree',
        );
      },
    );

    test(
      'watchActiveNames falls back to the id when the display name is blank',
      () async {
        // Same reason as the vendor twin: `clients.display_name` can be empty
        // for a nameless client whose server-computed value was a minted
        // placeholder (invoiceninja/flutter#116), and the pickers order by it
        // and render it verbatim.
        final (:repo, :api) = makeRepo();
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: ClientApi.fromJson({
            'id': 'c_blank',
            'name': '',
            'display_name': 'dq9GHaI6Dncm0Zd@example.com',
            'balance': '0',
            'updated_at': 1700000000,
          }),
        );
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: ClientApi.fromJson({
            'id': 'c_named',
            'name': 'Acme',
            'balance': '0',
            'updated_at': 1700000000,
          }),
        );

        final rows = await repo.watchActiveNames(companyId: 'co').first;
        final byId = {for (final r in rows) r.id: r.name};
        expect(byId['c_blank'], 'c_blank', reason: 'never an empty label');
        expect(byId['c_named'], 'Acme');
      },
    );

    test(
      'Decimal balance survives the storage round-trip without precision loss',
      () async {
        final (:repo, :api) = makeRepo();
        final c = Client.fromApi(
          ClientApi.fromJson({
            'id': 'c1',
            'name': 'Acme',
            'balance': '12345.67',
          }),
        );

        await repo.save(companyId: 'co', client: c);
        final got = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(got!.balance, Decimal.parse('12345.67'));
      },
    );

    test(
      'isDirty survives the storage round-trip so the "Unsynced" chip renders '
      'after restart',
      () async {
        // Regression: _fromRow used to discard the row's is_dirty column
        // because Client.fromApi only sees the API payload.
        final (:repo, :api) = makeRepo();
        final c = Client.fromApi(apiClient('c1', name: 'Acme'));
        await repo.save(companyId: 'co', client: c);

        final got = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(got!.isDirty, isTrue);

        // Server confirms the save → applyUpdateResponse clears the flag.
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: apiClient('c1', name: 'Acme'),
        );
        final clean = await repo.watch(companyId: 'co', id: 'c1').first;
        expect(clean!.isDirty, isFalse);
      },
    );

    test('applyDeleteResponse marks the local row is_deleted=true so the list '
        'hides it immediately', () async {
      // Regression: the dispatcher used to wait for the next pull-to-refresh
      // to remove deleted rows from the visible list.
      final (:repo, :api) = makeRepo();
      await repo.save(
        companyId: 'co',
        client: Client.fromApi(apiClient('c1', name: 'Acme')),
      );

      await repo.applyDeleteResponse(companyId: 'co', id: 'c1');

      final visible = await repo
          .watchPage(companyId: 'co', loadedPages: 1)
          .first;
      expect(
        visible.map((c) => c.id),
        isEmpty,
        reason: 'is_deleted=true rows are filtered out of watchPage',
      );
    });
  });

  group('watchPage extraFilters[name]', () {
    test('applies a substring `name` filter locally so the list narrows in '
        'lockstep with the server', () async {
      // Regression: previously the local watch ignored `extraFilters`,
      // so applying a name chip left every cached row visible even
      // though the server returned only the matching subset.
      final (:repo, :api) = makeRepo();
      await repo.save(
        companyId: 'co',
        client: Client.fromApi(apiClient('c1', name: 'Alpha')),
      );
      await repo.save(
        companyId: 'co',
        client: Client.fromApi(apiClient('c2', name: 'Beta')),
      );
      await repo.save(
        companyId: 'co',
        client: Client.fromApi(apiClient('c3', name: 'Gamma')),
      );

      final filtered = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'name': {'ma'},
            },
          )
          .first;
      expect(
        filtered.map((c) => c.name),
        ['Gamma'],
        reason: 'SQL LIKE %ma% on the `name` column matches only Gamma',
      );

      // Sanity: with no filter, all three are visible.
      final unfiltered = await repo
          .watchPage(companyId: 'co', loadedPages: 1)
          .first;
      expect(unfiltered.map((c) => c.name).toList()..sort(), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
    });

    test('empty value set is treated as no filter', () async {
      final (:repo, :api) = makeRepo();
      await repo.save(
        companyId: 'co',
        client: Client.fromApi(apiClient('c1', name: 'Alpha')),
      );
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {'name': <String>{}},
          )
          .first;
      expect(result.map((c) => c.name), ['Alpha']);
    });
  });

  group('watchPage extraFilters[balance]', () {
    // Fixture: four clients with balances spanning the demo data shape.
    // The DAO casts the TEXT column to REAL for numeric comparison.
    Future<ClientRepository> seedBalances(ClientRepository repo) async {
      for (final (id, name, balance) in const [
        ('c1', 'Alpha', '100'),
        ('c2', 'Beta', '500'),
        ('c3', 'Gamma', '1000'),
        ('c4', 'Delta', '2000'),
      ]) {
        await repo.save(
          companyId: 'co',
          client: Client.fromApi(
            ClientApi.fromJson({'id': id, 'name': name, 'balance': balance}),
          ),
        );
      }
      return repo;
    }

    test('applies legacy suffix `value:gt` locally — balance > 500 narrows '
        'to two rows', () async {
      final (:repo, :api) = makeRepo();
      await seedBalances(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'balance': {'500:gt'},
            },
          )
          .first;
      expect(result.map((c) => c.name).toList()..sort(), ['Delta', 'Gamma']);
    });

    test('applies legacy suffix `value:lt` locally — balance < 500 narrows '
        'to one row', () async {
      final (:repo, :api) = makeRepo();
      await seedBalances(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'balance': {'500:lt'},
            },
          )
          .first;
      expect(result.map((c) => c.name), ['Alpha']);
    });

    test('numeric cast — 100 < 1000 lexicographically would invert; cast '
        'ensures the comparison is correct', () async {
      // String comparison would put '1000' < '500' < '100'. CAST as
      // REAL gives the expected 100 < 500 < 1000 < 2000.
      final (:repo, :api) = makeRepo();
      await seedBalances(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'balance': {'1500:lt'},
            },
          )
          .first;
      expect(result.map((c) => c.name).toList()..sort(), [
        'Alpha',
        'Beta',
        'Gamma',
      ]);
    });

    test('canonical prefix `gt:value` is parsed locally (the wire the '
        'segmented-chip work standardised on)', () async {
      final (:repo, :api) = makeRepo();
      await seedBalances(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'balance': {'gt:500'},
            },
          )
          .first;
      expect(result.map((c) => c.name).toList()..sort(), ['Delta', 'Gamma']);
    });

    test('empty value set is treated as no filter', () async {
      final (:repo, :api) = makeRepo();
      await seedBalances(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {'balance': <String>{}},
          )
          .first;
      expect(result, hasLength(4));
    });

    test('unparseable wire is ignored — no rows are filtered out', () async {
      final (:repo, :api) = makeRepo();
      await seedBalances(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'balance': {'garbage'},
            },
          )
          .first;
      expect(result, hasLength(4));
    });
  });

  group('watchPage extraFilters[updated_at_range / created_at_range]', () {
    // Three clients on distinct created/updated calendar days (noon UTC so
    // the day can't drift across timezones). The `updated`/`created`
    // DateColumnFilterKey `between` operator stores a window under
    // `<col>_range`; ClientRepository mirrors it onto the DAO's created/updated
    // epoch-second predicates so the local watch narrows in lockstep.
    Future<void> seedDates(ClientRepository repo) async {
      for (final (id, name, createdAt, updatedAt) in const [
        // created Jan 10 2023 / updated Mar 10 2023
        ('c1', 'Alpha', 1673352000, 1678449600),
        // created Jun 15 2023 / updated Aug 15 2023
        ('c2', 'Beta', 1686830400, 1692100800),
        // created Dec 20 2023 / updated Feb 20 2024
        ('c3', 'Gamma', 1703073600, 1708430400),
      ]) {
        await repo.save(
          companyId: 'co',
          client: Client.fromApi(
            ClientApi.fromJson({
              'id': id,
              'name': name,
              'created_at': createdAt,
              'updated_at': updatedAt,
            }),
          ),
        );
      }
    }

    test('updated_at_range narrows to rows updated within the window '
        '(inclusive day bounds)', () async {
      final (:repo, :api) = makeRepo();
      await seedDates(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'updated_at_range': {'updated_at,2023-03-01,2023-03-31'},
            },
          )
          .first;
      expect(result.map((c) => c.name), [
        'Alpha',
      ], reason: 'only Alpha was updated in March 2023');
    });

    test('created_at_range narrows on the created_at column, independently of '
        'updated_at', () async {
      final (:repo, :api) = makeRepo();
      await seedDates(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'created_at_range': {'created_at,2023-06-01,2023-06-30'},
            },
          )
          .first;
      expect(
        result.map((c) => c.name),
        ['Beta'],
        reason: 'only Beta was created in June 2023 (its updated_at is August)',
      );
    });

    test('legacy 2-part window wire still narrows', () async {
      final (:repo, :api) = makeRepo();
      await seedDates(repo);
      final result = await repo
          .watchPage(
            companyId: 'co',
            loadedPages: 1,
            extraFilters: const {
              'updated_at_range': {'2023-08-01,2023-08-31'},
            },
          )
          .first;
      expect(result.map((c) => c.name), ['Beta']);
    });

    test('no window → all rows visible', () async {
      final (:repo, :api) = makeRepo();
      await seedDates(repo);
      final result = await repo
          .watchPage(companyId: 'co', loadedPages: 1)
          .first;
      expect(result, hasLength(3));
    });
  });

  group('reactivateContactEmail', () {
    test('enqueues a reactivate_email row keyed to the client with the '
        'message_id payload — no local Drift write', () async {
      final (:repo, :api) = makeRepo();

      await repo.reactivateContactEmail(
        companyId: 'co',
        clientId: 'c1',
        messageId: 'msg-99',
      );

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending, hasLength(1));
      final row = pending.single;
      expect(row.entityType, 'client');
      expect(row.entityId, 'c1');
      expect(row.mutationKind, MutationKind.reactivateEmail.wireName);
      expect(row.mutationKind, 'reactivate_email');
      expect(row.idempotencyKey, isNotEmpty);
      expect(row.requiresPassword, isFalse);

      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      expect(payload['message_id'], 'msg-99');

      final clientRow = await db.clientDao
          .watchById(companyId: 'co', id: 'c1')
          .first;
      expect(clientRow, isNull, reason: 'reactivation never touches Drift');
    });
  });

  group('addComment', () {
    test('enqueues a single add_comment outbox row with trimmed notes and '
        'the entity_id payload — no local Drift write', () async {
      final (:repo, :api) = makeRepo();

      await repo.addComment(
        companyId: 'co',
        clientId: 'c1',
        text: '  hello world  ',
      );

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending, hasLength(1));
      final row = pending.single;
      expect(row.entityType, 'client');
      expect(row.entityId, 'c1');
      expect(row.mutationKind, 'add_comment');
      expect(row.idempotencyKey, isNotEmpty);
      expect(row.requiresPassword, isFalse);

      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      expect(payload['entity_id'], 'c1');
      expect(
        payload['notes'],
        'hello world',
        reason: 'whitespace must be trimmed before the server sees it',
      );

      // Comments do not touch the clients table.
      final clientRow = await db.clientDao
          .watchById(companyId: 'co', id: 'c1')
          .first;
      expect(clientRow, isNull);
    });

    test('watchPendingForEntity streams the row until it lands', () async {
      final (:repo, :api) = makeRepo();
      await repo.addComment(companyId: 'co', clientId: 'c1', text: 'hi');

      final pending = await db.outboxDao
          .watchPendingForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
            kind: MutationKind.addComment,
          )
          .first;
      expect(pending, hasLength(1));
      expect(pending.single.mutationKind, 'add_comment');
    });

    test('watchPendingForEntity[kind] excludes rows of other mutation kinds '
        'on the same entity — a parallel `update` does not leak into the '
        'Activity tab', () async {
      final (:repo, :api) = makeRepo();
      // Two pending mutations on the same client: an update + an
      // addComment. The Activity tab should only see the comment.
      await repo.save(
        companyId: 'co',
        client: Client.fromApi(apiClient('c1', name: 'Acme')),
      );
      await repo.addComment(companyId: 'co', clientId: 'c1', text: 'note');

      final scoped = await db.outboxDao
          .watchPendingForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
            kind: MutationKind.addComment,
          )
          .first;
      expect(scoped, hasLength(1));
      expect(scoped.single.mutationKind, 'add_comment');

      // Sanity: without the kind filter, both rows surface.
      final unfiltered = await db.outboxDao
          .watchPendingForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
          )
          .first;
      expect(unfiltered, hasLength(2));
    });
  });

  group('ClientRepository — refreshByIds (payment/tx side-effect)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test(
      'force-refetches an already-cached client and updates the row',
      () async {
        final api = _RefreshClientsApi(
          responses: {
            'cli1': const ClientApi(
              id: 'cli1',
              name: 'New',
              updatedAt: 1700000100,
            ),
          },
        );
        final repo = ClientRepository(db: db, api: api);
        // Seed a clean cached client.
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: const ClientApi(
            id: 'cli1',
            name: 'Old',
            updatedAt: 1700000000,
          ),
        );

        await repo.refreshByIds(companyId: 'co', ids: const ['cli1']);

        expect(api.fetched, ['cli1']);
        final c = await repo.watch(companyId: 'co', id: 'cli1').first;
        expect(c!.name, 'New');
      },
    );

    test('skips tmp_/empty ids and swallows per-id errors', () async {
      final api = _RefreshClientsApi(errors: {'boom': Exception('network')});
      final repo = ClientRepository(db: db, api: api);

      await repo.refreshByIds(
        companyId: 'co',
        ids: const ['tmp_pending', '', 'boom'],
      );

      // tmp_/empty are never fetched; the error id is fetched then swallowed.
      expect(api.fetched, ['boom']);
    });
  });
}
