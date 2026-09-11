import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

/// Identifier of the synthetic "how many rows in this bucket" series.
///
/// Not a preview column — [GroupTotals.count] already holds the number and
/// the table's group rows already print it; only the chart couldn't draw
/// it, which on a report grouped by a date is the one series worth drawing.
/// It is composed here rather than in the view model because the label
/// needs a `BuildContext`, and because `setChartColumn` stores an arbitrary
/// `String` that is never reconciled against the column set.
///
/// Named for the server's own key for the same figure (`groupedReturnJson`
/// appends a `group.count` column), which a preview can never carry: the
/// app does its grouping locally and never sends `group_by` on preview.
const String kReportCountSeriesId = 'group.count';

/// Which series a chart shows when the user hasn't picked one.
///
/// Count wins in two cases: when the report has no numeric column at all
/// (which used to be the `no_numeric_values_to_chart` dead end), and when
/// the grouping is the opted-in date column — grouping clients by *date
/// created* is unambiguously a "how many" question, and the first numeric
/// column there is `Balance`, which answers a different one. Everywhere
/// else the first numeric column still wins, so an invoice report grouped
/// by date keeps charting Amount.
String defaultReportSeriesId(ReportsViewModel vm) {
  final numeric = vm.numericChartColumns();
  final countWins =
      numeric.isEmpty ||
      (vm.group != null && vm.group == vm.definition.optionalDateColumnId);
  return countWins ? kReportCountSeriesId : numeric.first.identifier;
}

/// Bar chart per group, anchored on the picked series — the row count or
/// any numeric column. A date grouping renders a chronological line
/// instead, with empty periods filled in as zeroes. Renders between the
/// drill breadcrumb and the totals card in `_ReportTableArea`.
/// Caller is responsible for the visibility gate — the card assumes it's
/// mounted only when `view.groups.isNotEmpty && vm.chartVisible`.
///
/// Manages two pieces of local state: the auto-picked series (read back
/// from `vm.chartColumn` after the post-frame callback) and the active
/// currency for multi-currency views (transient — not persisted on the
/// VM, unlike the series, which is).
class ReportsChartCard extends StatefulWidget {
  const ReportsChartCard({
    super.key,
    required this.view,
    required this.formatter,
  });

  final ReportView view;
  final Formatter? formatter;

  @override
  State<ReportsChartCard> createState() => _ReportsChartCardState();
}

class _ReportsChartCardState extends State<ReportsChartCard> {
  String? _activeCurrency;

  @override
  void initState() {
    super.initState();
    _scheduleAutoPick();
  }

  @override
  void didUpdateWidget(ReportsChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleAutoPick();
  }

  /// Auto-pick a series when `vm.chartColumn` is null or stale (names a
  /// column the current preview doesn't carry). Runs post-frame so we don't
  /// notify mid-build; guarded by `mounted` so a disposed card (report
  /// switch) doesn't fire a stale write. See [defaultReportSeriesId].
  void _scheduleAutoPick() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<ReportsViewModel>();
      final current = vm.chartColumn;
      final numeric = vm.numericChartColumns();
      final isValid =
          current == kReportCountSeriesId ||
          (current != null && numeric.any((c) => c.identifier == current));
      if (isValid) return;
      vm.setChartColumn(defaultReportSeriesId(vm));
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportsViewModel>();
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final numeric = [
      ReportColumn(
        identifier: kReportCountSeriesId,
        displayLabel: context.tr('count'),
        type: ReportColumnType.number,
      ),
      ...vm.numericChartColumns(),
    ];
    final groupColumnId = vm.group;
    final groupColumn = _findColumn(widget.view, groupColumnId);
    final groupLabel = groupColumn?.displayLabel ?? context.tr('chart');

