import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';

class _CountingApi implements ActivitiesApi {
  _CountingApi({
    this.rows = const [],
    this.cached,
    this.gate,
    this.commentRows = const [],
    this.commentError,
    this.refusesEntity = false,
    this.ignoresActivityTypeFilter = false,
  });

  /// The unfiltered feed.
  final List<ActivityApi> rows;
  final List<ActivityApi>? cached;

  /// What a comments-only (`activityTypeIds:`) fetch answers.
  final List<ActivityApi> commentRows;
  final Object? commentError;

  /// When set, the next comments-only fetch parks on it.
  Completer<void>? commentGate;

  /// The server 422s the entity name, as one without `recurring_expense`
  /// in `ShowActivityRequest` does. Remembered after the first refusal, as
  /// the real API remembers it.
  final bool refusesEntity;
  bool _refused = false;

  @override
  final bool ignoresActivityTypeFilter;

  /// When supplied, the first fetch parks on this until the test completes it —
  /// the only way to hold a request genuinely in flight while something else
  /// happens.
  final Completer<void>? gate;

  int fetches = 0;
  int commentFetches = 0;
  int peeks = 0;

  @override
  bool isEntityUnsupported(String entity) => _refused;

  @override
  List<ActivityApi>? peekForEntity({
    required String entity,
    required String entityId,
    Set<int>? activityTypeIds,
  }) {
    peeks++;
    return activityTypeIds == null ? cached : null;
  }

