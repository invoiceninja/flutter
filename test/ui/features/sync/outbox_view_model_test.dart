import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/ui/features/sync/view_models/outbox_view_model.dart';

/// Stands in for the real engine so a discard can be gated, made to throw, or
/// made to do nothing at all. The dao side is a REAL in-memory database — the
/// point of most of these tests is what the Drift watch does (or doesn't) do
/// around the action.
class _FakeSync implements SyncRepository {
  _FakeSync({required this.onDiscard});

  /// Runs in place of the real discard. Returning normally without touching
  /// the row is how "the action silently didn't take" is simulated.
  final Future<void> Function(int id) onDiscard;

  final List<int> discarded = [];
  final List<String> drains = [];

  @override
  Future<bool> discardOutboxRow(int id) async {
    discarded.add(id);
    await onDiscard(id);
    return true;
  }

  @override
  Future<int> drainOnce({required String companyId}) async {
    drains.add(companyId);
    return 0;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Feeds the view model a stream the test drives directly, so a watch failure
/// can be simulated (the real dao's stream can't be made to throw on demand).
class _ScriptedDao implements OutboxDao {
  final ctrl = StreamController<List<OutboxRow>>.broadcast();

  @override
  Stream<List<OutboxRow>> watchAll(String companyId) => ctrl.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<int> enqueue({
    String entityId = 'c1',
    String idempotencyKey = 'k',
    int createdAt = 0,
    String state = 'pending',
  }) => db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: 'co',
      entityType: 'client',
      entityId: entityId,
      mutationKind: 'update',
      payload: jsonEncode({'id': entityId}),
      idempotencyKey: idempotencyKey,
      nextAttemptAt: 0,
      createdAt: createdAt,
      state: Value(state),
    ),
  );

  Future<void> deleteRow(int id) => db.outboxDao.deleteRow(id);

  OutboxViewModel build(_FakeSync sync) =>
      OutboxViewModel(dao: db.outboxDao, sync: sync, companyId: 'co');

  test('exposes the queue once the first emission lands', () async {
    await enqueue(entityId: 'a', idempotencyKey: 'k1', createdAt: 1);
    await enqueue(entityId: 'b', idempotencyKey: 'k2', createdAt: 2);
    final vm = build(_FakeSync(onDiscard: (_) async {}));
    addTearDown(vm.dispose);

    expect(vm.isLoading, isTrue, reason: 'nothing read yet');
    await pumpEventQueue();

    expect(vm.isLoading, isFalse);
    expect(vm.rows.map((r) => r.entityId), ['b', 'a'], reason: 'newest first');
  });

  test('discard drops the row from the list before the delete lands — the '
      'invoiceninja/flutter#44 regression', () async {
    final gate = Completer<void>();
    final id = await enqueue(entityId: 'a', idempotencyKey: 'k1');
    await enqueue(entityId: 'b', idempotencyKey: 'k2');
    final sync = _FakeSync(
      onDiscard: (rowId) async {
        await gate.future;
        await deleteRow(rowId);
      },
    );
    final vm = build(sync);
    addTearDown(vm.dispose);
    await pumpEventQueue();

    final pending = vm.discard(id);
    await pumpEventQueue();

    // The DB still holds the row — only the optimistic hide is in play.
    expect(await db.outboxDao.byId(id), isNotNull);
    expect(vm.rows.map((r) => r.entityId), ['b']);

    gate.complete();
    expect(await pending, isTrue);
    await pumpEventQueue();
    expect(vm.rows.map((r) => r.entityId), ['b'], reason: 'stays gone');
  });

  test(
    'a discard that deletes the row and THEN throws still counts as done',
    () async {
      final id = await enqueue(entityId: 'a', idempotencyKey: 'k1');
      // `discardOutboxRow`'s post-delete cascade can throw after the user's row
      // is already gone. Reporting that as a failure would flash the tile back
      // and toast an error for a discard that worked.
      final vm = build(
        _FakeSync(
          onDiscard: (rowId) async {
            await deleteRow(rowId);
            throw StateError('cascade blew up');
          },
        ),
      );
      addTearDown(vm.dispose);
      await pumpEventQueue();

      expect(await vm.discard(id), isTrue);
      expect(vm.rows, isEmpty, reason: 'and it never comes back');
    },
  );