    final picked = _pickedColumn(vm, numeric);
    final allCurrencies = _allCurrenciesForColumn(picked.identifier);
    final defaultCurrency = _defaultCurrency(allCurrencies);
    final currency = _activeCurrency ?? defaultCurrency;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: DashboardCardShell(
        title: groupLabel,
        trailing: _HeaderTrailing(
          numericColumns: numeric,
          pickedColumnId: picked.identifier,
          currencies: allCurrencies,
          activeCurrency: currency,
          onColumnChanged: (id) {
            if (id == null) return;
            vm.setChartColumn(id);
            // Reset active currency so the default policy re-evaluates
            // against the new column's currency mix.
            setState(() => _activeCurrency = null);
          },
          onCurrencyChanged: (cur) => setState(() => _activeCurrency = cur),
          onClose: () => vm.setChartVisible(false),
        ),
        child: _Body(
          view: widget.view,
          formatter: widget.formatter,
          pickedColumn: picked,
          groupColumn: groupColumn,
          bucketKeys: vm.chartBucketKeys(widget.view.groups, groupColumn),
          subgroup: vm.subgroup,
          currency: currency,
          showCurrencyHint: allCurrencies.length > 1 && _activeCurrency == null,
          accent: tokens.accent,
          axisLabelStyle: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink2,
          ),
        ),
      ),
    );
  }

  /// The series currently selected for charting, resolved against [series]
  /// (the count series plus every numeric column). Falls back to the same
  /// rule the post-frame auto-pick uses, so the frame before that callback
  /// lands doesn't chart a different series than the one that sticks.
  ReportColumn _pickedColumn(ReportsViewModel vm, List<ReportColumn> series) {
    final id = vm.chartColumn ?? defaultReportSeriesId(vm);
    for (final c in series) {
      if (c.identifier == id) return c;
    }
    return series.first;
  }

  ReportColumn? _findColumn(ReportView view, String? id) {
    if (id == null) return null;
    for (final c in view.visibleColumns) {
      if (c.identifier == id) return c;
    }
    return null;
  }

  /// Union of every currency that appears in any group's bucket for the
  /// given column. Empty when no column is picked or no group has values
  /// for it.
  Set<String> _allCurrenciesForColumn(String? columnId) {
    if (columnId == null || columnId == kReportCountSeriesId) {
      return const <String>{};
    }
    final out = <String>{};
    for (final g in widget.view.groups) {
      final perCur = g.numericTotals[columnId];
      if (perCur == null) continue;
      for (final cur in perCur.keys) {
        if (perCur[cur] != Decimal.zero) out.add(cur);
      }
    }
    return out;
  }

  /// The default currency for the chart: company currency if present in
  /// the data, otherwise the currency with the largest absolute total
  /// across all groups (the "dominant" one). Falls back to '' on empty.
  String _defaultCurrency(Set<String> currencies) {
    if (currencies.isEmpty) return '';
    final companyId = widget.formatter?.settings.currencyId;
    if (companyId != null && currencies.contains(companyId)) return companyId;
    // Pick the dominant currency by summed absolute value across groups.
    final pickedColumn = context.read<ReportsViewModel>().chartColumn;
    if (pickedColumn == null) return currencies.first;
    String best = currencies.first;
    Decimal bestSum = Decimal.zero;
    for (final cur in currencies) {
      Decimal sum = Decimal.zero;
      for (final g in widget.view.groups) {
        final v = g.numericTotals[pickedColumn]?[cur];
        if (v != null) sum += v.abs();
      }
      if (sum > bestSum) {
        bestSum = sum;
        best = cur;
      }
    }
    return best;
  }
}

class _HeaderTrailing extends StatelessWidget {
  const _HeaderTrailing({
    required this.numericColumns,
    required this.pickedColumnId,
    required this.currencies,
    required this.activeCurrency,
    required this.onColumnChanged,
    required this.onCurrencyChanged,
    required this.onClose,
  });

