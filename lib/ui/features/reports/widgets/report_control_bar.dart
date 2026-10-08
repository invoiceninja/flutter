import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/scroll_edge_fades.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/reports/helpers/report_range.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/report_column_tools.dart';
import 'package:admin/ui/features/reports/widgets/report_filters.dart';
import 'package:admin/utils/formatting.dart';

/// The controls that decide what a report covers and how it is cut — sitting
/// directly above the figures, chart and table they all change.
///
/// Each one shows its value at rest. They used to be a 320 px panel beside
/// the results, which a reader had to open and read down to learn what they
/// were looking at, and which on a phone took more than half the screen.
///
/// **What narrows the rows is one row of chips**, whatever kind of filter it
/// is — one the server applies, one the app applies to a column, a drill
/// into a group from the chart. To the reader they are the same thing: the
/// rows are fewer, and here is why, and each can be taken off again.
class ReportControlBar extends StatelessWidget {
  const ReportControlBar({
    super.key,
    required this.vm,
    required this.formatter,
    required this.currencies,
    required this.currencyId,
    required this.wide,
    this.currencyCounts = const {},
  });

  final ReportsViewModel vm;
  final Formatter? formatter;

  /// The currencies the result holds, most rows first; fewer than two draws
  /// no currency control at all.
  final List<String> currencies;
  final String currencyId;

  /// Whether the pane has room for the controls to wrap over a line or two.
  /// Passed by the screen, which already knows. On a narrow pane they are
  /// one line that scrolls sideways instead — still on the page, still
  /// showing their values — because the range and the grouping are what the
  /// reader needs to know they are looking at, and a sheet behind an icon
  /// answers that only when opened.
  final bool wide;

  /// How many rows of the result are in each currency, for the currency
  /// menu.
  final Map<String, int> currencyCounts;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final chips = reportFilterChips(context, vm, formatter);
    final scope = reportScopeControls(context, vm, formatter);
    final shape = reportShapeControls(
      context,
      vm,
      formatter,
      currencies: currencies,
      currencyId: currencyId,
      currencyCounts: currencyCounts,
    );
    // A report with nothing to choose — no range it honours, no filter, no
    // result to cut — has no bar. An empty band is still a band's height.
    if (scope.isEmpty && shape.isEmpty && chips.isEmpty) {
      return const SizedBox.shrink();
    }
    final gap = InSpacing.md(context);
    final Widget content;
    if (!wide) {
      final controls = [...scope, ...shape];
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controls.isNotEmpty)
            ScrollEdgeFades(
              color: tokens.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: InSpacing.lg(context),
                  vertical: InSpacing.sm,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < controls.length; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      controls[i],
                    ],
                  ],
                ),
              ),
            ),
          // Nothing at all when nothing is filtered: an empty strip is
          // still a strip's worth of height.
          if (chips.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                InSpacing.lg(context),
                0,
                InSpacing.lg(context),
                InSpacing.sm,
              ),
              child: Wrap(
                spacing: InSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...chips,
                  ReportClearFilters(vm: vm),
                ],
              ),
            ),
        ],
      );
    } else {
      // What the report covers at the start, how it is cut at the end. Two
      // groups pushed apart while they share a line; when the first grows
      // long enough to need it, the second takes a line of its own.
      Widget group(List<Widget> children) => Wrap(
        spacing: gap,
        runSpacing: InSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.xl,
          vertical: InSpacing.md(context),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: gap,
          runSpacing: InSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            group([
              ...scope,
              ...chips,
              if (chips.isNotEmpty) ReportClearFilters(vm: vm),
            ]),
            if (shape.isNotEmpty) group(shape),
          ],
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: content,
    );
  }
}

