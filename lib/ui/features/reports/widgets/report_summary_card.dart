import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_chart_model.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/domain/reports/report_measures.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/charts/report_bar_list.dart';
import 'package:admin/ui/features/reports/widgets/charts/report_series_plot.dart';
import 'package:admin/ui/features/reports/widgets/report_cell_text.dart';
import 'package:admin/utils/formatting.dart';

/// How many figures the card leads with before the rest go behind "more".
const int _kMaxFigures = 4;

/// A figure the report can lead with and chart.
class _Measure {
  const _Measure({required this.id, required this.label, this.column});

  final String id;
  final String label;

  /// Null for the row count.
  final ReportColumn? column;
}

/// The measure a report charts when the reader has not chosen one.
///
/// The report's first declared headline that the result carries; else its
/// first figure of any kind; else the row count. The count also wins when
/// the grouping is the report's own opted-in date column — grouping clients
/// by *date created* is unambiguously a "how many" question, and the first
/// figure there is Balance, which answers a different one.
String defaultReportMeasureId(ReportsViewModel vm) {
  final columns = reportMeasureColumns(vm.run.preview);
  if (columns.isEmpty) return kReportCountSeriesId;
  if (vm.group != null && vm.group == vm.definition.optionalDateColumnId) {
    return kReportCountSeriesId;
  }
  for (final id in vm.definition.headlineMeasureIds) {
    if (columns.any((c) => c.identifier == id)) return id;
  }
  return columns.first.identifier;
}

/// The measure in force: the reader's choice while the result still carries
/// it, otherwise [defaultReportMeasureId].
String resolveReportMeasureId(ReportsViewModel vm) {
  final chosen = vm.chartColumn;
  if (chosen == kReportCountSeriesId) return kReportCountSeriesId;
  if (chosen != null &&
      reportMeasureColumns(vm.run.preview).any((c) => c.identifier == chosen)) {
    return chosen;
  }
  return defaultReportMeasureId(vm);
}

