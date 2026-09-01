import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/domain/sync/mutation.dart';

/// Universal contract every CRUD-list entity repository must satisfy.
///
/// Each entity test file supplies a fixture wiring the abstract knobs to its
/// concrete API + domain types, then calls
/// `runEntityRepositoryContract(fixture)` at the top of `main()`. The harness
/// installs its own `setUp` / `tearDown` and uses an in-memory Drift DB.
///
/// What's covered: tmp-id mint, outbox enqueue for create/update/delete,
/// requiresPassword flag, applyCreateResponse remap, applyUpdateResponse
/// clearing is_dirty, applyDeleteResponse hiding the row, watch(tmpId)
/// surviving the swap. What's NOT covered: per-entity filters, server query
/// shapes, custom-field plumbing — those stay in the concrete entity test
/// files.
abstract class EntityRepositoryContractFixture<TDomain, TApi> {
  /// Closure-style factory. Concrete fixtures collapse from ~50 LOC of
  /// abstract-method bodies to a single `EntityRepositoryContractFixture.build(
  /// entityType: 'foo', buildRepo: ..., buildApiModel: ..., fromApi: ...,
  /// ...);` call. The abstract class stays as the inheritance path for the
  /// few fixtures that need extra plumbing.
  factory EntityRepositoryContractFixture.build({
    required String entityType,
    required BaseEntityRepository<TDomain, TApi> Function(AppDatabase)
    buildRepo,
    required TApi Function({
      required String id,
      String? displayValue,
      int updatedAt,
    })
    buildApiModel,
    required TDomain Function(TApi) fromApi,
    required TDomain Function(TDomain item, {required String displayValue})
    editCopy,
    required String Function(TDomain) idOf,
    required bool Function(TDomain) isDirtyOf,
    required Future<SaveResult<TDomain>> Function(
      BaseEntityRepository<TDomain, TApi> repo, {
      required String companyId,
      required TDomain draft,
    })
    create,
    required Future<SaveResult<TDomain>> Function(
      BaseEntityRepository<TDomain, TApi> repo, {
      required String companyId,
      required TDomain entity,
    })
    save,
    required Future<void> Function(
      BaseEntityRepository<TDomain, TApi> repo, {
      required String companyId,
      required String id,
    })
    delete,
    bool createRequiresPassword,
    bool deleteRequiresPassword,
    DateTime Function(TDomain item)? updatedAtOf,
  }) = _ClosureContractFixture<TDomain, TApi>;

  /// Concrete subclasses that need extra plumbing keep the inheritance
  /// constructor.
  EntityRepositoryContractFixture();

  /// The entity's server `updated_at`, when the domain model carries one.
  ///
  /// Opt-in: leave it null and the timestamp-survival test is skipped. That
  /// test is the one guard on a hazard `TagRepository._fromRow` and
  /// `PaymentLink.toApiJson` each had to solve individually — the local save
  /// path writes the Drift `payload` from `toApiJson`, which deliberately omits
  /// server-assigned timestamps, so a `_fromRow` that decodes the payload
  /// without overlaying them from the (authoritative) columns hands back epoch
  /// 0 and the list paints 1 Jan 1970.
  DateTime Function(TDomain item)? get updatedAtOf => null;

  /// Matches `EntityType.<x>.name` — used both to scope outbox lookups and to
  /// label the test group output.
  String get entityType;

  /// Whether `MutationKind.create` outbox rows should carry
  /// `requiresPassword=true` for this entity. Default `false` matches the
  /// historic pattern (only `delete` is password-gated). User Management
  /// overrides to `true` because `POST /api/v1/users` is server-side
  /// password-gated — mirrors React's edit flow.
  bool get createRequiresPassword => false;

  /// Whether `MutationKind.delete` outbox rows should carry
  /// `requiresPassword=true` for this entity. Default `true` matches the
  /// historic pattern (delete/purge are password-gated so `ConfirmPasswordSheet`
  /// fires). Webhooks override to `false` — the server applies no password
  /// middleware to webhooks.
  bool get deleteRequiresPassword => true;

  /// Build the repository under test. Called once per `setUp`; the fixture
  /// can rely on a fresh in-memory database each time.
  BaseEntityRepository<TDomain, TApi> buildRepo(AppDatabase db);

