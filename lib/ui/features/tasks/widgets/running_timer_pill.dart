import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';

/// Persistent "running timer" surface that lets the user stop the active
/// timer from anywhere — not just from the task edit screen.
///
/// Mount once at the AppShell level (above `NavigationRail` / below
/// `NavigationBar`). Subscribes to `services.tasks.watchRunning(companyId)`:
/// hidden when nothing is running; renders a compact pill with the
/// description + live duration + stop button when one entry is active.
///
/// Tapping the pill body → opens the task's edit screen.
/// Tapping the stop icon → enqueues a save with `stop = now` on the
/// running entry; no edit-screen detour required.
class RunningTimerPill extends StatelessWidget {
  const RunningTimerPill({super.key});

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
              return const SizedBox.shrink();
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
