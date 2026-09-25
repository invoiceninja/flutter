import 'dart:async';
import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/request_scope.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

/// These tests target the sync engine's STATE MACHINE — the transitions that
/// production reliability depends on:
///   * success → outbox row removed
///   * 422 → row marked dead + ValidationFailedEvent
///   * 409 → row stays pending + ConflictEvent (with retry deferred)
///   * PasswordRequired → row stays pending + PasswordRequiredEvent (emitted
///     on the FIRST 412 only; repeats back off and finally die)
///   * 429 with Retry-After → row stays pending with delay honored
///   * 5xx/network → backoff schedule (1st failure → 5s, 2nd → 30s, ...)
///   * exceeding max attempts → marked dead
///   * unknown mutation kind / missing dispatcher → marked dead, never hangs

/// Programmable fake dispatcher — each `dispatch` call throws a queued
/// outcome (or returns void on success).
class _ProgrammableDispatcher implements SyncDispatcher {
  final List<Object?> _outcomes = [];
  int dispatches = 0;
  OutboxRow? lastRow;

  void queueSuccess() => _outcomes.add(null);
  void queueThrow(Object error) => _outcomes.add(error);

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    dispatches++;
    lastRow = row;
    if (_outcomes.isEmpty) {
      throw StateError('no outcome queued for dispatch #$dispatches');
    }
    final outcome = _outcomes.removeAt(0);
    if (outcome is Object) {
      throw outcome;
    }
  }

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}
}

/// Dispatcher that runs [onDispatch] — for asserting what the dispatch sees
/// (its `RequestScope`) or scripting a failure after a partial success.
class _CallbackDispatcher implements SyncDispatcher {
  _CallbackDispatcher(this.onDispatch);
  final Future<void> Function(OutboxRow row) onDispatch;

  @override
  Future<void> dispatch({required OutboxRow row, required MutationKind kind}) =>
      onDispatch(row);

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}
}

/// Dispatcher that records which ids had their optimistic `is_dirty` flag
/// released, so a test can assert the dead-row reconciliation actually fired.
class _DirtySpyDispatcher implements SyncDispatcher {
  final List<String> clearedDirty = [];
  final List<Object?> _outcomes = [];

  void queueThrow(Object error) => _outcomes.add(error);

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    if (_outcomes.isEmpty) throw StateError('no outcome queued');
    final outcome = _outcomes.removeAt(0);
    if (outcome is Object) throw outcome;
  }

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async => clearedDirty.add(id);
}

/// Dispatcher that forwards `deleteLocalRecord` to a repo, the way
/// `BaseEntitySyncDispatcher` does — used by the discard tests to observe
/// that the ghost path reaches the repository.
class _RepoDeleteDispatcher implements SyncDispatcher {
  _RepoDeleteDispatcher(this.repo);
  final BaseEntityRepository<dynamic, dynamic> repo;

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {}

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) => repo.deleteLocalById(companyId: companyId, id: id);

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => repo.clearLocalDirty(companyId: companyId, id: id);
}