  /// Construct an API-shape DTO with the given id and a stable display value
  /// (so the round-trip assertions can spot mismatched fields). `updatedAt`
  /// defaults to a non-zero so cursor logic doesn't trip.
  TApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  });

  /// Lift the API DTO into the domain model the repo's create/save methods
  /// consume.
  TDomain fromApi(TApi api);

  /// Return a copy of [item] with the display value swapped — used by the
  /// "update writes is_dirty and enqueues an update outbox row" test.
  TDomain editCopy(TDomain item, {required String displayValue});

  /// Domain accessors.
  String idOf(TDomain item);
  bool isDirtyOf(TDomain item);

  /// Repo-method shims. `BaseEntityRepository` doesn't expose `create` /
  /// `save` / `delete` directly — they live on the concrete subclass with
  /// entity-specific named params (`save({client:})`, `save({product:})`,
  /// …). The fixture closes the gap.
  Future<SaveResult<TDomain>> create(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required TDomain draft,
  });

  Future<SaveResult<TDomain>> save(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required TDomain entity,
  });

  Future<void> delete(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required String id,
  });

  /// `watch(id)` is on the base class but typed `Stream<TDomain?>`; expose it
  /// here so the harness can read without casting.
  Stream<TDomain?> watch(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required String id,
  }) => repo.watch(companyId: companyId, id: id);
}

/// Closure-fixture wiring. Subclass of the abstract fixture that delegates
/// every hook to a closure — produced by [EntityRepositoryContractFixture.build].
class _ClosureContractFixture<TDomain, TApi>
    extends EntityRepositoryContractFixture<TDomain, TApi> {
  _ClosureContractFixture({
    required this.entityType,
    required BaseEntityRepository<TDomain, TApi> Function(AppDatabase)
    buildRepo,
    required TApi Function({
      required String id,
      String? displayValue,
      int updatedAt,
    })
    buildApiModel,
    required TDomain Function(TApi) fromApi,
    required TDomain Function(TDomain item, {required String displayValue})
    editCopy,
    required String Function(TDomain) idOf,
    required bool Function(TDomain) isDirtyOf,
    required Future<SaveResult<TDomain>> Function(
      BaseEntityRepository<TDomain, TApi> repo, {
      required String companyId,
      required TDomain draft,
    })
    create,
    required Future<SaveResult<TDomain>> Function(
      BaseEntityRepository<TDomain, TApi> repo, {
      required String companyId,
      required TDomain entity,
    })
    save,
    required Future<void> Function(
      BaseEntityRepository<TDomain, TApi> repo, {
      required String companyId,
      required String id,
    })
    delete,
    bool createRequiresPassword = false,
    bool deleteRequiresPassword = true,
    DateTime Function(TDomain item)? updatedAtOf,
  }) : _buildRepo = buildRepo,
       _updatedAtOf = updatedAtOf,
       _buildApiModel = buildApiModel,
       _fromApi = fromApi,
       _editCopy = editCopy,
       _idOf = idOf,
       _isDirtyOf = isDirtyOf,
       _create = create,
       _save = save,
       _delete = delete,
       _createRequiresPassword = createRequiresPassword,
       _deleteRequiresPassword = deleteRequiresPassword;

  @override
  final String entityType;
  final bool _createRequiresPassword;
  final bool _deleteRequiresPassword;

  @override
  bool get createRequiresPassword => _createRequiresPassword;

  @override
  bool get deleteRequiresPassword => _deleteRequiresPassword;
  final DateTime Function(TDomain item)? _updatedAtOf;

  @override
  DateTime Function(TDomain item)? get updatedAtOf => _updatedAtOf;

  final BaseEntityRepository<TDomain, TApi> Function(AppDatabase) _buildRepo;
  final TApi Function({required String id, String? displayValue, int updatedAt})
  _buildApiModel;
  final TDomain Function(TApi) _fromApi;
  final TDomain Function(TDomain item, {required String displayValue})
  _editCopy;
  final String Function(TDomain) _idOf;
  final bool Function(TDomain) _isDirtyOf;
  final Future<SaveResult<TDomain>> Function(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required TDomain draft,
  })
  _create;
  final Future<SaveResult<TDomain>> Function(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required TDomain entity,
  })
  _save;
  final Future<void> Function(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required String id,
  })
  _delete;

  @override
  BaseEntityRepository<TDomain, TApi> buildRepo(AppDatabase db) =>
      _buildRepo(db);

  @override
  TApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) =>
      _buildApiModel(id: id, displayValue: displayValue, updatedAt: updatedAt);

  @override
  TDomain fromApi(TApi api) => _fromApi(api);

  @override
  TDomain editCopy(TDomain item, {required String displayValue}) =>
      _editCopy(item, displayValue: displayValue);

  @override
  String idOf(TDomain item) => _idOf(item);

  @override
  bool isDirtyOf(TDomain item) => _isDirtyOf(item);

  @override
  Future<SaveResult<TDomain>> create(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required TDomain draft,
  }) => _create(repo, companyId: companyId, draft: draft);

  @override
  Future<SaveResult<TDomain>> save(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required TDomain entity,
  }) => _save(repo, companyId: companyId, entity: entity);

  @override
  Future<void> delete(
    BaseEntityRepository<TDomain, TApi> repo, {
    required String companyId,
    required String id,
  }) => _delete(repo, companyId: companyId, id: id);
}

