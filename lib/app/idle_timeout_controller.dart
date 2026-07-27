import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';

/// Enforces the per-company **idle session timeout** (Account → Security →
/// "Web Session Timeout", stored as `company.sessionTimeout` in ms; `0` =
/// Never). The setting UI + persistence already existed; this is the missing
/// enforcement: after the configured span of no user interaction the session
/// is logged out (the router then redirects to `/login`).
///
/// Design mirrors [SyncLifecycleObserver]/[PasswordCacheLifecycleObserver]:
/// the controller owns only timing state; the actual work delegates to
/// [AuthRepository.logout]. Activity is fed in via [poke] (wired to a
/// root-level `Listener` in `main.dart`); a low-frequency periodic check
/// compares elapsed-since-last-activity against the timeout so pointer
/// events stay cheap. App-resume runs the check immediately so time spent
/// backgrounded counts toward the timeout.
class IdleTimeoutController with WidgetsBindingObserver {
  IdleTimeoutController({
    required this.auth,
    required this.company,
    required this.sync,
    DateTime Function() now = DateTime.now,
  }) : _now = now {
    _lastActivity = _now();
    auth.session.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  final AuthRepository auth;
  final CompanyRepository company;
  final SyncRepository sync;
  final DateTime Function() _now;

  StreamSubscription<void>? _companySub;
  Timer? _ticker;
  DateTime _lastActivity = DateTime.fromMillisecondsSinceEpoch(0);
  int _timeoutMs = 0;
  String? _watchedCompanyId;

  /// Record user activity. Cheap — just stamps the clock; the periodic
  /// [_check] reads it. Safe to call on every pointer event.
  void poke() => _lastActivity = _now();

  void _onSessionChanged() {
    final id = auth.session.value?.currentCompanyId;
    if (id == null || id.isEmpty) {
      _disable();
      return;
    }
    if (id == _watchedCompanyId) return;
    _watchedCompanyId = id;
    _companySub?.cancel();
    _companySub = company.watchCompany(id).listen((c) {
      final next = c?.sessionTimeout ?? 0;
      // Drift table-watches re-emit the company row on every write, including
      // the periodic /refresh that only bumps `last_sync_at` (every 5 min —
      // far below the 30-min minimum timeout). Re-arming on those no-op
      // emissions would reset the inactivity clock each refresh and the
      // timeout would never fire. Only re-arm when the configured timeout
      // actually changes (mirrors the `id == _watchedCompanyId` dedup above).
      if (next == _timeoutMs && _ticker != null) return;
      _timeoutMs = next;
      _rearm();
    });
  }

  void _disable() {
    _watchedCompanyId = null;
    _companySub?.cancel();
    _companySub = null;
    _ticker?.cancel();
    _ticker = null;
    _timeoutMs = 0;
  }

  void _rearm() {
    _ticker?.cancel();
    if (_timeoutMs <= 0) {
      _ticker = null;
      return;
    }
    // Reset the activity clock when (re)arming so a freshly-loaded or
    // changed timeout doesn't fire against stale inactivity.
    _lastActivity = _now();
    // Check often enough to be timely without being chatty: at most every
    // 30 s, at least every 5 s, never longer than the timeout itself.
    final intervalMs = _timeoutMs.clamp(5000, 30000);
    _ticker = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _check(),
    );
  }

  void _check() {
    if (_timeoutMs <= 0) return;
    if (auth.session.value == null) return;
    final idleMs = _now().difference(_lastActivity).inMilliseconds;
    if (idleMs < _timeoutMs) return;
    // Expired. Stop the ticker first so a slow logout can't double-fire,
    // then end the session (fire-and-forget — lifecycle/timer callbacks must
    // never throw; the router redirects to /login when the session clears).
    _ticker?.cancel();
    _ticker = null;
    unawaited(_expire());
  }

  /// End the session on timeout. If the outbox still holds unsynced rows, lock
  /// the session WITHOUT wiping the local DB so the edits survive to the next
  /// login — a destructive logout would silently drop the user's offline work
  /// (CLAUDE.md: "never silently drops user data"). A clean timeout (nothing
  /// pending, or everything drained) does the normal full logout.
  Future<void> _expire() async {
    final preserve = await shouldPreserveOnTimeout();
    await auth.logout(preserveLocalData: preserve);
  }

  /// Decide whether an idle timeout should PRESERVE local data (re-lock, keeping
  /// the encrypted DB + outbox) rather than do a destructive full logout: true
  /// when ANY company still has unsynced outbox rows — the full logout wipes
  /// the whole DB, so a non-active company's pending edits count just as much
  /// as the active one's. The company set comes from the OUTBOX itself
  /// (`companiesWithActiveRows`), not `session.companies`, so a company that
  /// vanished from the session envelope still protects its rows. This is a
  /// fast local read only — no network drain on the security-lock path, so
  /// the lock happens promptly; the preserved outbox drains after the next
  /// sign-in (which also clears the re-lock gate). Errs toward preserving on
  /// any error — per CLAUDE.md, never silently drop the user's offline edits.
  @visibleForTesting
  Future<bool> shouldPreserveOnTimeout() => sync.hasUnsyncedWork();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Time spent backgrounded counts as idle — check immediately on resume
    // rather than waiting for the next tick.
    _check();
  }

  void dispose() {
    auth.session.removeListener(_onSessionChanged);
    _companySub?.cancel();
    _ticker?.cancel();
  }
}
