import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/edit/time_entry_editor_sheet.dart';
import 'package:admin/ui/features/tasks/widgets/edit/time_entry_row.dart';
import 'package:admin/ui/features/tasks/widgets/edit/time_entry_table.dart';
import 'package:admin/ui/features/tasks/widgets/task_total_duration_label.dart';
import 'package:admin/utils/formatting.dart';

/// The time-log editor inside the Task edit form. Header row holds
/// "+ Add time" and a Start / Stop / Resume toggle button; the body lists
/// the entries newest-first.
class TaskEditTimesSection extends StatelessWidget {
  const TaskEditTimesSection({
    super.key,
    required this.vm,
    required this.locked,
    this.formatter,
  });

  final TaskEditViewModel vm;
  final bool locked;

  /// Resolved company `Formatter` for date rendering inside each row.
  /// Null in test contexts; falls back to ISO inside `TimeEntryRow`.
  final Formatter? formatter;

  /// The desktop time-log table's intrinsic minimum width (six fixed
  /// columns + gaps + card padding ≈ 792px, rounded up). Below this width
  /// the mobile `TimeEntryRow` list renders instead so the table never
  /// overflows its constraints (the generic 600px `Breakpoints.isWide`
  /// used to leave a 600–792px band — tablet / iPad portrait — that did).
  static const double _kTableMinWidth = 800;

  Future<void> _openEditor(
    BuildContext context,
    int displayIndex, {
    required bool allowBillable,
    required bool showEndDate,
    required bool showItemDescription,
  }) async {
    final entries = vm.draft.timeLog;
    final actualIndex = entries.length - 1 - displayIndex;
    final result = await TimeEntryEditorSheet.show(
      context,
      initial: entries[actualIndex],
      formatter: formatter,
      allowBillableToggle: allowBillable,
      showEndDate: showEndDate,
      showItemDescription: showItemDescription,
    );
    if (result == null) return;
    if (TimeEntryEditorSheet.isRemoveSignal(result)) {
      vm.removeEntry(actualIndex);
    } else {
      vm.updateEntry(actualIndex, result);
    }
  }

  /// Mobile: open the editor sheet so the user can edit a fresh entry on
  /// a full-screen surface. Tiny inline cells aren't usable on small
  /// viewports.
  Future<void> _addEntryViaSheet(
    BuildContext context, {
    required bool allowBillable,
    required bool showEndDate,
    required bool showItemDescription,
  }) async {
    final result = await TimeEntryEditorSheet.show(
      context,
      initial: TimeEntry(
        start: DateTime.now().subtract(const Duration(minutes: 30)),
        stop: DateTime.now(),
      ),
      formatter: formatter,
      allowBillableToggle: allowBillable,
      showEndDate: showEndDate,
      showItemDescription: showItemDescription,
    );
    if (result == null) return;
    if (TimeEntryEditorSheet.isRemoveSignal(result)) return;
    vm.addEntry(
      start: result.start,
      stop: result.stop,
      description: result.description,
      billable: result.billable,
    );
  }

  /// Desktop: append a fresh entry inline with the VM's default seed
  /// (30 min back → now). The table watches the VM and surfaces a new
  /// row + focuses its start cell on the next frame.
  void _addEntryInline() {
    vm.addEntry();
  }

  /// The server's own verdict on this draft's `time_log`, rendered where the

  /// rows are.

  ///

  /// `Request::checkTimeLog` rejects the whole payload on an overlap, an

  /// inverted entry, or a running entry that isn't last — and a rejected save

  /// is invisible until the outbox row dies. Save is gated on this too

  /// (`task_edit_screen.dart`), so the message is the explanation for a

  /// disabled button rather than a warning nobody has to act on.