  test(
    'a discard that leaves the row queued un-hides it and reports failure',
    () async {
      final id = await enqueue(entityId: 'a', idempotencyKey: 'k1');
      // Completes normally without deleting anything — the silent no-op the
      // optimistic hide must never paper over.
      final vm = build(_FakeSync(onDiscard: (_) async {}));
      addTearDown(vm.dispose);
      await pumpEventQueue();

      expect(await vm.discard(id), isFalse);
      expect(vm.rows.map((r) => r.entityId), [
        'a',
      ], reason: 'the row came back');
    },
  );

  test('a throwing discard un-hides the row and reports failure', () async {
    final id = await enqueue(entityId: 'a', idempotencyKey: 'k1');
    final vm = build(
      _FakeSync(onDiscard: (_) async => throw StateError('boom')),
    );
    addTearDown(vm.dispose);
    await pumpEventQueue();

    expect(await vm.discard(id), isFalse);
    expect(vm.rows.map((r) => r.entityId), ['a']);
  });

  test('retry re-arms a dead row and kicks a drain', () async {
    final id = await enqueue(
      entityId: 'a',
      idempotencyKey: 'k1',
      state: 'dead',
    );
    final sync = _FakeSync(onDiscard: (_) async {});
    final vm = build(sync);
    addTearDown(vm.dispose);
    await pumpEventQueue();

    expect(await vm.retry(vm.rows.single), isTrue);
    await pumpEventQueue();

    expect((await db.outboxDao.byId(id))!.state, 'pending');
    expect(sync.drains, ['co']);
  });

  test(
    'retry on a row that vanished reports failure, not a false start',
    () async {
      final id = await enqueue(
        entityId: 'a',
        idempotencyKey: 'k1',
        state: 'dead',
      );
      final sync = _FakeSync(onDiscard: (_) async {});
      final vm = build(sync);
      addTearDown(vm.dispose);
      await pumpEventQueue();
      final row = vm.rows.single;

      // Drained (or discarded from another surface) while the menu was open.
      await deleteRow(id);

      expect(await vm.retry(row), isFalse);
      expect(sync.drains, isEmpty, reason: 'nothing left to drain');
    },
  );

  test('a failed watch surfaces an error instead of a blank screen', () async {
    final dao = _ScriptedDao();
    final vm = OutboxViewModel(
      dao: dao,
      sync: _FakeSync(onDiscard: (_) async {}),
      companyId: 'co',
    );
    addTearDown(vm.dispose);
    addTearDown(dao.ctrl.close);
    await pumpEventQueue();
    expect(vm.isLoading, isTrue);

    dao.ctrl.addError(StateError('boom'));
    await pumpEventQueue();

    // Loading must not stay true, or the screen sits blank forever behind its
    // loading gate with nothing explaining why.
    expect(vm.isLoading, isFalse);
    expect(vm.error, isNotNull);

    // Still subscribed: a good emission heals it without a manual retry.
    dao.ctrl.add(const []);
    await pumpEventQueue();
    expect(vm.error, isNull);
  });

  test('rebind clears the error and re-opens the watch', () async {
    final dao = _ScriptedDao();
    final vm = OutboxViewModel(
      dao: dao,
      sync: _FakeSync(onDiscard: (_) async {}),
      companyId: 'co',
    );
    addTearDown(vm.dispose);
    addTearDown(dao.ctrl.close);
    await pumpEventQueue();
    dao.ctrl.addError(StateError('boom'));
    await pumpEventQueue();
    expect(vm.error, isNotNull);

    vm.rebind();
    await pumpEventQueue();
    expect(vm.error, isNull);

    // Pin the re-listen itself, not just the cleared field: drop `_bind()`
    // from `rebind()` and this emission lands nowhere (the old subscription
    // was cancelled), so `rows` stays empty.
    final seeded = (await db.outboxDao.byId(
      await enqueue(entityId: 'a', idempotencyKey: 'k1'),
    ))!;
    dao.ctrl.add([seeded]);
    await pumpEventQueue();
    expect(vm.rows.map((r) => r.entityId), ['a']);
  });

  test('dispose stops listening — a later write cannot notify', () async {
    await enqueue(entityId: 'a', idempotencyKey: 'k1');
    final vm = build(_FakeSync(onDiscard: (_) async {}));
    var notifications = 0;
    vm.addListener(() => notifications++);
    await pumpEventQueue();
    final before = notifications;

    vm.dispose();
    await enqueue(entityId: 'b', idempotencyKey: 'k2');
    await pumpEventQueue();

    expect(notifications, before);
  });
}
