import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/core/utils/show_seconds.dart';
import 'package:admin/utils/formatting.dart';

/// Live-updating total for the entire task — sum of every `TimeEntry` in
/// the draft, regardless of `billable` (i.e. `Task.loggedDuration`). Ticks
/// once per second whenever the draft has a running entry; otherwise renders
/// statically. The list / detail / kanban surfaces show the same wall-clock
/// total now; only invoice quantities use `Task.billableDuration`.
class TaskTotalDurationLabel extends StatefulWidget {
  const TaskTotalDurationLabel({super.key, required this.vm});

  final TaskEditViewModel vm;

  @override
  State<TaskTotalDurationLabel> createState() => _TaskTotalDurationLabelState();
}

class _TaskTotalDurationLabelState extends State<TaskTotalDurationLabel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onVmChanged);
    _restartTicker();
  }

  void _onVmChanged() {
    _restartTicker();
    if (mounted) setState(() {});
  }

  void _restartTicker() {
    _ticker?.cancel();
    _ticker = widget.vm.hasRunningEntry
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          })
        : null;
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    _ticker?.cancel();
    super.dispose();
  }

  Duration _wallClockTotal() => widget.vm.draft.loggedDuration();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final total = _wallClockTotal();
    return Tooltip(
      message: context.tr('total_duration'),
      child: Text(
        formatDuration(
          total,
          compactDays: true,
          secondsPastDay: watchShowSeconds(context),
        ),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: tokens.ink,
          // Tabular figures keep each digit the same width so the label
          // doesn't reflow when the seconds tick.
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