EntityRegistry _registryWith(SyncDispatcher dispatcher) => EntityRegistry({
  EntityType.client: EntityHandlers(
    type: EntityType.client,
    wireName: 'client',
    apiPath: '/api/v1/clients',
    routePath: '/clients',
    icon: Icons.people,
    requiresPasswordFor: const {MutationKind.delete},
    dispatcher: dispatcher,
  ),
});

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<int> enqueueClient({
    required String entityId,
    MutationKind kind = MutationKind.update,
    int nextAttemptAt = 0,
    int attempts = 0,
    String idempotencyKey = 'k',
  }) => db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: 'co',
      entityType: 'client',
      entityId: entityId,
      mutationKind: kind.wireName,
      payload: jsonEncode({'id': entityId}),
      idempotencyKey: idempotencyKey,
      nextAttemptAt: nextAttemptAt,
      createdAt: 0,
      attempts: Value(attempts),
    ),
  );

  Future<OutboxRow?> rowById(int id) async {
    final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  SyncRepository makeEngine(SyncDispatcher dispatcher, {int nowMs = 1000}) {
    return SyncRepository(
      db: db,
      registry: _registryWith(dispatcher),
      now: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
  }

  group('hasUnsyncedWork', () {
    // Every involuntary session end (idle timeout, client-too-old, restore
    // with missing rows, a failed Danger Zone switch) consults this before
    // choosing a destructive logout. It used to ignore `dead` rows, so a
    // rejected edit — and the dirty local row holding it for a fix-and-retry
    // — was wiped by the next idle timeout with no prompt.
    test('a dead row alone is unsynced work', () async {
      final engine = makeEngine(_ProgrammableDispatcher());
      expect(await engine.hasUnsyncedWork(), isFalse);
      final id = await enqueueClient(entityId: 'c1');
      await db.outboxDao.markDead(id: id, error: '422', statusCode: 422);
      expect(await engine.hasUnsyncedWork(), isTrue);
      expect(await engine.attentionCountEverywhere(), 1);
    });
  });

  group('holdDrains', () {
    // The sign-out review holds drains while the user decides: a reconnect's
    // drain sent what they had just chosen to discard. Holds nest — a second
    // flow's release doesn't lift the first's — and wait for nothing.
    test('no pass starts until every hold is released', () async {
      final disp = _ProgrammableDispatcher()..queueSuccess();
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1');

      engine
        ..holdDrains()
        ..holdDrains();
      await engine.drainOnce(companyId: 'co');
      engine.releaseDrains();
      await engine.drainOnce(companyId: 'co');
      expect(disp.dispatches, 0, reason: 'one hold is still taken');

      engine.releaseDrains();
      await engine.drainOnce(companyId: 'co');
      expect(disp.dispatches, 1);
    });

    test('a running pass stops at its next row', () async {
      final sent = <String>[];
      late SyncRepository engine;
      engine = makeEngine(
        _CallbackDispatcher((row) async {
          sent.add(row.entityId);
          engine.holdDrains(); // taken while the first row is on the wire
        }),
      );
      await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await enqueueClient(entityId: 'c2', idempotencyKey: 'k2');

      await engine.drainOnce(companyId: 'co');

      expect(sent, ['c1']);
    });
  });

  group('a re-sent create is not held behind the changes waiting for it', () {
    // A record whose create failed, then archived (or commented on, or marked
    // sent) before the user fixed it and saved it again: the archive waits for
    // a create to land, and the per-record barrier held the new create behind
    // the archive. Neither was ever sent, while the form said it was saving.
    const tmp = 'tmp_00000000-0000-4000-8000-0000000000e1';

    test(
      'the create goes, then the archive, re-keyed to the new record',
      () async {
        final dispatched = <String>[];
        final engine = makeEngine(
          _CallbackDispatcher((row) async {
            dispatched.add('${row.mutationKind}:${row.entityId}');
            if (row.mutationKind == MutationKind.create.wireName) {
              await db.idRemapDao.remember(
                entityType: 'client',
                tempId: row.entityId,
                realId: 'real_e1',
                now: 0,
              );
              await db.outboxDao.rewriteTempIdInPayloads(
                companyId: 'co',
                entityType: 'client',
                tempId: row.entityId,
                realId: 'real_e1',
              );
            }
          }),
        );
        final failed = await enqueueClient(
          entityId: tmp,
          kind: MutationKind.create,
          idempotencyKey: 'c1',
        );
        await db.outboxDao.markDead(
          id: failed,
          error: 'The given data was invalid.',
          statusCode: 422,
        );
        await enqueueClient(
          entityId: tmp,
          kind: MutationKind.archive,
          idempotencyKey: 'a1',
        );
        await enqueueClient(
          entityId: tmp,
          kind: MutationKind.create,
          idempotencyKey: 'c2',
        );

        await engine.drainOnce(companyId: 'co');
        await engine.drainOnce(companyId: 'co');

        expect(dispatched, ['create:$tmp', 'archive:real_e1']);
      },
    );

    test('an earlier create of the record still holds it back', () async {
      // The one earlier change that does come first: a create that may have
      // gone through waits on the user, and this one behind it.
      final disp = _ProgrammableDispatcher();
      final engine = makeEngine(disp);
      final first = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'c1',
      );
      await db.outboxDao.markUnconfirmed(id: first, error: 'timed out');
      final second = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'c2',
      );

      await engine.drainOnce(companyId: 'co');

      expect(disp.dispatches, 0);
      expect(
        (await db.outboxDao.byId(second))?.lastError,
        kHeldBehindUnconfirmedError,
      );
    });
  });

  group('a create for a record that already exists is never sent again', () {
    // The server ignores Idempotency-Key, so a create sent for a record it
    // already holds makes that record twice. A create's id stops being a
    // `tmp_` id only when an earlier attempt at it landed
    // (`rewriteTempIdInPayloads`), and a tmp id maps only once one did.
    const tmp = 'tmp_00000000-0000-4000-8000-0000000000d1';

    Future<List<SyncEvent>> drainCollecting(SyncRepository engine) async {
      final events = <SyncEvent>[];
      final sub = engine.events.listen(events.add);
      await engine.drainOnce(companyId: 'co');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      return events;
    }

    Future<OutboxRow> rowOf(int id) async => (await db.outboxDao.byId(id))!;

    test('a create under a real id is refused, not sent', () async {
      final disp = _ProgrammableDispatcher();
      final engine = makeEngine(disp);
      final id = await enqueueClient(
        entityId: 'c_real',
        kind: MutationKind.create,
      );

      final events = await drainCollecting(engine);

      expect(disp.dispatches, 0);
      final row = await rowOf(id);
      expect(row.state, 'dead');
      expect(row.lastError, kAlreadyCreatedError);
      expect(isCreateOfExistingRecord(row), isTrue);
      expect(events.whereType<DeadEvent>(), hasLength(1));
    });

    test('a create whose temp id already landed is refused', () async {
      final disp = _ProgrammableDispatcher();
      await db.idRemapDao.remember(
        entityType: 'client',
        tempId: tmp,
        realId: 'real_c1',
        now: 0,
      );
      final id = await enqueueClient(entityId: tmp, kind: MutationKind.create);

      await drainCollecting(makeEngine(disp));

      expect(disp.dispatches, 0);
      expect((await rowOf(id)).lastError, kAlreadyCreatedError);
    });

    test('a second create queued while the first was in flight dies instead '
        'of making the record twice', () async {
      // The first lands and re-keys the second to the real id; sent, it made a
      // second record, and its landing then remapped the first record's real
      // id onto the duplicate's.
      var landed = 0;
      final dispatched = <int>[];
      final engine = makeEngine(
        _CallbackDispatcher((row) async {
          dispatched.add(row.id);
          landed++;
          final realId = 'real_$landed';
          await db.idRemapDao.remember(
            entityType: 'client',
            tempId: row.entityId,
            realId: realId,
            now: 0,
          );
          await db.outboxDao.rewriteTempIdInPayloads(
            companyId: 'co',
            entityType: 'client',
            tempId: row.entityId,
            realId: realId,
          );
        }),
      );
      final first = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'k1',
      );
      final second = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'k2',
      );

      await engine.drainOnce(companyId: 'co');
      await engine.drainOnce(companyId: 'co');

      expect(dispatched, [first]);
      final row = await rowOf(second);
      expect(row.state, 'dead');
      expect(row.entityId, 'real_1');
      expect(
        await db.idRemapDao.resolve(entityType: 'client', tempId: 'real_1'),
        isNull,
        reason: 'no real id is remapped onto a duplicate',
      );
    });

    test('Retry of a failed create under a real id is refused again', () async {
      final disp = _ProgrammableDispatcher();
      final engine = makeEngine(disp);
      final id = await enqueueClient(
        entityId: 'c_real',
        kind: MutationKind.create,
      );
      await db.outboxDao.markDead(id: id, error: 'Down', statusCode: 503);

      expect(await db.outboxDao.retryDead(id: id, now: 0), isTrue);
      await engine.drainOnce(companyId: 'co');

      expect(disp.dispatches, 0);
      expect((await rowOf(id)).state, 'dead');
    });

    test('a password supplied later does not revive it into a send', () async {
      final disp = _ProgrammableDispatcher();
      final engine = makeEngine(disp);
      final id = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c_real',
          mutationKind: MutationKind.create.wireName,
          payload: '{}',
          idempotencyKey: 'k',
          nextAttemptAt: 0,
          createdAt: 0,
          requiresPassword: const Value(true),
        ),
      );
      await db.outboxDao.markDead(
        id: id,
        error: 'Invalid Password',
        statusCode: 412,
      );

      await engine.retryPasswordRows(companyId: 'co');
      await engine.retryPasswordRows(companyId: 'co');

      expect(disp.dispatches, 0);
      expect((await rowOf(id)).state, 'dead');
    });
  });

  group('rows orphaned in flight (the app died mid-attempt)', () {
    // `in_flight` at drain start means a prior pass was interrupted. They
    // used to be re-armed unconditionally "because the idempotency key makes
    // a re-send harmless" — but the server ignores that header.
    Future<int> orphan({
      required String entityId,
      required MutationKind kind,
    }) async {
      final id = await enqueueClient(entityId: entityId, kind: kind);
      await db.outboxDao.markInFlight(id);
      return id;
    }

    test('a create whose response was already applied is retired, not '
        're-sent as a duplicate', () async {
      // The id_remap entry is written in the same transaction that applies
      // the server's response; the row delete is a separate statement after
      // it. A remap with the row still in flight means the app died in that
      // gap: the record exists on the server already.
      final id = await orphan(entityId: 'tmp_c1', kind: MutationKind.create);
      await db.idRemapDao.remember(
        entityType: 'client',
        tempId: 'tmp_c1',
        realId: 'real_c1',
        now: 0,
      );
      final disp = _ProgrammableDispatcher();

      await makeEngine(disp).drainOnce(companyId: 'co');

      expect(disp.dispatches, 0, reason: 'a re-send would duplicate it');
      expect(await db.outboxDao.byId(id), isNull);
    });

    test('a create with no remap may have landed: it waits for the user, '
        'never re-sent on its own', () async {
      final id = await orphan(entityId: 'tmp_c2', kind: MutationKind.create);
      final disp = _ProgrammableDispatcher();

      await makeEngine(disp).drainOnce(companyId: 'co');

      expect(disp.dispatches, 0);
      expect((await db.outboxDao.byId(id))?.state, 'unconfirmed');
    });

    test('other kinds are re-armed as before', () async {
      await orphan(entityId: 'c3', kind: MutationKind.update);
      final disp = _ProgrammableDispatcher()..queueSuccess();

      await makeEngine(disp).drainOnce(companyId: 'co');

      expect(disp.dispatches, 1);
    });
  });

  group('pruneDeadRows', () {
    test(
      'scoped to a company, it leaves every other company\'s failures',
      () async {
        final engine = makeEngine(_ProgrammableDispatcher());
        final mine = await enqueueClient(entityId: 'c1');
        await db.outboxDao.markDead(id: mine, error: '422');
        final theirs = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'other',
            entityType: 'client',
            entityId: 'c2',
            mutationKind: 'update',
            payload: '{}',
            idempotencyKey: 'k-other',
            nextAttemptAt: 0,
            createdAt: 0,
            state: const Value('dead'),
          ),
        );

        expect(
          await engine.pruneDeadRows(companyId: 'co', ttl: Duration.zero),
          1,
        );
        expect(await db.outboxDao.byId(mine), isNull);
        expect(await db.outboxDao.byId(theirs), isNotNull);
      },
    );
  });

  group('supersedeDeadSave', () {
    // After a successful re-save the edit form drops the failed attempt it
    // replaced. It used to delete whatever dead row the record had — a
    // rejected email or payment included.
    test('drops a failed save, and only a failed save', () async {
      final engine = makeEngine(_ProgrammableDispatcher());
      final save = await enqueueClient(entityId: 'c1');
      await db.outboxDao.markDead(id: save, error: '422');
      final email = await enqueueClient(
        entityId: 'c1',
        kind: MutationKind.emailEntity,
        idempotencyKey: 'k2',
      );
      await db.outboxDao.markDead(id: email, error: '400');
      final pending = await enqueueClient(entityId: 'c1', idempotencyKey: 'k3');

      expect(await engine.supersedeDeadSave(email), isFalse);
      expect(await engine.supersedeDeadSave(pending), isFalse);
      expect(await engine.supersedeDeadSave(save), isTrue);

      expect(await db.outboxDao.byId(save), isNull);
      expect(await db.outboxDao.byId(email), isNotNull);
      expect(await db.outboxDao.byId(pending), isNotNull);
    });

    test('keeps a failed create of a record the server has never seen until '
        'a newer create replaces it', () async {
      // An edit of that record saves an update, which waits behind the create
      // and can't send before it: dropping the create stranded the record.
      final engine = makeEngine(_ProgrammableDispatcher());
      const tmp = 'tmp_00000000-0000-4000-8000-0000000000f2';
      final create = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'k1',
      );
      await db.outboxDao.markDead(id: create, error: '422');
      await enqueueClient(entityId: tmp, idempotencyKey: 'k2');

      expect(await engine.supersedeDeadSave(create), isFalse);
      expect(await db.outboxDao.byId(create), isNotNull);

      await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'k3',
      );
      expect(await engine.supersedeDeadSave(create), isTrue);
    });

    test('drops the older failed saves it replaced too', () async {
      // Two rejected saves, then one that goes through: the form is linked to
      // the newer failure only. The older one used to stay — its error came
      // back on the next open, and a Retry would PUT stale content.
      final engine = makeEngine(_ProgrammableDispatcher());
      final older = await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await db.outboxDao.markDead(id: older, error: '422');
      final newer = await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');
      await db.outboxDao.markDead(id: newer, error: '422');
      final other = await enqueueClient(entityId: 'c2', idempotencyKey: 'k3');
      await db.outboxDao.markDead(id: other, error: '422');

      expect(await engine.supersedeDeadSave(newer), isTrue);

      expect(await db.outboxDao.byId(older), isNull);
      expect(await db.outboxDao.byId(newer), isNull);
      expect(await db.outboxDao.byId(other), isNotNull);
    });

    test(
      'an update of a never-synced record keeps its failed create',
      () async {
        final engine = makeEngine(_ProgrammableDispatcher());
        const tmp = 'tmp_00000000-0000-4000-8000-0000000000f3';
        final create = await enqueueClient(
          entityId: tmp,
          kind: MutationKind.create,
          idempotencyKey: 'k1',
        );
        await db.outboxDao.markDead(id: create, error: '422');
        final update = await enqueueClient(entityId: tmp, idempotencyKey: 'k2');
        await db.outboxDao.markDead(id: update, error: '422');

        expect(await engine.supersedeDeadSave(update), isTrue);
        expect(await db.outboxDao.byId(create), isNotNull);
      },
    );
  });

  group('an outcome the server never confirmed', () {
    // The server ignores `Idempotency-Key`, so a write that went out with no
    // answer may have been applied. Re-sending one whose replay repeats its
    // effect (another record, another email, another payment) could do it
    // twice — it waits for the user as `unconfirmed` instead. What provably
    // never went out, or is harmless to repeat, keeps its old retry.
    late List<SyncEvent> events;

    SyncRepository engineFor(SyncDispatcher disp) {
      final engine = makeEngine(disp);
      events = [];
      engine.events.listen(events.add);
      return engine;
    }

    /// What `ApiClient` records for a write whose body went out, then [error].
    _CallbackDispatcher sentThen(Object error, {bool committed = false}) =>
        _CallbackDispatcher((_) async {
          RequestScope.current!.markWriteSent();
          if (committed) RequestScope.current!.markCommitted();
          throw error;
        });

    Future<int> enqueue(
      String entityId,
      MutationKind kind, {
      Map<String, Object?>? payload,
    }) => db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co',
        entityType: 'client',
        entityId: entityId,
        mutationKind: kind.wireName,
        payload: jsonEncode(payload ?? {'id': entityId}),
        idempotencyKey: 'k-$entityId',
        nextAttemptAt: 0,
        createdAt: 0,
      ),
    );

    Future<OutboxRow> drained(SyncRepository engine, int id) async {
      await engine.drainOnce(companyId: 'co');
      await Future<void>.delayed(Duration.zero); // flush broadcast
      return (await db.outboxDao.byId(id))!;
    }

    test('a create that went out with no answer waits for the user, and '
        'says so', () async {
      final id = await enqueue('tmp_c1', MutationKind.create);
      var dispatches = 0;
      final engine = engineFor(
        _CallbackDispatcher((_) async {
          dispatches++;
          RequestScope.current!.markWriteSent();
          throw const NetworkException('Connection reset by peer');
        }),
      );

      final row = await drained(engine, id);

      expect(row.state, 'unconfirmed');
      expect(row.attempts, 0);
      expect(row.lastError, 'Connection reset by peer');
      expect(events.single, isA<UnconfirmedEvent>());
      await engine.drainOnce(companyId: 'co');
      expect(dispatches, 1, reason: 'no drain sends it again');
    });

    test('an idempotent write is retried as before', () async {
      final id = await enqueue('c1', MutationKind.update);
      final row = await drained(
        engineFor(sentThen(const NetworkException('reset'))),
        id,
      );
      expect(row.state, 'pending');
      expect(events, isEmpty);
    });

    test('a save that carries a payment is not idempotent', () async {
      final id = await enqueue(
        'c1',
        MutationKind.update,
        payload: {
          'id': 'c1',
          kSaveQueryPayloadKey: {'paid': 'true'},
        },
      );
      final row = await drained(
        engineFor(sentThen(const NetworkException('reset'))),
        id,
      );
      expect(row.state, 'unconfirmed');
    });

    test('provably never sent — or nothing written yet — is retried, '
        'whatever the kind', () async {
      final notSent = await enqueue('tmp_a', MutationKind.create);
      var row = await drained(
        engineFor(sentThen(const RequestNotSentException('No route to host'))),
        notSent,
      );
      expect(row.state, 'pending');

      // A follow-up read failing before any write proves nothing changed.
      final readFirst = await enqueue('tmp_b', MutationKind.create);
      row = await drained(
        engineFor(
          _CallbackDispatcher(
            (_) async => throw const NetworkException('reset'),
          ),
        ),
        readFirst,
      );
      expect(row.state, 'pending');
    });

    test('a 500 / 502 / 504 may have been applied; a 503 was not', () async {
      for (final code in [500, 502, 504]) {
        final id = await enqueue('tmp_$code', MutationKind.create);
        final row = await drained(
          engineFor(sentThen(ServerException(code, 'Bad gateway'))),
          id,
        );
        expect(row.state, 'unconfirmed', reason: '$code');
        expect(row.lastStatusCode, code);
      }
      final id = await enqueue('tmp_503', MutationKind.create);
      final row = await drained(
        engineFor(sentThen(const ServerException(503, 'Maintenance'))),
        id,
      );
      expect(row.state, 'pending');
      expect(row.attempts, 1, reason: 'the ordinary 5xx backoff');
    });

    test('a 500 that also says the app is too old is still an unknown '
        'outcome', () async {
      // The header throws before the 500 is read, and this arm re-parked
      // every row an hour out — so a create that may have landed was sent
      // again every hour, for as long as the app stayed out of date.
      final id = await enqueue('tmp_c1', MutationKind.create);
      final row = await drained(
        engineFor(
          sentThen(
            const ClientTooOldException(
              minRequiredVersion: '9.9.9',
              currentVersion: '1.0.0',
              statusCode: 500,
            ),
          ),
        ),
        id,
      );
      expect(row.state, 'unconfirmed');
      expect(row.lastStatusCode, 500);
    });

    test(
      'any other client-too-old rejection waits an hour for the update',
      () async {
        final id = await enqueue('c1', MutationKind.update);
        final row = await drained(
          engineFor(
            sentThen(
              const ClientTooOldException(
                minRequiredVersion: '9.9.9',
                currentVersion: '1.0.0',
                statusCode: 500,
              ),
            ),
          ),
          id,
        );
        expect(row.state, 'pending', reason: 'an update replays harmlessly');
        expect(row.attempts, 0);
        expect(
          row.nextAttemptAt,
          1000 + const Duration(hours: 1).inMilliseconds,
        );
      },
    );

    test('an unclassified throw after the write went out', () async {
      final id = await enqueue('tmp_c1', MutationKind.create);
      final row = await drained(engineFor(sentThen(StateError('?'))), id);
      expect(row.state, 'unconfirmed');
    });

    group('after the server accepted the write', () {
      test('a failure after it does not re-send it: the row is done and the '
          'record re-fetched', () async {
        // The client-too-old header on a 2xx used to re-park the row for an
        // hour and send the write again, every hour.
        final id = await enqueue('c1', MutationKind.update);
        final refetched = <String>[];
        final engine = engineFor(
          sentThen(
            const ClientTooOldException(
              minRequiredVersion: '9.9.9',
              currentVersion: '1.0.0',
            ),
            committed: true,
          ),
        )..refreshRecord = (companyId, type, id) async => refetched.add(id);

        await engine.drainOnce(companyId: 'co');

        expect(await db.outboxDao.byId(id), isNull);
        expect(refetched, ['c1']);
      });

      test('a create whose reply was lost waits for the user', () async {
        final id = await enqueue('tmp_c1', MutationKind.create);
        final row = await drained(
          engineFor(
            sentThen(const FormatException('bad json'), committed: true),
          ),
          id,
        );
        expect(row.state, 'unconfirmed');
      });

      test('a create whose reply was applied is done', () async {
        final id = await enqueue('tmp_c1', MutationKind.create);
        final engine = engineFor(
          _CallbackDispatcher((_) async {
            RequestScope.current!
              ..markWriteSent()
              ..markCommitted();
            await db.idRemapDao.remember(
              entityType: 'client',
              tempId: 'tmp_c1',
              realId: 'real_c1',
              now: 0,
            );
            throw StateError('a follow-up failed');
          }),
        );
        await engine.drainOnce(companyId: 'co');
        expect(await db.outboxDao.byId(id), isNull);
      });
    });

    group('once a row is unconfirmed', () {
      Future<int> unconfirmedEmail() async {
        final id = await enqueue('c1', MutationKind.emailEntity);
        await db.outboxDao.markUnconfirmed(id: id, error: 'reset');
        return id;
      }

      test('a later save of the same record waits behind it, and awaitRow '
          'says so at once', () async {
        final ahead = await unconfirmedEmail();
        final save = await enqueue('c1', MutationKind.update);
        final disp = _ProgrammableDispatcher();
        final engine = engineFor(disp);

        final result = await engine.awaitRow(
          rowId: save,
          companyId: 'co',
          timeout: const Duration(seconds: 20),
        );

        expect(result.outcome, SyncRowOutcome.unconfirmed);
        expect(result.unconfirmedRowId, ahead);
        expect(result.unconfirmedMutationKind, 'email_entity');
        expect(disp.dispatches, 0, reason: 'held back, not sent');
      });

      test('a save held behind it leaves the drain window rather than '
          'staying due', () async {
        // Left due, a held row came back in every `nextReady` snapshot — a
        // 50-row window — for as long as the unconfirmed change waited on the
        // user, and enough of them starved every row queued after them.
        await unconfirmedEmail();
        final save = await enqueue('c1', MutationKind.update);
        final disp = _ProgrammableDispatcher();
        final engine = engineFor(disp);

        await engine.drainOnce(companyId: 'co');

        final row = (await db.outboxDao.byId(save))!;
        expect(disp.dispatches, 0, reason: 'still held back');
        expect(row.state, 'pending');
        expect(row.attempts, 0, reason: 'waiting costs no retry budget');
        expect(
          await db.outboxDao.nextReady(companyId: 'co', now: 1000),
          isEmpty,
        );
      });

      test('Resend makes the saves held behind it due again', () async {
        // A held save is parked a minute at a time. Left parked, it sat out
        // that minute — and the next drain tick after it — once the change it
        // waited on was resent, instead of going in the same pass.
        final ahead = await unconfirmedEmail();
        final save = await enqueue('c1', MutationKind.update);
        final disp = _ProgrammableDispatcher()
          ..queueSuccess()
          ..queueSuccess();
        final engine = engineFor(disp);
        await engine.drainOnce(companyId: 'co');
        expect(disp.dispatches, 0, reason: 'precondition: held and parked');

        expect(await engine.resendUnconfirmed(ahead), isTrue);
        await engine.drainOnce(companyId: 'co');

        expect(disp.dispatches, 2, reason: 'the resent change, then the save');
        expect(await db.outboxDao.byId(save), isNull);
      });

      test('Discard sends the saves held behind it', () async {
        // Made due, they still waited for the next drain trigger — up to the
        // periodic tick — where Resend sends them in the same pass.
        final ahead = await unconfirmedEmail();
        final save = await enqueue('c1', MutationKind.update);
        final disp = _ProgrammableDispatcher()..queueSuccess();
        final engine = engineFor(disp);
        await engine.drainOnce(companyId: 'co');
        expect(disp.dispatches, 0, reason: 'precondition: held and parked');

        await engine.discardOutboxRow(ahead);
        // No explicit drain: the discard starts one.
        for (var i = 0; i < 50 && disp.dispatches == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(disp.dispatches, 1);
        expect(await db.outboxDao.byId(save), isNull);
      });

      test('…for the active company only: another company\'s drain can\'t '
          'send, and would surface its events here', () async {
        final ahead = await unconfirmedEmail();
        final disp = _ProgrammableDispatcher();
        final engine = engineFor(disp);
        // A drain of this company would fail this change — its record was
        // discarded before it synced — and say so, to a user looking at
        // another company.
        final orphan = await enqueue('tmp_orphan', MutationKind.update);
        engine.activeCompanyId = () => 'co_other';

        await engine.discardOutboxRow(ahead);
        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(events.whereType<DeadEvent>(), isEmpty);
        expect((await db.outboxDao.byId(orphan))?.state, 'pending');
      });

      test('awaitRow reports a row that went unconfirmed itself', () async {
        final id = await enqueue('tmp_c1', MutationKind.create);
        final engine = engineFor(sentThen(const NetworkException('reset')));
        final result = await engine.awaitRow(
          rowId: id,
          companyId: 'co',
          timeout: const Duration(seconds: 20),
        );
        expect(result.outcome, SyncRowOutcome.unconfirmed);
        expect(result.unconfirmedRowId, id);
        expect(
          (events.single as UnconfirmedEvent).handledByCaller,
          isTrue,
          reason: 'the waiting form surfaces it',
        );
      });

      test('Resend puts it back in line and sends it', () async {
        final id = await unconfirmedEmail();
        final disp = _ProgrammableDispatcher()..queueSuccess();
        final engine = engineFor(disp);

        expect(await engine.resendUnconfirmed(id), isTrue);
        await engine.drainOnce(companyId: 'co');

        expect(disp.dispatches, 1);
        expect(await db.outboxDao.byId(id), isNull);
      });

      test(
        'Check re-fetches the record — or, for a create, its list',
        () async {
          final fetched = <String>[];
          final engine = engineFor(_ProgrammableDispatcher());
          engine.refreshRecord = (companyId, type, id) async {
            fetched.add('record $id');
          };
          engine.refreshNewest = (companyId, type) async {
            fetched.add('list');
          };
          final email = await unconfirmedEmail();
          final create = await enqueue('tmp_c1', MutationKind.create);

          await engine.recheck((await db.outboxDao.byId(email))!);
          await engine.recheck((await db.outboxDao.byId(create))!);

          expect(fetched, ['record c1', 'list']);
        },
      );
    });
  });

  group('connectivity before an attempt', () {
    Future<bool?> offlineSeenByDispatch(
      Future<bool> Function()? isOnline,
    ) async {
      bool? seen;
      final engine = makeEngine(
        _CallbackDispatcher(
          (_) async => seen = RequestScope.current?.offlineBeforeSend,
        ),
      )..isOnline = isOnline;
      await enqueueClient(entityId: 'c1');
      await engine.drainOnce(companyId: 'co');
      return seen;
    }

    test('a "no connectivity" reading is carried into the dispatch — and the '
        'attempt still goes ahead', () async {
      expect(await offlineSeenByDispatch(() async => false), isTrue);
    });

    test('online, unwired, or a failing probe all count as online', () async {
      expect(await offlineSeenByDispatch(() async => true), isFalse);
      expect(await offlineSeenByDispatch(null), isFalse);
      expect(
        await offlineSeenByDispatch(() async => throw StateError('dbus')),
        isFalse,
      );
    });
  });

  group('a company switch mid-dispatch', () {
    test('the dispatch runs bound to the row\'s company', () async {
      final seen = <String?>[];
      final disp = _CallbackDispatcher(
        (_) async => seen.add(RequestScope.current?.companyId),
      );
      await enqueueClient(entityId: 'c1');
      await makeEngine(disp).drainOnce(companyId: 'co');
      expect(seen, ['co']);
    });

    test('caught before anything was sent: the row goes back for its own '
        'company, budget untouched', () async {
      final id = await enqueueClient(entityId: 'c1', attempts: 2);
      final disp = _ProgrammableDispatcher()
        ..queueThrow(
          const CompanySwitchedException(
            expected: 'co',
            active: 'other',
            entityType: 'an outbox request',
          ),
        );
      await makeEngine(disp).drainOnce(companyId: 'co');
      final row = await db.outboxDao.byId(id);
      expect(row?.state, 'pending');
      expect(row?.attempts, 2, reason: 'a switch is not a failed attempt');
      expect(row?.nextAttemptAt, lessThanOrEqualTo(1000), reason: 'due now');
    });

    test(
      'caught after a write committed: the row is done, never re-sent',
      () async {
        // e.g. a handler that POSTs, then reads the record back: the switch
        // stops the read, but the write already happened.
        final id = await enqueueClient(entityId: 'c1');
        final disp = _CallbackDispatcher((_) async {
          RequestScope.current!.markCommitted();
          throw const CompanySwitchedException(
            expected: 'co',
            active: 'other',
            entityType: 'an outbox request',
          );
        });
        await makeEngine(disp).drainOnce(companyId: 'co');
        expect(await db.outboxDao.byId(id), isNull);
      },
    );
  });

  group('success path', () {
    test('200-class result removes the outbox row', () async {
      final disp = _ProgrammableDispatcher()..queueSuccess();
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1');

      final success = await engine.drainOnce(companyId: 'co');
      expect(success, 1);
      final remaining = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(remaining, isEmpty);
    });
  });

  group('error transitions', () {
    test(
      '422 marks the row dead and emits ValidationFailedEvent with fields',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueThrow(
            const ValidationException('Validation failed', {
              'email': ['Must be unique'],
            }),
          );
        final engine = makeEngine(disp);
        final events = <SyncEvent>[];
        engine.events.listen(events.add);
        final id = await enqueueClient(entityId: 'c1');

        await engine.drainOnce(companyId: 'co');
        await Future<void>.delayed(Duration.zero); // flush broadcast

        final row = await rowById(id);
        // After dead, the row no longer comes back via nextReady() since
        // nextReady only returns pending. Read directly via the table.
        final all = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).get();
        expect(all.single.state, 'dead');
        expect(all.single.lastStatusCode, 422);
        expect(row, isNull, reason: 'dead rows are not pending');
        // The dead row also carries the structured field errors so the
        // edit form can replay them after restart; the bare last_error
        // alone isn't enough.
        expect(all.single.fieldErrorsJson, isNotNull);
        final persisted = jsonDecode(all.single.fieldErrorsJson!);
        expect(persisted, {
          'email': ['Must be unique'],
        });

        expect(events, hasLength(1));
        final v = events.single as ValidationFailedEvent;
        expect(v.fieldErrors['email'], ['Must be unique']);
      },
    );

    test('422 with no field map leaves fieldErrorsJson null — the bare message '
        'stays in last_error so we don\'t serialize an empty object', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ValidationException('Validation failed', {}));
      final engine = makeEngine(disp);
      final id = await enqueueClient(entityId: 'c2');
      await engine.drainOnce(companyId: 'co');
      final all = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).get();
      expect(all.single.state, 'dead');
      expect(all.single.fieldErrorsJson, isNull);
      expect(all.single.lastError, 'Validation failed');
    });

    test('409 leaves the row pending but parked far in the future so the '
        'engine does not auto-retry into the same conflict', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ConflictException('Stale'));
      final engine = makeEngine(disp, nowMs: 1000);
      final events = <SyncEvent>[];
      engine.events.listen(events.add);
      final id = await enqueueClient(entityId: 'c1');

      await engine.drainOnce(companyId: 'co');
      await Future<void>.delayed(Duration.zero);

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(row.state, 'pending');
      expect(row.lastStatusCode, 409);
      // The exact delay is an implementation detail; what we care about is
      // that auto-retry won't fire in any reasonable drain window.
      expect(
        row.nextAttemptAt - 1000,
        greaterThan(const Duration(days: 30).inMilliseconds),
        reason: 'auto-retry must not hit the same 409 over and over',
      );
      expect(events.single, isA<ConflictEvent>());
      expect((events.single as ConflictEvent).statusCode, 409);
      expect((events.single as ConflictEvent).isDeletedServerSide, isFalse);
    });

    test(
      'entity-missing parks the row + emits a deleted-server-side '
      'ConflictEvent carrying the row id, so the sheet offers discard-locally '
      '(NotFoundException is a ConflictException subtype — caught first)',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueThrow(const NotFoundException('not found'));
        final engine = makeEngine(disp, nowMs: 1000);
        final events = <SyncEvent>[];
        engine.events.listen(events.add);
        final id = await enqueueClient(entityId: 'c1');

        await engine.drainOnce(companyId: 'co');
        await Future<void>.delayed(Duration.zero);

        final row = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).getSingle();
        expect(row.state, 'pending');
        expect(
          row.lastStatusCode,
          400,
          reason:
              'the wire status Invoice Ninja actually sends for a missing '
              'entity (Handler.php renders ModelNotFoundException as 400) — '
              'recorded verbatim for the Outbox inspector',
        );
        expect(
          row.nextAttemptAt - 1000,
          greaterThan(const Duration(days: 30).inMilliseconds),
          reason:
              'parked — re-sending an update to a gone entity fails forever',
        );
        final event = events.single as ConflictEvent;
        expect(event.statusCode, 400);
        expect(
          event.isDeletedServerSide,
          isTrue,
          reason:
              'an explicit flag, not a magic status code: this drives a local '
              'hard-delete on discard, so a routing 404 must never reach it',
        );
        expect(event.outboxRowId, id);
        expect(
          event.wireEntityType,
          'client',
          reason:
              "the ROW's wire type — the listener's discardPendingForEntity "
              'exact-matches on it (handlers.wireName diverges for the user '
              "module, whose rows carry 'user' under a 'user_settings' slot)",
        );
      },
    );

    test('a bare 404 marks the row dead and emits NO ConflictEvent — on this '
        'server a 404 means we built a bad URL/verb, not that the entity '
        'vanished, and the deleted-server-side sheet hard-deletes the local row '
        'when the user discards (invoiceninja/flutter#36)', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(404, 'Route does not exist'));
      final engine = makeEngine(disp, nowMs: 1000);
      final events = <SyncEvent>[];
      engine.events.listen(events.add);
      final id = await enqueueClient(entityId: 'c1');

      await engine.drainOnce(companyId: 'co');
      await Future<void>.delayed(Duration.zero);

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(row.state, 'dead');
      expect(row.lastStatusCode, 404);
      expect(
        events.whereType<ConflictEvent>(),
        isEmpty,
        reason: 'no resolution sheet — nothing about the entity is wrong',
      );
      expect(events.whereType<DeadEvent>(), hasLength(1));
    });

    test('a record-deleted 400 marks the row dead carrying the server\'s own '
        'instruction, so the Outbox row and a reopened edit form can state the '
        'reason and drop the futile Retry', () async {
      const serverMessage =
          'Record is deleted and cannot be edited. Restore the record to '
          'enable editing';
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const RecordDeletedException(serverMessage));
      final engine = makeEngine(disp, nowMs: 1000);
      final events = <SyncEvent>[];
      engine.events.listen(events.add);
      final id = await enqueueClient(entityId: 'c1');

      await engine.drainOnce(companyId: 'co');
      await Future<void>.delayed(Duration.zero);

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(row.state, 'dead');
      expect(row.lastStatusCode, 400);
      expect(row.lastError, serverMessage);
      expect(
        isRecordDeletedRejection(row.lastStatusCode, row.lastError),
        isTrue,
        reason:
            'the persisted pair must re-classify — the exception object is '
            'gone by the time the Outbox screen renders',
      );
      expect(
        events.whereType<ConflictEvent>(),
        isEmpty,
        reason: 'the record exists, it just needs restoring — not a conflict',
      );
    });

    test(
      'PasswordRequired keeps row + emits event so UI prompts the user',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueThrow(const PasswordRequiredException());
        final engine = makeEngine(disp);
        final events = <SyncEvent>[];
        engine.events.listen(events.add);
        final id = await enqueueClient(
          entityId: 'c1',
          kind: MutationKind.delete,
        );

        await engine.drainOnce(companyId: 'co');
        await Future<void>.delayed(Duration.zero);

        final row = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).getSingle();
        expect(row.state, 'pending');
        // Fix B: the 412 handler upgrades the row (enqueued here with
        // requiresPassword=false) so the post-prompt retry attaches the
        // X-API-PASSWORD-BASE64 header.
        expect(row.requiresPassword, isTrue);
        expect(events.single, isA<PasswordRequiredEvent>());
        expect(
          row.attempts,
          1,
          reason:
              'the failure is COUNTED. It used to re-park with the same '
              'attempt count, so the row could never reach kMaxAttempts and '
              'every drain trigger re-opened the password sheet forever',
        );
      },
    );

    test(
      'repeated 412s back off, prompt only once, and finally mark the row dead',
      () async {
        // A user who cancels the sheet — or mistypes (the sheet does no
        // server-side validation, so a wrong password is cached and 412s
        // here) — must land in a terminal, visible state instead of being
        // re-prompted every few minutes forever.
        final disp = _ProgrammableDispatcher();
        for (var i = 0; i < kMaxAttempts; i++) {
          disp.queueThrow(const PasswordRequiredException());
        }
        final engine = makeEngine(disp);
        final events = <SyncEvent>[];
        engine.events.listen(events.add);
        final id = await enqueueClient(
          entityId: 'c1',
          kind: MutationKind.delete,
        );

        // Each pass re-arms the row the way the password sheet does, so the
        // loop mirrors a user repeatedly failing to unlock it.
        for (var i = 0; i < kMaxAttempts; i++) {
          await engine.retryPasswordRows(companyId: 'co');
          await Future<void>.delayed(Duration.zero);
        }

        final dead = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).getSingle();
        expect(
          dead.state,
          'dead',
          reason: 'the row reaches a terminal state the Outbox screen shows',
        );
        expect(dead.lastStatusCode, 412);
        expect(
          events.whereType<PasswordRequiredEvent>(),
          hasLength(1),
          reason: 'the sheet is offered once, not on every retry',
        );
        expect(events.whereType<DeadEvent>(), hasLength(1));
      },
    );

    test(
      'a later password resurrects a dead 412 row (and only a 412 one)',
      () async {
        // Without this, marking the row dead would swap an infinite nag for a
        // silently stuck edit: `readyPasswordRows` only ever re-armed
        // `pending` rows, so a password supplied afterwards could not heal it.
        final disp = _ProgrammableDispatcher();
        for (var i = 0; i < kMaxAttempts; i++) {
          disp.queueThrow(const PasswordRequiredException());
        }
        disp.queueSuccess();
        final engine = makeEngine(disp);
        final gated = await enqueueClient(
          entityId: 'c1',
          kind: MutationKind.delete,
        );
        for (var i = 0; i < kMaxAttempts; i++) {
          await engine.retryPasswordRows(companyId: 'co');
          await Future<void>.delayed(Duration.zero);
        }
        expect(
          (await (db.select(
            db.outbox,
          )..where((o) => o.id.equals(gated))).getSingle()).state,
          'dead',
        );

        // An unrelated dead row must NOT be swept back in by the same call.
        final unrelated = await enqueueClient(entityId: 'c2');
        await db.outboxDao.markDead(
          id: unrelated,
          error: 'Validation failed',
          statusCode: 422,
        );

        await engine.retryPasswordRows(companyId: 'co');
        await Future<void>.delayed(Duration.zero);

        expect(
          await rowById(gated),
          isNull,
          reason: 'resurrected with a fresh budget, then drained to success',
        );
        expect(
          (await (db.select(
            db.outbox,
          )..where((o) => o.id.equals(unrelated))).getSingle()).state,
          'dead',
          reason: 'a 422 death is not a password problem — it stays dead',
        );
      },
    );

    test(
      'PasswordRequired upgrade + re-arm lets the retry drain to success',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueThrow(const PasswordRequiredException())
          ..queueSuccess();
        final engine = makeEngine(disp);
        final id = await enqueueClient(
          entityId: 'c1',
          kind: MutationKind.delete,
        );

        await engine.drainOnce(companyId: 'co');
        await Future<void>.delayed(Duration.zero);
        final parked = await rowById(id);
        expect(parked, isNotNull);
        expect(parked!.requiresPassword, isTrue);
        expect(parked.state, 'pending');

        // Simulate the password sheet: the cache is now warm, so re-arming the
        // parked row + draining attaches the header and the row drains.
        await engine.retryPasswordRows(companyId: 'co');
        await Future<void>.delayed(Duration.zero);

        expect(await rowById(id), isNull);
      },
    );

    test(
      '429 with Retry-After honors the delay before the next attempt',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueThrow(
            const RateLimitedException(retryAfter: Duration(seconds: 12)),
          );
        final engine = makeEngine(disp, nowMs: 1000);
        final id = await enqueueClient(entityId: 'c1');

        await engine.drainOnce(companyId: 'co');

        final row = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).getSingle();
        expect(
          row.nextAttemptAt,
          1000 + 12000,
          reason: 'Retry-After dictates the wakeup time',
        );
      },
    );

    test('5xx walks the backoff schedule by attempt count', () async {
      // First failure (attempts: 0 → 1) waits schedule[0] = 5s, per the
      // file header's documented contract.
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(500, 'Boom'));
      final engine = makeEngine(disp, nowMs: 1000);
      final id = await enqueueClient(entityId: 'c1', attempts: 0);

      await engine.drainOnce(companyId: 'co');
      final row1 = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(
        row1.nextAttemptAt - 1000,
        kBackoffSchedule[0].inMilliseconds,
        reason: 'attempts 0 → next 1 → schedule[0] = 5s',
      );
    });

    test('exceeding max attempts marks the row dead', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(500, 'Boom'));
      final engine = makeEngine(disp);
      final id = await enqueueClient(
        entityId: 'c1',
        attempts: kMaxAttempts - 1,
      );

      await engine.drainOnce(companyId: 'co');

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(row.state, 'dead');
    });
  });

  group('FIFO + safety', () {
    test('rows past their next_attempt_at are picked up in id order', () async {
      // Two pending rows; the engine should dispatch in insert order.
      final disp = _ProgrammableDispatcher()
        ..queueSuccess()
        ..queueSuccess();
      final engine = makeEngine(disp, nowMs: 1000);
      await enqueueClient(entityId: 'first');
      await enqueueClient(entityId: 'second');

      await engine.drainOnce(companyId: 'co');
      expect(disp.dispatches, 2);
    });

    test('a document upload that fails holds back no later save of its '
        'record in the same pass', () async {
      // The in-pass latch is the SQL ordering guard's twin, and the guard
      // lets an upload hold nothing back — it writes no field of the record.
      // Two gates disagreeing about the same question is the shape the drain
      // warns against.
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(503, 'Maintenance'))
        ..queueSuccess();
      final engine = makeEngine(disp);
      await enqueueClient(
        entityId: 'c1',
        kind: MutationKind.documentUpload,
        idempotencyKey: 'k-upload',
      );
      final save = await enqueueClient(
        entityId: 'c1',
        idempotencyKey: 'k-save',
      );

      await engine.drainOnce(companyId: 'co');

      expect(disp.dispatches, 2);
      expect(await db.outboxDao.byId(save), isNull, reason: 'sent');
    });

    test(
      'unknown mutation_kind is marked dead, not silently retried forever',
      () async {
        final disp = _ProgrammableDispatcher();
        final engine = makeEngine(disp);
        final id = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
            mutationKind: 'action:future_thing', // unknown in M1
            payload: '{}',
            idempotencyKey: 'k',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        await engine.drainOnce(companyId: 'co');

        final row = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).getSingle();
        expect(row.state, 'dead');
        expect(
          disp.dispatches,
          0,
          reason: 'unknown kinds never reach the dispatcher',
        );
      },
    );

    test(
      'missing registry entry is marked dead, not silently retried forever',
      () async {
        final disp = _ProgrammableDispatcher();
        final engine = makeEngine(disp);
        final id = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'invoice', // not registered in this test
            entityId: 'i1',
            mutationKind: MutationKind.update.wireName,
            payload: '{}',
            idempotencyKey: 'k',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        await engine.drainOnce(companyId: 'co');

        final row = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).getSingle();
        expect(row.state, 'dead');
      },
    );
  });

  group('tmp_ dependency guard', () {
    // Ids minted by mintTempId() are tmp_<uuid-v4>; the guard matches that
    // exact shape.
    const tmpA = 'tmp_00000000-0000-4000-8000-00000000000a';
    const tmpB = 'tmp_00000000-0000-4000-8000-00000000000b';

    test('an update aimed at a tmp_ id whose create failed is skipped, '
        'not dispatched with the unresolved id', () async {
      final dispatcher = _ProgrammableDispatcher();
      final engine = makeEngine(dispatcher);
      // The create fails server-side (5xx → backoff, stays pending) …
      await enqueueClient(
        entityId: tmpA,
        kind: MutationKind.create,
        idempotencyKey: 'k1',
      );
      dispatcher.queueThrow(ServerException(500, 'boom'));
      // … so the queued follow-up edit still carries the tmp_ id.
      final updateId = await enqueueClient(
        entityId: tmpA,
        idempotencyKey: 'k2',
      );

      await engine.drainOnce(companyId: 'co');

      expect(
        dispatcher.dispatches,
        1,
        reason:
            'only the create may be attempted; dispatching the update '
            'would PUT /clients/tmp_… → 404 → bogus year-long conflict',
      );
      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(updateId))).getSingle();
      expect(row.state, 'pending');
      expect(row.attempts, 0, reason: 'a skip is not a failed attempt');
    });

    test('an update referencing a tmp_ id with NO create row anywhere is '
        'marked dead — its parent create was discarded, so the reference can '
        'never heal and deferring would zombie it forever', () async {
      final dispatcher = _ProgrammableDispatcher();
      final engine = makeEngine(dispatcher);
      // No create row for tmpA exists in ANY state (ghost-discarded before
      // this drain) and no id_remap mapping (the create never succeeded).
      final updateId = await enqueueClient(
        entityId: tmpA,
        idempotencyKey: 'k9',
      );

      await engine.drainOnce(companyId: 'co');

      expect(dispatcher.dispatches, 0);
      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(updateId))).getSingle();
      expect(row.state, 'dead');
      expect(row.lastError, contains('discarded'));
    });

    test(
      'a create referencing another entity\'s unresolved tmp_ id is skipped, '
      'while a create carrying only its own tmp_ id dispatches',
      () async {
        final dispatcher = _ProgrammableDispatcher();
        final engine = makeEngine(dispatcher);
        // Cross-entity ref: e.g. an invoice created offline against an
        // offline-created client. (Modeled as a client row here — the guard
        // only inspects the payload.)
        final crossRefId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: tmpB,
            mutationKind: MutationKind.create.wireName,
            payload: jsonEncode({'id': tmpB, 'client_id': tmpA}),
            idempotencyKey: 'k3',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        // Own-id-only create: must NOT be blocked by its own tmp_ id.
        await enqueueClient(
          entityId: tmpA,
          kind: MutationKind.create,
          idempotencyKey: 'k4',
        );
        dispatcher.queueSuccess();

        await engine.drainOnce(companyId: 'co');

        expect(
          dispatcher.dispatches,
          1,
          reason: 'the own-id create dispatches; the cross-ref create waits',
        );
        expect(dispatcher.lastRow?.entityId, tmpA);
        final crossRef = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(crossRefId))).getSingle();
        expect(crossRef.state, 'pending');
        expect(crossRef.attempts, 0);
      },
    );

    test('rewriteTempIdInPayloads heals dead rows too, so Retry can succeed '
        'after the parent create finally lands', () async {
      final deadId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'real_1',
          mutationKind: MutationKind.update.wireName,
          payload: jsonEncode({'id': 'real_1', 'client_id': tmpA}),
          idempotencyKey: 'k5',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      await db.outboxDao.markDead(id: deadId, error: '422', statusCode: 422);

      await db.outboxDao.rewriteTempIdInPayloads(
        companyId: 'co',
        entityType: 'client',
        tempId: tmpA,
        realId: 'real_A',
      );

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(deadId))).getSingle();
      expect(row.payload, contains('real_A'));
      expect(row.payload, isNot(contains(tmpA)));
    });

    test(
      'rewriteTempIdInPayloads re-arms a deferred PENDING dependent '
      '(nextAttemptAt→0, error cleared) but leaves DEAD rows scheduled as-is',
      () async {
        // A pending dependent the drain deferred +60s with an error set.
        final pendingId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'real_p',
            mutationKind: MutationKind.update.wireName,
            payload: jsonEncode({'id': 'real_p', 'client_id': tmpA}),
            idempotencyKey: 'kp',
            nextAttemptAt: 999999,
            createdAt: 0,
            attempts: const Value(2),
            lastError: const Value('waiting'),
          ),
        );
        final deadId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'real_d',
            mutationKind: MutationKind.update.wireName,
            payload: jsonEncode({'id': 'real_d', 'client_id': tmpA}),
            idempotencyKey: 'kd',
            nextAttemptAt: 888888,
            createdAt: 0,
          ),
        );
        await db.outboxDao.markDead(id: deadId, error: '422', statusCode: 422);

        await db.outboxDao.rewriteTempIdInPayloads(
          companyId: 'co',
          entityType: 'client',
          tempId: tmpA,
          realId: 'real_A',
        );

        final pending = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(pendingId))).getSingle();
        expect(pending.payload, contains('real_A'));
        expect(pending.nextAttemptAt, 0, reason: 'healed → immediately due');
        expect(pending.lastError, isNull);
        expect(pending.attempts, 2, reason: 'retry budget preserved');

        final dead = await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(deadId))).getSingle();
        expect(dead.payload, contains('real_A'), reason: 'payload still heals');
        expect(dead.state, 'dead', reason: 'dead stays dead');
        expect(
          dead.nextAttemptAt,
          888888,
          reason: 'dead row scheduling untouched',
        );
      },
    );

    test(
      'a tmp_ ref whose entity ALREADY synced (id_remap recorded, no pending '
      'create) is healed from id_remap and dispatched, not deferred forever',
      () async {
        // The "parent synced before dependent enqueued" ordering: an inline-
        // created tag whose tiny create round-tripped and was DELETED while
        // the user was still filling the task form, so rewriteTempIdInPayloads
        // (create-success-time only) never touched the task row that didn't
        // exist yet. The id_remap entry survives the deleted outbox row.
        final dispatcher = _ProgrammableDispatcher()..queueSuccess();
        final engine = makeEngine(dispatcher);
        await db.idRemapDao.remember(
          entityType: 'tag',
          tempId: tmpA,
          realId: 'real_A',
          now: 0,
        );
        // The task save carries the now-dead tmp tag id in its tags array.
        final depId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'real_task',
            mutationKind: MutationKind.update.wireName,
            payload: jsonEncode({
              'id': 'real_task',
              'tags': [tmpA],
            }),
            idempotencyKey: 'kheal',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        await engine.drainOnce(companyId: 'co');

        expect(
          dispatcher.dispatches,
          1,
          reason:
              'the dependent heals from id_remap and dispatches, '
              'instead of deferring +60s forever',
        );
        expect(dispatcher.lastRow?.payload, contains('real_A'));
        expect(dispatcher.lastRow?.payload, isNot(contains('tmp_')));
        expect(
          await db.outboxDao.pendingCountForCompany('co'),
          0,
          reason:
              'healed + dispatched → row deleted → pending settles to 0, '
              'so logout/switch "Sync first" can complete',
        );
        // depId is consumed by the successful dispatch.
        expect(await db.outboxDao.byId(depId), isNull);
      },
    );

    test('a failed tmp_ create (422) marks its dependents dead too, so they '
        'stop deferring forever and pendingCountFor can reach zero', () async {
      final events = <SyncEvent>[];
      final dispatcher = _ProgrammableDispatcher();
      final engine = makeEngine(dispatcher);
      engine.events.listen(events.add);
      // Parent create fails validation.
      await enqueueClient(
        entityId: tmpA,
        kind: MutationKind.create,
        idempotencyKey: 'kc',
      );
      dispatcher.queueThrow(const ValidationException('bad', {}));
      // Dependent create referencing the parent's tmp id.
      final depId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: tmpB,
          mutationKind: MutationKind.create.wireName,
          payload: jsonEncode({'id': tmpB, 'client_id': tmpA}),
          idempotencyKey: 'kdep',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );

      await engine.drainOnce(companyId: 'co');

      final dep = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(depId))).getSingle();
      expect(
        dep.state,
        'dead',
        reason:
            'dependent of a dead tmp_ create is marked dead, not '
            'deferred forever',
      );
      expect(await db.outboxDao.pendingCountForCompany('co'), 0);
      expect(
        events.whereType<DeadEvent>().any((e) => e.entityId == tmpB),
        isTrue,
        reason: 'the cascade-killed dependent surfaces a DeadEvent',
      );
    });
  });

  group('auto-drain on enqueue', () {
    test(
      'BaseEntityRepository.enqueueMutation invokes onEnqueued so the row drains '
      'without an explicit drainOnce call',
      () async {
        final disp = _ProgrammableDispatcher()..queueSuccess();
        // Share a clock between the repo and the engine — without this, the
        // repo stamps `nextAttemptAt` from real wall-clock time and the
        // engine's `nextReady` (using its own injected 1000ms clock) filters
        // the row out as "not ready yet".
        DateTime fakeNow() => DateTime.fromMillisecondsSinceEpoch(1000);
        final engine = SyncRepository(
          db: db,
          registry: _registryWith(disp),
          now: fakeNow,
        );
        final repo = _TestRepo(
          db: db,
          now: fakeNow,
          onEnqueued: (companyId) {
            engine.drainOnce(companyId: companyId);
          },
        );

        await repo.enqueueMutation(
          companyId: 'co',
          entityId: 'c1',
          kind: MutationKind.update,
          payload: const {'id': 'c1'},
        );
        // The auto-drain is fire-and-forget; pump microtasks until the
        // dispatcher has been hit.
        for (var i = 0; i < 10 && disp.dispatches == 0; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(disp.dispatches, 1);
        final remaining = await db.outboxDao.nextReady(
          companyId: 'co',
          now: 1 << 60,
        );
        expect(
          remaining,
          isEmpty,
          reason: 'auto-drain should have removed the row',
        );
      },
    );
  });

  group('single-flight', () {
    test('concurrent drainOnce calls for the same company coalesce — each row '
        'is dispatched exactly once', () async {
      // Gate the first dispatch so both drainOnce calls overlap.
      final firstGate = Completer<void>();
      final disp = _GatedDispatcher(firstBlocker: firstGate.future);
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await enqueueClient(entityId: 'c2', idempotencyKey: 'k2');

      final first = engine.drainOnce(companyId: 'co');
      // Let the drain reach the gated first dispatch.
      await Future<void>.delayed(Duration.zero);
      final second = engine.drainOnce(companyId: 'co');
      expect(
        identical(first, second),
        isTrue,
        reason: 'second concurrent call must return the in-flight future',
      );

      firstGate.complete();
      await Future.wait([first, second]);

      expect(
        disp.dispatches,
        2,
        reason: 'two rows → two dispatches total, not four',
      );
    });

    test(
      'a fresh drainOnce after the previous one settles starts a new pass',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueSuccess()
          ..queueSuccess();
        final engine = makeEngine(disp);
        await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
        await engine.drainOnce(companyId: 'co');
        await enqueueClient(entityId: 'c2', idempotencyKey: 'k2');
        await engine.drainOnce(companyId: 'co');

        expect(disp.dispatches, 2);
      },
    );

    test(
      'drainOnce for different companies run in parallel, not serialised',
      () async {
        final firstGate = Completer<void>();
        final disp = _GatedDispatcher(firstBlocker: firstGate.future);
        final engine = makeEngine(disp);
        // co-A row gates the dispatch; co-B should still drain to completion.
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co-A',
            entityType: 'client',
            entityId: 'a1',
            mutationKind: 'update',
            payload: '{}',
            idempotencyKey: 'ka',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co-B',
            entityType: 'client',
            entityId: 'b1',
            mutationKind: 'update',
            payload: '{}',
            idempotencyKey: 'kb',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        final drainA = engine.drainOnce(companyId: 'co-A');
        final drainB = engine.drainOnce(companyId: 'co-B');
        // B should finish on its own — it's gated by nothing.
        await drainB;
        // A is still parked on the gate; release and finish.
        firstGate.complete();
        await drainA;

        expect(disp.dispatches, 2);
      },
    );
  });

  group('cancel', () {
    test('stops the drain between rows', () async {
      // First dispatch blocks until we release it; later dispatches return
      // immediately. With cancel firing during the block, the second outbox
      // row must never reach the dispatcher.
      final firstDispatchGate = Completer<void>();
      final disp = _GatedDispatcher(firstBlocker: firstDispatchGate.future);
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await enqueueClient(entityId: 'c2', idempotencyKey: 'k2');

      final drainFuture = engine.drainOnce(companyId: 'co');
      // Let the drain reach the first dispatch and park there.
      await Future<void>.delayed(Duration.zero);
      expect(disp.dispatches, 1, reason: 'first row should be in-flight');

      final cancelFuture = engine.cancel();
      firstDispatchGate.complete(); // release the in-flight request

      await cancelFuture;
      final success = await drainFuture;

      expect(disp.dispatches, 1, reason: 'second row was skipped after cancel');
      expect(success, 1, reason: 'first row still counted as a success');
      // The skipped row is still pending and will be picked up next drain.
      final remaining = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(remaining.map((r) => r.idempotencyKey), contains('k2'));
    });

    test('returns immediately when no drain is in flight', () async {
      final engine = makeEngine(_ProgrammableDispatcher());
      // Should not hang.
      await engine.cancel().timeout(const Duration(seconds: 1));
    });

    test(
      'cancel latches: drainOnce is a no-op until resume(), then drains',
      () async {
        final disp = _ProgrammableDispatcher()
          ..queueSuccess()
          ..queueSuccess();
        final engine = makeEngine(disp);
        await engine.cancel(); // latches while idle
        await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
        await enqueueClient(entityId: 'c2', idempotencyKey: 'k2');

        expect(
          await engine.drainOnce(companyId: 'co'),
          0,
          reason:
              'a cancelled engine must not start a pass — logout relies on '
              'cancel() meaning "no drain runs" right through the Drift wipe',
        );

        // Company activation (login / restore / switch) releases the latch.
        engine.resume();

        expect(
          await engine.drainOnce(companyId: 'co'),
          2,
          reason: 'resume() re-enables draining and both rows go out',
        );
      },
    );
  });

  group('discard', () {
    Future<OutboxRow?> rawRow(int id) =>
        (db.select(db.outbox)..where((o) => o.id.equals(id))).getSingleOrNull();

    group('discardDeletesUnsyncedRecord — what a form asks before', () {
      const tmp = 'tmp_00000000-0000-4000-8000-0000000000f2';

      Future<OutboxRow> createIn(String state, {String entityId = tmp}) async {
        final id = await enqueueClient(
          entityId: entityId,
          kind: MutationKind.create,
          idempotencyKey: 'k-$state-$entityId',
        );
        switch (state) {
          case 'dead':
            await db.outboxDao.markDead(id: id, error: 'bad', statusCode: 422);
          case 'unconfirmed':
            await db.outboxDao.markUnconfirmed(id: id, error: 'timed out');
        }
        return (await rawRow(id))!;
      }

      test(
        'the failed or queued create of a record the server never saw',
        () async {
          final engine = makeEngine(_ProgrammableDispatcher());
          expect(
            await engine.discardDeletesUnsyncedRecord(await createIn('dead')),
            isTrue,
          );
        },
      );

      test('not one that may already have reached the server — what was made '
          'for it is kept, and "never saved" would be untrue', () async {
        final engine = makeEngine(_ProgrammableDispatcher());
        expect(
          await engine.discardDeletesUnsyncedRecord(
            await createIn('unconfirmed'),
          ),
          isFalse,
        );
      });

      test('not while another attempt at it is on the wire — the discard then '
          'drops the one row', () async {
        final engine = makeEngine(_ProgrammableDispatcher());
        final onTheWire = await enqueueClient(
          entityId: tmp,
          kind: MutationKind.create,
          idempotencyKey: 'k-wire',
        );
        await db.outboxDao.markInFlight(onTheWire);
        expect(
          await engine.discardDeletesUnsyncedRecord(await createIn('dead')),
          isFalse,
        );
      });

      test('not an edit, nor a create of a record that exists', () async {
        final engine = makeEngine(_ProgrammableDispatcher());
        final edit = await enqueueClient(entityId: tmp, idempotencyKey: 'k-e');
        expect(
          await engine.discardDeletesUnsyncedRecord((await rawRow(edit))!),
          isFalse,
        );
        expect(
          await engine.discardDeletesUnsyncedRecord(
            await createIn('dead', entityId: 'c_real'),
          ),
          isFalse,
        );
      });
    });

    /// A never-synced client's create, and an edit of another record that
    /// refers to it — which the discard fails.
    Future<({int parent, int dependent})> parentAndDependent() async {
      const tmp = 'tmp_00000000-0000-4000-8000-0000000000f1';
      final parent = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'kp',
      );
      final dependent = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c_real',
          mutationKind: MutationKind.update.wireName,
          payload: jsonEncode({'id': 'c_real', 'parent_id': tmp}),
          idempotencyKey: 'kd',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      return (parent: parent, dependent: dependent);
    }

    test('discarding a change of another company fails what depends on it '
        'without a word here — its Outbox shows them, and this one\'s View '
        'would open the wrong queue', () async {
      final events = <SyncEvent>[];
      final engine = makeEngine(_ProgrammableDispatcher())
        ..activeCompanyId = (() => 'co_active');
      engine.events.listen(events.add);
      final (:parent, :dependent) = await parentAndDependent();

      await engine.discardOutboxRow(parent);
      await Future<void>.delayed(Duration.zero);

      expect((await rawRow(dependent))?.state, 'dead');
      expect(events.whereType<DeadEvent>(), isEmpty);
    });

    test('…while in the active company\'s own Outbox it is said', () async {
      final events = <SyncEvent>[];
      final engine = makeEngine(_ProgrammableDispatcher())
        ..activeCompanyId = (() => 'co');
      engine.events.listen(events.add);
      final (:parent, :dependent) = await parentAndDependent();

      await engine.discardOutboxRow(parent);
      await Future<void>.delayed(Duration.zero);

      expect((await rawRow(dependent))?.state, 'dead');
      expect(events.whereType<DeadEvent>(), hasLength(1));
    });

    SyncRepository engineWith(_TestRepo repo) => SyncRepository(
      db: db,
      registry: _registryWith(_RepoDeleteDispatcher(repo)),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    test('discardOutboxRow on a never-synced ghost create deletes the local '
        'record AND every outbox row for that tmp entity', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final createId = await enqueueClient(
        entityId: 'tmp_g',
        kind: MutationKind.create,
      );
      // A queued follow-up edit against the same tmp entity.
      final updateId = await enqueueClient(
        entityId: 'tmp_g',
        idempotencyKey: 'k2',
      );

      final removed = await engine.discardOutboxRow(createId);

      expect(removed, isTrue);
      expect(repo.localDeletes, [('co', 'tmp_g')]);
      expect(await rawRow(createId), isNull);
      expect(
        await rawRow(updateId),
        isNull,
        reason: 'follow-up rows for the gone entity go too',
      );
    });

    test('discardFailedSave drops the failed save the discarded one '
        'replaced, first — so the record is released', () async {
      // The form opened on dead D; the re-save queued P, which failed again.
      // Discarding P alone left D holding the record's dirty flag: it went on
      // showing the discarded content, shielded from refresh.
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final dead = await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await db.outboxDao.markDead(id: dead, error: 'bad', statusCode: 422);
      final retry = await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');

      expect(await engine.discardFailedSave(retry), isFalse);

      expect(await rawRow(dead), isNull);
      expect(await rawRow(retry), isNull);
      expect(repo.dirtyCleared, [('co', 'c1')]);
    });

    test(
      'discardFailedSave keeps the failed create of a record the server has '
      'never seen when a later edit is discarded — it is the record',
      () async {
        final repo = _TestRepo(db: db);
        final engine = engineWith(repo);
        const tmp = 'tmp_00000000-0000-4000-8000-0000000000f1';
        final create = await enqueueClient(
          entityId: tmp,
          kind: MutationKind.create,
          idempotencyKey: 'k1',
        );
        await db.outboxDao.markDead(id: create, error: 'bad', statusCode: 422);
        final edit = await enqueueClient(entityId: tmp, idempotencyKey: 'k2');

        await engine.discardFailedSave(edit);

        expect(await rawRow(create), isNotNull);
        expect(repo.localDeletes, isEmpty);
      },
    );

    test(
      'discardFailedSave leaves a failed email on the same record',
      () async {
        final repo = _TestRepo(db: db);
        final engine = engineWith(repo);
        final email = await enqueueClient(
          entityId: 'c1',
          kind: MutationKind.emailEntity,
          idempotencyKey: 'k1',
        );
        await db.outboxDao.markDead(id: email, error: 'bad', statusCode: 422);
        final save = await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');

        await engine.discardFailedSave(save);

        expect(await rawRow(email), isNotNull);
      },
    );

    test('discardFailedSave on a never-synced create still takes the record '
        'and every row, as a ghost discard does', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final create = await enqueueClient(
        entityId: 'tmp_g',
        kind: MutationKind.create,
        idempotencyKey: 'k1',
      );

      expect(await engine.discardFailedSave(create), isTrue);
      expect(repo.localDeletes, [('co', 'tmp_g')]);
    });

    test('a ghost create is not deleted while another attempt at it is on '
        'the wire — only the discarded row goes', () async {
      // Two creates of one never-synced record: a re-save queued while the
      // first was in flight. Deleting the record and every row for it left
      // the in-flight request landing with nothing behind it — and what had
      // been made against the record was already gone.
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      const tmp = 'tmp_00000000-0000-4000-8000-0000000000d2';
      final inFlight = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'k1',
      );
      await db.outboxDao.markInFlight(inFlight);
      final second = await enqueueClient(
        entityId: tmp,
        kind: MutationKind.create,
        idempotencyKey: 'k2',
      );
      final dependent = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'tmp_00000000-0000-4000-8000-0000000000d3',
          mutationKind: 'create',
          payload: jsonEncode({'parent': tmp}),
          idempotencyKey: 'k3',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );

      final removed = await engine.discardOutboxRow(second);

      expect(removed, isFalse, reason: 'the record stays');
      expect(await rawRow(second), isNull);
      expect(await rawRow(inFlight), isNotNull);
      expect(await rawRow(dependent), isNotNull);
      expect(repo.localDeletes, isEmpty);
    });

    test('a ghost create whose local delete throws still drops its outbox '
        'rows — a stranded row surfaces as a tile that never goes away '
        '(invoiceninja/flutter#44)', () async {
      final repo = _TestRepo(db: db)..throwOnLocalDelete = true;
      final engine = engineWith(repo);
      final createId = await enqueueClient(
        entityId: 'tmp_g',
        kind: MutationKind.create,
      );

      final removed = await engine.discardOutboxRow(createId);

      expect(await rawRow(createId), isNull, reason: 'the discard still lands');
      expect(repo.localDeletes, [('co', 'tmp_g')], reason: 'it was attempted');
      expect(
        removed,
        isFalse,
        reason:
            'false means the local record survived — a caller showing it '
            'must NOT navigate away',
      );
    });

    test('a ghost dependent whose local delete throws cannot reject a discard '
        'that already succeeded', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final parentId = await enqueueClient(
        entityId: 'tmp_parent',
        kind: MutationKind.create,
      );
      // A second ghost create whose payload references the parent — the
      // cascade in `_failTmpDependents` hard-deletes this one too, and that
      // runs AFTER the parent's own outbox rows are gone.
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'tmp_child',
          mutationKind: 'create',
          payload: jsonEncode({'id': 'tmp_child', 'parent': 'tmp_parent'}),
          idempotencyKey: 'k-child',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      // Throw only once the cascade reaches the child.
      repo.throwOnLocalDeleteOf = 'tmp_child';

      final removed = await engine.discardOutboxRow(parentId);

      expect(
        repo.localDeletes,
        [('co', 'tmp_parent'), ('co', 'tmp_child')],
        reason: 'the cascade really did reach the throwing child',
      );
      expect(removed, isTrue, reason: 'the parent record went');
      expect(await rawRow(parentId), isNull);
      expect(
        await (db.select(
          db.outbox,
        )..where((o) => o.entityId.equals('tmp_child'))).get(),
        isEmpty,
        reason: "the child's rows go too, throw or no throw",
      );
    });

    test('discarding an unconfirmed create keeps the offline work that '
        'references it — the record may already exist on the server', () async {
      // It cascaded like a never-sent ghost: every offline dependent (an
      // invoice made for this client) was hard-deleted along with its rows.
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final parentId = await enqueueClient(
        entityId: 'tmp_parent',
        kind: MutationKind.create,
      );
      await db.outboxDao.markUnconfirmed(id: parentId, error: 'reset');
      final childId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'tmp_child',
          mutationKind: 'create',
          payload: jsonEncode({'id': 'tmp_child', 'parent': 'tmp_parent'}),
          idempotencyKey: 'k-child',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );

      final removed = await engine.discardOutboxRow(parentId);

      expect(removed, isTrue, reason: 'the discarded record itself goes');
      expect(await rawRow(parentId), isNull);
      expect(repo.localDeletes, [('co', 'tmp_parent')]);
      final child = await rawRow(childId);
      expect(child?.state, 'dead', reason: 'kept, for the user to re-point');
      expect(child?.lastError, contains('may already exist on the server'));
    });

    test('discardOutboxRow on an in_flight ghost create only drops the '
        'outbox row — the network attempt may still be landing', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final id = await enqueueClient(
        entityId: 'tmp_g',
        kind: MutationKind.create,
      );
      await db.outboxDao.markInFlight(id);

      final removed = await engine.discardOutboxRow(id);

      expect(removed, isFalse);
      expect(repo.localDeletes, isEmpty, reason: 'no TOCTOU ghost delete');
      expect(await rawRow(id), isNull);
      expect(
        repo.dirtyCleared,
        isEmpty,
        reason: 'an in_flight create keeps its flag — its request may land',
      );
    });

    test(
      'discardOutboxRow on an in_flight UPDATE reconciles is_dirty so a '
      'later failed attempt does not orphan the abandoned edit (#28)',
      () async {
        final repo = _TestRepo(db: db);
        final engine = engineWith(repo);
        final id = await enqueueClient(entityId: 'c1'); // update, real id
        await db.outboxDao.markInFlight(id);

        await engine.discardOutboxRow(id);

        expect(repo.dirtyCleared, [('co', 'c1')]);
      },
    );

    test('discardOutboxRow on a failed update of a real entity keeps the '
        'local record — discarding must not nuke a server-known row', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final id = await enqueueClient(entityId: 'c1'); // update, real id
      await db.outboxDao.markDead(id: id, error: 'boom', statusCode: 422);

      final removed = await engine.discardOutboxRow(id);

      expect(removed, isFalse);
      expect(repo.localDeletes, isEmpty);
      expect(await rawRow(id), isNull);
    });

    test('discardOutboxRow on a create whose id_remap exists (already '
        'synced) keeps the local record', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final id = await enqueueClient(
        entityId: 'tmp_s',
        kind: MutationKind.create,
      );
      await db.idRemapDao.remember(
        entityType: 'client',
        tempId: 'tmp_s',
        realId: 'real_s',
        now: 0,
      );

      final removed = await engine.discardOutboxRow(id);

      expect(removed, isFalse);
      expect(repo.localDeletes, isEmpty);
      expect(await rawRow(id), isNull);
    });

    test('discardPendingFor cleans a ghost create, drops a real pending '
        'update, and leaves dead rows untouched', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final ghostId = await enqueueClient(
        entityId: 'tmp_g',
        kind: MutationKind.create,
      );
      final realUpdateId = await enqueueClient(
        entityId: 'c1',
        idempotencyKey: 'k2',
      );
      final deadId = await enqueueClient(entityId: 'c2', idempotencyKey: 'k3');
      await db.outboxDao.markDead(id: deadId, error: 'x', statusCode: 422);

      await engine.discardPendingFor('co');

      expect(repo.localDeletes, [('co', 'tmp_g')]);
      expect(await rawRow(ghostId), isNull);
      expect(await rawRow(realUpdateId), isNull);
      final dead = await rawRow(deadId);
      expect(
        dead?.state,
        'dead',
        reason: 'dead rows are not "pending" — discardPendingFor skips them',
      );
    });

    test(
      'discarding a ghost create cascades through a 3-level offline '
      'subtree: ghost dependents deleted, non-ghost dependents marked dead',
      () async {
        final repo = _TestRepo(db: db);
        final events = <SyncEvent>[];
        final engine = engineWith(repo);
        engine.events.listen(events.add);
        // client tmp_A (ghost) ← invoice tmp_B (ghost, refs A) ← payment tmp_C
        // (ghost, refs B); plus a non-ghost update to real client c9 that also
        // references tmp_A.
        final clientId = await enqueueClient(
          entityId: 'tmp_A',
          kind: MutationKind.create,
        );
        final invoiceId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client', // entity type is irrelevant to the guard
            entityId: 'tmp_B',
            mutationKind: MutationKind.create.wireName,
            payload: jsonEncode({'id': 'tmp_B', 'client_id': 'tmp_A'}),
            idempotencyKey: 'kB',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        final paymentId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'tmp_C',
            mutationKind: MutationKind.create.wireName,
            payload: jsonEncode({'id': 'tmp_C', 'invoice_id': 'tmp_B'}),
            idempotencyKey: 'kC',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        final realUpdateId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c9',
            mutationKind: MutationKind.update.wireName,
            payload: jsonEncode({'id': 'c9', 'client_id': 'tmp_A'}),
            idempotencyKey: 'k9',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        final removed = await engine.discardOutboxRow(clientId);

        expect(removed, isTrue);
        // Ghost subtree removed wholesale (local record + outbox rows).
        expect(
          repo.localDeletes,
          containsAll([('co', 'tmp_A'), ('co', 'tmp_B'), ('co', 'tmp_C')]),
        );
        expect(await rawRow(invoiceId), isNull);
        expect(await rawRow(paymentId), isNull);
        // Non-ghost dependent kept as a dead row the user can resolve.
        final realUpdate = await rawRow(realUpdateId);
        expect(realUpdate?.state, 'dead');
        // Nothing left pending → "Sync first" can settle.
        expect(await db.outboxDao.pendingCountForCompany('co'), 0);
      },
    );

    test('non-ghost discard clears the local record is_dirty only when no '
        'other active outbox row remains for that entity', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      // Two pending updates to the SAME real entity c1.
      final firstId = await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');

      // Discarding the first leaves a second pending row → must NOT clear.
      await engine.discardOutboxRow(firstId);
      expect(
        repo.dirtyCleared,
        isEmpty,
        reason: 'another queued edit still protects the entity',
      );

      // Discard the remaining one → now no active row → clear is_dirty.
      final second = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      await engine.discardOutboxRow(second.single.id);
      expect(repo.dirtyCleared, [('co', 'c1')]);
    });

    test(
      'discarding a NON-edit row keeps is_dirty while a dead edit still needs '
      'it (invoiceninja/flutter#123)',
      () async {
        // `hasActiveRowsForEntity` matches only `pending` / `in_flight`, so a
        // **dead** edit is invisible to it — and a dead edit is the user's
        // unsaved work, held on screen by `SaveFailedBanner` + Retry.
        //
        // "The user abandoned it" is true of the row being discarded, not of
        // the entity: `add_comment` is enqueued under the PARENT's
        // entity_type/entity_id, so discarding a queued comment used to release
        // the dead edit's flag and let the next refresh clobber it. Reachable
        // in two taps from the comment row's `⋯` menu.
        final repo = _TestRepo(db: db);
        final engine = engineWith(repo);

        final deadEdit = await enqueueClient(
          entityId: 'c1',
          idempotencyKey: 'edit',
        );
        await db.outboxDao.markDead(
          id: deadEdit,
          error: '422',
          statusCode: 422,
        );
        final comment = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
            mutationKind: MutationKind.addComment.wireName,
            payload: jsonEncode({'entity_id': 'c1', 'notes': 'Chasing'}),
            idempotencyKey: 'note',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        await engine.discardOutboxRow(comment);

        expect(
          repo.dirtyCleared,
          isEmpty,
          reason: 'the dead edit still needs its is_dirty protection',
        );

        // …and discarding the dead edit itself still clears, as it always has:
        // the row is deleted before the reconcile runs, so the guard cannot
        // match the row being discarded.
        await engine.discardOutboxRow(deadEdit);
        expect(repo.dirtyCleared, [('co', 'c1')]);
      },
    );

    Future<int> enqueueReorder(Object payload) => db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co',
        entityType: 'client',
        entityId: kReorderEntityId,
        mutationKind: MutationKind.reorder.wireName,
        payload: jsonEncode(payload),
        idempotencyKey: 'reorder',
        nextAttemptAt: 0,
        createdAt: 0,
      ),
    );

    test('discarding a dead reorder clears is_dirty on every reordered id — '
        'the synthetic `_sort` entityId cannot (#8)', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final id = await enqueueReorder({
        'status_ids': ['s1'],
        'task_ids': {
          's1': ['c1', 'c2'],
        },
      });
      await db.outboxDao.markDead(id: id, error: 'boom', statusCode: 422);

      await engine.discardOutboxRow(id);

      expect(repo.dirtyCleared, containsAll([('co', 'c1'), ('co', 'c2')]));
    });

    test('discarding a dead task-STATUS reorder (payload {status, all_ids}) '
        'clears is_dirty on every reordered status (#8 regression)', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      final id = await enqueueReorder({
        'status': <String, dynamic>{},
        'all_ids': ['c1', 'c2'],
      });
      await db.outboxDao.markDead(id: id, error: 'boom', statusCode: 422);

      await engine.discardOutboxRow(id);

      expect(repo.dirtyCleared, containsAll([('co', 'c1'), ('co', 'c2')]));
    });

    test('a reordered id with its OWN pending edit is NOT cleared on reorder '
        'discard — the separate edit stays protected (#8)', () async {
      final repo = _TestRepo(db: db);
      final engine = engineWith(repo);
      // c1 carries an independent pending update.
      await enqueueClient(entityId: 'c1', idempotencyKey: 'edit-c1');
      final id = await enqueueReorder({
        'task_ids': {
          's1': ['c1', 'c2'],
        },
      });
      await db.outboxDao.markDead(id: id, error: 'boom', statusCode: 422);

      await engine.discardOutboxRow(id);

      expect(repo.dirtyCleared, [
        ('co', 'c2'),
      ], reason: 'c1 is still protected by its own queued edit');
    });
  });

  group('awaitRow (synchronous-when-online seam)', () {
    test('returns success when the dispatcher drains the row', () async {
      final disp = _ProgrammableDispatcher()..queueSuccess();
      final engine = makeEngine(disp);
      final rowId = await enqueueClient(entityId: 'c1');

      final result = await engine.awaitRow(
        rowId: rowId,
        companyId: 'co',
        pollInterval: const Duration(milliseconds: 5),
      );

      expect(result.outcome, SyncRowOutcome.success);
      expect(await rowById(rowId), isNull);
    });

    test('returns validationFailed with fieldErrors when the dispatcher throws '
        'ValidationException (422)', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(
          const ValidationException('Validation failed', {
            'email': ['Must be unique'],
          }),
        );
      final engine = makeEngine(disp);
      final rowId = await enqueueClient(entityId: 'c1');

      final result = await engine.awaitRow(
        rowId: rowId,
        companyId: 'co',
        pollInterval: const Duration(milliseconds: 5),
      );

      expect(result.outcome, SyncRowOutcome.validationFailed);
      expect(result.statusCode, 422);
      expect(result.fieldErrors['email'], ['Must be unique']);
    });

    test('returns serverError when a transient failure parks the row with a '
        'future nextAttemptAt (backoff scheduled)', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const NetworkException('Connection lost'));
      final engine = makeEngine(disp);
      final rowId = await enqueueClient(entityId: 'c1');

      final result = await engine.awaitRow(
        rowId: rowId,
        companyId: 'co',
        pollInterval: const Duration(milliseconds: 5),
      );

      expect(result.outcome, SyncRowOutcome.serverError);
      expect(result.message, contains('Connection lost'));
    });

    group('a save parked behind an unsynced parent', () {
      const parent = 'tmp_00000000-0000-4000-8000-0000000000c1';
      const child = 'tmp_00000000-0000-4000-8000-0000000000c2';

      /// Queue the parent create in [state] — `pending` parked far ahead, so
      /// it stays on its way without sending — then await a save that
      /// references it.
      Future<(SyncRowResult, _ProgrammableDispatcher)> awaitChild(
        String state,
      ) async {
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: parent,
            mutationKind: 'create',
            payload: jsonEncode({'id': parent}),
            idempotencyKey: 'k-parent',
            nextAttemptAt: state == 'pending' ? 1 << 50 : 0,
            createdAt: 0,
            state: Value(state),
          ),
        );
        final rowId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: child,
            mutationKind: 'create',
            payload: jsonEncode({'id': child, 'parent_id': parent}),
            idempotencyKey: 'k-child',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        final disp = _ProgrammableDispatcher();
        final result = await makeEngine(disp).awaitRow(
          rowId: rowId,
          companyId: 'co',
          timeout: const Duration(milliseconds: 150),
          pollInterval: const Duration(milliseconds: 5),
        );
        return (result, disp);
      }

      test(
        'is not reported as failed while the parent is on its way',
        () async {
          // The tmp_ guard parks it until the parent create lands, and it goes
          // the moment that happens (rewriteTempIdInPayloads re-arms it). It
          // used to come back as serverError — "The server rejected this save"
          // — though nothing had been sent.
          final (result, disp) = await awaitChild('pending');

          expect(result.outcome, SyncRowOutcome.timeout);
          expect(disp.dispatches, 0, reason: 'nothing was sent');
        },
      );

      test('is not reported once the parent has just landed', () async {
        // Read before the landing, the save still carries the parent's temp
        // id while the parent's own row is already gone: the landing wrote its
        // id_remap entry in the transaction that re-armed the save.
        await db.idRemapDao.remember(
          entityType: 'client',
          tempId: parent,
          realId: 'c_real',
          now: 0,
        );
        final rowId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: child,
            mutationKind: 'create',
            payload: jsonEncode({'id': child, 'parent_id': parent}),
            idempotencyKey: 'k-child',
            nextAttemptAt: 1 << 50,
            createdAt: 0,
          ),
        );

        final result = await makeEngine(_ProgrammableDispatcher()).awaitRow(
          rowId: rowId,
          companyId: 'co',
          timeout: const Duration(milliseconds: 150),
          pollInterval: const Duration(milliseconds: 5),
        );

        expect(result.outcome, SyncRowOutcome.timeout);
      });

      test('is reported when the parent waits on a grandparent that waits on '
          'the user', () async {
        // The parent's own create is queued, but it references a record whose
        // create failed: it will never send by itself, and neither will this.
        const grandparent = 'tmp_00000000-0000-4000-8000-0000000000c0';
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: grandparent,
            mutationKind: 'create',
            payload: '{}',
            idempotencyKey: 'k-grandparent',
            nextAttemptAt: 0,
            createdAt: 0,
            state: const Value('dead'),
          ),
        );
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: parent,
            mutationKind: 'create',
            payload: jsonEncode({'parent_id': grandparent}),
            idempotencyKey: 'k-parent',
            nextAttemptAt: 1 << 50,
            createdAt: 0,
          ),
        );
        final rowId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: child,
            mutationKind: 'create',
            payload: jsonEncode({'parent_id': parent}),
            idempotencyKey: 'k-child',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        final disp = _ProgrammableDispatcher();

        final result = await makeEngine(disp).awaitRow(
          rowId: rowId,
          companyId: 'co',
          timeout: const Duration(milliseconds: 150),
          pollInterval: const Duration(milliseconds: 5),
        );

        expect(result.outcome, SyncRowOutcome.serverError);
        expect(disp.dispatches, 0);
      });

      test('is reported when the parent\'s create is held behind one that may '
          'already have gone through', () async {
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: parent,
            mutationKind: 'create',
            payload: '{}',
            idempotencyKey: 'k-first',
            nextAttemptAt: 0,
            createdAt: 0,
            state: const Value('unconfirmed'),
          ),
        );
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: parent,
            mutationKind: 'create',
            payload: '{}',
            idempotencyKey: 'k-second',
            nextAttemptAt: 1 << 50,
            createdAt: 0,
            lastError: const Value(kHeldBehindUnconfirmedError),
          ),
        );
        final rowId = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: child,
            mutationKind: 'create',
            payload: jsonEncode({'parent_id': parent}),
            idempotencyKey: 'k-child',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        final disp = _ProgrammableDispatcher();

        final result = await makeEngine(disp).awaitRow(
          rowId: rowId,
          companyId: 'co',
          timeout: const Duration(milliseconds: 150),
          pollInterval: const Duration(milliseconds: 5),
        );

        expect(result.outcome, SyncRowOutcome.serverError);
        expect(disp.dispatches, 0);
      });

      test('is reported when the parent waits on the user', () async {
        // A dead parent, or one that may already have gone through, never
        // lands by itself: waiting it out would claim "saving in background"
        // for a save that goes nowhere until the user acts.
        for (final state in ['dead', 'unconfirmed']) {
          await db.delete(db.outbox).go();
          final (result, disp) = await awaitChild(state);

          expect(result.outcome, SyncRowOutcome.serverError, reason: state);
          expect(disp.dispatches, 0, reason: state);
        }
      });
    });

    test('returns timeout when the deadline elapses while the row is still '
        'pending or in-flight', () async {
      final blocker = Completer<void>();
      final disp = _GatedDispatcher(firstBlocker: blocker.future);
      final engine = makeEngine(disp);
      final rowId = await enqueueClient(entityId: 'c1');

      final result = await engine.awaitRow(
        rowId: rowId,
        companyId: 'co',
        timeout: const Duration(milliseconds: 50),
        pollInterval: const Duration(milliseconds: 5),
      );

      expect(result.outcome, SyncRowOutcome.timeout);
      blocker.complete();
    });
  });

  group('fail-fast 4xx + orphan recovery + caller-handled deaths', () {
    test('a 4xx client error is marked dead on the FIRST attempt (no backoff) '
        'and emits a DeadEvent the shell can surface', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(400, 'Bounce ID not found'));
      final engine = makeEngine(disp);
      final events = <SyncEvent>[];
      engine.events.listen(events.add);
      final id = await enqueueClient(entityId: 'c1', attempts: 0);

      await engine.drainOnce(companyId: 'co');
      await Future<void>.delayed(Duration.zero); // flush broadcast

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(row.state, 'dead', reason: '400 is permanent — fail fast');
      expect(row.lastStatusCode, 400);
      expect(
        row.attempts,
        0,
        reason: 'died on the first attempt, never walked the backoff schedule',
      );
      expect(disp.dispatches, 1);
      final dead = events.single as DeadEvent;
      expect(dead.statusCode, 400);
      expect(dead.message, 'Bounce ID not found');
      expect(
        dead.handledByCaller,
        isFalse,
        reason: 'no awaitRow caller — the shell escalates to a modal online',
      );
    });

    test('a 5xx server error still walks the backoff schedule (stays pending '
        'on the first attempt), unlike a 4xx', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(503, 'Unavailable'));
      final engine = makeEngine(disp, nowMs: 1000);
      final id = await enqueueClient(entityId: 'c1', attempts: 0);

      await engine.drainOnce(companyId: 'co');

      final row = await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle();
      expect(row.state, 'pending', reason: '5xx is transient — retried');
      expect(row.nextAttemptAt - 1000, kBackoffSchedule[0].inMilliseconds);
    });

    test('a row orphaned in in_flight (interrupted drain) is re-armed to '
        'pending and dispatched on the next drain', () async {
      final disp = _ProgrammableDispatcher()..queueSuccess();
      final engine = makeEngine(disp);
      final id = await enqueueClient(entityId: 'c1');
      // Simulate a prior pass that marked the row in_flight then died (process
      // death) before its catch handler could reschedule / kill it.
      await db.outboxDao.markInFlight(id);

      final successes = await engine.drainOnce(companyId: 'co');

      expect(
        successes,
        1,
        reason: 'reset in_flight → pending, then dispatched to success',
      );
      expect(disp.dispatches, 1);
      final remaining = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      expect(remaining, isEmpty, reason: 'drained and removed');
    });

    test('awaitRow (default callerWillDisplayFailure) tags the dead row\'s '
        'DeadEvent handledByCaller=true so the shell suppresses the modal and '
        'lets the form/tap-site show it inline', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(400, 'Bounce ID not found'));
      final engine = makeEngine(disp);
      final events = <SyncEvent>[];
      engine.events.listen(events.add);
      final rowId = await enqueueClient(entityId: 'c1');

      final result = await engine.awaitRow(
        rowId: rowId,
        companyId: 'co',
        pollInterval: const Duration(milliseconds: 5),
      );
      await Future<void>.delayed(Duration.zero);

      expect(result.outcome, SyncRowOutcome.serverError);
      expect(result.statusCode, 400);
      final dead = events.whereType<DeadEvent>().single;
      expect(dead.handledByCaller, isTrue);
    });

    test('awaitRow(callerWillDisplayFailure: false) leaves the DeadEvent '
        'unhandled so the shell escalates to a modal', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const ServerException(400, 'Bounce ID not found'));
      final engine = makeEngine(disp);
      final events = <SyncEvent>[];
      engine.events.listen(events.add);
      final rowId = await enqueueClient(entityId: 'c1');

      final result = await engine.awaitRow(
        rowId: rowId,
        companyId: 'co',
        pollInterval: const Duration(milliseconds: 5),
        callerWillDisplayFailure: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(result.outcome, SyncRowOutcome.serverError);
      final dead = events.whereType<DeadEvent>().single;
      expect(dead.handledByCaller, isFalse);
    });
  });

  group('tag-create 422 salvages dependents (M1)', () {
    test('strips the dead tmp tag id from a dependent task and lets it save '
        'instead of marking the parent dead', () async {
      // The tag create (dispatched first) 422s — e.g. a name colliding with a
      // tag archived/deleted on another device. The task update referencing
      // the new tmp tag id must NOT be killed: the dead tmp id is stripped and
      // the task drains with its remaining tags.
      final disp = _ProgrammableDispatcher()
        ..queueThrow(
          const ValidationException('name has already been taken', {}),
        )
        ..queueSuccess();
      final registry = EntityRegistry({
        EntityType.tag: EntityHandlers(
          type: EntityType.tag,
          wireName: 'tag',
          apiPath: '/api/v1/tags',
          routePath: '/settings/tags',
          icon: Icons.label,
          dispatcher: disp,
        ),
        EntityType.task: EntityHandlers(
          type: EntityType.task,
          wireName: 'task',
          apiPath: '/api/v1/tasks',
          routePath: '/tasks',
          icon: Icons.task,
          dispatcher: disp,
        ),
      });
      final engine = SyncRepository(
        db: db,
        registry: registry,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );

      final tagId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'tag',
          entityId: 'tmp_tag1',
          mutationKind: MutationKind.create.wireName,
          payload: jsonEncode({'id': 'tmp_tag1', 'name': 'Urgent'}),
          idempotencyKey: 'kt',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      final taskId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'task',
          entityId: 'task1',
          mutationKind: MutationKind.update.wireName,
          payload: jsonEncode({
            'id': 'task1',
            'tags': ['tmp_tag1', 'keep'],
          }),
          idempotencyKey: 'kk',
          nextAttemptAt: 0,
          createdAt: 1,
        ),
      );

      await engine.drainOnce(companyId: 'co');

      // Tag create is dead (422)...
      final tagRow = await db.outboxDao.byId(tagId);
      expect(tagRow?.state, 'dead');
      expect(tagRow?.lastStatusCode, 422);

      // ...but the dependent task was dispatched (not killed) with the dead
      // tag id stripped and 'keep' retained, then removed on success.
      expect(disp.lastRow?.entityType, 'task');
      final dispatched =
          jsonDecode(disp.lastRow!.payload) as Map<String, dynamic>;
      expect(dispatched['tags'], ['keep']);
      final taskRow = await db.outboxDao.byId(taskId);
      expect(taskRow, isNull, reason: 'task drained successfully, not dead');
    });

    test('a dependent parked on the tag goes at once once the tag is '
        'stripped — it no longer waits on anything', () async {
      // An earlier pass parked the task behind the unsynced tag. Stripped of
      // it, the task sat out the rest of its minute, and a form awaiting it
      // reported "The server rejected this save" meanwhile.
      const tag = 'tmp_00000000-0000-4000-8000-0000000000e1';
      final disp = _ProgrammableDispatcher()
        ..queueThrow(
          const ValidationException('name has already been taken', {}),
        )
        ..queueSuccess();
      final engine = SyncRepository(
        db: db,
        registry: EntityRegistry({
          EntityType.tag: EntityHandlers(
            type: EntityType.tag,
            wireName: 'tag',
            apiPath: '/api/v1/tags',
            routePath: '/settings/tags',
            icon: Icons.label,
            dispatcher: disp,
          ),
          EntityType.task: EntityHandlers(
            type: EntityType.task,
            wireName: 'task',
            apiPath: '/api/v1/tasks',
            routePath: '/tasks',
            icon: Icons.task,
            dispatcher: disp,
          ),
        }),
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'tag',
          entityId: tag,
          mutationKind: MutationKind.create.wireName,
          payload: jsonEncode({'name': 'Urgent'}),
          idempotencyKey: 'kt',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      final taskId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'task',
          entityId: 'task1',
          mutationKind: MutationKind.update.wireName,
          payload: jsonEncode({
            'id': 'task1',
            'tags': [tag, 'keep'],
          }),
          idempotencyKey: 'kk',
          nextAttemptAt: 1000 + 60000,
          createdAt: 1,
          lastError: const Value(kWaitingForReferencedRecordError),
        ),
      );

      await engine.drainOnce(companyId: 'co');

      final task = await db.outboxDao.byId(taskId);
      final sent = disp.dispatches == 2;
      expect(
        sent || (task?.nextAttemptAt == 0 && task?.lastError == null),
        isTrue,
        reason: 'sent at once, or due at once',
      );
      if (task != null) {
        final payload = jsonDecode(task.payload) as Map<String, dynamic>;
        expect(payload['tags'], ['keep']);
      }
    });

    test('marks the tag own follow-up rows dead (rename/archive) instead of '
        'deferring them forever', () async {
      // The tag create (dispatched first) 422s. The tag's OWN offline follow-up
      // — here a rename (update) keyed to the same tmp id, carrying NO `tags`
      // list — must be settled DEAD, not left pending. Pre-fix it was skipped
      // by the strip loop and then deferred +1 min on every drain forever by
      // the tmp-dependency guard (a non-create on a tmp_ entityId).
      final disp = _ProgrammableDispatcher()
        ..queueThrow(
          const ValidationException('name has already been taken', {}),
        );
      final registry = EntityRegistry({
        EntityType.tag: EntityHandlers(
          type: EntityType.tag,
          wireName: 'tag',
          apiPath: '/api/v1/tags',
          routePath: '/settings/tags',
          icon: Icons.label,
          dispatcher: disp,
        ),
      });
      final engine = SyncRepository(
        db: db,
        registry: registry,
        now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      );

      final tagId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'tag',
          entityId: 'tmp_tag1',
          mutationKind: MutationKind.create.wireName,
          payload: jsonEncode({'id': 'tmp_tag1', 'name': 'Urgent'}),
          idempotencyKey: 'kt',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      // Offline rename of the same not-yet-synced tag (update embeds the tmp
      // id; no `tags` key — see Tag.toApiJson).
      final renameId = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'tag',
          entityId: 'tmp_tag1',
          mutationKind: MutationKind.update.wireName,
          payload: jsonEncode({'id': 'tmp_tag1', 'name': 'Renamed'}),
          idempotencyKey: 'kr',
          nextAttemptAt: 0,
          createdAt: 1,
        ),
      );

      await engine.drainOnce(companyId: 'co');

      final tagRow = await db.outboxDao.byId(tagId);
      expect(tagRow?.state, 'dead');
      final renameRow = await db.outboxDao.byId(renameId);
      expect(
        renameRow?.state,
        'dead',
        reason:
            'the tag own follow-up must be settled dead, not left pending '
            '(which the tmp-dependency guard would defer forever)',
      );
      expect(
        disp.dispatches,
        1,
        reason:
            'only the create dispatches; the rename is marked dead before '
            'the drain loop reaches it',
      );
    });
  });

  // Regression: `delete()` / `archive()` flip the local Drift row optimistically
  // (`is_deleted=true, is_dirty=true`) before the server agrees. When the row
  // then died permanently — the user cancels the password sheet on a delete, or
  // an OAuth-only account has none to give — nothing undid that flip, and
  // `upsertAllPreservingDirty` skips dirty ids on every page fetch, `refreshAll`
  // and bundle apply. The record stayed invisible locally and refresh-frozen
  // forever while the server still had it, live.
  group('per-entity ordering barrier', () {
    // `nextReady` is id-ordered, but a failed row was merely rescheduled and
    // the loop carried on — so mutation N+1 for the same record could be
    // applied before mutation N, and the OLDER payload then won on its retry.
    test('a later row for the same entity is held back when an earlier one '
        'fails in the same pass', () async {
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const NetworkException('offline'))
        ..queueSuccess();
      final engine = makeEngine(disp);
      final first = await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      final second = await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');

      final successes = await engine.drainOnce(companyId: 'co');

      expect(successes, 0, reason: 'the second row must not have dispatched');
      expect(await rowById(first), isNotNull);
      expect(
        await rowById(second),
        isNotNull,
        reason:
            'v2 stays queued behind v1; letting it through would let v1 '
            'overwrite it on retry',
      );
    });

    test('a RE-PARKED earlier row still holds back the later one — the '
        'scenario the per-pass set alone could not see', () async {
      // `nextReady` only returns rows that are DUE, so once row1 fails and
      // re-parks into the future it drops out of the snapshot entirely. A
      // per-pass Set therefore never learns about it, row2 dispatches, and
      // row1 overwrites it on its own retry. This is the actual lost-update.
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const NetworkException('offline'))
        ..queueSuccess();
      final engine = makeEngine(disp);
      final first = await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      final second = await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');

      // Pass 1: row1 fails and re-parks; row2 is held back by the set.
      await engine.drainOnce(companyId: 'co');
      // Pass 2: row1 is parked in the future and so is NOT in the snapshot.
      final successes = await engine.drainOnce(companyId: 'co');

      expect(
        successes,
        0,
        reason: 'v2 must not go out while v1 is still queued to retry',
      );
      expect(await rowById(first), isNotNull);
      expect(await rowById(second), isNotNull);
    });

    test(
      'a row parked beyond the horizon (409 conflict) does NOT block',
      () async {
        // A conflict parks a row `pending` a YEAR out while it waits for the
        // user. Treating that as "still going to be sent" would starve the
        // record for a year — worse than the reordering it prevents.
        final disp = _ProgrammableDispatcher()..queueSuccess();
        final engine = makeEngine(disp);
        final parked = await enqueueClient(
          entityId: 'c1',
          idempotencyKey: 'k1',
          nextAttemptAt: 1000 + const Duration(days: 365).inMilliseconds,
        );
        await enqueueClient(entityId: 'c1', idempotencyKey: 'k2');

        expect(await engine.drainOnce(companyId: 'co'), 1);
        expect(
          await rowById(parked),
          isNotNull,
          reason:
              'the parked row is untouched, but it did not gate the later one',
        );
      },
    );

    test('a row for a DIFFERENT entity still dispatches', () async {
      // The barrier is per record, not a stop-the-world.
      final disp = _ProgrammableDispatcher()
        ..queueThrow(const NetworkException('offline'))
        ..queueSuccess();
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1', idempotencyKey: 'k1');
      await enqueueClient(entityId: 'c2', idempotencyKey: 'k2');

      expect(await engine.drainOnce(companyId: 'co'), 1);
    });
  });

  group('offline never dead-letters queued work', () {
    test(
      'a NetworkException re-parks without consuming the retry budget',
      () async {
        // Working offline in the foreground used to burn one attempt per
        // five-minute refresh tick (nothing gates the drain on connectivity), so
        // every queued mutation hit `dead` in ~25 minutes — and a later sign-out
        // then wiped those payloads with no prompt, because the pending-count
        // queries exclude `dead`.
        final disp = _ProgrammableDispatcher();
        for (var i = 0; i < kMaxAttempts + 3; i++) {
          disp.queueThrow(const NetworkException('offline'));
        }
        final engine = makeEngine(disp);
        final id = await enqueueClient(entityId: 'c1');

        for (var i = 0; i < kMaxAttempts + 3; i++) {
          await engine.drainOnce(companyId: 'co');
          // Re-arm: the row parks into the future, so move it back to due.
          await db.outboxDao.scheduleRetry(
            id: id,
            attempts: (await rowById(id))!.attempts,
            nextAttemptAt: 0,
            error: 'retry',
          );
        }

        final row = await rowById(id);
        expect(row, isNotNull, reason: 'the row must survive');
        expect(row!.state, 'pending');
        expect(row.attempts, 0, reason: 'offline must not consume the budget');
      },
    );

    test(
      'the re-park delay is the flat offline delay, not the 5s backoff head',
      () async {
        // With `attempts` frozen, reusing `_retryWithBackoff` would index
        // kBackoffSchedule[0] = 5s every time — a 5-second retry hot-loop for as
        // long as the device is offline.
        final disp = _ProgrammableDispatcher()
          ..queueThrow(const NetworkException('offline'));
        final engine = makeEngine(disp, nowMs: 1000);
        final id = await enqueueClient(entityId: 'c1');

        await engine.drainOnce(companyId: 'co');

        final row = (await db.select(db.outbox).get()).firstWhere(
          (r) => r.id == id,
        );
        expect(row.nextAttemptAt, 1000 + kOfflineRetryDelay.inMilliseconds);
      },
    );
  });

  group('pruning dead rows releases the dirty flag', () {
    test('a pruned dead UPDATE clears is_dirty so refreshes resume', () async {
      // A dead create/update deliberately KEEPS `is_dirty` (the local row is
      // the user's unsaved work, offered back by SaveFailedBanner + Retry) and
      // `upsertAllPreservingDirty` skips every dirty id. The boot-time prune
      // deleted the row explaining that flag with a bare DELETE, so the record
      // was frozen at its stale local value for the life of the install.
      final disp = _DirtySpyDispatcher()
        ..queueThrow(const ValidationException('nope', {}));
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1', kind: MutationKind.update);
      await engine.drainOnce(companyId: 'co');
      expect(disp.clearedDirty, isEmpty, reason: 'dead edit keeps its flag');

      final removed = await engine.pruneDeadRows(ttl: Duration.zero);

      expect(removed, 1);
      expect(
        disp.clearedDirty,
        ['c1'],
        reason: 'once the row is gone there is nothing left to retry from',
      );
    });

    test('a dead row inside the TTL is left alone', () async {
      final disp = _DirtySpyDispatcher()
        ..queueThrow(const ValidationException('nope', {}));
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c1', kind: MutationKind.update);
      await engine.drainOnce(companyId: 'co');

      expect(await engine.pruneDeadRows(), 0);
      expect(disp.clearedDirty, isEmpty);
    });
  });

  group('a dead LIFECYCLE row releases its optimistic dirty flag', () {
    test(
      'a dead delete clears is_dirty so a refresh can restore the row',
      () async {
        final disp = _DirtySpyDispatcher()
          ..queueThrow(const ValidationException('nope', {}));
        final engine = makeEngine(disp);
        await enqueueClient(entityId: 'c1', kind: MutationKind.delete);

        await engine.drainOnce(companyId: 'co');

        expect(disp.clearedDirty, ['c1']);
      },
    );

    test('a dead archive does too', () async {
      final disp = _DirtySpyDispatcher()
        ..queueThrow(const ValidationException('nope', {}));
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c2', kind: MutationKind.archive);

      await engine.drainOnce(companyId: 'co');

      expect(disp.clearedDirty, ['c2']);
    });

    test('a dead UPDATE does NOT — that dirty row is the user\'s unsaved edit '
        'and the edit screen re-opens onto it with a Retry', () async {
      final disp = _DirtySpyDispatcher()
        ..queueThrow(const ValidationException('nope', {}));
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c3', kind: MutationKind.update);

      await engine.drainOnce(companyId: 'co');

      expect(disp.clearedDirty, isEmpty);
    });

    test('a DEAD edit for the same id also keeps its flag', () async {
      // `hasActiveRowsForEntity` matches only pending / in_flight, so a dead
      // update — the user's unsaved work, sitting behind a SaveFailedBanner +
      // Retry — used to be invisible to the guard. Clearing dirty there lets
      // the next refresh overwrite the very edit the user is being asked to
      // retry.
      final disp = _DirtySpyDispatcher()
        ..queueThrow(const ValidationException('nope', {}))
        ..queueThrow(const ValidationException('nope', {}));
      final engine = makeEngine(disp);
      // The edit dies first...
      await enqueueClient(entityId: 'c5', kind: MutationKind.update);
      await engine.drainOnce(companyId: 'co');
      // ...then an archive of the same record dies too.
      await enqueueClient(
        entityId: 'c5',
        kind: MutationKind.archive,
        idempotencyKey: 'k2',
      );
      await engine.drainOnce(companyId: 'co');

      expect(disp.clearedDirty, isEmpty);
    });

    test('an id that still has another pending row keeps its flag', () async {
      final disp = _DirtySpyDispatcher()
        ..queueThrow(const ValidationException('nope', {}));
      final engine = makeEngine(disp);
      await enqueueClient(entityId: 'c4', kind: MutationKind.delete);
      // A separate, still-queued edit for the same record.
      await enqueueClient(
        entityId: 'c4',
        kind: MutationKind.update,
        idempotencyKey: 'k2',
        nextAttemptAt: 1 << 40,
      );

      await engine.drainOnce(companyId: 'co');

      expect(disp.clearedDirty, isEmpty);
    });
  });
}

