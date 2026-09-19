import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _log = Logger('ResyncController');

/// Where an in-flight "Sync" pass currently is.
enum ResyncPhase {
  idle,

  /// Prologue: pushing queued outbox edits, then the full auth refresh. The
  /// step total isn't known yet — the enabled-module mask is deliberately read
  /// *after* the refresh, so a just-changed module setting is honored.
  preparing,

  /// Walking the per-entity download plan; [ResyncProgress.total] is exact.
  downloading,
}

/// Snapshot of the app-wide "Sync" pass, published by [ResyncController].
@immutable
class ResyncProgress {
  const ResyncProgress.idle()
    : phase = ResyncPhase.idle,
      companyId = null,
      completed = 0,
      total = 0;

  const ResyncProgress.preparing(String this.companyId)
    : phase = ResyncPhase.preparing,
      completed = 0,
      total = 0;

  const ResyncProgress.downloading({
    required String this.companyId,
    required this.completed,
    required this.total,
  }) : phase = ResyncPhase.downloading;

  final ResyncPhase phase;

  /// Company the in-flight pass is downloading; null when idle. [isRunning]
  /// alone would put a spinner on the wrong workspace, so compare against the
  /// active company via [isRunningFor] before rendering.
  ///
  /// A pass no longer survives a company switch: `Services.build` calls
  /// [cancel] from `auth.onActiveCompanyChanged`. It used to, on the reasoning
  /// that "its writes are all `company_id` scoped" — but that controls where
  /// rows *land*, not which token *fetched* them. `ApiClient` resolves
  /// credentials at request-build time, so the remaining entities of a pass
  /// started in company A were fetched under B's token and written under
  /// `company_id = A`.
  final String? companyId;

  final int completed;

  /// 0 while still in the [ResyncPhase.preparing] prologue.
  final int total;

  bool get isRunning => phase != ResyncPhase.idle;

  bool isRunningFor(String id) => isRunning && companyId == id;

  /// 0..1, or null while [total] is unknown — feeds a progress indicator's
  /// `value:` directly.
  double? get fraction =>
      total <= 0 ? null : (completed / total).clamp(0.0, 1.0);

  // Value equality over all four fields. `ValueNotifier` skips notifying on an
  // equal value, which is exactly what's wanted: a repeated identical emission
  // shouldn't repaint the sidebar, and every real advance (preparing →
  // downloading, n → n+1, → idle) compares unequal. Leaning on the default
  // identity equality instead would work only by accident — it would break the
  // moment a call site wrote `const ResyncProgress.downloading(...)`, which
  // Dart canonicalizes into a silently-dropped notification.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResyncProgress &&
          other.phase == phase &&
          other.companyId == companyId &&
          other.completed == completed &&
          other.total == total;

  @override
  int get hashCode => Object.hash(phase, companyId, completed, total);

  @override
  String toString() =>
      'ResyncProgress(${phase.name}, company: $companyId, $completed/$total)';
}

/// How a [ResyncController.run] call was handled.
enum ResyncDisposition {
  /// This call started the pass and owns reporting its result to the user.
  ///
  /// Means "this caller owned the pass", **not** "the pass succeeded" — a pass
  /// whose prologue threw also lands here, carrying [ResyncResult.error].
  /// Check [ResyncResult.isClean] for the outcome.
  completed,

  /// A pass for the same company was already running; this call attached to it
  /// and settles with the same outcome. Stays silent — the starter reports.
  joined,

  /// A pass for a *different* company is running; nothing was started.
  busy,

  /// The pass was cancelled mid-flight (logout).
  cancelled,
}

@immutable
class ResyncResult {
  const ResyncResult(
    this.disposition, {
    this.failedEntities = const <String>[],
    this.error,
  });

  final ResyncDisposition disposition;

  /// Entities whose download failed — same contract as
  /// `Services.resyncAllEntities`. Empty on a clean pass.
  final List<String> failedEntities;

  /// Set when the prologue itself threw (the pass never reached the per-entity
  /// loop), so nothing downloaded at all.
  final Object? error;

  bool get isClean => error == null && failedEntities.isEmpty;
}

