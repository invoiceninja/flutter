import 'dart:async';

import 'package:logging/logging.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/sync/refresh_sync_constants.dart';

final _log = Logger('RefreshScheduler');

/// Foreground delta-refresh pump. While the app is active and authenticated
/// it fires `auth.refresh()` (a cheap `updated_at` delta after the first
/// full snapshot) every [kRefreshInterval], plus once on app-resume, so the
/// 13 bundled reference entities + auth/company/settings stay current without
/// the user touching anything. Mirrors the legacy admin-portal's 5-minute
/// `Timer.periodic` + resume refresh.
///
/// Not a [WidgetsBindingObserver] itself — lifecycle transitions are routed
/// in by `SyncLifecycleObserver` (one observer, one place) via [start] /
/// [stop] / [triggerNow]. Owned by `Services`; [stop] is chained into
/// `auth.onBeforeLogout` and [start] into `auth.onActiveCompanyChanged`.
///
/// A third trigger, [requestSoon], is the hosted real-time channel saying the
/// server changed. It runs the same delta through the same single-flight, but
/// is debounced and gapped on its own, shorter clock, and — unlike a tick — is
/// never dropped: a request that lands mid-refresh re-runs once that refresh
/// is done, because the refresh on the wire may have read the server before
/// the change it was told about.
class RefreshScheduler {
  RefreshScheduler({
    required AuthRepository auth,
    this.onTick,
    DateTime Function()? now,
  }) : _auth = auth,
       _now = now ?? DateTime.now;

  final AuthRepository _auth;

  /// Optional extra work run on every (gated) tick — wired to kick an outbox
  /// drain. Without it, a row parked on exponential backoff after a transient
  /// failure never retries while the device stays continuously online and
  /// foregrounded: the other drain triggers (connectivity *transition*, app
  /// resume, a new edit, company switch) don't fire in that steady state.
  final void Function()? onTick;

  final DateTime Function() _now;

  Timer? _timer;
  Future<bool>? _inFlight;
  int _lastRefreshMs = 0;

  Timer? _pushTimer;
  Completer<bool>? _pushWaiter;
  bool _pushAfterInFlight = false;

  /// Begin (or keep) the periodic pump. Idempotent — repeated calls (login,
  /// company switch, resume) reuse the existing timer.
  void start() {
    // Fire-and-forget by design: `_tick` is internally gated + never throws
    // (`.catchError`). `unawaited` makes that explicit and satisfies the
    // codebase's discarded-future lint.
    _timer ??= Timer.periodic(kRefreshInterval, (_) => unawaited(_tick()));
  }

  /// Halt the pump. Called on logout and when the app backgrounds; a timer
  /// must never fire a network refresh while the user is signed out or away.
  /// A pending [requestSoon] is dropped too, and its future completes `false`.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _pushTimer?.cancel();
    _pushTimer = null;
    _pushAfterInFlight = false;
    _completePush(false);
  }

  /// Deterministically cancel the timer on app teardown — mirrors
  /// `IdleTimeoutController.dispose()`. Just [stop]; there's no other state.
  void dispose() => stop();

  /// Immediate delta refresh on app-resume, subject to the same gating as a
  /// timer tick (min-gap, single-flight, authenticated).
  Future<void> triggerNow() => _tick();

  /// The server says something changed: run a delta refresh soon.
  ///
  /// Requests within [kPushRefreshDebounce] of each other collapse into one,
  /// and a refresh never starts within [kMinPushRefreshGap] of the last one
  /// finishing — it waits the gap out rather than being dropped. The future
  /// completes `true` once a refresh that started after this call has landed
  /// cleanly, and `false` when [stop] dropped it, the session ended, or that
  /// refresh failed.
  Future<bool> requestSoon() {
    final waiter = _pushWaiter ??= Completer<bool>();
    _schedulePush(kPushRefreshDebounce);
    return waiter.future;
  }

  void _schedulePush(Duration delay) {
    _pushTimer?.cancel();
    _pushTimer = Timer(delay, _firePush);
  }

  void _firePush() {
    _pushTimer = null;
    if (_pushWaiter == null) return;
    if (!_auth.isAuthenticated) return _completePush(false);
    if (_inFlight != null) {
      // That refresh may have read the server before the change arrived —
      // go again once it lands (see `_run`).
      _pushAfterInFlight = true;
      return;
    }
    final sinceLast = _now().millisecondsSinceEpoch - _lastRefreshMs;
    final gapLeft = kMinPushRefreshGap.inMilliseconds - sinceLast;
    if (gapLeft > 0) {
      _schedulePush(Duration(milliseconds: gapLeft));
      return;
    }
    final waiter = _pushWaiter!;
    _pushWaiter = null;
    unawaited(_run().then(waiter.complete));
  }

  void _completePush(bool refreshed) {
    final waiter = _pushWaiter;
    _pushWaiter = null;
    waiter?.complete(refreshed);
  }

  Future<void> _tick() async {
    if (!_auth.isAuthenticated) return;
    if (_inFlight != null) return; // single-flight
    final nowMs = _now().millisecondsSinceEpoch;
    if (nowMs - _lastRefreshMs < kMinRefreshGap.inMilliseconds) return;
    await _run();
  }

  /// One delta refresh, whoever asked for it. Completes `true` when it landed
  /// without an error; never throws.
  Future<bool> _run() {
    // Retry any backoff-parked outbox rows. Fire-and-forget; `drainOnce` is
    // itself single-flight per company, so an over-kick is a no-op.
    onTick?.call();

    final future = _auth
        .refresh() // delta (fullSync:false) — cheap by design
        .then((_) => true)
        .catchError((Object e, StackTrace st) {
          // A scheduler tick must never throw (offline / 401-in-flight /
          // parse blip). The next tick retries; a real 401 already routes
          // through ApiClient → logout independently.
          _log.fine('scheduled refresh skipped', e, st);
          return false;
        })
        .whenComplete(() {
          _lastRefreshMs = _now().millisecondsSinceEpoch;
          _inFlight = null;
          if (_pushAfterInFlight) {
            _pushAfterInFlight = false;
            _schedulePush(Duration.zero);
          }
        });
    _inFlight = future;
    return future;
  }
}
