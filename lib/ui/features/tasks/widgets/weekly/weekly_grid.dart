import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/weekly/weekly_cell_note_popover.dart';
import 'package:admin/ui/features/tasks/widgets/weekly/weekly_merge.dart';
import 'package:admin/utils/formatting.dart';

const double _kTaskCol = 240;
const double _kDayCol = 92;
const double _kTotalCol = 84;
const double _kRowMinHeight = 56;
const _tabular = [FontFeature.tabularFigures()];

/// The weekly timesheet grid: a 9-column table (task + 7 days + total) that
/// scrolls horizontally as a unit and vertically over task rows. Editable
/// duration cells write back through the VM's per-task debounce.
class WeeklyGrid extends StatelessWidget {
  const WeeklyGrid({
    super.key,
    this.formatter,
    this.hoursMinutes = false,
    this.onHoursMinutesChanged,
  });

  final Formatter? formatter;

  /// Show hours as `H:MM` rather than decimal hours — every cell and total.
  final bool hoursMinutes;

  /// Flips [hoursMinutes]; the switch in the Total row is drawn only when set.
  final ValueChanged<bool>? onHoursMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskWeeklyViewModel>();
    final tokens = context.inTheme;
    final days = vm.weekDays;
    final rows = vm.rows;
    final locale = formatter?.settings.locale;
    final localeArg = (locale == null || locale.isEmpty) ? null : locale;

