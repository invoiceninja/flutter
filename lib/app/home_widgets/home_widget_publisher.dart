import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/home_widgets/home_widget_reader.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/domain/home_widgets/widget_snapshot_builder.dart';
import 'package:admin/utils/perf_trace.dart';

final _log = Logger('HomeWidgetPublisher');

/// How long the publisher waits after a change before rewriting the snapshot,
/// so a burst (a Sync pass, a save draining) is one write.
const Duration kWidgetWriteDebounce = Duration(seconds: 2);

/// The least time between two figure-driven widget reloads. iOS budgets a
/// widget's reloads (roughly 40–70 a day), and a Mac left open refetches the
/// dashboard every few minutes. A timer change and a sign-out reload at once.
const Duration kWidgetReloadGap = Duration(minutes: 5);

/// How long after a session starts (or the company changes) the widgets fetch:
/// past the dashboard's own boot fetch, so `maxAge` skips what it fetched.
const Duration kWidgetSessionFetchDelay = Duration(seconds: 10);

/// How often a running timer's snapshot is re-confirmed while the app runs —
/// well inside the widget's 12 h "may have been stopped elsewhere" threshold.
const Duration kWidgetHeartbeat = Duration(hours: 1);

/// Keeps the home-screen widgets' snapshot in step with the app — see
/// `docs/home-screen-widgets.md`.
///
/// Rebuilds the whole snapshot from Drift on every change (never merges into
/// the last one), writes it only when it differs, and reloads only the widget
/// kinds whose part changed, within [kWidgetReloadGap]. Every session end
/// leaves it signed out ([signOut]).
class HomeWidgetPublisher {
  HomeWidgetPublisher({
    required this.bridge,
    required this.session,
    required this.reader,
    required Stream<void> dataChanges,
    required Stream<void> fetchRequests,
    this.debounce = kWidgetWriteDebounce,
    this.reloadGap = kWidgetReloadGap,
    this.heartbeatEvery = const Duration(minutes: 30),
    this.sessionFetchDelay = kWidgetSessionFetchDelay,
    DateTime Function()? now,
    Date Function()? today,
  }) : _now = now ?? DateTime.now,
       _today = today ?? Date.today,
       _dataChanges = dataChanges,
       _fetchRequests = fetchRequests;

  final HomeWidgetBridge bridge;
  final ValueListenable<AuthSession?> session;
  final HomeWidgetReader reader;
  final Duration debounce;
  final Duration reloadGap;

  /// How often a rebuild runs with nothing else asking for one — the
  /// heartbeat's clock. Null switches it off (tests).
  final Duration? heartbeatEvery;

  /// [kWidgetSessionFetchDelay]; injectable for tests.
  final Duration sessionFetchDelay;
  final DateTime Function() _now;
  final Date Function() _today;
  final Stream<void> _dataChanges;
  final Stream<void> _fetchRequests;

  final List<StreamSubscription<void>> _subs = [];
  Timer? _pending;
  Timer? _deferredReload;
  bool _started = false;
  bool _disposed = false;

  /// Bumped by [signOut]: a rebuild that began before it must not write.
  int _generation = 0;

  WidgetTranslate? _tr;
  String _localeTag = 'en';
  bool _rtl = false;

  String? _lastBase;
  String? _lastTimers;
  String? _lastFigures;
  DateTime? _lastFigureReload;
  bool _figureReloadOwed = false;
  bool? _wroteSignedIn;
  DateTime? _lastWriteAt;
  Timer? _heartbeat;

  /// Called by the widget tree once the app's strings have loaded, and again
  /// on every language change.
  void setLocalization(
    WidgetTranslate tr, {
    required String localeTag,
    required bool rtl,
  }) {
    _tr = tr;
    _localeTag = localeTag;
    _rtl = rtl;
    if (!_started) return;
    // Signed out: the stub written before the strings loaded says "Sign in"
    // in no language at all — write it again in the app's.
    if (session.value == null) {
      if (_sessionKnown) unawaited(signOut());
      return;
    }
    schedule();
  }

