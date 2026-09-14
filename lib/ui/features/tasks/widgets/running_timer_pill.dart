import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';

/// Persistent "running timer" surface that lets the user stop the active
/// timer from anywhere — not just from the task edit screen.
///
/// Mount once at the AppShell level (above `NavigationRail` / below
/// `NavigationBar`). Two modes in one slot, and they can never collide —
/// claiming a booking is what makes it running:
///
///  * a timer is running → the description + live duration + stop button;
///  * nothing running, but a booked block's window is open → "Due now" and a
///    start button (invoiceninja/flutter#149). This is the app's only task
///    control reachable from every screen, which is the point: the alternative
///    is finding the Tasks list, picking a view and scrolling.
///
/// Hidden when neither holds.
///
/// Tapping the pill body → opens the task's edit screen.
/// Tapping the stop icon → enqueues a save with `stop = now` on the
/// running entry; no edit-screen detour required.
class RunningTimerPill extends StatefulWidget {
  const RunningTimerPill({super.key});

  @override
  State<RunningTimerPill> createState() => _RunningTimerPillState();
}

class _RunningTimerPillState extends State<RunningTimerPill>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// "Due now" is computed against `DateTime.now()` at build time, and Drift
  /// only emits when a row changes — so a booking whose window opens while the
  /// app sits in a pocket would never surface it. A periodic ticker is the
  /// wrong tool for one transition per booking (and `task_day_load.dart`
  /// refuses one for far less); the frame that actually matters to someone
  /// between jobs is the first one after they unlock the phone.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Listen to the session so the pill REBUILDS + re-subscribes when the
    // active company changes. `Provider<Services>.value` never notifies and
    // this widget is mounted as a `const` instance, so without this the pill
    // kept the FIRST company's `watchRunning` stream for the whole app session
    // (showing another company's timer, a dead stop button, and hiding the
    // current company's running timer).
    return ValueListenableBuilder(
      valueListenable: services.auth.session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        // Permission gate — non-admin users without `view_task` shouldn't see
        // the pill (they can't open the task it points to anyway).
        final company = session.currentCompany;
        if (company == null || !company.can('view_task')) {
          return const SizedBox.shrink();
        }
        return StreamBuilder<Task?>(
          stream: services.tasks.watchRunning(
            companyId: session.currentCompanyId,
          ),
          builder: (context, snapshot) {
            final task = snapshot.data;
            if (task == null || !task.isRunning || task.timeLog.isEmpty) {
              // Nothing running — but a booked job whose window is open right
              // now is the other thing worth a permanent, thumb-height
              // control. This pill is the only task affordance reachable from
              // every screen, and for someone standing outside a customer's
              // house it beats finding the Tasks list, picking a view and
              // scrolling (invoiceninja/flutter#149).
              return _DueNowPill(
                services: services,
                companyId: session.currentCompanyId,
              );
            }
            return StreamBuilder<int>(
              stream: services.tasks.watchRunningCount(
                companyId: session.currentCompanyId,
              ),
              builder: (context, countSnap) => _Pill(
                task: task,
                services: services,
                runningCount: countSnap.data ?? 1,
              ),
            );
          },
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.task,
    required this.services,
    required this.runningCount,
  });

  final Task task;
  final Services services;

  /// Total running timers for the company. When > 1 the pill surfaces a
  /// "Stop all (N)" affordance — `watchRunning` only shows the newest one,
  /// so without this concurrent timers would accrue invisibly.
  final int runningCount;

  Future<void> _stop(BuildContext context) async {
    final session = services.auth.session.value;
    if (session == null) return;
    // Centralized in the repo so the read-modify-write logic + outbox
    // enqueue lives in one place (see TaskRepository.stopRunningTimer).
    await services.tasks.stopRunningTimer(
      companyId: session.currentCompanyId,
      taskId: task.id,
    );
  }

  Future<void> _stopAll(BuildContext context) async {
    final session = services.auth.session.value;
    if (session == null) return;
    await services.tasks.stopAllRunning(companyId: session.currentCompanyId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = task.description.isEmpty
        ? (task.number.isEmpty ? context.tr('running') : '#${task.number}')
        : task.description;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}/edit'),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: InSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: tokens.accentSoft,
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RunningDurationLabel(
                start: task.timeLog.last.start!,
                dotSize: 6,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.ink2),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: context.tr('stop'),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                onPressed: () => _stop(context),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
              ),
              // Concurrent timers stay visible + clearable: this pill only
              // renders the newest running task, so surface a count + a
              // one-tap "stop them all".
              if (runningCount > 1) ...[
                const SizedBox(width: 2),
                TextButton(
                  onPressed: () => _stopAll(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tokens.ink2,
                  ),
                  child: Text(
                    '${context.tr('stop_all')} ($runningCount)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Due now" — the shell pill's second mode, shown only when no timer is
/// running and a booked block's window contains the current moment.
///
/// Deliberately the same slot, chrome and geometry as the running pill: one
/// place on screen means one thing ("the job you are on"), and the two states
/// can never collide, since claiming a booking is what makes it running.
class _DueNowPill extends StatefulWidget {
  const _DueNowPill({required this.services, required this.companyId});

  final Services services;
  final String companyId;

  @override
  State<_DueNowPill> createState() => _DueNowPillState();
}

class _DueNowPillState extends State<_DueNowPill> {
  late Stream<Task?> _stream = _open();

  /// Held in `State`, not rebuilt in `build`. `watchDueNow` selects up to 50
  /// rows and decodes each one's payload, and the parent rebuilds on every
  /// emission of the running-task stream — so an inline stream re-subscribed
  /// on any task write, with a null frame in between that blinks the pill.
  ///
  /// The freshness this used to get for free from that churn now comes from
  /// [_RunningTimerPillState.didChangeAppLifecycleState], which re-creates this
  /// element on resume — the frame that matters between jobs.
  Stream<Task?> _open() =>
      widget.services.tasks.watchDueNow(companyId: widget.companyId);

  @override
  void didUpdateWidget(_DueNowPill old) {
    super.didUpdateWidget(old);
    if (old.companyId != widget.companyId) _stream = _open();
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    final companyId = widget.companyId;
    final tokens = context.inTheme;
    return StreamBuilder<Task?>(
      stream: _stream,
      builder: (context, snap) {
        final task = snap.data;
        if (task == null) return const SizedBox.shrink();
        final label = taskPrimaryLabel(task);
        // `Ink` idiom (CLAUDE.md): the FILL rides on the `Material`, above its
        // own ink layer, and the `Container` carries the border only — an
        // opaque child would paint over the fill, the border and the ripple.
        return Material(
          color: tokens.warningSoft,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: InkWell(
            borderRadius: BorderRadius.circular(InRadii.r2),
            onTap: () => context.go('/tasks/${task.id}/edit'),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.md(context),
                vertical: InSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('due_now'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: tokens.ink2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // The whole point: start the job without leaving the screen
                  // you are on. Routed through `TaskActions.toggleTimer` so it
                  // claims the booking, moves the status and offers Undo
                  // exactly as the list row does.
                  IconButton(
                    tooltip: context.tr('start'),
                    icon: const Icon(Icons.play_circle_outlined, size: 18),
                    // Same box as `_Pill`'s stop button — without the zeroed
                    // padding an `IconButton`'s default `EdgeInsets.all(8)`
                    // makes this pill taller than the one it alternates with,
                    // in the same slot.
                    padding: EdgeInsets.zero,
                    color: tokens.warning,
                    onPressed: () => TaskActions.toggleTimer(
                      context,
                      services,
                      companyId,
                      task,
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