/// One Sync pass that ran to its end, as published on
/// [ResyncController.lastCompletion].
@immutable
class ResyncCompletion {
  const ResyncCompletion({
    required this.serial,
    required this.companyId,
    required this.result,
  });

  /// Strictly increasing per controller. Equality is over this alone, so two
  /// back-to-back passes for the same company compare unequal and both notify —
  /// `ValueNotifier` drops an equal value without a word, which is the same
  /// trap [ResyncProgress]'s `==` is written around.
  final int serial;

  /// The company the pass downloaded. A listener compares it against its own:
  /// a company switch swaps the session (and so every per-company view model)
  /// *before* its hook cancels the pass, so a pass for the company just left
  /// can still finish uncancelled and be published.
  final String companyId;

  /// Never carries an [ResyncResult.error] — see [ResyncController.lastCompletion].
  final ResyncResult result;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResyncCompletion && other.serial == serial;

  @override
  int get hashCode => serial.hashCode;

  @override
  String toString() => 'ResyncCompletion(#$serial, company: $companyId)';
}

/// The work a [ResyncController] drives. Injected as a callback rather than a
/// `Services` reference so the controller unit-tests with zero DI.
typedef ResyncRunner =
    Future<List<String>> Function({
      required String companyId,
      void Function(int completed, int total)? onProgress,
      bool Function()? isCancelled,
    });

/// App-wide single-flight + progress state for the "Sync" pass (push queued
/// offline edits, then re-download every browsable entity).
///
/// Three surfaces drive this one controller — the sidebar header's Sync button,
/// Settings → Device Settings → Data → Sync, and Account Management → Force
/// full sync — so they can't start competing passes and can't disagree about
/// whether a spinner should be showing.
class ResyncController extends ValueNotifier<ResyncProgress> {
  ResyncController({required ResyncRunner runner})
    : _runner = runner,
      super(const ResyncProgress.idle());

  final ResyncRunner _runner;

  Future<ResyncResult>? _inFlight;
  bool _cancelled = false;

  bool get isRunning => value.isRunning;

  /// The most recent pass that ran to its end — the signal for anything that
  /// has to *fetch* off the back of one (invoiceninja/flutter#162: the mounted
  /// dashboard refetches the filter-keyed sections the pass can't know about).
  /// Null until a pass has completed.
  ///
  /// Published once per pass, after [value] returns to idle and before
  /// [run]'s future resolves — and **only** for a pass that was neither
  /// cancelled nor failed in its prologue. That is the whole difference from
  /// the idle falling edge, which fires for every ending alike and so must not
  /// be what a fetch hangs off. A cancelled pass means logout — whose screens
  /// stay mounted until the router swaps them, so a fetch there races the
  /// Drift wipe — or a company switch, where the next request goes out under
  /// the other company's token. See `docs/sync.md` § A screen that refetches
  /// after a Sync pass listens to `lastCompletion`.
  ValueListenable<ResyncCompletion?> get lastCompletion => _lastCompletion;
  final ValueNotifier<ResyncCompletion?> _lastCompletion = ValueNotifier(null);
  int _completions = 0;