  Widget _problemBanner(BuildContext context) {
    final problem = vm.draftTimeLogProblem;

    if (problem == null) return const SizedBox.shrink();

    final tokens = context.inTheme;

    final military = formatter?.settings.enableMilitaryTime ?? false;

    String clock(DateTime? t) {
      final local = t?.toLocal();

      return local == null
          ? ''
          : formatTimeOfDay(local.hour, local.minute, military: military);
    }

    final message = switch (problem.kind) {
      TimeLogProblemKind.inverted => context.tr('time_log_inverted'),

      TimeLogProblemKind.runningNotLast => context.tr(
        'time_log_running_not_last',
      ),

      TimeLogProblemKind.overlap => context.tr('time_log_overlap', {
        'from': clock(problem.from),

        'to': clock(problem.to),
      }),
    };

    return Padding(
      padding: EdgeInsets.only(top: InSpacing.sm),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: tokens.warning),

          const SizedBox(width: InSpacing.sm),

          Expanded(
            child: Text(
              message,

              style: TextStyle(color: tokens.warning, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timerButton(BuildContext context, {bool compact = false}) {
    // Per-call minimumSize override — `FilledButton.tonal` inherits
    // `Size.fromHeight(44)` from the theme, which is infinite-width and
    // crashes when rendered in this Row. See CLAUDE.md § Design system
    // (v2) for the canonical rule + reference call site.
    final style = FilledButton.styleFrom(minimumSize: const Size(64, 44));
    // Phones: drop the label so the title + total + two buttons fit.
    final compactStyle = FilledButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
    );
    final (
      IconData icon,
      String labelKey,
      VoidCallback? onPressed,
    ) = vm.hasRunningEntry
        ? (Icons.stop_circle_outlined, 'stop', locked ? null : vm.stopTimer)
        // `hasStoppedEntries` is true for a booking too, so it alone offered
        // "Resume" on a task that has never been worked — the mislabel
        // invoiceninja/flutter#149 opens with, on the third of four surfaces.
        : (vm.hasStoppedEntries && vm.scheduleState == TaskScheduleState.none)
        ? (Icons.play_circle_outlined, 'resume', locked ? null : vm.resumeTimer)
        : (Icons.play_circle_outlined, 'start', locked ? null : vm.startTimer);
    if (compact) {
      return FilledButton.tonal(
        style: compactStyle,
        onPressed: onPressed,
        child: Icon(icon),
      );
    }
    return FilledButton.tonalIcon(
      style: style,
      icon: Icon(icon),
      label: Text(context.tr(labelKey)),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(vm.companyId),
      builder: (context, companySnap) {
        final company = companySnap.data;
        // `show_task_end_date` defaults false (admin-portal parity: start +
        // duration, no explicit stop date); the others default to showing.
        final allowBillable = company?.settings.allowBillableTaskItems ?? true;
        final showEndDate = company?.showTaskEndDate ?? false;
        final showItemDescription =
            company?.settings.showTaskItemDescription ?? true;
        final tokens = context.inTheme;
        final entries = vm.draft.timeLog.reversed.toList(growable: false);
        return Container(
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border.all(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r3),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Gate the desktop table on its real minimum width, not the
              // generic 600px breakpoint — below it the mobile row list renders.
              final wide = constraints.maxWidth >= _kTableMinWidth;
              // Phones: collapse the header actions to icon-only so the title +
              // live total + two buttons don't overflow the header Row.
              final compact = constraints.maxWidth < 480;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header — same on both layouts; only the "add" action's
                  // entry point differs (inline on desktop, modal sheet on
                  // mobile). `InSpacing.lg(context)` matches the canonical card-
                  // interior padding documented in CLAUDE.md § Design
                  // system (v2) — same inset as `FormSection`,
                  // `DashboardCardShell`, and the identity card above.
                  Padding(
                    padding: EdgeInsets.all(InSpacing.lg(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                context.tr('time_log').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.ink3,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            SizedBox(width: InSpacing.md(context)),
                            // Live wall-clock total — ticks every second when an
                            // entry is running, otherwise renders statically.
                            TaskTotalDurationLabel(vm: vm),
                            const Spacer(),
                            if (!locked) ...[
                              // Per-call minimumSize override: lib/app/theme.dart
                              // sets `Size.fromHeight(40)` on OutlinedButton which
                              // is `Size(double.infinity, 40)` — fine in a column,
                              // fatal in this Row. Same story for the
                              // FilledButton.tonalIcon returned by `_timerButton`.
                              // See CLAUDE.md § Design system (v2) "Default to
                              // side-by-side dialog actions" for the verbatim rule.
                              if (compact)
                                IconButton(
                                  tooltip: context.tr('add_time'),
                                  icon: const Icon(Icons.add),
                                  onPressed: wide
                                      ? _addEntryInline
                                      : () => _addEntryViaSheet(
                                          context,
                                          allowBillable: allowBillable,
                                          showEndDate: showEndDate,
                                          showItemDescription:
                                              showItemDescription,
                                        ),
                                )
                              else
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(64, 40),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(context.tr('add_time')),
                                  onPressed: wide
                                      ? _addEntryInline
                                      : () => _addEntryViaSheet(
                                          context,
                                          allowBillable: allowBillable,
                                          showEndDate: showEndDate,
                                          showItemDescription:
                                              showItemDescription,
                                        ),
                                ),
                              const SizedBox(width: InSpacing.sm),
                              _timerButton(context, compact: compact),
                            ],
                          ],
                        ),
                        _problemBanner(context),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.border),
                  // Pick between the desktop table and the mobile card list.
                  if (wide)
                    TimeEntryTable(
                      vm: vm,
                      locked: locked,
                      formatter: formatter,
                      onAddEntry: _addEntryInline,
                      allowBillable: allowBillable,
                      showDescription: showItemDescription,
                    )
                  else if (entries.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: Center(
                        child: Text(
                          context.tr('no_entries'),
                          style: TextStyle(color: tokens.ink3),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          TimeEntryRow(
                            dueDate: vm.draft.dueDate,
                            entry: entries[i],
                            enabled: !locked,
                            formatter: formatter,
                            onTap: () => _openEditor(
                              context,
                              i,
                              allowBillable: allowBillable,
                              showEndDate: showEndDate,
                              showItemDescription: showItemDescription,
                            ),
                            onRemove: () =>
                                vm.removeEntry(vm.draft.timeLog.length - 1 - i),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