  bool _timerReloadOwed = false;

  /// Redraws the Timer widget now, even if its data didn't change — after the
  /// app handled a widget's queued Stop. Its "Stopped · syncs…" label is drawn
  /// from the command file, which is gone; an unchanged snapshot (a stop that
  /// was skipped or expired) would otherwise leave the label up. The native
  /// side doesn't redraw on delete: from the snapshot it holds, that would
  /// flash the timer back to running until this write lands.
  Future<void> reloadTimer() {
    _timerReloadOwed = true;
    _pending?.cancel();
    _pending = null;
    return _rebuildSerially();
  }

  /// [key] in the app's language, or null before the strings have loaded.
  String? translate(String key, [Map<String, String>? params]) =>
      _tr?.call(key, params);

  /// [sessionKnown] is false when the boot restore failed or timed out: a
  /// null session then means "not known", not "signed out", and must not blank
  /// a widget that shows the user's real figures. It becomes known with the
  /// first session, and every sign-out after that passes through [signOut].
  void start({bool sessionKnown = true}) {
    if (_started || !bridge.supported) return;
    _started = true;
    _sessionKnown = sessionKnown;
    session.addListener(_onSession);
    _subs
      ..add(_dataChanges.listen((_) => schedule()))
      ..add(_fetchRequests.listen((_) => unawaited(fetch())))
      ..add(
        bridge.widgetsChanged.listen((_) {
          unawaited(fetch());
          schedule();
        }),
      );
    // The heartbeat's clock: a rebuild every half hour, which writes only when
    // something changed or a running timer's stamp is an hour old.
    final every = heartbeatEvery;
    if (every != null) _heartbeat = Timer.periodic(every, (_) => schedule());
    _onSession();
  }

  bool _sessionKnown = true;

  AuthSession? _lastSession;

  /// Set by [signOut]; nothing is written or fetched while it is.
  ///
  /// `onBeforeLogout` runs *before* the session is cleared (and then awaits
  /// the outbox drain), so for a while the ended session is still
  /// `session.value` — possibly a fresh copy of it (a companies-row change
  /// during the drain rebuilds it). A rebuild started then would write the
  /// figures back over the stub. Cleared only when a session starts again:
  /// after a null one, or for a different user.
  bool _blocked = false;
  String? _blockedUserId;

  /// The fetch [_onSession] defers — see [kWidgetSessionFetchDelay].
  Timer? _sessionFetch;

  void _onSession() {
    final s = session.value;
    final was = _lastSession;
    _lastSession = s;
    if (s == null) {
      // A session that never existed (a cold start signed out) still leaves
      // the signed-out stub, so a widget left from an earlier sign-in — or a
      // logout that crashed half way — says "Sign in", not stale figures.
      if (_sessionKnown && _wroteSignedIn != false) unawaited(signOut());
      return;
    }
    _sessionKnown = true;
    if (_blocked && (was == null || s.userId != _blockedUserId)) {
      _blocked = false;
      _blockedUserId = null;
    }
    if (was == null || was.currentCompanyId != s.currentCompanyId) {
      // Deferred: at a cold start or a company switch the dashboard is about
      // to fetch the same rows. Asked first, the widget's fetch would make
      // the dashboard's "fetch now" wait for it and then fetch again (see
      // `DashboardRepository._coalesced`); asked after, `maxAge` skips them.
      _sessionFetch?.cancel();
      _sessionFetch = Timer(sessionFetchDelay, () => unawaited(fetch()));
    }
    schedule();
  }

  /// Rebuild after [debounce]; a later call restarts the wait.
  void schedule() {
    if (!_started || _disposed) return;
    _pending?.cancel();
    _pending = Timer(debounce, () {
      _pending = null;
      unawaited(_rebuildSerially());
    });
  }

  /// Writes now whatever is pending — the app is going to the background,
  /// where iOS suspends it before a 2 s timer fires.
  Future<void> flush() async {
    if (_pending == null) return;
    _pending!.cancel();
    _pending = null;
    await _rebuildSerially();
  }