  /// Start a pass for [companyId] — or attach to the one already running.
  ///
  /// Never throws: a failing prologue comes back as [ResyncResult.error], so
  /// every call site has exactly one result shape to handle.
  Future<ResyncResult> run(String companyId) {
    final inFlight = _inFlight;
    if (inFlight != null) {
      // A pass bound to another company is running. Queueing would give the
      // user no feedback for an unbounded wait, so decline and say so.
      if (value.companyId != companyId) {
        return Future.value(const ResyncResult(ResyncDisposition.busy));
      }
      return inFlight.then(_asJoined);
    }
    // The completer is claimed *synchronously*, before any runner code can
    // execute. Assigning `_inFlight = _run(...)` instead would leave a window
    // where a runner that throws before its first suspension clears `_inFlight`
    // in its `finally` and is then overwritten by the assignment — wedging the
    // controller as permanently busy.
    final completer = Completer<ResyncResult>();
    _inFlight = completer.future;
    _cancelled = false;
    value = ResyncProgress.preparing(companyId);
    unawaited(
      _run(companyId).then((result) {
        // Decided before `_cancelled` is reset below. Two terms, each covering
        // what the other can't:
        //  * the flag — logout or a company switch asked the pass to stop. It
        //    subsumes the disposition (`_run` reports `cancelled` off this same
        //    flag, and nothing clears it before here), and it also catches a
        //    runner that *threw* after the cancel, which `_run`'s catch reports
        //    as `completed` — the usual shape of a 401, whose logout pulls the
        //    token out from under the pass;
        //  * the error — a prologue that failed with nobody cancelling (offline,
        //    a 5xx, a bad envelope): nothing downloaded and the tail never ran,
        //    so there is nothing for a listener to follow up.
        final announce = !_cancelled && result.error == null;
        // try/finally, because `value =` notifies listeners: if one ever threw
        // past Flutter's own guard, the completer would never complete and
        // every caller would hang forever with nothing surfaced (`unawaited`
        // installs no error handler). Completion must not depend on the UI.
        try {
          _inFlight = null;
          _cancelled = false;
          // Both notifiers are written from a detached `.then`, so a `dispose`
          // that lands between the pass starting and it finishing would make
          // these throw "used after being disposed" out of an `unawaited`
          // future. Unreachable in production (this is a `Services`-lifetime
          // singleton) but not in a test that disposes mid-pass, and the
          // completer below still has to complete either way.
          if (!_disposed) {
            value = const ResyncProgress.idle();
            if (announce) {
              _lastCompletion.value = ResyncCompletion(
                serial: ++_completions,
                companyId: companyId,
                result: result,
              );
            }
          }
        } finally {
          completer.complete(result);
        }
      }),
    );
    return completer.future;
  }

  /// Ask the in-flight pass to stop at the next entity boundary. Wired to
  /// logout, which wipes every Drift table — without this the remaining
  /// entities keep writing rows into the wiped database behind the login
  /// screen. No-op when idle.
  ///
  /// **Narrows the window, doesn't close it.** This is synchronous and returns
  /// immediately, and the flag is only polled *between* entities — the entity
  /// already downloading runs its `refreshAll` page loop to completion (up to
  /// 1000 pages) and writes those rows regardless. So a logout mid-pass can
  /// still land one entity's worth of writes in the wiped DB, versus fourteen
  /// without this.
  ///
  /// Awaiting the pass here is deliberately *not* the fix: a single large
  /// entity can take minutes, and logout would appear to hang. Closing it
  /// properly means threading a cancellation token into
  /// `BaseEntityRepository.refreshAll`'s page loop.
  void cancel() {
    if (_inFlight != null) _cancelled = true;
  }

  /// Never throws — every failure is folded into the returned result.
  Future<ResyncResult> _run(String companyId) async {
    try {
      final failed = await _runner(
        companyId: companyId,
        onProgress: (completed, total) {
          // `_disposed` as well as `_cancelled`: this fires once per entity —
          // fourteen times a pass — so it is the *likelier* of the two writers
          // to land after a dispose, and the assertion it would throw is
          // swallowed by `_run`'s catch into `ResyncResult(completed, error:)`,
          // which then makes `announce` false and aborts the pass silently at
          // the next entity boundary.
          if (_cancelled || _disposed) return;
          value = ResyncProgress.downloading(
            companyId: companyId,
            completed: completed,
            total: total,
          );
        },
        isCancelled: () => _cancelled,
      );
      if (_cancelled) return const ResyncResult(ResyncDisposition.cancelled);
      return ResyncResult(ResyncDisposition.completed, failedEntities: failed);
    } catch (e, st) {
      _log.warning('Sync pass failed for company $companyId', e, st);
      return ResyncResult(ResyncDisposition.completed, error: e);
    }
  }

  /// Set before the notifiers go, so a pass still in flight stops writing to
  /// them rather than throwing out of its detached completion callback.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _lastCompletion.dispose();
    super.dispose();
  }

  static ResyncResult _asJoined(ResyncResult r) =>
      r.disposition == ResyncDisposition.completed
      ? ResyncResult(
          ResyncDisposition.joined,
          failedEntities: r.failedEntities,
          error: r.error,
        )
      : r;
}