class _GatedDispatcher implements SyncDispatcher {
  _GatedDispatcher({required this.firstBlocker});
  final Future<void> firstBlocker;
  int dispatches = 0;

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    dispatches++;
    if (dispatches == 1) await firstBlocker;
  }

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}
}

/// Minimal concrete repository for `BaseEntityRepository` tests — the real
/// `ClientRepository` etc. drag in API clients we don't need here. The
/// `entityType: EntityType.client` matches what the `_registryWith(...)`
/// helper above registers, so the dispatcher hooks up correctly.
class _TestRepo extends BaseEntityRepository<Object, Object> {
  _TestRepo({required super.db, super.onEnqueued, super.now})
    : super(entityType: EntityType.client);

  @override
  String get entityTypeName => 'client';

  /// Captured `(companyId, id)` pairs for every `deleteLocalById` call so
  /// the discard tests can assert the ghost path reached the repo (and the
  /// non-ghost path did not).
  final List<(String, String)> localDeletes = [];

  /// Captured `(companyId, id)` pairs for every `clearLocalDirty` call so the
  /// Issue-4 reconciliation tests can assert the non-ghost discard cleared
  /// the local record's dirty flag (only when no other active row remained).
  final List<(String, String)> dirtyCleared = [];

  /// Makes `deleteLocalById` throw — a DAO/DB failure, or a repo that hasn't
  /// overridden the base's throwing default.
  bool throwOnLocalDelete = false;

  /// Throw for one specific entity id only — lets a test fail the cascade's
  /// delete while the primary row's delete succeeds.
  String? throwOnLocalDeleteOf;

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) async {
    localDeletes.add((companyId, id));
    if (throwOnLocalDelete || id == throwOnLocalDeleteOf) {
      throw UnsupportedError('no deleteLocalById');
    }
  }

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {
    dirtyCleared.add((companyId, id));
  }

  @override
  Stream<Object?> watchByRealId({
    required String companyId,
    required String id,
  }) => const Stream<Object?>.empty();
}
