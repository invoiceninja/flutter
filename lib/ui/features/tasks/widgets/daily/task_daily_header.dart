import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/view_models/task_daily_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/daily/task_daily_actions.dart';
import 'package:admin/utils/formatting.dart';

/// Day navigation + day totals + actions above the daily timeline.
class TaskDailyHeader extends StatelessWidget {
  const TaskDailyHeader({super.key, required this.wide, this.formatter});

  /// From the host screen's `LayoutBuilder` — the **content pane**, not the
  /// window. Read locally it answered a pane question with a window number, so
  /// in the 600-832 px band (rail up, pane under 600) this header drew
  /// full-label chrome into a narrow pane. One bool per screen now feeds the
  /// AppBar, the filter bar and this row; see `taskFiltersInline`.
  final bool wide;

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskDailyViewModel>();
    final services = context.read<Services>();
    final tokens = context.inTheme;
    final dayLabel = formatter?.date(vm.day.toIso()) ?? vm.day.toIso();
    final totalStr = formatDuration(vm.total, showSeconds: false);
    final billableStr = formatDuration(vm.billable, showSeconds: false);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: context.tr('previous'),
            icon: const Icon(Icons.chevron_left),
            onPressed: vm.prevDay,
          ),
          IconButton(
            tooltip: context.tr('next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: vm.nextDay,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$totalStr ${context.tr('total')} · '
                  '$billableStr ${context.tr('billable_hours')}',
                  style: TextStyle(fontSize: 12, color: tokens.ink3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (wide)
            TextButton(
              onPressed: vm.goToToday,
              child: Text(context.tr('today')),
            )
          else
            IconButton(
              tooltip: context.tr('today'),
              icon: const Icon(Icons.today_outlined),
              onPressed: vm.goToToday,
            ),
          if (vm.isToday)
            IconButton(
              tooltip: context.tr('duplicate_yesterday'),
              icon: const Icon(Icons.copy_outlined),
              // Disabled while a run is in flight or once this day was already
              // duplicated, so a re-tap can't double-create the batch (M2).
              onPressed: vm.canDuplicateYesterday
                  ? () => TaskDailyActions.duplicateYesterday(
                      context,
                      services,
                      vm.companyId,
                      vm,
                    )
                  : null,
            ),
          const SizedBox(width: 8),
          if (wide)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => TaskDailyActions.logTime(context, vm.day),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.tr('log_time')),
            )
          else
            IconButton.filledTonal(
              tooltip: context.tr('log_time'),
              onPressed: () => TaskDailyActions.logTime(context, vm.day),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
    );
  }
}