/// The controls that decide **what** the report covers: its range, the
/// accounting basis where it has one, and a way to add a filter.
List<Widget> reportScopeControls(
  BuildContext context,
  ReportsViewModel vm,
  Formatter? formatter,
) {
  final tokens = context.inTheme;
  final tr = context.tr;
  final definition = vm.definition;
  final dateKey = reportDateKeyLabelKey(definition.dateRangeKey);
  final caption = Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: tokens.ink2);
  final addable = [
    for (final field in reportBarFilters(definition))
      if (!isReportFilterActive(vm.payload, field)) field,
  ];
  return [
    if (definition.honoursDateRange)
      Builder(
        builder: (anchor) => ReportBarButton(
          key: const Key('report-range'),
          icon: Icons.calendar_today_outlined,
          label: reportRangeLabel(context, vm.payload, formatter),
          onPressed: () => openDateRangePicker(
            anchor,
            current: reportRangeAsPickerValue(vm.payload),
            formatter: formatter,
            onChange: (range) =>
                vm.setPayload(reportPayloadWithRange(vm.payload, range)),
          ),
        ),
      ),
    // Which date the range is a range *of*. Read-only on purpose: the
    // server cannot honour a different one (see
    // `ReportDefinition.dateRangeKey`), so a picker here would be a lie.
    if (definition.honoursDateRange && dateKey != null)
      Text('${tr('filtered_by')} ${tr(dateKey)}', style: caption),
    // Beside the range it is a comparison *of*. Offered only where there is
    // a period before to compare with — and kept on show while it is on, so
    // a range changed to "All time" does not strand it out of reach.
    if (vm.canCompare || vm.compare)
      ReportToggleButton(
        key: const Key('report-compare'),
        label: '${tr('compare')}: ${tr('previous_period')}',
        value: vm.compare,
        onChanged: vm.canCompare || vm.compare ? vm.setCompare : null,
      ),
    if (definition.filterFields.contains(ReportFilterField.isIncomeBilled))
      // A choice of exactly two is shown as two, not hidden in a menu.
      SegmentedButton<bool>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: Env.isTouchPrimary
              ? VisualDensity.standard
              : VisualDensity.compact,
        ),
        segments: [
          ButtonSegment(value: false, label: Text(tr('cash_accounting'))),
          ButtonSegment(value: true, label: Text(tr('cash_vs_accrual'))),
        ],
        selected: {vm.payload.isIncomeBilled},
        onSelectionChanged: (s) =>
            vm.setPayload(vm.payload.copyWith(isIncomeBilled: s.first)),
      ),
    if (addable.isNotEmpty)
      BackDismissibleMenuAnchor(
        menuChildren: [
          for (final field in addable)
            MenuItemButton(
              onPressed: () {
                if (field == ReportFilterField.includeDeleted) {
                  vm.setPayload(vm.payload.copyWith(includeDeleted: true));
                } else {
                  editReportFilter(context, vm, field);
                }
              },
              child: Text(reportFilterLabel(context, field)),
            ),
        ],
        builder: (context, controller, _) => ReportBarButton(
          key: const Key('report-add-filter'),
          icon: Icons.add,
          label: tr('add_filter'),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
  ];
}

/// One removable chip for each thing narrowing the rows.
List<Widget> reportFilterChips(
  BuildContext context,
  ReportsViewModel vm,
  Formatter? formatter,
) {
  final tr = context.tr;
  final chips = <Widget>[];
  for (final field in reportBarFilters(vm.definition)) {
    if (!isReportFilterActive(vm.payload, field)) continue;
    final label = reportFilterLabel(context, field);
    if (field == ReportFilterField.includeDeleted) {
      chips.add(
        _FilterChip(
          label: label,
          onRemove: () =>
              vm.setPayload(vm.payload.copyWith(includeDeleted: false)),
        ),
      );
      continue;
    }
    chips.add(
      ReportFilterSummary(
        vm: vm,
        field: field,
        builder: (context, summary) => _FilterChip(
          label: '$label: $summary',
          onEdit: () => editReportFilter(context, vm, field),
          onRemove: () =>
              vm.setPayload(reportPayloadWithFilter(vm.payload, field, null)),
        ),
      ),
    );
  }
  final columns = vm.run.preview?.columns ?? const <ReportColumn>[];
  for (final entry in vm.columnFilters.entries) {
    final column = columns.where((c) => c.identifier == entry.key).firstOrNull;
    if (column == null) continue;
    chips.add(
      _FilterChip(
        label:
            '${column.displayLabel}: '
            '${reportColumnFilterSummary(context, column, entry.value, formatter: formatter)}',
        onEdit: () =>
            editReportColumnFilter(context, vm, column, formatter: formatter),
        onRemove: () => vm.clearColumnFilter(entry.key),
      ),
    );
  }
  final drill = vm.selectedGroup;
  final group = vm.groupColumn;
  if (drill != null && drill.isNotEmpty && group != null) {
    final text = reportGroupDisplayLabel(
      key: drill,
      columnType: group.type,
      subgroup: vm.subgroup,
      formatter: formatter,
    );
    chips.add(
      _FilterChip(
        label: '${group.displayLabel}: ${text.isEmpty ? tr('blank') : text}',
        onRemove: () => vm.setSelectedGroup(null),
      ),
    );
  }
  return chips;
}

