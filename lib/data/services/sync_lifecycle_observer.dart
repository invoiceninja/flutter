import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/realtime/realtime_service.dart';
import 'package:admin/data/services/refresh_scheduler.dart';

/// Drives the three foreground sync mechanisms off app lifecycle transitions:
///   * **Outbox drain** on resume — a mutation written while backgrounded
///     would otherwise sit until the next user action. Combined with the
///     connectivity listener and the post-`enqueueMutation` hook, this closes
///     the last common gap where the user sees "unsynced changes" despite
///     having been online.
///   * **Delta refresh pump** ([RefreshScheduler]) — paused while
///     backgrounded (no network ticks while away / signed out), kicked once
///     immediately on resume, then resumed on its periodic cadence.
///   * **Real-time socket** ([RealtimeService]) — closed while backgrounded
///     and reopened on resume; the resume delta covers what it missed.
///
/// Mirrors [PasswordCacheLifecycleObserver]: the lifecycle hook is the only
/// state, the work itself is delegated to existing repositories.
class SyncLifecycleObserver with WidgetsBindingObserver {
  SyncLifecycleObserver({
    required this.auth,
    required this.sync,
    required this.refreshScheduler,
    this.realtime,
  });

  final AuthRepository auth;
  final SyncRepository sync;
  final RefreshScheduler refreshScheduler;
  final RealtimeService? realtime;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Match PasswordCacheLifecycleObserver: only `paused`/`detached` mean the
    // app is genuinely backgrounded. iOS fires `inactive` (and Android can
    // surface `hidden`) on transient interruptions — notification shade,
    // app-switcher peek, an incoming call — and stopping here would churn
    // the timer (stop → resume → triggerNow) on every such blip.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // No periodic network refresh while the app isn't in front of the user.
      refreshScheduler.stop();
      realtime?.pause();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    realtime?.resume();
    final companyId = auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    // Fire-and-forget: the row will retry on its own backoff if the drain
    // fails. We never want lifecycle callbacks to throw.
    sync.drainOnce(companyId: companyId);
    // Catch up immediately, then keep the periodic pump running. Both are
    // gated internally (authenticated + min-gap + single-flight).
    unawaited(refreshScheduler.triggerNow());
    refreshScheduler.start();
  }
}
