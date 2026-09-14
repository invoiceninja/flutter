import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';

/// One-tap play/stop timer button shared by every inline task surface —
/// list rows, kanban cards, and the detail KPI strip. Self-gating: renders
/// nothing when [TaskActions.canToggleTimer] is false (invoiced / deleted /
/// unsynced `tmp_`), so callers drop it in unconditionally.
///
/// Idle → a muted `play_circle_outlined` that lifts to the accent color on
/// desktop hover (touch keeps the muted resting state). Running → an accent
/// `stop_circle_outlined`. The circular pair keeps a constant footprint
/// across states. A tap routes through the shared [TaskActions.toggleTimer].
class InlineTimerToggleButton extends StatefulWidget {
  const InlineTimerToggleButton({
    super.key,
    required this.task,
    required this.companyId,
    this.iconSize = 18,
    this.minTapTarget = 44,
  });

  final Task task;
  final String companyId;
  final double iconSize;

  /// Minimum square hit area. 44 on list/detail (touch minimum); the denser
  /// kanban cards pass a smaller value.
  final double minTapTarget;

  @override
  State<InlineTimerToggleButton> createState() =>
      _InlineTimerToggleButtonState();
}

class _InlineTimerToggleButtonState extends State<InlineTimerToggleButton> {
  bool _hovering = false;

  /// Re-tap guard. `toggleTimer` awaits a Drift read and a save before the row
  /// rebuilds, and two taps inside that window both read `isRunning == false`
  /// from the same stale copy — two outbox rows, two toasts, two Undo buttons
  /// pointing at the same snapshot. `TaskDailyActions.duplicateYesterday`
  /// carries the same guard for the same reason.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    if (!TaskActions.canToggleTimer(task)) return const SizedBox.shrink();

    final tokens = context.inTheme;
    final services = context.read<Services>();
    final running = task.isRunning;
    // Running is always accent; idle is muted but lifts to accent on desktop
    // hover so a mouse user learns the row is actionable without adding
    // resting noise to dense tables.
    final color = running || _hovering ? tokens.accent : tokens.ink3;

    return MouseRegion(
      onEnter: (_) {
        if (!_hovering) setState(() => _hovering = true);
      },
      onExit: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      child: IconButton(
        // `play_circle_outlined`, pairing with `stop_circle_outlined`. Every
        // task timer control in the app uses this pair — the list row, the
        // kanban card, the detail KPI strip, the daily timeline, the edit
        // screen, the bulk toolbar and the ⋮ menu. They used to split between
        // a circled play here and a bare `play_arrow_outlined` on Daily and
        // the edit form, which is invoiceninja/flutter#153: the same verb
        // wearing two glyphs one tab apart. The circled pair wins because the
        // stop glyph has no un-circled sibling in Material, so the other
        // direction leaves Start and Stop mismatched wherever they alternate
        // in one slot — which is every slot here.
        // `test/lint/task_start_rules_test.dart` fails the build on a bare
        // `play_arrow` under `lib/ui/features/tasks/`.
        tooltip: context.tr(running ? 'stop' : 'start'),
        icon: Icon(
          running ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
        ),
        iconSize: widget.iconSize,
        color: color,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: BoxConstraints(
          minWidth: widget.minTapTarget,
          minHeight: widget.minTapTarget,
        ),
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await TaskActions.toggleTimer(
                    context,
                    services,
                    widget.companyId,
                    task,
                  );
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      ),
    );
  }
}
