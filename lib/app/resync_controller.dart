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

  /// Company the in-flight pass is downloading; null when idle. A pass
  /// deliberately survives a company switch (its writes are all `company_id`
  /// scoped), so [isRunning] alone would put a spinner on the wrong workspace —
  /// compare against the active company via [isRunningFor] before rendering.
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
/// Settings → Device Settings → Data → Download, and Account Management →
/// Force full resync — so they can't start competing passes and can't disagree
/// about whether a spinner should be showing.
class ResyncController extends ValueNotifier<ResyncProgress> {
  ResyncController({required ResyncRunner runner})
    : _runner = runner,
      super(const ResyncProgress.idle());

  final ResyncRunner _runner;

  Future<ResyncResult>? _inFlight;
  bool _cancelled = false;

  bool get isRunning => value.isRunning;

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
        // try/finally, because `value =` notifies listeners: if one ever threw
        // past Flutter's own guard, the completer would never complete and
        // every caller would hang forever with nothing surfaced (`unawaited`
        // installs no error handler). Completion must not depend on the UI.
        try {
          _inFlight = null;
          _cancelled = false;
          value = const ResyncProgress.idle();
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
          if (_cancelled) return;
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

  static ResyncResult _asJoined(ResyncResult r) =>
      r.disposition == ResyncDisposition.completed
      ? ResyncResult(
          ResyncDisposition.joined,
          failedEntities: r.failedEntities,
          error: r.error,
        )
      : r;
}
