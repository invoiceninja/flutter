import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';

class _CountingApi implements ActivitiesApi {
  _CountingApi({this.rows = const [], this.cached, this.gate});

  final List<ActivityApi> rows;
  final List<ActivityApi>? cached;

  /// When supplied, the first fetch parks on this until the test completes it —
  /// the only way to hold a request genuinely in flight while something else
  /// happens.
  final Completer<void>? gate;

  int fetches = 0;
  int peeks = 0;

  @override
  List<ActivityApi>? peekForEntity({
    required String entity,
    required String entityId,
  }) {
    peeks++;
    return cached;
  }

  @override
  Future<List<ActivityApi>> fetchForEntity({
    required String entity,
    required String entityId,
    int rows = kEntityActivityRows,
  }) async {
    fetches++;
    if (fetches == 1 && gate != null) await gate!.future;
    return this.rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Outbox implements OutboxDao {
  _Outbox([this.rows = const []]);

  final List<OutboxRow> rows;
  final _controller = StreamController<List<OutboxRow>>.broadcast();

  @override
  Stream<List<OutboxRow>> watchPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    MutationKind? kind,
  }) async* {
    yield rows;
    yield* _controller.stream;
  }

  void emit(List<OutboxRow> next) => _controller.add(next);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ActivityApi _row({required int typeId, String id = 'a1'}) => ActivityApi(
  id: id,
  activityTypeId: typeId,
  notes: '',
  createdAt: 1778990481,
  ip: '',
);

OutboxRow _pending() => OutboxRow(
  id: 1,
  companyId: 'co',
  entityType: 'client',
  entityId: 'c1',
  mutationKind: 'add_comment',
  payload: '{"notes":"hi"}',
  idempotencyKey: 'k',
  state: 'pending',
  attempts: 0,
  createdAt: 0,
  nextAttemptAt: 0,
  requiresPassword: false,
);

EntityActivityViewModel _build(
  _CountingApi api, {
  OutboxDao? outbox,
  String entityId = 'c1',
  Duration debounce = Duration.zero,
}) => EntityActivityViewModel(
  api: api,
  outbox: outbox ?? _Outbox(),
  companyId: 'co',
  entityWireName: 'client',
  entityId: entityId,
  kickDebounce: debounce,
);

void main() {
  test('kick is idempotent — a burst of mounts costs one fetch', () async {
    final api = _CountingApi();
    final vm = _build(api)
      ..kick()
      ..kick()
      ..kick();
    await Future<void>.delayed(Duration.zero);
    expect(api.fetches, 1);
    vm.dispose();
  });

  test('a tmp_ record never reaches the wire', () async {
    // `ShowActivityRequest` validates `entity_id` with `Rule::exists`, so this
    // could only ever come back 422.
    final api = _CountingApi();
    final vm = _build(api, entityId: 'tmp_abc')..kick();
    await Future<void>.delayed(Duration.zero);
    expect(api.fetches, 0);
    vm.dispose();
  });

  test('a cached feed paints immediately and still refetches', () async {
    final api = _CountingApi(
      cached: [_row(typeId: 141)],
      rows: [
        _row(typeId: 141, id: 'a2'),
        _row(typeId: 4, id: 'a3'),
      ],
    );
    final vm = _build(api)..kick();
    // Painted from the peek before the request has even gone out.
    expect(vm.comments, hasLength(1));
    expect(vm.hasAnyComment, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(api.fetches, 1);
    expect(vm.activities, hasLength(2));
    expect(vm.comments, hasLength(1));
    vm.dispose();
  });

  test('a comment queued before the screen opened renders on the first '
      'emission', () async {
    // The old shape leaned on a `StreamBuilder` rendering that first emission
    // while the VM used it only to seed a counter — so an offline comment
    // written earlier stayed invisible until a second emission that might
    // never come.
    final vm = _build(_CountingApi(), outbox: _Outbox([_pending()]));
    await Future<void>.delayed(Duration.zero);
    expect(vm.pendingRows, hasLength(1));
    expect(vm.hasAnyComment, isTrue);
    vm.dispose();
  });

  test(
    'a drain refetches so the confirmed row replaces the optimistic one',
    () async {
      final api = _CountingApi();
      final outbox = _Outbox([_pending()]);
      final vm = _build(api, outbox: outbox)..kick();
      await Future<void>.delayed(Duration.zero);
      expect(api.fetches, 1);
      outbox.emit(const []);
      await Future<void>.delayed(Duration.zero);
      expect(api.fetches, 2);
      vm.dispose();
    },
  );

  test('dispose cancels the pending kick timer', () async {
    // Named for what it checks: `dispose()` cancels the debounce, so no
    // request goes out and no `Timer` outlives the tree.
    final api = _CountingApi();
    final vm = _build(api, debounce: const Duration(milliseconds: 50))..kick();
    vm.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(api.fetches, 0);
  });

  test('dispose mid-fetch does not notify a torn-down notifier', () async {
    // The ordering the guard exists for, which the kick/dispose pair above
    // never reaches: `refresh()` must already be awaiting the API.
    final api = _CountingApi();
    final vm = _build(api);
    final inFlight = vm.refresh();
    vm.dispose();
    // `ChangeNotifier` throws on a post-dispose notify, so completing without
    // an exception is the assertion.
    await inFlight;
  });

  test('a drain that lands mid-fetch is deferred, not dropped', () async {
    // The in-flight request was issued BEFORE `addNote` reached the server, so
    // its response cannot hold the new note — and Drift emits this falling
    // edge exactly once. Swallowing it made a just-posted comment disappear
    // when the stale response landed, taking the card with it.
    final gate = Completer<void>();
    final api = _CountingApi(gate: gate);
    final outbox = _Outbox([_pending()]);
    final vm = _build(api, outbox: outbox);
    // Let the seeded emission land first: `_Outbox` yields it before it
    // subscribes to the broadcast controller, and a broadcast controller drops
    // anything added while nobody is listening.
    await Future<void>.delayed(Duration.zero);
    final first = vm.refresh();
    await Future<void>.delayed(Duration.zero);
    // The request is parked on the gate, so this drain genuinely lands
    // mid-fetch — the window the old `!_isLoading` guard swallowed.
    outbox.emit(const []);
    await Future<void>.delayed(Duration.zero);
    expect(api.fetches, 1, reason: 'still parked on the gate');
    gate.complete();
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(api.fetches, 2, reason: 'the deferred refetch must still run');
    vm.dispose();
  });
}