    if (rows.isEmpty) {
      // Filter-aware, for the reason `EntityListScreenScaffold._emptyState`
      // spells out: without it a filtered week is a dead end that never says a
      // filter is responsible. Both keys already exist. `hasFilteredOutRows`,
      // not `filtersActive` — a week with nothing logged is equally empty with
      // a filter applied, and pointing that user at "Clear filters" sends them
      // somewhere that reveals nothing.
      if (vm.hasFilteredOutRows) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: context.tr('no_records_found'),
          action: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: vm.clearFilters,
            icon: const Icon(Icons.close),
            label: Text(context.tr('clear_filters')),
          ),
        );
      }
      return EmptyState(
        icon: Icons.calendar_view_week_outlined,
        title: context.tr('no_records_found'),
      );
    }

    final dayTotals = [
      for (final d in days)
        rows.fold<int>(0, (sum, t) => sum + vm.secondsFor(t.id, d)),
    ];
    final grandTotal = rows.fold<int>(
      0,
      (sum, t) => sum + vm.weekTotalFor(t.id),
    );
    final totalWidth = _kTaskCol + _kDayCol * 7 + _kTotalCol;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              _headerRow(context, tokens, days, localeArg),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final task in rows)
                        _taskRow(context, vm, tokens, task, days),
                    ],
                  ),
                ),
              ),
              // Outside the vertical scroll so it stays pinned at the bottom
              // (still inside the horizontal SizedBox, so columns stay aligned).
              _totalsRow(context, tokens, days, dayTotals, grandTotal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow(
    BuildContext context,
    InTheme tokens,
    List<Date> days,
    String? localeArg,
  ) {
    final hStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: tokens.ink3,
    );
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kTaskCol,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(context.tr('task'), style: hStyle),
            ),
          ),
          for (final d in days)
            SizedBox(
              width: _kDayCol,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE', localeArg).format(d.toDateTime()),
                      style: hStyle,
                    ),
                    Text(
                      '${d.day}',
                      style: TextStyle(fontSize: 11, color: tokens.ink2),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(
            width: _kTotalCol,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                context.tr('total'),
                style: hStyle,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(
    BuildContext context,
    TaskWeeklyViewModel vm,
    InTheme tokens,
    Task task,
    List<Date> days,
  ) {
    final readOnly = vm.isReadOnly(task.id);
    return Container(
      constraints: const BoxConstraints(minHeight: _kRowMinHeight),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      // `IntrinsicHeight` bounds the row before `stretch` asks for its full
      // height: the rows sit in a vertical scroll view, so without it every
      // cell was handed an infinite height and no row ever laid out.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: _kTaskCol, child: _nameCell(context, tokens, task)),
            for (final d in days)
              SizedBox(
                width: _kDayCol,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: WeeklyDurationCell(
                    key: ValueKey('${task.id}|${d.toIso()}'),
                    displayText: weeklyHoursText(
                      vm.secondsFor(task.id, d),
                      formatter,
                      hoursMinutes: hoursMinutes,
                    ),
                    hoursMinutes: hoursMinutes,
                    readOnly: readOnly,
                    hasNote:
                        vm.cellDescription(task.id, d).isNotEmpty ||
                        !vm.cellBillable(task.id, d),
                    formatter: formatter,
                    onDuration: (raw) => vm.editCell(task.id, d, duration: raw),
                    onNoteTap: () =>
                        showWeeklyCellNote(context, vm, task.id, d),
                  ),
                ),
              ),
            SizedBox(
              width: _kTotalCol,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    weeklyHoursText(
                      vm.weekTotalFor(task.id),
                      formatter,
                      hoursMinutes: hoursMinutes,
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameCell(BuildContext context, InTheme tokens, Task task) {
    final secondaryStyle = TextStyle(fontSize: 12, color: tokens.ink3);
    return InkWell(
      onTap: () => goEntityRecord(context, EntityType.task, task.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    taskPrimaryLabel(task, max: 40),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (task.isRunning) ...[
                  const SizedBox(width: 6),
                  StatusPill(
                    label: context.tr('running'),
                    fgColor: tokens.accent,
                  ),
                ],
              ],
            ),
            if (task.projectId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ProjectNameLabel(
                  projectId: task.projectId,
                  style: secondaryStyle,
                ),
              )
            else if (task.clientId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: ClientNameLabel(
                  clientId: task.clientId,
                  style: secondaryStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _totalsRow(
    BuildContext context,
    InTheme tokens,
    List<Date> days,
    List<int> dayTotals,
    int grandTotal,
  ) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: tokens.ink,
      fontFeatures: _tabular,
    );
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kTaskCol,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: onHoursMinutesChanged == null ? 12 : 4,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(context.tr('total'), style: style)),
                  // Beside the totals it reformats, at the leading edge every
                  // pane shows: the header has no width to spare on a phone.
                  if (onHoursMinutesChanged != null)
                    HoursFormatSwitch(
                      hoursMinutes: hoursMinutes,
                      formatter: formatter,
                      onChanged: onHoursMinutesChanged!,
                    ),
                ],
              ),
            ),
          ),
          for (var i = 0; i < days.length; i++)
            SizedBox(
              width: _kDayCol,
              child: Center(
                child: Text(
                  weeklyHoursText(
                    dayTotals[i],
                    formatter,
                    hoursMinutes: hoursMinutes,
                  ),
                  style: style,
                ),
              ),
            ),
          SizedBox(
            width: _kTotalCol,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  weeklyHoursText(
                    grandTotal,
                    formatter,
                    hoursMinutes: hoursMinutes,
                  ),
                  style: style,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decimal hours or `H:MM` — the two choices, each labelled by the same
/// ninety minutes written its way (`1.5` / `1:30`), so the control explains
/// itself in any language; the tooltips name them. React ui#3422.
class HoursFormatSwitch extends StatelessWidget {
  const HoursFormatSwitch({
    super.key,
    required this.hoursMinutes,
    required this.onChanged,
    this.formatter,
  });

  final bool hoursMinutes;
  final ValueChanged<bool> onChanged;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: false,
          label: Text(formatter?.decimal(1.5) ?? '1.5'),
          tooltip: context.tr('decimal_hours'),
        ),
        ButtonSegment(
          value: true,
          label: Text(hoursMinutesText(90 * 60)),
          tooltip: context.tr('hours_and_minutes'),
        ),
      ],
      selected: {hoursMinutes},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Editable hours cell. Mirrors `time_entry_table._DurationCell` for
/// cursor stability: the controller re-seeds only when the external value
/// changed AND the user isn't mid-keystroke. Accepts decimal hours (`1.5`) or
/// `h:mm` (`1:30`); an empty string clears the cell (deletes the entry).
class WeeklyDurationCell extends StatefulWidget {
  const WeeklyDurationCell({
    super.key,
    required this.displayText,
    required this.readOnly,
    required this.hasNote,
    required this.onDuration,
    required this.onNoteTap,
    this.formatter,
    this.hoursMinutes = false,
  });

  final String displayText;

  /// Whether [displayText] is `H:MM` — what a typed value is re-rendered as.
  final bool hoursMinutes;
  final bool readOnly;
  final bool hasNote;
  final void Function(String raw) onDuration;
  final VoidCallback onNoteTap;
  final Formatter? formatter;

  @override
  State<WeeklyDurationCell> createState() => _WeeklyDurationCellState();
}

class _WeeklyDurationCellState extends State<WeeklyDurationCell> {
  late final TextEditingController _controller;
  String _externalText = '';

  @override
  void initState() {
    super.initState();
    _externalText = widget.displayText;
    _controller = TextEditingController(text: _externalText);
  }

  @override
  void didUpdateWidget(covariant WeeklyDurationCell old) {
    super.didUpdateWidget(old);
    final next = widget.displayText;
    if (next != _externalText && next != _controller.text) {
      _externalText = next;
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String raw) {
    // Stash the canonical display before notifying so `didUpdateWidget`'s
    // re-seed branch sees `next == _externalText` and leaves the cursor put.
    final secs = durationStringToSeconds(raw);
    _externalText = secs == null
        ? raw
        : weeklyHoursText(
            secs,
            widget.formatter,
            hoursMinutes: widget.hoursMinutes,
          );
    widget.onDuration(raw);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      message: '1.5 / 1:30',
      waitDuration: const Duration(milliseconds: 600),
      child: TextField(
        controller: _controller,
        enabled: !widget.readOnly,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        // Allow comma too: the display (weeklyHoursText → f.decimal) renders a
        // comma in comma-decimal locales, and parseDurationInput normalizes
        // ',' → '.', so without it a comma-locale user typing "1,5" gets the
        // comma stripped to "15" and silently logs 15h instead of 1.5h (H3/L5).
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp('[0-9:.,]')),
        ],
        style: const TextStyle(fontSize: 13, fontFeatures: _tabular),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(InRadii.r1),
          ),
          suffixIcon: widget.readOnly
              ? null
              : InkWell(
                  onTap: widget.onNoteTap,
                  child: Icon(
                    Icons.notes,
                    size: 14,
                    color: widget.hasNote ? tokens.accent : tokens.ink4,
                  ),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
        ),
        onChanged: _onChanged,
        textInputAction: TextInputAction.done,
      ),
    );
  }
}
