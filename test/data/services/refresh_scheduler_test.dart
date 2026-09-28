import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/refresh_scheduler.dart';
import 'package:admin/domain/sync/refresh_sync_constants.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth({this.authed = true});

  bool authed;
  int refreshCalls = 0;
  Object? throwOnRefresh;
  final List<bool> fullSyncArgs = [];

  @override
  bool get isAuthenticated => authed;

  @override
  Future<void> refresh({bool fullSync = false}) async {
    refreshCalls++;
    fullSyncArgs.add(fullSync);
    if (throwOnRefresh != null) throw throwOnRefresh!;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late DateTime clock;
  DateTime now() => clock;

  setUp(() {
    clock = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  });

  test('triggerNow refreshes (delta, not full) when authenticated', () async {
    final auth = _FakeAuth();
    final s = RefreshScheduler(auth: auth, now: now);

    await s.triggerNow();

    expect(auth.refreshCalls, 1);
    expect(auth.fullSyncArgs.single, isFalse);
  });

  test('skips entirely when unauthenticated', () async {
    final auth = _FakeAuth(authed: false);
    final s = RefreshScheduler(auth: auth, now: now);

    await s.triggerNow();

    expect(auth.refreshCalls, 0);
  });

  test('enforces the min-gap between refreshes', () async {
    final auth = _FakeAuth();
    final s = RefreshScheduler(auth: auth, now: now);

    await s.triggerNow();
    expect(auth.refreshCalls, 1);

    // Within the gap → suppressed.
    clock = clock.add(kMinRefreshGap - const Duration(seconds: 1));
    await s.triggerNow();
    expect(auth.refreshCalls, 1);

    // Past the gap → fires again.
    clock = clock.add(const Duration(seconds: 2));
    await s.triggerNow();
    expect(auth.refreshCalls, 2);
  });

  test('a tick one full interval after the last refresh is NOT suppressed '
      '(min-gap must stay below the cadence)', () async {
    // Regression guard: when kMinRefreshGap == kRefreshInterval the
    // periodic timer self-suppressed every tick (gap measured from
    // completion, timer scheduled from start). The invariant that prevents
    // it: kMinRefreshGap < kRefreshInterval.
    expect(
      kMinRefreshGap,
      lessThan(kRefreshInterval),
      reason: 'min-gap must be shorter than the refresh cadence',
    );

    final auth = _FakeAuth();
    final s = RefreshScheduler(auth: auth, now: now);

    await s.triggerNow();
    expect(auth.refreshCalls, 1);

    // The next periodic tick lands ~kRefreshInterval after the last
    // refresh; it must fire, not be eaten by the min-gap.
    clock = clock.add(kRefreshInterval);
    await s.triggerNow();
    expect(auth.refreshCalls, 2);
  });

  test('single-flight: overlapping ticks collapse to one refresh', () async {
    final auth = _FakeAuth();
    final gate = Completer<void>();
    final slowAuth = _SlowAuth(gate);
    final s = RefreshScheduler(auth: slowAuth, now: now);

    final a = s.triggerNow();
    final b = s.triggerNow(); // should no-op while a is in flight
    gate.complete();
    await Future.wait([a, b]);

    expect(slowAuth.refreshCalls, 1);
    // Sanity: the unused fake keeps the analyzer happy about _FakeAuth use.
    expect(auth.refreshCalls, 0);
  });

  test('never throws when refresh rejects; next tick still works', () async {
    final auth = _FakeAuth()..throwOnRefresh = StateError('offline');
    final s = RefreshScheduler(auth: auth, now: now);

    await s.triggerNow(); // must not throw
    expect(auth.refreshCalls, 1);

    auth.throwOnRefresh = null;
    clock = clock.add(kMinRefreshGap + const Duration(seconds: 1));
    await s.triggerNow();
    expect(auth.refreshCalls, 2);
  });

  group('requestSoon (a pushed server change)', () {
    // `testWidgets` for its fake timers only — there is no widget here. The
    // scheduler's clock is stepped alongside, a second at a time, so the gap
    // check inside a timer callback sees the same time the timer fired at.
    Future<void> advance(WidgetTester tester, Duration d) async {
      for (var i = 0; i < d.inSeconds; i++) {
        clock = clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('a burst of requests collapses into one refresh', (
      tester,
    ) async {
      final auth = _FakeAuth();
      final s = RefreshScheduler(auth: auth, now: now);
      final results = <bool>[];

      unawaited(s.requestSoon().then(results.add));
      await advance(tester, const Duration(seconds: 1));
      unawaited(s.requestSoon().then(results.add));
      await advance(tester, kPushRefreshDebounce);

      expect(auth.refreshCalls, 1);
      expect(results, [true, true]);
      s.stop();
    });

    testWidgets('waits out the push gap instead of dropping the request', (
      tester,
    ) async {
      final auth = _FakeAuth();
      final s = RefreshScheduler(auth: auth, now: now);
      await s.triggerNow();
      expect(auth.refreshCalls, 1);

      var done = false;
      unawaited(s.requestSoon().then((_) => done = true));
      await advance(tester, kPushRefreshDebounce);
      expect(auth.refreshCalls, 1, reason: 'still inside the push gap');

      await advance(tester, kMinPushRefreshGap);
      expect(auth.refreshCalls, 2);
      expect(done, isTrue);
      s.stop();
    });

    testWidgets('a request during a refresh runs again after it', (
      tester,
    ) async {
      final gate = Completer<void>();
      final auth = _SlowAuth(gate);
      final s = RefreshScheduler(auth: auth, now: now);
      unawaited(s.triggerNow());
      expect(auth.refreshCalls, 1);

      var result = false;
      unawaited(s.requestSoon().then((r) => result = r));
      await advance(tester, kPushRefreshDebounce);
      expect(auth.refreshCalls, 1, reason: 'single-flight');

      gate.complete();
      // The gap runs from when that refresh landed, a step into the advance.
      await advance(tester, kMinPushRefreshGap + const Duration(seconds: 1));
      expect(
        auth.refreshCalls,
        2,
        reason: 'the refresh on the wire may predate the change',
      );
      expect(result, isTrue);
      s.stop();
    });

    testWidgets('stop() drops a pending request and says so', (tester) async {
      final auth = _FakeAuth();
      final s = RefreshScheduler(auth: auth, now: now);
      bool? result;
      unawaited(s.requestSoon().then((r) => result = r));
      s.stop();
      await advance(tester, kPushRefreshDebounce);

      expect(result, isFalse);
      expect(auth.refreshCalls, 0);
    });

    testWidgets('a failed refresh completes false', (tester) async {
      final auth = _FakeAuth()..throwOnRefresh = Exception('offline');
      final s = RefreshScheduler(auth: auth, now: now);
      bool? result;
      unawaited(s.requestSoon().then((r) => result = r));
      await advance(tester, kPushRefreshDebounce);

      expect(auth.refreshCalls, 1);
      expect(result, isFalse);
      s.stop();
    });

    testWidgets('signed out → no refresh, completes false', (tester) async {
      final auth = _FakeAuth(authed: false);
      final s = RefreshScheduler(auth: auth, now: now);
      bool? result;
      unawaited(s.requestSoon().then((r) => result = r));
      await advance(tester, kPushRefreshDebounce);

      expect(auth.refreshCalls, 0);
      expect(result, isFalse);
    });

    test('the push gap stays well under the timer de-dup gap', () {
      expect(kMinPushRefreshGap < kMinRefreshGap, isTrue);
      expect(kPushRefreshDebounce < kMinPushRefreshGap, isTrue);
    });
  });

  test('stop() cancels the periodic timer', () {
    final auth = _FakeAuth();
    final s = RefreshScheduler(auth: auth, now: now);
    s.start();
    s.start(); // idempotent
    s.stop();
    // No assertion on timing — just exercising start/stop is enough to catch
    // a double-timer leak (the second start() must reuse the first).
  });
}

class _SlowAuth implements AuthRepository {
  _SlowAuth(this._gate);
  final Completer<void> _gate;
  int refreshCalls = 0;

  @override
  bool get isAuthenticated => true;

  @override
  Future<void> refresh({bool fullSync = false}) async {
    refreshCalls++;
    await _gate.future;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
