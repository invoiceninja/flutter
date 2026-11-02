import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/task_repository.dart'
    show TimerStopResult;
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/home_widgets/widget_command.dart';

final _log = Logger('HomeWidgetCommands');

/// What happened to one queued command — for the toast and the diagnostics
/// log.
enum WidgetCommandOutcome {
  /// The timer stopped, at the time of the tap.
  applied,

  /// Waiting for its company to be the active one; kept.
  deferred,

  /// The timer was stopped and restarted on another device since the tap, so
  /// stopping it now would stop the wrong session. The one outcome the user is
  /// told about.
  changedElsewhere,

  /// Nothing to do, and nothing worth saying: stopped already (a second tap,
  /// or a stop made in the app), the task is gone, this user may not edit it,
  /// or the command was applied before.
  skipped,

  /// Older than [kWidgetCommandMaxAge] — dropped, and the user told: the
  /// widget promised it would sync, and the timer is still running.
  expired,

  /// Not this user's, or unreadable — dropped.
  discarded,

  /// Applying it threw (a database error, say): kept for the next pass, so
  /// the "Stopped · syncs…" the widget showed still comes true.
  failed,
}

/// Stops a timer for a widget command. `TaskRepository.stopRunningTimer` in
/// the app; a fake in tests.
typedef StopTimer =
    Future<TimerStopResult> Function({
      required String companyId,
      required String taskId,
      required DateTime stopAt,
      required DateTime runningSince,
      required bool Function(Task task) only,
    });

/// Opens a task and starts its timer for a widget's Start — the app's deep
/// link choreography (held while locked, company switched behind its
/// guards), then the same start a tap in the app makes. Not awaited by the
/// pass: the switch may wait on a dialog.
typedef StartTask = Future<void> Function(WidgetCommand command);

