import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/features/tasks/widgets/inline_timer_toggle_button.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// One row in the tasks list. Wide-mode layout matches the column header
/// strip (leading `…` slot, leading select, per-column cells, reserved
/// trailing pill slot). Narrow stacks identity + duration + running pill.
class TaskListTile extends StatefulWidget {
  const TaskListTile({
    super.key,
    required this.task,
    required this.companyId,
    required this.columns,
    required this.onTap,
    this.wide = true,
    this.editable = true,
    this.onAction,
    this.onSelectTap,
    this.onLongPress,
    this.selected = false,
    this.urlSelected = false,
    this.selecting = false,
    this.hideBottomDivider = false,
  });

  final Task task;

  /// Active company id — threaded to the inline timer toggle so a 1-tap
  /// start/stop enqueues against the right company.
  final String companyId;
  final List<ColumnDefinition<Task>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<TaskAction>? onAction;
  final VoidCallback? onSelectTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// True when this row matches the URL's `:id` (active in master-detail
  /// split view). Distinct from [selected] (multi-select) so the tile
  /// can render an unmistakable accent stripe on the left edge for
  /// URL-active rows without conflating with the bulk-select chip.
  final bool urlSelected;
  final bool selecting;

  /// Suppresses the bottom hairline (last row, the selected row, or the row
  /// directly above the selected one). Computed by the list scaffold and
  /// passed straight to [SelectableListRow.hideBottomDivider].
  final bool hideBottomDivider;

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tokens = context.inTheme;
    return SelectableListRow(
      selected: w.selected,
      urlSelected: w.urlSelected,
      hideBottomDivider: w.hideBottomDivider,
      onTap: () => (w.selecting ? w.onSelectTap : w.onTap)?.call(),
      onLongPress: w.onLongPress,
      child: Padding(
        padding: EmbeddedListScope.of(context)
            ? const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14)
            : const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
        child: w.wide ? _wide(context, tokens) : _narrow(context, tokens),
      ),
    );
  }

  Widget _wide(BuildContext context, InTheme tokens) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: kColWMoreMenu,
          child: (w.onAction == null || w.selecting)
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<TaskAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  icon: Icons.more_horiz,
                  items: TaskActions.itemsFor(context, w.task, w.onAction!),
                ),
        ),
        const SizedBox(width: kColActionsLeadingGap),
        _leading(),
        const SizedBox(width: kColCellGap),
        for (final col in w.columns) ...[
          _CellSlot(
            column: col,
            task: w.task,
            child: col.cellBuilder(w.task, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        // Reserved trailing slot: an icon-only 1-tap start/stop toggle. The
        // live duration now ticks in the duration column, so nothing here
        // can overflow the fixed 96px. Hidden in multi-select;
        // `InlineTimerToggleButton` self-gates on eligibility.
        SizedBox(
          width: kColWPillSlot,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: w.selecting
                ? const SizedBox.shrink()
                : InlineTimerToggleButton(task: w.task, companyId: w.companyId),
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context, InTheme tokens) {
    final w = widget;
    final t = w.task;
    final identity = t.description.isEmpty
        ? (t.number.isEmpty ? '—' : '#${t.number}')
        : t.description;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                identity,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // Status + client on one secondary line. The narrow layout has
              // no column strip, so without this the phone list is the only
              // surface where a task's status is invisible (v1 showed it on
              // its mobile row too). Both children are Flexible so a long
              // status or client name ellipsizes instead of squeezing the
              // trailing duration / timer / ⋯ controls.
              if (t.statusId.isNotEmpty || t.clientId.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (t.statusId.isNotEmpty) ...[
                      Flexible(
                        child: TaskStatusPill(
                          statusId: t.statusId,
                          dotSize: 6,
                          textStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      if (t.clientId.isNotEmpty) const SizedBox(width: 6),
                    ],
                    if (t.clientId.isNotEmpty)
                      Flexible(
                        child: ClientNameLabel(
                          clientId: t.clientId,
                          style: TextStyle(color: tokens.ink3, fontSize: 12),
                          link: true,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (t.isRunning && t.timeLog.isNotEmpty)
          RunningDurationLabel(
            start: t.timeLog.last.start!,
            precision: const Duration(seconds: 1),
            style: TextStyle(
              color: tokens.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        else
          Text(
            formatDuration(t.loggedDuration(), compactDays: true),
            style: TextStyle(
              color: tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        if (!w.selecting && TaskActions.canToggleTimer(t)) ...[
          const SizedBox(width: InSpacing.sm),
          InlineTimerToggleButton(task: t, companyId: w.companyId),
        ],
        if (w.onAction != null && !w.selecting) ...[
          const SizedBox(width: InSpacing.sm),
          EntityActionsPopupButton<TaskAction>(
            icon: Icons.more_horiz,
            items: TaskActions.itemsFor(context, w.task, w.onAction!),
          ),
        ],
      ],
    );
  }

  Widget _leading() {
    final w = widget;
    return LeadingSelectSlot(
      selecting: w.selecting,
      selected: w.selected,
      onSelectTap: w.onSelectTap,
      defaultChild: const SizedBox.shrink(),
    );
  }
}

class _CellSlot extends StatelessWidget {
  const _CellSlot({
    required this.column,
    required this.task,
    required this.child,
  });
  final ColumnDefinition<Task> column;
  final Task task;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aligned = Align(
      alignment: column.align == ColumnAlign.end
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: child,
    );
    final cell = CellCopyHover(
      value: column.valueBuilder?.call(task),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) return Expanded(child: cell);
    return SizedBox(width: column.width, child: cell);
  }
}
