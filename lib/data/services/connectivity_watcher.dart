import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Surface the sync layer cares about:
///   * [onOnline] fires when the device transitions **into** an online
///     state (so listeners don't churn on going-offline events),
///   * a one-shot [isOnline] read used by the company-switch dialog to
///     decide whether to silently drain or prompt the user, and
///   * [isOnlineStream], a single-subscription stream of the current state (a
///     fresh stream per getter access) — emits the current value on listen and
///     again on every transition. The OfflineBanner consumes it (each
///     `StreamBuilder` reads the getter, so each gets its own stream).
///
/// "Online" = any [ConnectivityResult] other than [ConnectivityResult.none].
/// Mobile / wifi / ethernet / vpn / other are treated the same: the sync
/// layer just needs the radio up; the request itself fails and retries via
/// the outbox if the link is flaky.
///
/// **Fault tolerance (Linux / Snap).** `connectivity_plus` reaches
/// NetworkManager over the system D-Bus on Linux. Under Snap `strict`
/// confinement that call is blocked by AppArmor unless the
/// (non-auto-connected) `network-manager` interface is plugged, so the probe
/// can throw. Connectivity detection is only an optimization — actual HTTP
/// works under the `network` plug regardless — so [_LiveConnectivityWatcher]
/// degrades a failed or stalled probe to "assume online" rather than letting
/// it break a save. See docs/setup.md § Linux desktop / Snap.
///
/// Use [ConnectivityWatcher.live] in production, [ConnectivityWatcher.fixed]
/// in tests where you want a deterministic state without the
/// `connectivity_plus` platform channel.
abstract class ConnectivityWatcher {
  ConnectivityWatcher();

  factory ConnectivityWatcher.live() {
    final connectivity = Connectivity();
    return _LiveConnectivityWatcher.raw(
      check: connectivity.checkConnectivity,
      changes: () => connectivity.onConnectivityChanged,
    );
  }

  /// Test-only seam over the raw `connectivity_plus` surface so the
  /// fault-tolerance (degrade-on-error / probe-then-subscribe) can be
  /// exercised without the platform channel. [check] stands in for
  /// `Connectivity.checkConnectivity`, [changes] for
  /// `Connectivity.onConnectivityChanged`.
  @visibleForTesting
  factory ConnectivityWatcher.liveWith({
    required Future<List<ConnectivityResult>> Function() check,
    required Stream<List<ConnectivityResult>> Function() changes,
  }) = _LiveConnectivityWatcher.raw;

  /// Test-only — always reports [online], emits one fake transition if the
  /// listener subscribes while [online] is true (so wiring-up code can be
  /// exercised), and never emits otherwise.
  factory ConnectivityWatcher.fixed({required bool online}) =
      _FixedConnectivityWatcher;

  Future<bool> get isOnline;

  Stream<void> get onOnline;

  /// Single-subscription stream of the current online state (a fresh stream per
  /// getter access). Emits the current value on listen and again on every
  /// transition. The `bool` is `true` when online, `false` when offline.
  Stream<bool> get isOnlineStream;
}

class _LiveConnectivityWatcher extends ConnectivityWatcher {
  _LiveConnectivityWatcher.raw({required this.check, required this.changes});

  /// Raw probe — `Connectivity.checkConnectivity` in production.
  final Future<List<ConnectivityResult>> Function() check;

  /// Raw change-stream factory — `() => Connectivity.onConnectivityChanged` in
  /// production. A factory (not a stored stream) so each listen re-derives it,
  /// matching the plugin's broadcast getter.
  final Stream<List<ConnectivityResult>> Function() changes;

  /// Cap the probe so a *stalled* D-Bus call degrades like a thrown one.
  /// `GenericEditViewModel.save()` awaits [isOnline] with no surrounding
  /// timeout, so an unbounded probe would hang the save.
  static const _probeTimeout = Duration(seconds: 5);

  /// One-shot connectivity read — the online bool, or `null` when the probe is
  /// unavailable or stalled (e.g. NetworkManager's D-Bus call blocked by
  /// AppArmor under Snap strict confinement, or hanging). The probe is only an
  /// optimization — HTTP works under the `network` plug regardless — so callers
  /// degrade `null` to "assume online".
  Future<bool?> _probe() async {
    try {
      return _anyOnline(await check().timeout(_probeTimeout));
    } catch (_) {
      return null;
    }
  }

  // `_probe()` → null means "couldn't determine", which we treat as online:
  // HTTP works under the `network` plug even when the NetworkManager probe is
  // blocked, so this keeps inline 422 validation in the common (online) case.
  // Trade-off for the narrow Snap-without-plug-and-genuinely-offline case:
  // `save()` waits up to its 30 s timeout before the optimistic "saving in
  // background" fallback (no data loss). Connecting `network-manager` avoids it.
  @override
  Future<bool> get isOnline async => (await _probe()) ?? true;

  @override
  Stream<void> get onOnline async* {
    // Probe before subscribing. `connectivity_plus` runs its D-Bus connect
    // inside an un-awaited async `onListen`, so a blocked/failed connect
    // escapes as an unhandled *zone* error — not a stream error we could
    // `.handleError`. If the probe fails we stay inert rather than trigger that
    // path. (This also means a *transient* probe failure at subscription — rare
    // off-Snap — leaves auto-drain-on-reconnect inactive for the session; the
    // other drain triggers — on-enqueue, save-time, app-resume, company-switch
    // — still flush the outbox.)
    if (await _probe() == null) return;
    var wasOnline = false;
    yield* changes()
        .map(_anyOnline)
        .where((online) {
          final transitioned = online && !wasOnline;
          wasOnline = online;
          return transitioned;
        })
        .map((_) {})
        // Belt-and-suspenders for any error delivered *through* the stream
        // after a healthy probe (the probe gate above handles the common
        // onListen-throw case).
        .handleError((Object _) {});
  }

  @override
  Stream<bool> get isOnlineStream async* {
    // Seed with a single probe, then subscribe — the same one-read-then-listen
    // ordering as before (a second read would race a transition arriving
    // between the two calls). A failed probe means "assume online, don't
    // subscribe" — subscribing would re-trigger the throwing `onListen`.
    final seed = await _probe();
    if (seed == null) {
      yield true;
      return;
    }
    var last = seed;
    yield last;
    try {
      await for (final results in changes()) {
        final next = _anyOnline(results);
        if (next != last) {
          last = next;
          yield next;
        }
      }
    } catch (_) {
      // A stream error delivered after a healthy probe — stop emitting
      // transitions and keep the last known state.
    }
  }

  static bool _anyOnline(List<ConnectivityResult> results) {
    for (final r in results) {
      if (r != ConnectivityResult.none) return true;
    }
    return false;
  }
}

class _FixedConnectivityWatcher extends ConnectivityWatcher {
  _FixedConnectivityWatcher({required this.online});

  final bool online;

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<void> get onOnline => const Stream<void>.empty();

  @override
  Stream<bool> get isOnlineStream => Stream<bool>.value(online);
}