/// Applies the commands the home-screen widgets queued (Stop and Start) —
/// see `docs/home-screen-widgets.md` § The only write is a queued command.
///
/// Runs when started (by `HomeWidgetsHost`, once the app's strings exist for
/// the toast), on every resume, when the native side says one was just
/// queued, and when the active company changes. A command is applied through
/// the outbox, so it works offline, and its file is deleted only once it has
/// been handled. Each id is applied once per run of the app, so a delete that
/// failed can't stop a timer twice.
class HomeWidgetCommands {
  HomeWidgetCommands({
    required this.bridge,
    required this.session,
    required this.stopTimer,
    this.startTask,
    this.onOutcome,
    this.onHandled,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// After a pass that removed any command — the publisher redraws the Timer
  /// widget, whose "Stopped" label came from a command file.
  final Future<void> Function()? onHandled;

  final HomeWidgetBridge bridge;
  final ValueListenable<AuthSession?> session;
  final StopTimer stopTimer;

  /// Set by `main.dart` once the router exists — a start needs navigation and
  /// a `BuildContext`, which `Services` doesn't have. Null until then (and in
  /// a test harness): a start waits in its file for the next pass.
  StartTask? startTask;

  /// Told of every command handled — the app toasts [changedElsewhere],
  /// [expired], and (once per command per run) [deferred].
  final void Function(WidgetCommand command, WidgetCommandOutcome outcome)?
  onOutcome;
  final DateTime Function() _now;

  final Set<String> _applied = {};
  StreamSubscription<void>? _sub;
  Future<void>? _running;
  bool _again = false;
  String? _companyId;

  void start() {
    if (!bridge.supported || _sub != null) return;
    _sub = bridge.commandsQueued.listen((_) => unawaited(run()));
    session.addListener(_onSession);
    _onSession();
  }

  void _onSession() {
    final company = session.value?.currentCompanyId;
    if (company == _companyId) return;
    _companyId = company;
    if (company != null) unawaited(run());
  }

  /// Applies every command waiting. One pass at a time; a call during a pass
  /// runs one more after it. Never throws.
  Future<void> run() {
    final running = _running;
    if (running != null) {
      _again = true;
      return running;
    }
    final pass = _pass()
        .catchError((Object e, StackTrace st) {
          _log.warning('Widget commands pass failed', e, st);
        })
        .whenComplete(() {
          _running = null;
          if (_again) {
            _again = false;
            unawaited(run());
          }
        });
    _running = pass;
    return pass;
  }

  Future<void> _pass() async {
    final first = session.value;
    if (first == null) return;
    var handled = false;
    try {
      handled = await _applyAll(first);
    } finally {
      if (handled) await onHandled?.call();
    }
  }

  /// One pass over the waiting commands; whether it removed any.
  Future<bool> _applyAll(AuthSession first) async {
    var handled = false;
    for (final (:fileId, :command) in await bridge.takeCommands()) {
      // Re-read for every command: a sign-out or a company switch during the
      // pass must not have a stop written under the session it ended — after
      // `onBeforeLogout`, into a database about to be wiped.
      final s = session.value;
      if (s == null ||
          s.userId != first.userId ||
          s.currentCompanyId != first.currentCompanyId) {
        return handled;
      }
      WidgetCommandOutcome outcome;
      try {
        outcome = await _apply(s, command);
      } catch (e, st) {
        _log.warning('Widget command not applied', e, st);
        outcome = WidgetCommandOutcome.failed;
      }
      if (outcome != WidgetCommandOutcome.deferred &&
          outcome != WidgetCommandOutcome.failed) {
        await bridge.deleteCommand(fileId);
        handled = true;
      }
      if (command != null) {
        _log.info('Widget command ${command.kind.wire}: ${outcome.name}');
        onOutcome?.call(command, outcome);
      }
    }
    return handled;
  }

  Future<WidgetCommandOutcome> _apply(
    AuthSession s,
    WidgetCommand? command,
  ) async {
    if (command == null) return WidgetCommandOutcome.discarded;
    if (command.userId != s.userId) return WidgetCommandOutcome.discarded;
    final maxAge = command.kind == WidgetCommandKind.start
        ? kWidgetStartMaxAge
        : kWidgetCommandMaxAge;
    if (_now().difference(command.at) > maxAge) {
      return WidgetCommandOutcome.expired;
    }
    if (!s.companies.any((c) => c.id == command.companyId)) {
      return WidgetCommandOutcome.discarded;
    }
    if (_applied.contains(command.id)) return WidgetCommandOutcome.skipped;
    // The outbox and the edit rule belong to the active company: a stop for
    // another one waits until the user is in it. A start doesn't wait — the
    // user is opening the app on it, and its link switches company itself.
    if (command.kind == WidgetCommandKind.stop &&
        command.companyId != s.currentCompanyId) {
      return WidgetCommandOutcome.deferred;
    }
    switch (command.kind) {
      case WidgetCommandKind.start:
        final start = startTask;
        if (start == null) return WidgetCommandOutcome.deferred;
        _applied.add(command.id);
        // Handed over, not awaited: the link may wait on the lock screen or
        // a company-switch dialog, and the file must not be applied twice
        // meanwhile. The start itself decides (running already, no right to
        // edit, a booking to claim) and says so in the app.
        unawaited(
          start(command).catchError((Object e, StackTrace st) {
            _log.warning('Widget start not applied', e, st);
          }),
        );
        return WidgetCommandOutcome.applied;
      case WidgetCommandKind.stop:
        final result = await stopTimer(
          companyId: command.companyId,
          taskId: command.taskId,
          stopAt: command.at,
          runningSince: command.runningSince!,
          only: (task) => s.canEditRecord(
            'task',
            createdBy: task.userId,
            assignedTo: task.assignedUserId,
            recordId: task.id,
          ),
        );
        _applied.add(command.id);
        return switch (result) {
          TimerStopResult.stopped => WidgetCommandOutcome.applied,
          TimerStopResult.changedElsewhere =>
            WidgetCommandOutcome.changedElsewhere,
          TimerStopResult.missing ||
          TimerStopResult.notRunning ||
          TimerStopResult.refused => WidgetCommandOutcome.skipped,
        };
    }
  }

  void dispose() {
    unawaited(_sub?.cancel());
    session.removeListener(_onSession);
  }
}