  Future<void>? _rebuilding;

  /// The pass queued behind [_rebuilding] — what a caller arriving during a
  /// rebuild waits for, since only it carries that caller's change.
  Completer<void>? _queued;

  /// One rebuild at a time, the last request always run: two overlapping
  /// rebuilds (a slow formatter load, a flush during a timer-fired one) could
  /// otherwise finish out of order and write the older data last — a timer
  /// just stopped shown running again.
  ///
  /// A call during a rebuild returns the *queued* pass, not the one running:
  /// [flush] on the way to the background must not return before the newest
  /// data is written.
  Future<void> _rebuildSerially() {
    if (_rebuilding != null) return (_queued ??= Completer<void>()).future;
    final pass = _rebuild().whenComplete(() {
      _rebuilding = null;
      final queued = _queued;
      _queued = null;
      if (queued != null) {
        queued.complete(_disposed ? null : _rebuildSerially());
      }
    });
    _rebuilding = pass;
    return pass;
  }

  /// Fetches what the installed widgets show for the active company (anything
  /// fresher than a minute is left alone). The cache writes it causes reach
  /// the snapshot through `dataChanges`.
  Future<void> fetch() async {
    final s = session.value;
    if (!_started || _disposed || s == null || _blocked) return;
    final installed = await bridge.installed();
    if (installed == null || installed.isEmpty) return;
    await reader.fetch(s, installed: installed, today: _today());
  }

  /// Every session end: cancel the pending write, outdate any rebuild in
  /// flight, and leave the widgets saying "Sign in". Chained into
  /// `AuthRepository.onBeforeLogout` and the data wipe.
  Future<void> signOut() async {
    _pending?.cancel();
    _pending = null;
    _deferredReload?.cancel();
    _deferredReload = null;
    _sessionFetch?.cancel();
    _blocked = true;
    _blockedUserId = session.value?.userId;
    _generation++;
    _lastBase = _lastTimers = _lastFigures = null;
    _lastWriteAt = null;
    _wroteSignedIn = false;
    if (!bridge.supported) return;
    final tr = _tr;
    await bridge.write(
      WidgetSnapshot.signedOut(
        strings: tr == null ? const {} : widgetStrings(tr),
        rtl: _rtl,
      ).toJson(writtenAt: _now()),
    );
    await bridge.deleteAllCommands();
  }

  Future<void> _rebuild() async {
    if (_disposed) return;
    final generation = _generation;
    final s = session.value;
    final tr = _tr;
    if (s == null || tr == null || _blocked) return;
    try {
      final snapshot = await traceAsync('homeWidgets.rebuild', () async {
        // Unknown (the native side didn't answer): write nothing rather than
        // a snapshot for "no widgets", which would blank every one.
        final installed = await bridge.installed();
        if (installed == null) return null;
        final today = _today();
        final showFigures = installed.kinds.any((k) => k != WidgetKind.timer);
        final showTimers = installed.kinds.contains(WidgetKind.timer);
        final wanted = {s.currentCompanyId, ...installed.companyIds};
        return buildWidgetSnapshot(
          userId: s.userId,
          activeCompanyId: s.currentCompanyId,
          appLock: s.biometricEnabled,
          rtl: _rtl,
          tr: tr,
          today: today,
          companies: [
            for (final c in s.companies)
              await reader.read(
                s,
                c,
                installed: installed,
                figures: showFigures && wanted.contains(c.id),
                // Task names and client names leave the encrypted store only
                // for a Timer widget that shows them.
                timers: showTimers && wanted.contains(c.id),
                localeTag: _localeTag,
                today: today,
              ),
          ],
        );
      });
      if (snapshot == null || generation != _generation || _disposed) return;
      await _write(snapshot, generation);
    } catch (e, st) {
      _log.warning('Home widget snapshot not written', e, st);
    }
  }