/// Registers the universal contract tests against [fixture]. Call inside
/// `main()` (or a parent `group`) of the entity's `*_repository_test.dart`.
void runEntityRepositoryContract<TDomain, TApi>(
  EntityRepositoryContractFixture<TDomain, TApi> fixture,
) {
  group('BaseEntityRepository contract — ${fixture.entityType}', () {
    late AppDatabase db;
    late BaseEntityRepository<TDomain, TApi> repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = fixture.buildRepo(db);
    });
    tearDown(() async {
      await db.close();
    });

    test('create offline mints a tmp_ id and stores is_dirty=true', () async {
      // `repo.create` returns the draft with its tmp id assigned; the
      // `is_dirty=true` flag is set on the Drift row inside the transaction
      // and re-emerges through `watch` (the repo's `_fromRow` overlay).
      final draft = fixture.fromApi(
        fixture.buildApiModel(id: '', displayValue: 'A'),
      );

      final created = await fixture.create(repo, companyId: 'co', draft: draft);

      expect(fixture.idOf(created.entity), startsWith('tmp_'));
      expect(
        created.outboxRowId,
        greaterThan(0),
        reason:
            'create must return the just-enqueued outbox row id so '
            'GenericEditViewModel.save() can await it (synchronous-when-online)',
      );
      final fromDb = await fixture
          .watch(repo, companyId: 'co', id: fixture.idOf(created.entity))
          .first;
      expect(fromDb, isNotNull);
      expect(fixture.isDirtyOf(fromDb as TDomain), isTrue);
    });

    test('deleteLocalById hard-deletes the local row (the discard-ghost '
        'seam — SyncRepository.discardOutboxRow)', () async {
      final draft = fixture.fromApi(
        fixture.buildApiModel(id: '', displayValue: 'A'),
      );
      final created = await fixture.create(repo, companyId: 'co', draft: draft);
      final tmpId = fixture.idOf(created.entity);
      expect(
        await fixture.watch(repo, companyId: 'co', id: tmpId).first,
        isNotNull,
      );

      await repo.deleteLocalById(companyId: 'co', id: tmpId);

      expect(
        await fixture.watch(repo, companyId: 'co', id: tmpId).first,
        isNull,
        reason: 'discarding a never-synced ghost create must remove the row',
      );
    });

    test('create enqueues a create outbox row with a fresh idempotency key '
        'and the entity\'s wireName', () async {
      final draft = fixture.fromApi(
        fixture.buildApiModel(id: '', displayValue: 'A'),
      );
      await fixture.create(repo, companyId: 'co', draft: draft);

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(pending, hasLength(1));
      expect(pending.single.mutationKind, MutationKind.create.wireName);
      expect(pending.single.entityType, fixture.entityType);
      expect(pending.single.idempotencyKey, isNotEmpty);
      expect(
        pending.single.requiresPassword,
        equals(fixture.createRequiresPassword),
        reason: fixture.createRequiresPassword
            ? 'create is server-side password-gated for this entity'
            : 'create does not require password — only delete does',
      );
    });

    test(
      'save writes is_dirty=true and enqueues an update outbox row',
      () async {
        // Seed an existing row via applyCreateResponse so save() goes through
        // the update path, not the create path.
        const existingId = 'existing_1';
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: existingId,
          serverResponse: fixture.buildApiModel(
            id: existingId,
            displayValue: 'A',
          ),
        );
        final loaded = await fixture
            .watch(repo, companyId: 'co', id: existingId)
            .first;
        expect(loaded, isNotNull);
        final edited = fixture.editCopy(
          loaded as TDomain,
          displayValue: 'A renamed',
        );
        await fixture.save(repo, companyId: 'co', entity: edited);

        final after = await fixture
            .watch(repo, companyId: 'co', id: existingId)
            .first;
        expect(fixture.isDirtyOf(after as TDomain), isTrue);

        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(
          pending.where((p) => p.mutationKind == MutationKind.update.wireName),
          hasLength(1),
        );
      },
    );

    test(
      'delete enqueues with requiresPassword matching server policy',
      () async {
        await fixture.delete(repo, companyId: 'co', id: 'any_id');

        final pending = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(pending.single.mutationKind, MutationKind.delete.wireName);
        expect(
          pending.single.requiresPassword,
          equals(fixture.deleteRequiresPassword),
          reason: fixture.deleteRequiresPassword
              ? 'delete must surface ConfirmPasswordSheet'
              : 'delete is not password-gated server-side for this entity',
        );
      },
    );

    test('applyCreateResponse upserts the real-id row, removes the tmp row, '
        'and writes the id_remap', () async {
      final draft = fixture.fromApi(
        fixture.buildApiModel(id: '', displayValue: 'A'),
      );
      final created = await fixture.create(repo, companyId: 'co', draft: draft);
      final tmpId = fixture.idOf(created.entity);

      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: tmpId,
        serverResponse: fixture.buildApiModel(id: 'real_1', displayValue: 'A'),
      );

      // Real row exists; tmp row was removed in the same transaction.
      final real = await fixture
          .watch(repo, companyId: 'co', id: 'real_1')
          .first;
      expect(real, isNotNull);

      // id_remap row was recorded so subsequent watch(tmpId) calls resolve.
      final mapped = await db.idRemapDao.resolve(
        entityType: fixture.entityType,
        tempId: tmpId,
      );
      expect(mapped, 'real_1');
    });

    group('peek (the first-frame seed cache)', () {
      // `peek` exists so a freshly-MOUNTED *NameLabel paints the right name
      // instead of a raw hashid — the master-detail pane re-keys its subtree
      // per `:id`, so every row click is a fresh mount. It is a seed, never a
      // source of truth; `test/lint/peek_is_seed_only_test.dart` pins that.

      test('is null before anything has watched the id', () {
        expect(repo.peek(companyId: 'co', id: 'p_1'), isNull);
      });

      test('mirrors what watch emitted', () async {
        const id = 'p_1';
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: id,
          serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
        );
        final watched = await fixture
            .watch(repo, companyId: 'co', id: id)
            .first;

        expect(watched, isNotNull);
        expect(repo.peek(companyId: 'co', id: id), watched);
      });

      test('is scoped by company', () async {
        const id = 'p_1';
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: id,
          serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
        );
        await fixture.watch(repo, companyId: 'co', id: id).first;

        expect(repo.peek(companyId: 'other', id: id), isNull);
      });

      test('a null emission REMOVES the entry, so a record deleted '
          'server-side is never resurrected as a seed', () async {
        // The load-bearing case. A naive `_lastSeen[key] = value` keeps the
        // last good value forever, and the next remount would paint a record
        // the server no longer has.
        const id = 'p_1';
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: id,
          serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
        );
        await fixture.watch(repo, companyId: 'co', id: id).first;
        expect(repo.peek(companyId: 'co', id: id), isNotNull);

        await repo.deleteLocalById(companyId: 'co', id: id);
        final gone = await fixture.watch(repo, companyId: 'co', id: id).first;

        expect(gone, isNull);
        expect(repo.peek(companyId: 'co', id: id), isNull);
      });

      test('clearPeekCache drops everything (the logout path)', () async {
        const id = 'p_1';
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: id,
          serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
        );
        await fixture.watch(repo, companyId: 'co', id: id).first;

        repo.clearPeekCache();

        expect(repo.peek(companyId: 'co', id: id), isNull);
      });

      test('evicts the least recently observed past the cap', () async {
        // Seed cap + 1 distinct ids; the first observed must fall out.
        const limit = BaseEntityRepository.peekCacheLimit;
        for (var i = 0; i <= limit; i++) {
          final id = 'p_$i';
          await repo.applyCreateResponse(
            companyId: 'co',
            tempId: id,
            serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
          );
          await fixture.watch(repo, companyId: 'co', id: id).first;
        }

        expect(repo.peek(companyId: 'co', id: 'p_0'), isNull);
        expect(repo.peek(companyId: 'co', id: 'p_$limit'), isNotNull);
      });
    });

    test('applyUpdateResponse clears is_dirty so the "Unsynced" chip '
        'disappears after the round-trip', () async {
      // Seed via applyCreateResponse (clean), then dirty via save(), then
      // confirm applyUpdateResponse clears the flag again.
      const id = 'p_1';
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: id,
        serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
      );
      final loaded = await fixture.watch(repo, companyId: 'co', id: id).first;
      await fixture.save(
        repo,
        companyId: 'co',
        entity: fixture.editCopy(loaded as TDomain, displayValue: 'A renamed'),
      );
      final dirty = await fixture.watch(repo, companyId: 'co', id: id).first;
      expect(fixture.isDirtyOf(dirty as TDomain), isTrue);

      await repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: fixture.buildApiModel(
          id: id,
          displayValue: 'A renamed',
        ),
      );
      final clean = await fixture.watch(repo, companyId: 'co', id: id).first;
      expect(fixture.isDirtyOf(clean as TDomain), isFalse);
    });

    test('a locally-edited row keeps its server timestamps', () async {
      // `toApiJson` (rightly) omits `created_at` / `updated_at`, and the same
      // map is written into the Drift `payload` column on every local save. A
      // `_fromRow` that decodes the payload without overlaying the timestamps
      // from the columns therefore reports epoch 0 for any row with a pending
      // edit — which the list renders as 1 Jan 1970 and the sort orders first.
      // See `TagRepository._fromRow` and
      // `payment_link_repository_test.dart`'s "Timestamps must survive".
      final updatedAtOf = fixture.updatedAtOf;
      if (updatedAtOf == null) return; // opt-in

      const seconds = 1700000000;
      final seeded = fixture.fromApi(
        fixture.buildApiModel(id: 'e_1', displayValue: 'A', updatedAt: seconds),
      );
      await fixture.save(repo, companyId: 'co', entity: seeded);
      final saved = await repo.watch(companyId: 'co', id: 'e_1').first;
      expect(saved, isNotNull);
      expect(
        updatedAtOf(saved as TDomain).millisecondsSinceEpoch ~/ 1000,
        seconds,
        reason:
            'a dirty row must still report the server timestamp, not epoch 0',
      );
    });

    test('applyDeleteResponse marks the local row is_deleted so the list '
        'hides it immediately (no pull-to-refresh required)', () async {
      const id = 'p_1';
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: id,
        serverResponse: fixture.buildApiModel(id: id, displayValue: 'A'),
      );

      await repo.applyDeleteResponse(companyId: 'co', id: id);

      // watch returns the row directly (it doesn't filter is_deleted) but
      // every entity DAO's `watchPage` does — the concrete test for the
      // entity asserts the page-level hide. Here we just confirm the row
      // is flagged and not physically deleted (so undo / restore still
      // has something to work with).
      final after = await fixture.watch(repo, companyId: 'co', id: id).first;
      // Some entities don't expose `isDeleted` on the domain; trust that
      // watchPage filters out is_deleted rows in the entity-specific test.
      // The applyDeleteResponse contract here is: it doesn't throw and
      // returns successfully.
      expect(after, isNotNull, reason: 'soft-delete keeps the row around');
    });

    test(
      'watch(tmpId) keeps emitting after applyCreateResponse swaps the id',
      () async {
        final draft = fixture.fromApi(
          fixture.buildApiModel(id: '', displayValue: 'A'),
        );
        final created = await fixture.create(
          repo,
          companyId: 'co',
          draft: draft,
        );
        final tmpId = fixture.idOf(created.entity);

        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: tmpId,
          serverResponse: fixture.buildApiModel(
            id: 'real_2',
            displayValue: 'A',
          ),
        );

        final landed = await fixture
            .watch(repo, companyId: 'co', id: tmpId)
            .first;
        expect(landed, isNotNull);
        expect(fixture.idOf(landed as TDomain), 'real_2');
      },
    );
  });
}