/// The top of a report: what it adds up to, and the shape of it.
///
/// **The figures are the chart's measure picker.** Each one is a tab; the
/// selected one is what the chart beneath plots. A report used to have a
/// list of totals in one box and a chart with its own dropdown in another,
/// with nothing to say the two were the same numbers.
///
/// **The chart's form follows the data**, not a setting: a date grouping is
/// a trend, any other grouping a ranking, a grouping split by period both at
/// once, and an ungrouped report still shows its largest rows. See
/// [ReportChartModels].
class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({
    super.key,
    required this.vm,
    required this.view,
    required this.formatter,
    required this.currencyId,
    required this.wide,
    this.previous,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final Formatter? formatter;

  /// The period before, cut the same way, when the report is being compared
  /// with it. Every figure then says how it moved, and the chart draws the
  /// earlier period beside the current one.
  final ReportView? previous;

  /// The currency the figures are read in; `''` for a report without one.
  final String currencyId;

  /// Whether the pane has room for a chart and its legend side by side.
  /// Passed by the screen, which already knows.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final measures = _measures(context);
    final selectedId = resolveReportMeasureId(vm);
    final selected = measures.firstWhere(
      (m) => m.id == selectedId,
      orElse: () => measures.first,
    );
    final groupColumn = vm.groupColumn;
    final model = ReportChartModels.build(
      view: view,
      measureId: selected.id,
      currencyId: currencyId,
      groupColumn: view.groups.isEmpty ? null : groupColumn,
      splitByPeriod: vm.isSplitByPeriod,
      fillSpan: vm.periodSpan,
      cumulative: vm.cumulative,
      slots: vm.seriesSlots,
      previous: previous,
      previousPeriodOf: vm.previousPeriodOf,
    );
    final radius = BorderRadius.circular(InRadii.r3);
    final drawable = model != null && !_isBlank(model);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.shadow1,
      ),
      child: Material(
        color: tokens.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FigureTabs(
              vm: vm,
              view: view,
              measures: measures,
              selectedId: selected.id,
              formatter: formatter,
              currencyId: currencyId,
              wide: wide,
              previous: previous,
            ),
            if (drawable) ...[
              Divider(height: 1, thickness: 1, color: tokens.border),
              _ChartHeader(
                vm: vm,
                model: model,
                measure: selected,
                groupColumn: groupColumn,
                formatter: formatter,
              ),
              if (vm.chartVisible)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    InSpacing.lg(context),
                    0,
                    InSpacing.lg(context),
                    InSpacing.lg(context),
                  ),
                  child: _ChartBody(
                    vm: vm,
                    view: view,
                    model: model,
                    measure: selected,
                    groupColumn: groupColumn,
                    formatter: formatter,
                    wide: wide,
                    comparing: previous != null,
                  ),
                ),
            ] else if (view.totalRowCount > 0 &&
                (view.groups.isNotEmpty || selected.column != null)) ...[
              // Rows, and a figure, and nothing to draw: every value of it
              // is zero. Said in the chart's place — a chart that simply
              // vanished when a tab was picked read as something broken,
              // and moved the table up the page under the pointer.
              Divider(height: 1, thickness: 1, color: tokens.border),
              Padding(
                padding: EdgeInsets.all(InSpacing.lg(context)),
                child: Text(
                  context.tr('no_numeric_values_to_chart'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
                ),
              ),
            ],
            if (view.groups.isEmpty) _Suggestions(vm: vm),
          ],
        ),
      ),
    );
  }

  /// Whether [model] has nothing to draw: no marks at all, or marks that are
  /// every one of them zero.
  static bool _isBlank(ReportChartModel model) => switch (model) {
    ReportTimeSeriesChart() => model.points.every(
      (p) => p.value == Decimal.zero,
    ),
    ReportRankedChart() => model.items.isEmpty,
    ReportPivotChart() => model.isEmpty || model.total == Decimal.zero,
  };

  /// The figures on offer: the row count, then every figure the result
  /// carries — the report's declared headlines first, in their declared
  /// order.
  List<_Measure> _measures(BuildContext context) {
    final columns = reportMeasureColumns(vm.run.preview);
    final byId = {for (final c in columns) c.identifier: c};
    final ordered = <ReportColumn>[
      for (final id in vm.definition.headlineMeasureIds) ?byId[id],
    ];
    for (final c in columns) {
      if (!ordered.contains(c)) ordered.add(c);
    }
    return [
      _Measure(id: kReportCountSeriesId, label: _countLabel(context)),
      for (final c in ordered)
        _Measure(id: c.identifier, label: c.displayLabel, column: c),
    ];
  }

  /// What the rows are a count *of*: the report's own name ("Invoices")
  /// where a row is one of them. A report whose rows repeat a record — a
  /// task has a row per time entry — counts rows, and says so.
  String _countLabel(BuildContext context) =>
      vm.definition.oncePerRecordColumnIds.isEmpty
      ? context.tr(vm.definition.labelKey)
      : context.tr('count');
}

String _valueText(
  BuildContext context,
  _Measure measure,
  Decimal value, {
  required Formatter? formatter,
  required String currencyId,
}) {
  final column = measure.column;
  if (column == null) {
    return formatter?.integer(value.toBigInt().toInt()) ??
        value.toBigInt().toString();
  }
  return reportValueText(
    value,
    column: column,
    formatter: formatter,
    currencyId: currencyId,
  );
}

/// Which way is good news for [measure] on this report. Money coming in is
/// better when it rises; money going out, and money still owed, when it
/// falls. A trend drawn green for a rising unpaid balance would be telling
/// the reader the opposite of what happened.
GoodDirection _goodDirection(ReportsViewModel vm, _Measure measure) {
  final spending = vm.definition.category == ReportCategory.expenses;
  final owed = measure.id.split('.').last == 'balance';
  return spending || owed ? GoodDirection.down : GoodDirection.up;
}