/// Take every filter off: the server's, the columns', the drill.
class ReportClearFilters extends StatelessWidget {
  const ReportClearFilters({super.key, required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('report-clear-filters'),
      onPressed: () {
        vm.clearLocalFilters();
        vm.resetFilters();
      },
      style: TextButton.styleFrom(
        minimumSize: Size(48, Env.isTouchPrimary ? InSizes.touchTarget : 30),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(context.tr('clear_all')),
    );
  }
}

/// The controls that decide **how** the result is cut: what it is grouped
/// by, at what granularity, split by which period, and read in which
/// currency.
List<Widget> reportShapeControls(
  BuildContext context,
  ReportsViewModel vm,
  Formatter? formatter, {
  required List<String> currencies,
  required String currencyId,
  Map<String, int> currencyCounts = const {},
}) {
  final tr = context.tr;
  // Everything here cuts a result that has to exist first.
  if (!vm.definition.supportsPreview || vm.run.preview == null) return const [];
  final group = vm.groupColumn;
  final isDateGroup = group != null && isReportDateType(group.type);
  final candidates = vm.periodCandidates;
  final offerable = vm.offerableDateColumnId;
  final dateKeyLabel = reportDateKeyLabelKey(vm.definition.dateRangeKey);
  final canSplit =
      group != null &&
      !isDateGroup &&
      (candidates.isNotEmpty || (offerable != null && dateKeyLabel != null));
  final periodColumn = candidates
      .where((c) => c.identifier == vm.periodColumn)
      .firstOrNull;
  String currencyLabel(String id) => formatter?.currencies[id]?.code ?? id;
  final split = tr('report_split_by_period');

  return [
    ReportBarButton(
      key: const Key('report-group-by'),
      icon: Icons.segment,
      label:
          '${tr('group_by')}: '
          '${group?.displayLabel ?? (vm.group != null && vm.group == offerable ? tr(dateKeyLabel ?? 'date') : tr('none'))}',
      onPressed: () => _pickGroup(context, vm),
    ),
    if (canSplit)
      BackDismissibleMenuAnchor(
        menuChildren: [
          MenuItemButton(
            onPressed: () => vm.splitByPeriod(null),
            child: Text(tr('none')),
          ),
          for (final c in candidates)
            MenuItemButton(
              onPressed: () => vm.splitByPeriod(c.identifier),
              child: Text(c.displayLabel),
            ),
          if (offerable != null && dateKeyLabel != null)
            MenuItemButton(
              // Not in the result yet: picking it asks the server again.
              trailingIcon: const Icon(Icons.cloud_download_outlined, size: 16),
              onPressed: () => vm.splitByPeriod(offerable),
              child: Text(tr(dateKeyLabel)),
            ),
        ],
        builder: (context, controller, _) => ReportBarButton(
          key: const Key('report-split'),
          icon: Icons.date_range_outlined,
          // At rest it is an offer; once on, it names the date it splits by.
          label: periodColumn == null
              ? split
              : '$split: ${periodColumn.displayLabel}',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    // After the control it is the granularity *of*: the date grouping, or
    // the period split.
    if (isDateGroup || vm.isSplitByPeriod)
      BackDismissibleMenuAnchor(
        menuChildren: [
          for (final sub in ReportSubgroup.values)
            MenuItemButton(
              onPressed: () => vm.setSubgroup(sub),
              child: Text(tr(sub.labelKey)),
            ),
        ],
        builder: (context, controller, _) => ReportBarButton(
          key: const Key('report-granularity'),
          label: tr((vm.subgroup ?? ReportSubgroup.month).labelKey),
          dropdown: true,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    // Only when there is a choice: figures are never added across
    // currencies, so a result holding several is read in one at a time.
    if (currencies.length > 1)
      BackDismissibleMenuAnchor(
        menuChildren: [
          for (final id in currencies)
            MenuItemButton(
              onPressed: () => vm.setCurrency(id),
              leadingIcon: Icon(
                Icons.check,
                size: 16,
                color: id == currencyId
                    ? context.inTheme.ink2
                    : Colors.transparent,
              ),
              trailingIcon: currencyCounts[id] == null
                  ? null
                  : Text(
                      '${currencyCounts[id]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.inTheme.ink3,
                      ),
                    ),
              child: Text(currencyLabel(id)),
            ),
        ],
        builder: (context, controller, _) => ReportBarButton(
          key: const Key('report-currency'),
          icon: Icons.payments_outlined,
          label: currencyLabel(currencyId),
          dropdown: true,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
  ];
}

Future<void> _pickGroup(BuildContext context, ReportsViewModel vm) async {
  final picked = await showDialog<String>(
    context: context,
    builder: (context) => _GroupDialog(vm: vm),
  );
  // Null is a dismissal; the empty string is "no grouping".
  if (picked != null) vm.groupBy(picked);
}

/// Choose the column to group by — every column the result carries, with a
/// search, since a report can have sixty of them.
class _GroupDialog extends StatefulWidget {
  const _GroupDialog({required this.vm});

  final ReportsViewModel vm;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final tokens = context.inTheme;
    final tr = context.tr;
    final pad = InSpacing.lg(context);
    final columns = vm.run.preview?.columns ?? const <ReportColumn>[];
    final needle = _query.trim().toLowerCase();
    final shown = needle.isEmpty
        ? columns
        : [
            for (final c in columns)
              if (c.displayLabel.toLowerCase().contains(needle)) c,
          ];
    final offerable = vm.offerableDateColumnId;
    final dateKeyLabel = reportDateKeyLabelKey(vm.definition.dateRangeKey);

    Widget option(String id, String label, {IconData? trailing}) {
      final selected = (vm.group ?? '') == id;
      return ListTile(
        dense: true,
        selected: selected,
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing != null
            ? Icon(trailing, size: 16, color: tokens.ink3)
            : (selected ? const Icon(Icons.check, size: 18) : null),
        onTap: () => Navigator.of(context).pop(id),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, InSpacing.sm),
              child: Text(
                tr('group_by'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: TextField(
                autofocus: MediaQuery.sizeOf(context).width >= Breakpoints.wide,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: tr('search'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(height: InSpacing.sm),
            Expanded(
              child: ListView(
                children: [
                  if (needle.isEmpty) option('', tr('no_grouping')),
                  for (final c in shown) option(c.identifier, c.displayLabel),
                  if (offerable != null &&
                      dateKeyLabel != null &&
                      tr(dateKeyLabel).toLowerCase().contains(needle))
                    option(
                      offerable,
                      tr(dateKeyLabel),
                      trailing: Icons.cloud_download_outlined,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A control in the bar: a quiet bordered button that shows its value.
class ReportBarButton extends StatelessWidget {
  const ReportBarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dropdown = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  /// Draws a caret after the label: for a button whose label is only a
  /// value ("Month", "USD"), which otherwise reads as a tag, not a choice.
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style = TextButton.styleFrom(
      foregroundColor: tokens.ink,
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size(48, Env.isTouchPrimary ? InSizes.touchTarget : 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(InRadii.r2),
        side: BorderSide(color: tokens.border),
      ),
    );
    final text = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
    );
    final icon = this.icon;
    return TextButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tokens.ink2),
            const SizedBox(width: 6),
          ],
          Flexible(child: text),
          if (dropdown) ...[
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: tokens.ink2),
          ],
        ],
      ),
    );
  }
}

/// A control in the bar that is on or off, and looks it.
class ReportToggleButton extends StatelessWidget {
  const ReportToggleButton({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final onChanged = this.onChanged;
    void toggle() => onChanged?.call(!value);
    return Semantics(
      button: true,
      toggled: value,
      enabled: onChanged != null,
      label: label,
      onTap: onChanged == null ? null : toggle,
      child: ExcludeSemantics(
        child: Material(
          color: value ? tokens.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: value ? Colors.transparent : tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onChanged == null ? null : toggle,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 32,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      value ? Icons.check : Icons.compare_arrows,
                      size: 14,
                      color: value ? tokens.accentInk : tokens.ink2,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: value ? tokens.accentInk : tokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One filter in force: tap it to change it, its ✕ to take it off.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove, this.onEdit});

  final String label;
  final VoidCallback onRemove;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      onPressed: onEdit,
      onDeleted: onRemove,
      deleteButtonTooltipMessage: context.tr('remove'),
      materialTapTargetSize: Env.isTouchPrimary
          ? MaterialTapTargetSize.padded
          : MaterialTapTargetSize.shrinkWrap,
      visualDensity: Env.isTouchPrimary
          ? VisualDensity.standard
          : VisualDensity.compact,
    );
  }
}