  Future<void> _write(WidgetSnapshot snapshot, int generation) async {
    final json = snapshot.comparable();
    final companies = (json['companies']! as List).cast<Map<String, Object?>>();
    final base = jsonEncode({
      ...json,
      'companies': [
        for (final c in companies)
          {
            for (final e in c.entries)
              if (e.key != 'figures' &&
                  e.key != 'timers' &&
                  e.key != 'runningCount' &&
                  e.key != 'recentTasks' &&
                  e.key != 'today')
                e.key: e.value,
          },
      ],
    });
    // Recent tasks, the running count and today's total belong with the
    // timers: any task edit changes them, and as part of the base they
    // reloaded every kind, round the figures' budget.
    final timers = jsonEncode([
      for (final c in companies)
        [c['timers'], c['runningCount'], c['recentTasks'], c['today']],
    ]);
    final figures = jsonEncode([for (final c in companies) c['figures']]);

    final baseChanged = base != _lastBase;
    final timersChanged = timers != _lastTimers;
    final figuresChanged = figures != _lastFigures;
    final now = _now();
    if (!baseChanged &&
        !timersChanged &&
        !figuresChanged &&
        !_timerReloadOwed) {
      // Nothing changed — but a widget reads `writtenAt` as "the app last
      // confirmed this", and after 12 h stops trusting a running timer
      // ("Running since 9:14"). So while one runs, the app re-confirms it
      // hourly, without a reload: the widget picks the stamp up at its next.
      final runs = companies.any(
        (c) => (c['timers'] as List?)?.isNotEmpty ?? false,
      );
      final last = _lastWriteAt;
      if (!runs || (last != null && now.difference(last) < kWidgetHeartbeat)) {
        return;
      }
      final ok = await bridge.write(
        snapshot.toJson(writtenAt: now),
        reload: const {},
      );
      if (ok && generation == _generation) _lastWriteAt = now;
      return;
    }

    final reload = <WidgetKind>{};
    if (baseChanged) {
      reload.addAll(WidgetKind.values);
    } else {
      if (timersChanged || _timerReloadOwed) reload.add(WidgetKind.timer);
      if (figuresChanged || _figureReloadOwed) {
        final last = _lastFigureReload;
        if (last == null || now.difference(last) >= reloadGap) {
          reload
            ..add(WidgetKind.snapshot)
            ..add(WidgetKind.attention);
        } else {
          _owe(reloadGap - now.difference(last));
        }
      }
    }
    if (reload.contains(WidgetKind.snapshot)) {
      _lastFigureReload = now;
      _figureReloadOwed = false;
      _deferredReload?.cancel();
      _deferredReload = null;
    }

    final ok = await bridge.write(
      snapshot.toJson(writtenAt: now),
      reload: reload,
    );
    // Not written: nothing is remembered, so the next rebuild tries again.
    if (!ok) return;
    if (reload.contains(WidgetKind.timer)) _timerReloadOwed = false;
    // A sign-out during the write: its stub landed after this one, and these
    // must stay cleared — else the same user signing back in rebuilds an
    // identical snapshot, finds nothing changed, and the widget stays on
    // "Sign in".
    if (generation != _generation) return;
    _lastBase = base;
    _lastTimers = timers;
    _lastFigures = figures;
    _lastWriteAt = now;
    _wroteSignedIn = true;
  }

  /// A figure change landed inside [reloadGap]: the file already holds it, so
  /// the widget shows it at its next timeline reload anyway; this makes that
  /// reload happen when the gap ends rather than at midnight.
  void _owe(Duration wait) {
    _figureReloadOwed = true;
    if (_deferredReload != null) return;
    _deferredReload = Timer(wait, () {
      _deferredReload = null;
      if (_disposed || !_figureReloadOwed) return;
      // Forces the figure kinds through on the next write.
      _lastFigures = null;
      schedule();
    });
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _deferredReload?.cancel();
    _heartbeat?.cancel();
    _sessionFetch?.cancel();
    session.removeListener(_onSession);
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
  }
}