  @override
  Future<List<ActivityApi>> fetchForEntity({
    required String entity,
    required String entityId,
    int rows = kEntityActivityRows,
    Set<int>? activityTypeIds,
  }) async {
    if (activityTypeIds != null) {
      commentFetches++;
      final gate = commentGate;
      if (gate != null) await gate.future;
      if (commentError != null) throw commentError!;
      return commentRows;
    }
    fetches++;
    if (refusesEntity) {
      _refused = true;
      throw ActivityFeedUnsupportedException(entity);
    }
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

ActivityApi _row({
  required int typeId,
  String id = 'a1',
  int createdAt = 1778990481,
  ActivityLabelApi? purchaseOrder,
  ActivityLabelApi? recurringExpense,
  ActivityLabelApi? expense,
}) => ActivityApi(
  id: id,
  activityTypeId: typeId,
  notes: '',
  createdAt: createdAt,
  ip: '',
  purchaseOrder: purchaseOrder,
  recurringExpense: recurringExpense,
  expense: expense,
);

/// A feed that fills the window: one comment, the rest system rows.
List<ActivityApi> _fullWindow({String commentId = 'c-new'}) => [
  _row(typeId: 141, id: commentId, createdAt: 1778990481),
  for (var i = 1; i < kEntityActivityRows; i++)
    _row(typeId: 4, id: 'sys$i', createdAt: 1778990481 - i),
];

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
  String entityWireName = 'client',
  String entityId = 'c1',
  Duration debounce = Duration.zero,
}) => EntityActivityViewModel(
  api: api,
  outbox: outbox ?? _Outbox(),
  companyId: 'co',
  entityWireName: entityWireName,
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

  group('comments past the window (invoiceninja/invoiceninja#13365)', () {
    test(
      'a full window asks again for the comments alone, merged by id',
      () async {
        final api = _CountingApi(
          rows: _fullWindow(),
          commentRows: [
            // The one the window already has — must not appear twice.
            _row(typeId: 141, id: 'c-new', createdAt: 1778990481),
            // Older than every row in the window, so the window cut it off.
            _row(typeId: 141, id: 'c-old', createdAt: 1700000000),
          ],
        );
        final vm = _build(api);
        await vm.refresh();
        expect(api.commentFetches, 1);
        expect(vm.comments.map((a) => a.id), ['c-new', 'c-old']);
        // The Activity tab keeps the window as fetched.
        expect(vm.activities, hasLength(kEntityActivityRows));
        vm.dispose();
      },
    );

    test(
      'a feed shorter than the window holds every comment — one request',
      () async {
        final api = _CountingApi(
          rows: [
            _row(typeId: 141, id: 'c1'),
            _row(typeId: 4, id: 's1'),
          ],
        );
        final vm = _build(api);
        await vm.refresh();
        expect(api.fetches, 1);
        expect(api.commentFetches, 0);
        expect(vm.comments.map((a) => a.id), ['c1']);
        vm.dispose();
      },
    );

    test('a server that ignores the filter is not asked again', () async {
      final api = _CountingApi(
        rows: _fullWindow(),
        ignoresActivityTypeFilter: true,
      );
      final vm = _build(api);
      await vm.refresh();
      expect(api.commentFetches, 0);
      expect(vm.comments.map((a) => a.id), ['c-new']);
      vm.dispose();
    });

    test(
      'a failed follow-up keeps the window\'s comments and is no error',
      () async {
        final api = _CountingApi(
          rows: _fullWindow(),
          commentError: const NetworkException('offline'),
        );
        final vm = _build(api);
        await vm.refresh();
        expect(api.commentFetches, 1);
        expect(vm.error, isNull);
        expect(vm.comments.map((a) => a.id), ['c-new']);
        vm.dispose();
      },
    );

    test(
      'the merged comments survive the next refresh until it re-lands',
      () async {
        // Kept across refreshes, so the older comments don't vanish for the
        // round trip between the main feed landing and the follow-up.
        final api = _CountingApi(
          rows: _fullWindow(),
          commentRows: [_row(typeId: 141, id: 'c-old', createdAt: 1700000000)],
        );
        final vm = _build(api);
        await vm.refresh();
        final gate = api.commentGate = Completer<void>();
        final second = vm.refresh();
        // Let the main feed land; the follow-up is parked on the gate.
        await Future<void>.delayed(Duration.zero);
        expect(api.fetches, 2);
        expect(api.commentFetches, 2);
        expect(vm.comments.map((a) => a.id), ['c-new', 'c-old']);
        gate.complete();
        await second;
        expect(vm.comments.map((a) => a.id), ['c-new', 'c-old']);
        vm.dispose();
      },
    );
  });

  test('a full window paints before the follow-up lands', () async {
    // The follow-up must not hold the Activity tab and the card back a round
    // trip on exactly the busiest records.
    final api = _CountingApi(rows: _fullWindow())
      ..commentGate = Completer<void>();
    final vm = _build(api);
    final painted = <int>[];
    vm.addListener(() => painted.add(vm.activities.length));
    final inFlight = vm.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(api.commentFetches, 1, reason: 'parked on the gate');
    expect(painted, contains(kEntityActivityRows));
    api.commentGate!.complete();
    await inFlight;
    vm.dispose();
  });

  group('a server with no feed for the record type', () {
    test(
      'reads as unsupported, not as an error, and is not asked again',
      () async {
        final api = _CountingApi(refusesEntity: true);
        final vm = _build(api, entityWireName: 'recurring_expense');
        await vm.refresh();
        expect(vm.isUnsupported, isTrue);
        expect(vm.error, isNull);
        expect(vm.hasSettled, isTrue);
        await vm.refresh();
        expect(api.fetches, 1, reason: 'the refusal is remembered');
        expect(vm.isUnsupported, isTrue);
        vm.dispose();
      },
    );
  });

  group('an expense feed (the expense_id collision)', () {
    const po = ActivityLabelApi(label: 'PO-0005', hashedId: 'po5');
    const rec = ActivityLabelApi(label: 'R-0002', hashedId: 'rec2');
    final feed = [
      // A purchase order's comment, filed under expense #N by id collision.
      _row(typeId: 141, id: 'po-note', purchaseOrder: po, createdAt: 30),
      // A recurring expense's, the same way.
      _row(typeId: 141, id: 'rec-note', recurringExpense: rec, createdAt: 20),
      // The expense's own comment.
      _row(typeId: 141, id: 'own-note', createdAt: 10),
      // A system row naming the recurring expense that generated it — real.
      _row(typeId: 4, id: 'generated', recurringExpense: rec, createdAt: 5),
    ];

    test('drops the notes that belong to another record', () async {
      final api = _CountingApi(rows: feed);
      final vm = _build(api, entityWireName: 'expense');
      await vm.refresh();
      expect(vm.comments.map((a) => a.id), ['own-note']);
      expect(vm.activities.map((a) => a.id), ['own-note', 'generated']);
      vm.dispose();
    });

    test('keeps them on any other host', () async {
      // A PO's note copies the PO's client_id, so it belongs in that client's
      // feed — the collision is the expense column alone.
      final api = _CountingApi(rows: feed);
      final vm = _build(api, entityWireName: 'client');
      await vm.refresh();
      expect(vm.comments.map((a) => a.id), ['po-note', 'rec-note', 'own-note']);
      vm.dispose();
    });
  });
}