/// The headline figures, each a tab that picks what the chart plots.
class _FigureTabs extends StatelessWidget {
  const _FigureTabs({
    required this.vm,
    required this.view,
    required this.measures,
    required this.selectedId,
    required this.formatter,
    required this.currencyId,
    required this.wide,
    this.previous,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final List<_Measure> measures;
  final String selectedId;
  final Formatter? formatter;
  final String currencyId;
  final bool wide;
  final ReportView? previous;

  Decimal? _value(_Measure m) => _of(view, m);

  Decimal? _of(ReportView v, _Measure m) {
    // Every row, whatever its currency — the same number the table states.
    if (m.column == null) return Decimal.fromInt(v.totalRowCount);
    return reportTotal(v.grandTotalsByCurrency, m.id, currencyId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Lead with the count and the first few figures; whatever the reader
    // picked from "more" takes the last place rather than vanishing.
    final lead = measures.take(_kMaxFigures).toList();
    if (!lead.any((m) => m.id == selectedId)) {
      final chosen = measures.where((m) => m.id == selectedId).firstOrNull;
      if (chosen != null) lead[lead.length - 1] = chosen;
    }
    final rest = [
      for (final m in measures)
        if (!lead.contains(m)) m,
    ];

    Widget tab(_Measure m) {
      final value = _value(m);
      return _FigureTab(
        label: m.label,
        value: value == null
            ? '—'
            : _valueText(
                context,
                m,
                value,
                formatter: formatter,
                currencyId: currencyId,
              ),
        isMoney: m.column?.type == ReportColumnType.money,
        selected: m.id == selectedId,
        onTap: () => vm.setChartColumn(m.id),
        // Nothing in the earlier period is "no figure to compare with" —
        // the chip then draws a dash rather than an infinite rise.
        delta: previous == null
            ? null
            : DeltaChip(
                percent: percentDelta(
                  value,
                  _of(previous!, m) ?? (m.column == null ? null : Decimal.zero),
                ),
                goodDirection: _goodDirection(vm, m),
              ),
      );
    }

    final more = rest.isEmpty
        ? null
        : _MoreFigures(
            measures: rest,
            onSelect: (m) => vm.setChartColumn(m.id),
          );

    if (!wide) {
      // Two to a row; the page is not wide enough for four amounts abreast.
      final rows = <Widget>[];
      for (var i = 0; i < lead.length; i += 2) {
        if (i > 0) {
          rows.add(Divider(height: 1, thickness: 1, color: tokens.border));
        }
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tab(lead[i])),
                VerticalDivider(width: 1, thickness: 1, color: tokens.border),
                Expanded(
                  child: i + 1 < lead.length
                      ? tab(lead[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      }
      return Stack(
        children: [
          Column(mainAxisSize: MainAxisSize.min, children: rows),
          if (more != null) PositionedDirectional(top: 2, end: 2, child: more),
        ],
      );
    }
    return Stack(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < lead.length; i++) ...[
                if (i > 0)
                  VerticalDivider(width: 1, thickness: 1, color: tokens.border),
                Expanded(child: tab(lead[i])),
              ],
            ],
          ),
        ),
        if (more != null) PositionedDirectional(top: 2, end: 2, child: more),
      ],
    );
  }
}

class _FigureTab extends StatelessWidget {
  const _FigureTab({
    required this.label,
    required this.value,
    required this.isMoney,
    required this.selected,
    required this.onTap,
    this.delta,
  });

  final String label;
  final String value;
  final bool isMoney;
  final bool selected;
  final VoidCallback onTap;