  final List<ReportColumn> numericColumns;
  final String? pickedColumnId;
  final Set<String> currencies;
  final String activeCurrency;
  final ValueChanged<String?> onColumnChanged;
  final ValueChanged<String> onCurrencyChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final showColumnPicker = numericColumns.length > 1;
    final showCurrencyPicker = currencies.length > 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showColumnPicker) ...[
          DropdownButton<String>(
            key: const Key('report-chart-series'),
            value: pickedColumnId,
            underline: const SizedBox.shrink(),
            isDense: true,
            onChanged: onColumnChanged,
            items: [
              for (final c in numericColumns)
                DropdownMenuItem(
                  value: c.identifier,
                  child: Text(c.displayLabel),
                ),
            ],
          ),
          SizedBox(width: InSpacing.md(context)),
        ],
        if (showCurrencyPicker) ...[
          DropdownButton<String>(
            key: const Key('report-chart-currency'),
            value: activeCurrency.isEmpty ? null : activeCurrency,
            underline: const SizedBox.shrink(),
            isDense: true,
            onChanged: (cur) {
              if (cur != null) onCurrencyChanged(cur);
            },
            items: [
              for (final cur in currencies)
                DropdownMenuItem(
                  value: cur,
                  child: Text(_currencyLabel(context, cur)),
                ),
            ],
          ),
          SizedBox(width: InSpacing.md(context)),
        ],
        IconButton(
          tooltip: context.tr('hide_chart'),
          icon: Icon(Icons.close, size: 18, color: tokens.ink3),
          onPressed: onClose,
        ),
      ],
    );
  }

  String _currencyLabel(BuildContext context, String currencyId) {
    // The Formatter resolves currency code/name from the statics. The
    // chart card may not be able to reach that map here without lifting
    // the formatter into the trailing widget — keep it simple and show
    // the id; the picker is rarely opened.
    return currencyId;
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.view,
    required this.formatter,
    required this.pickedColumn,
    required this.groupColumn,
    required this.bucketKeys,
    required this.subgroup,
    required this.currency,
    required this.showCurrencyHint,
    required this.accent,
    required this.axisLabelStyle,
  });

  final ReportView view;
  final Formatter? formatter;
  final ReportColumn pickedColumn;
  final ReportColumn? groupColumn;

  /// Contiguous bucket keys for a date grouping, when the raw buckets have
  /// gaps. Empty means "plot the buckets as they are". See
  /// [ReportsViewModel.chartBucketKeys].
  final List<String> bucketKeys;
  final ReportSubgroup? subgroup;
  final String currency;
  final bool showCurrencyHint;
  final Color accent;
  final TextStyle? axisLabelStyle;

  @override
  Widget build(BuildContext context) {
    // A date/dateTime grouping renders as a chronological line (the engine
    // emits date buckets in ascending order); everything else is a
    // value-sorted bar chart. Mirrors admin-portal's bar-vs-time-series split.
    final isTimeSeries =
        groupColumn != null &&
        (groupColumn!.type == ReportColumnType.date ||
            groupColumn!.type == ReportColumnType.dateTime);
    final isCount = pickedColumn.identifier == kReportCountSeriesId;
    final values = isTimeSeries
        ? _series(view, pickedColumn.identifier, currency)
        : _bars(view, pickedColumn.identifier, currency);
    if (values.isEmpty) {
      return _EmptyHint(message: context.tr('no_numeric_values_to_chart'));
    }
    final maxY = values
        .map((b) => b.value.toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);
    // A count's headroom rounds up to a whole number, so fl_chart's own
    // interval lands on integers — "New clients: 2.4" is not a reading.
    final yMax = maxY <= 0
        ? 1.0
        : (isCount ? (maxY * 1.15).ceilToDouble() : maxY * 1.15);
    final rotateLabels = values.length > 6;
    final isMoney = pickedColumn.type == ReportColumnType.money;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showCurrencyHint)
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.sm),
            child: Text(
              context
                  .tr('chart_currency_hint')
                  .replaceFirst(':currency', currency),
              style: axisLabelStyle,
            ),
          ),
        Semantics(
          label:
              '${isTimeSeries ? 'Line chart' : 'Bar chart'}, '
              '${values.length} groups by ${pickedColumn.displayLabel}',
          child: SizedBox(
            height: 240,
            child: isTimeSeries
                ? _lineChart(
                    context,
                    values,
                    yMax,
                    rotateLabels,
                    isMoney,
                    isCount,
                  )
                : _barChart(
                    context,
                    values,
                    yMax,
                    rotateLabels,
                    isMoney,
                    isCount,
                  ),
          ),
        ),
      ],
    );
  }

  /// Shared left (value) + bottom (group label) axis config. The bottom axis
  /// only labels integer x positions (line charts may sample fractional x).
  FlTitlesData _axisTitles(
    List<_Bar> values,
    bool isMoney,
    bool rotateLabels, {
    bool isCount = false,
  }) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 56,
          getTitlesWidget: (v, _) {
            // Same guard the bottom axis uses: fl_chart picks its own
            // interval, and half a record does not exist.
            if (isCount && v != v.roundToDouble()) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                _formatValue(Decimal.parse(v.toString()), isMoney),
                style: axisLabelStyle,
                textAlign: TextAlign.right,
              ),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: rotateLabels ? 72 : 36,
          interval: 1,
          getTitlesWidget: (v, _) {
            if (v != v.roundToDouble()) return const SizedBox.shrink();
            final i = v.toInt();
            if (i < 0 || i >= values.length) {
              return const SizedBox.shrink();
            }
            final label = values[i].label;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: rotateLabels
                  ? RotatedBox(
                      quarterTurns: -1,
                      child: Text(label, style: axisLabelStyle),
                    )
                  : Text(
                      label,
                      style: axisLabelStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _barChart(
    BuildContext context,
    List<_Bar> values,
    double yMax,
    bool rotateLabels,
    bool isMoney,
    bool isCount,
  ) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, _) {
              final bar = values[group.x];
              return BarTooltipItem(
                '${bar.label}\n${_formatValue(bar.value, isMoney)}',
                TextStyle(color: context.inTheme.surface),
              );
            },
          ),
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final spot = response?.spot;
            if (spot == null) return;
            final idx = spot.touchedBarGroupIndex;
            if (idx < 0 || idx >= values.length) return;
            _drillInto(context, view, values[idx].key);
          },
        ),
        titlesData: _axisTitles(
          values,
          isMoney,
          rotateLabels,
          isCount: isCount,
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].value.toDouble(),
                  color: accent,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(InRadii.r1),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _lineChart(
    BuildContext context,
    List<_Bar> values,
    double yMax,
    bool rotateLabels,
    bool isMoney,
    bool isCount,
  ) {
    final tokens = context.inTheme;
    return LineChart(
      LineChartData(
        maxY: yMax,
        minY: 0,
        minX: 0,
        maxX: (values.length - 1).clamp(0, double.infinity).toDouble(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tokens.ink,
            getTooltipItems: (spots) => [
              for (final s in spots)
                if (s.x.toInt() >= 0 && s.x.toInt() < values.length)
                  LineTooltipItem(
                    '${values[s.x.toInt()].label}\n'
                    '${_formatValue(values[s.x.toInt()].value, isMoney)}',
                    TextStyle(color: tokens.surface),
                  ),
            ],
          ),
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final spots = response?.lineBarSpots;
            if (spots == null || spots.isEmpty) return;
            final idx = spots.first.x.toInt();
            if (idx < 0 || idx >= values.length) return;
            _drillInto(context, view, values[idx].key);
          },
        ),
        titlesData: _axisTitles(
          values,
          isMoney,
          rotateLabels,
          isCount: isCount,
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < values.length; i++)
                FlSpot(i.toDouble(), values[i].value.toDouble()),
            ],
            color: accent,
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: accent.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(Decimal value, bool isMoney) {
    if (isMoney && formatter != null) {
      return formatter!.money(value, currencyId: currency);
    }
    return value.toString();
  }

  /// One group's value for the picked series — its row count for the
  /// synthetic count series, otherwise the per-currency total.
  Decimal? _valueOf(GroupTotals g, String columnId, String currency) =>
      columnId == kReportCountSeriesId
      ? Decimal.fromInt(g.count)
      : g.numericTotals[columnId]?[currency];

  /// Build the bar series for the current column + currency. Sorts by
  /// value descending so the largest bar sits leftmost (more readable
  /// than the engine's alphabetic group order).
  List<_Bar> _bars(ReportView view, String columnId, String currency) {
    final out = <_Bar>[];
    for (final g in view.groups) {
      final v = _valueOf(g, columnId, currency);
      if (v == null || v == Decimal.zero) continue;
      out.add(_Bar(key: g.key, value: v, label: _label(g.key)));
    }
    out.sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// Time-series points in the engine's group order (date buckets are
  /// emitted ascending), so the line reads left-to-right in time.
  ///
  /// Every bucket is kept, zero totals included — and where [bucketKeys]
  /// supplies a contiguous span, so are the periods that produced no rows
  /// at all. Without that a month nobody signed up in isn't a zero, it is
  /// *absent*, and plotting by index draws January next to March as though
  /// they were consecutive.
  List<_Bar> _series(ReportView view, String columnId, String currency) {
    final byKey = {
      for (final g in view.groups) g.key: _valueOf(g, columnId, currency),
    };
    final keys = bucketKeys.isEmpty
        ? [for (final g in view.groups) g.key]
        : bucketKeys;
    return [
      for (final key in keys)
        _Bar(key: key, value: byKey[key] ?? Decimal.zero, label: _label(key)),
    ];
  }

  /// Drill into [key], unless it is a bucket the gap fill invented.
  ///
  /// A filled bucket has no `GroupTotals`, so `compute` would filter to zero
  /// rows and strand the user on "No results" with the chart unmounted. That
  /// is easy to hit by accident: fl_chart's `isInterestedForInteractions`
  /// does **not** exclude `FlPointerHoverEvent`, so on desktop and web these
  /// callbacks fire on mouse-over, not just on tap.
  void _drillInto(BuildContext context, ReportView view, String key) {
    if (!view.groups.any((g) => g.key == key)) return;
    context.read<ReportsViewModel>().setSelectedGroup(key);
  }

  /// Bucket keys are raw ISO dates (identity, not display) — render them
  /// through the shared formatter so the axis reads "April 2026".
  String _label(String key) => reportGroupDisplayLabel(
    key: key,
    columnType: groupColumn?.type,
    subgroup: subgroup,
    formatter: formatter,
  );
}

class _Bar {
  const _Bar({required this.key, required this.value, required this.label});

  /// The engine's bucket key — identity, and what `setSelectedGroup` must
  /// be handed so drill-down matches.
  final String key;
  final Decimal value;

  /// What the axis and tooltip show for [key].
  final String label;
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.md(context)),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
      ),
    );
  }
}