  /// How the figure moved against the period before, when compared.
  final Widget? delta;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final pad = InSpacing.lg(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $value',
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scaled to fit, never ellipsised: "RECHNU…" over a
                    // number does not say what the number is.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: selected ? tokens.ink : tokens.ink2,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        value,
                        maxLines: 1,
                        softWrap: false,
                        // Proportional figures at this size: equal-width
                        // digits make a large "121" look loose. The amount
                        // keeps the app's money face.
                        style: isMoney
                            ? moneyTextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.4,
                                height: 1.25,
                                color: tokens.ink,
                              )
                            : TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.4,
                                height: 1.25,
                                color: tokens.ink,
                              ),
                      ),
                    ),
                    if (delta != null) ...[const SizedBox(height: 2), delta!],
                  ],
                ),
              ),
              // Which figure the chart is of. A bar under the tab, not a
              // fill: the tab is a number first and a control second.
              if (selected)
                PositionedDirectional(
                  start: pad,
                  end: pad,
                  bottom: 0,
                  child: SizedBox(
                    height: 2,
                    child: ColoredBox(color: tokens.accent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreFigures extends StatelessWidget {
  const _MoreFigures({required this.measures, required this.onSelect});

  final List<_Measure> measures;
  final ValueChanged<_Measure> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final extent = Env.isTouchPrimary ? InSizes.touchTarget : 28.0;
    return BackDismissibleMenuAnchor(
      menuChildren: [
        for (final m in measures)
          MenuItemButton(onPressed: () => onSelect(m), child: Text(m.label)),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: context.tr('report_more_figures'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: Icon(Icons.more_vert, size: 16, color: tokens.ink3),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          fixedSize: Size(extent, extent),
          minimumSize: Size.zero,
          maximumSize: Size.infinite,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

String _groupingText(
  BuildContext context,
  ReportsViewModel vm,
  ReportColumn? groupColumn,
) {
  if (groupColumn == null) return '';
  final granularity = vm.subgroup == null
      ? null
      : context.tr(vm.subgroup!.labelKey);
  if (isReportDateType(groupColumn.type)) {
    return granularity ?? groupColumn.displayLabel;
  }
  if (vm.isSplitByPeriod) {
    return '${groupColumn.displayLabel} · '
        '${granularity ?? context.tr(ReportSubgroup.month.labelKey)}';
  }
  return groupColumn.displayLabel;
}

/// What the chart is of, and the few choices about how it is drawn.
class _ChartHeader extends StatelessWidget {
  const _ChartHeader({
    required this.vm,
    required this.model,
    required this.measure,
    required this.groupColumn,
    required this.formatter,
  });

  final ReportsViewModel vm;
  final ReportChartModel model;
  final _Measure measure;
  final ReportColumn? groupColumn;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final tr = context.tr;
    final model = this.model;
    final String title;
    if (model is ReportRankedChart && model.fromRows) {
      title = tr('report_top_rows', {
        'count': '${model.items.length}',
        'measure': measure.label,
      });
    } else {
      title = tr('report_group_by_label', {
        'measure': measure.label,
        'dimension': _groupingText(context, vm, groupColumn),
      });
    }
    final caption = _peakCaption(context);
    final isTime = model is ReportTimeSeriesChart || model is ReportPivotChart;
    final style = _effectiveStyle(vm, model);
    final extent = Env.isTouchPrimary ? InSizes.touchTarget : 28.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.sm,
        InSpacing.md(context),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: InSpacing.sm,
        children: [
          // The title keeps a readable width; when the controls cannot sit
          // beside that, they go to a line of their own rather than squeeze
          // "Amount by Month" down to "Amo…".
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (caption != null && vm.chartVisible)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink2,
                    ),
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vm.chartVisible && model is ReportTimeSeriesChart) ...[
                _Toggle(
                  label: tr('report_cumulative'),
                  value: vm.cumulative,
                  onChanged: vm.setCumulative,
                ),
                const SizedBox(width: InSpacing.sm),
              ],
              if (vm.chartVisible && isTime)
                SegmentedButton<ReportTimeChartStyle>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: Env.isTouchPrimary
                        ? VisualDensity.standard
                        : VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  segments: [
                    ButtonSegment(
                      value: ReportTimeChartStyle.columns,
                      icon: const Icon(Icons.bar_chart, size: 16),
                      tooltip: tr('report_chart_columns'),
                    ),
                    ButtonSegment(
                      value: ReportTimeChartStyle.line,
                      icon: const Icon(Icons.show_chart, size: 16),
                      tooltip: tr('report_chart_line'),
                    ),
                  ],
                  selected: {style},
                  onSelectionChanged: (s) => vm.setTimeChartStyle(s.first),
                ),
              IconButton(
                tooltip: tr(vm.chartVisible ? 'hide_chart' : 'show_chart'),
                onPressed: () => vm.setChartVisible(!vm.chartVisible),
                icon: Icon(
                  vm.chartVisible ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: tokens.ink2,
                ),
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  fixedSize: Size(extent, extent),
                  minimumSize: Size.zero,
                  maximumSize: Size.infinite,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Peak: March 2026 · $24,000" — the one point of a trend worth naming,
  /// said in words beside the title rather than as a number printed on every
  /// column.
  String? _peakCaption(BuildContext context) {
    final model = this.model;
    if (model is! ReportTimeSeriesChart) return null;
    final at = model.peakIndex;
    if (at < 0 || model.points.length < 3) return null;
    final point = model.points[at];
    final label = reportGroupDisplayLabel(
      key: point.key,
      columnType: groupColumn?.type,
      subgroup: vm.subgroup,
      formatter: formatter,
    );
    final value = _valueText(
      context,
      measure,
      point.value,
      formatter: formatter,
      currencyId: model.currencyId,
    );
    return '${context.tr('report_peak')}: $label · $value';
  }
}

/// Columns while there are few enough periods to be columns; a line beyond
/// that. The reader's own choice wins.
ReportTimeChartStyle _effectiveStyle(
  ReportsViewModel vm,
  ReportChartModel model,
) {
  final chosen = vm.timeChartStyle;
  if (chosen != null) return chosen;
  final periods = switch (model) {
    ReportTimeSeriesChart() => model.points.length,
    ReportPivotChart() => model.periods.length,
    ReportRankedChart() => 0,
  };
  return periods <= 24
      ? ReportTimeChartStyle.columns
      : ReportTimeChartStyle.line;
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Semantics(
      button: true,
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: Material(
          color: value ? tokens.accentSoft : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: value ? Colors.transparent : tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(!value),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 28,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: value ? tokens.accentInk : tokens.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartBody extends StatelessWidget {
  const _ChartBody({
    required this.vm,
    required this.view,
    required this.model,
    required this.measure,
    required this.groupColumn,
    required this.formatter,
    required this.wide,
    this.comparing = false,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final ReportChartModel model;
  final _Measure measure;
  final ReportColumn? groupColumn;
  final Formatter? formatter;
  final bool wide;

  /// Whether the report is being read against the period before.
  final bool comparing;

  String _full(BuildContext context, Decimal value) => _valueText(
    context,
    measure,
    value,
    formatter: formatter,
    currencyId: model.currencyId,
  );

  String _fullDouble(BuildContext context, double value) =>
      _full(context, Decimal.parse(value.toStringAsFixed(2)));

  /// A value as an axis label: short enough to sit in the margin.
  String _axis(double value) {
    final column = measure.column;
    if (column?.type == ReportColumnType.money && formatter != null) {
      return formatter!.money(
        Decimal.parse(value.toStringAsFixed(0)),
        currencyId: model.currencyId.isEmpty ? null : model.currencyId,
        compact: true,
      );
    }
    if (column?.type == ReportColumnType.duration) {
      final hours = value / 3600;
      return '${hours.toStringAsFixed(hours >= 10 || hours == 0 ? 0 : 1)}h';
    }
    return NumberFormat.compact().format(value);
  }

  String _groupLabel(String key) {
    final text = reportGroupDisplayLabel(
      key: key,
      columnType: groupColumn?.type,
      subgroup: vm.subgroup,
      formatter: formatter,
    );
    return text.isEmpty ? '—' : text;
  }

  String _periodLabel(String key) {
    if (key.isEmpty) return '—';
    return reportGroupDisplayLabel(
      key: key,
      columnType: ReportColumnType.date,
      subgroup: vm.subgroup ?? ReportSubgroup.month,
      formatter: formatter,
    );
  }

  String? _share(double? share) {
    if (share == null) return null;
    final percent = share * 100;
    return '${percent.toStringAsFixed(percent < 10 && percent > 0 ? 1 : 0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final model = this.model;
    final isCount = measure.column == null;
    final description =
        '${measure.label} — ${_groupingText(context, vm, groupColumn)}';
    switch (model) {
      case ReportTimeSeriesChart():
        final plot = ReportSeriesPlot(
          labels: [
            for (final p in model.points)
              reportGroupDisplayLabel(
                key: p.key,
                columnType: groupColumn?.type,
                subgroup: vm.subgroup,
                formatter: formatter,
              ),
          ],
          axisLabels: reportGroupAxisLabels(
            keys: [for (final p in model.points) p.key],
            subgroup: vm.subgroup,
            formatter: formatter,
          ),
          series: [
            ReportPlotSeries(
              name: measure.label,
              color: tokens.series.first,
              values: [for (final p in model.points) p.value.toDouble()],
            ),
            // The period before, in neutral ink behind the measure: context,
            // not a second measure.
            if (model.hasPrevious)
              ReportPlotSeries(
                name: context.tr('previous_period'),
                color: tokens.ink4,
                values: [for (final v in model.previous) v?.toDouble() ?? 0],
                context: true,
              ),
          ],
          style: _effectiveStyle(vm, model),
          axisText: _axis,
          valueText: (v) => _fullDouble(context, v),
          wholeNumbers: isCount,
          semanticsLabel: description,
          onTapIndex: (i) {
            final point = model.points[i];
            // A period the fill invented has no rows to show.
            if (point.hasRows) vm.setSelectedGroup(point.key);
          },
        );
        if (!model.hasPrevious) return plot;
        // Two series, so a legend — and it is where the earlier period is
        // said in dates, which "previous period" alone does not.
        final window = vm.compareWindow;
        final earlier = window == null
            ? null
            : formatter?.dateRange(
                window.previousStart.toIso(),
                window.previousEnd.toIso(),
              );
        Widget entry(Color color, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChartSwatch(color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: tokens.ink2),
              ),
            ),
          ],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: InSpacing.lg(context),
              runSpacing: 4,
              children: [
                entry(tokens.series.first, measure.label),
                entry(
                  tokens.ink4,
                  earlier == null
                      ? context.tr('previous_period')
                      : '${context.tr('previous_period')} · $earlier',
                ),
              ],
            ),
            const SizedBox(height: InSpacing.sm),
            plot,
          ],
        );
      case ReportRankedChart():
        final max = model.maxValue;
        return ReportBarList(
          items: [
            for (final item in model.items)
              ReportBarListItem(
                label: item.isOther
                    ? context.tr('report_other_groups', {
                        'count': '${item.count}',
                      })
                    : (model.fromRows
                          ? _rowLabel(context, model, item)
                          : _groupLabel(item.key)),
                valueText: _full(context, item.value),
                shareText: _share(item.share),
                fraction: max == Decimal.zero
                    ? 0
                    : (item.value.abs() / max).toDouble(),
                muted: item.isOther,
                onTap: _rankedTap(context, model, item),
                trailing: view.groups.isEmpty || item.isOther || !comparing
                    ? null
                    : SizedBox(
                        width: 64,
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: DeltaChip(
                            percent: percentDelta(item.value, item.previous),
                            goodDirection: _goodDirection(vm, measure),
                          ),
                        ),
                      ),
              ),
          ],
        );
      case ReportPivotChart():
        final hidden = vm.hiddenSeries;
        final plot = ReportSeriesPlot(
          labels: [for (final p in model.periods) _periodLabel(p)],
          axisLabels: reportGroupAxisLabels(
            keys: model.periods,
            subgroup: vm.subgroup ?? ReportSubgroup.month,
            formatter: formatter,
          ).map((l) => l.isEmpty ? '—' : l).toList(),
          series: [
            for (final s in model.series)
              ReportPlotSeries(
                name: s.isOther ? context.tr('other') : _groupLabel(s.key),
                color: s.isOther ? tokens.seriesOther : tokens.series[s.slot],
                // A hidden series stays in its place as zeros, so the ones
                // still shown keep their positions and their colours.
                values: [
                  for (final v in s.values)
                    hidden.contains(s.key) ? 0 : v.toDouble(),
                ],
              ),
          ],
          style: _effectiveStyle(vm, model),
          axisText: _axis,
          valueText: (v) => _fullDouble(context, v),
          wholeNumbers: isCount,
          semanticsLabel: description,
        );
        // The ranked list beside the chart *is* its legend: each line names
        // a series, shows its total, and switches it on and off.
        final max = model.series.fold<Decimal>(
          Decimal.zero,
          (best, s) => s.total.abs() > best ? s.total.abs() : best,
        );
        final legend = ReportBarList(
          items: [
            for (final s in model.series)
              ReportBarListItem(
                label: s.isOther
                    ? context.tr('report_other_groups', {'count': '${s.count}'})
                    : _groupLabel(s.key),
                valueText: _full(context, s.total),
                shareText: _share(
                  model.total > Decimal.zero
                      ? (s.total / model.total).toDouble()
                      : null,
                ),
                fraction: max == Decimal.zero
                    ? 0
                    : (s.total.abs() / max).toDouble(),
                color: s.isOther ? null : tokens.series[s.slot],
                muted: s.isOther,
                dimmed: hidden.contains(s.key),
                onTap: () => vm.toggleSeries(s.key),
              ),
          ],
        );
        if (!wide) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              plot,
              const SizedBox(height: InSpacing.sm),
              legend,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: plot),
            SizedBox(width: InSpacing.lg(context)),
            Expanded(flex: 2, child: legend),
          ],
        );
    }
  }

  String _rowLabel(
    BuildContext context,
    ReportRankedChart model,
    ReportRankedItem item,
  ) {
    final row = item.row;
    if (row == null) return '—';
    String cellAt(int index) {
      if (index < 0 || index >= row.cells.length) return '';
      final column = view.visibleColumns.firstWhere(
        (c) => view.cellIndexByColumn[c.identifier] == index,
        orElse: () => view.visibleColumns.first,
      );
      return reportCellText(context, row.cells[index], column, formatter);
    }

    final name = cellAt(model.labelCellIndex);
    final detail = cellAt(model.detailCellIndex);
    if (name.isEmpty) return detail.isEmpty ? '—' : detail;
    return detail.isEmpty ? name : '$name · $detail';
  }

  VoidCallback? _rankedTap(
    BuildContext context,
    ReportRankedChart model,
    ReportRankedItem item,
  ) {
    if (item.isOther) return null;
    if (model.fromRows) {
      final row = item.row;
      if (row == null) return null;
      final route = reportRowRoute(context, row);
      return route == null ? null : () => context.go(route);
    }
    return () => vm.setSelectedGroup(item.key);
  }
}

/// On a report that is not grouped: its ready-made views, one tap each.
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.vm});

  final ReportsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final preview = vm.run.preview;
    if (preview == null) return const SizedBox.shrink();
    final ids = {for (final c in preview.columns) c.identifier};
    final views = <ReportStarterView>[
      for (final v in vm.definition.starterViews)
        if (ids.contains(v.group)) v,
    ];
    if (views.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.sm,
        ),
        child: Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              context.tr('group_by'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
            ),
            for (final v in views)
              _Toggle(
                label: context.tr(v.labelKey),
                value: false,
                onChanged: (_) => vm.applyStarterView(v),
              ),
          ],
        ),
      ),
    );
  }
}
