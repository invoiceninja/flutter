import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_burnup_chart.dart';
import 'package:admin/utils/formatting.dart';

/// Analytics tab on the project detail screen — the server-computed view of a
/// project, from `charts/project_analytics/{id}` + `charts/project_burnup/{id}`.
///
/// Complements rather than replaces `ProjectProgressCard` on the detail body:
/// that card computes cumulative hours vs ideal pace **locally** from Drift
/// time logs and keeps working offline. This tab adds what local data can't
/// produce — the money series (invoiced / paid / outstanding / expense) and
/// the server's health, profitability and budget-vs-actual scoring.
///
/// Mounted only for users who can `view_dashboard`, matching the permission
/// both endpoints enforce (`ShowProjectAnalyticsRequest::authorize`), so a
/// restricted user never sees a tab that would only 403.
class ProjectAnalyticsTab extends StatefulWidget {
  const ProjectAnalyticsTab({
    super.key,
    required this.projectId,
    this.formatter,
  });

  final String projectId;
  final Formatter? formatter;

  @override
  State<ProjectAnalyticsTab> createState() => _ProjectAnalyticsTabState();
}

class _ProjectAnalyticsTabState extends State<ProjectAnalyticsTab> {
  late final ProjectAnalyticsViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ProjectAnalyticsViewModel(
      api: context.read<Services>().projectCharts,
      projectId: widget.projectId,
    );
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.initialLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (_vm.errorMessage != null) {
          return _AnalyticsError(vm: _vm);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Controls(vm: _vm),
            SizedBox(height: InSpacing.lg(context)),
            if (_vm.isEmpty)
              EmptyState(
                icon: Icons.insights_outlined,
                title: context.tr('no_analytics_data'),
              )
            else
              _Cards(vm: _vm, formatter: widget.formatter),
          ],
        );
      },
    );
  }
}

/// Window + bucket + drafts controls. Wraps so the row degrades to two lines
/// on a narrow screen instead of overflowing.
class _Controls extends StatelessWidget {
  const _Controls({required this.vm});
  final ProjectAnalyticsViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<ProjectAnalyticsRange>(
          segments: [
            for (final r in ProjectAnalyticsRange.values)
              ButtonSegment(value: r, label: Text(context.tr(r.labelKey))),
          ],
          selected: {vm.range},
          showSelectedIcon: false,
          onSelectionChanged: (s) => vm.setRange(s.first),
        ),
        SegmentedButton<BurnupBucket>(
          segments: [
            for (final b in BurnupBucket.values)
              ButtonSegment(
                value: b,
                label: Text(context.tr('bucket_${b.wireName}')),
              ),
          ],
          selected: {vm.bucket},
          showSelectedIcon: false,
          onSelectionChanged: (s) => vm.setBucket(s.first),
        ),
        FilterChip(
          label: Text(context.tr('include_drafts')),
          selected: vm.includeDrafts,
          onSelected: vm.setIncludeDrafts,
        ),
        if (vm.loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

class _AnalyticsError extends StatelessWidget {
  const _AnalyticsError({required this.vm});
  final ProjectAnalyticsViewModel vm;

  @override
  Widget build(BuildContext context) {
    // The endpoints landed server-side on 2026-06-30 and aren't on every
    // deployment yet, so a 404 here is "your server is older", not a bug —
    // say that rather than dumping a raw HTTP error.
    return EmptyState(
      icon: Icons.insights_outlined,
      title: context.tr('analytics_unavailable'),
      subtitle: vm.errorMessage,
      action: FilledButton(
        // Centered single action must constrain its own width, or the
        // Size.fromHeight(44) button theme stretches it edge-to-edge.
        style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
        onPressed: vm.load,
        child: Text(context.tr('retry')),
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.vm, required this.formatter});

  final ProjectAnalyticsViewModel vm;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final a = vm.analytics;
    final burnup = vm.burnup;
    final gap = SizedBox(height: InSpacing.lg(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (burnup != null && !burnup.isEmpty) ...[
          ProjectBurnupChart(burnup: burnup, formatter: formatter),
          gap,
        ],
        if (a?.budgetSummary != null) ...[
          _BudgetCard(
            summary: a!.budgetSummary!,
            split: a.budgetVsActual,
            formatter: formatter,
          ),
          gap,
        ],
        if (a?.invoiceProgress != null) ...[
          _InvoiceProgressCard(
            progress: a!.invoiceProgress!,
            formatter: formatter,
          ),
          gap,
        ],
        if (a?.profitability != null) ...[
          _ProfitabilityCard(profit: a!.profitability!, formatter: formatter),
          gap,
        ],
        if (a?.health != null) _HealthCard(health: a!.health!),
      ],
    );
  }
}

// ── cards ───────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.summary,
    required this.split,
    required this.formatter,
  });

  final ProjectBudgetSummary summary;
  final ProjectBudgetVsActual? split;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final money = _moneyFormatter(formatter, summary.currencyId);
    return DashboardCardShell(
      title: context.tr('budget'),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiWrap(
              cells: [
                _Kpi(context.tr('logged_hours'), _hours(summary.currentHours)),
                _Kpi(
                  context.tr('budgeted_hours'),
                  summary.budgetedHours == 0
                      ? '—'
                      : _hours(summary.budgetedHours),
                ),
                _Kpi(
                  context.tr('budgeted_amount'),
                  summary.budgetedAmount == Decimal.zero
                      ? '—'
                      : money(summary.budgetedAmount),
                ),
                _Kpi(context.tr('remaining'), money(summary.remainingBudget)),
                _Kpi(
                  context.tr('utilization'),
                  _percent(summary.budgetUtilization),
                ),
              ],
            ),
            if (split != null) ...[
              SizedBox(height: InSpacing.lg(context)),
              _StackedBar(
                segments: [
                  _BarSegment(
                    label: context.tr('tasks'),
                    value: split!.laborValue,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  _BarSegment(
                    label: context.tr('expenses'),
                    value: split!.expenseAmount,
                    color: context.inTheme.ink3,
                  ),
                ],
                total: split!.budgetedAmount > Decimal.zero
                    ? split!.budgetedAmount
                    : split!.actualAmount,
                money: money,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceProgressCard extends StatelessWidget {
  const _InvoiceProgressCard({required this.progress, required this.formatter});

  final ProjectInvoiceProgress progress;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final money = _moneyFormatter(formatter, progress.currencyId);
    final scheme = Theme.of(context).colorScheme;
    return DashboardCardShell(
      title: context.tr('invoices'),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiWrap(
              cells: [
                _Kpi(context.tr('work'), money(progress.workValue)),
                _Kpi(context.tr('invoiced'), money(progress.invoicedAmount)),
                _Kpi(context.tr('paid'), money(progress.paidAmount)),
                _Kpi(
                  context.tr('outstanding'),
                  money(progress.outstandingAmount),
                ),
                _Kpi(context.tr('unbilled'), money(progress.unbilledAmount)),
              ],
            ),
            SizedBox(height: InSpacing.lg(context)),
            _StackedBar(
              segments: [
                _BarSegment(
                  label: context.tr('paid'),
                  value: progress.paidAmount,
                  color: scheme.primary,
                ),
                _BarSegment(
                  label: context.tr('outstanding'),
                  value: progress.outstandingAmount,
                  color: scheme.tertiary,
                ),
                _BarSegment(
                  label: context.tr('unbilled'),
                  value: progress.unbilledAmount,
                  color: context.inTheme.ink3,
                ),
              ],
              total: progress.workValue,
              money: money,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitabilityCard extends StatelessWidget {
  const _ProfitabilityCard({required this.profit, required this.formatter});

  final ProjectProfitability profit;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final money = _moneyFormatter(formatter, profit.currencyId);
    final tokens = context.inTheme;
    final negative = profit.netMargin < Decimal.zero;
    return DashboardCardShell(
      title: context.tr('profit'),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: _KpiWrap(
          cells: [
            _Kpi(context.tr('invoiced'), money(profit.invoicedAmount)),
            _Kpi(context.tr('expenses'), money(profit.expenseAmount)),
            _Kpi(
              context.tr('net_margin'),
              money(profit.netMargin),
              valueColor: negative ? tokens.overdue : tokens.paid,
            ),
            _Kpi(context.tr('margin'), _percent(profit.marginRatio)),
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});
  final ProjectHealth health;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return DashboardCardShell(
      title: context.tr('project_health'),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (health.status.isNotEmpty)
                  StatusPill(
                    label: _humanize(health.status),
                    fgColor: _healthColor(health.status, tokens),
                  ),
                if (health.status.isNotEmpty)
                  SizedBox(width: InSpacing.md(context)),
                Text(
                  '${health.score}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (health.indicators.isNotEmpty) ...[
              SizedBox(height: InSpacing.md(context)),
              for (final indicator in health.indicators)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 6, color: tokens.ink3),
                      SizedBox(width: InSpacing.sm),
                      Expanded(
                        child: Text(
                          _humanize(indicator),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: tokens.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _healthColor(String status, InTheme tokens) => switch (status) {
    'healthy' || 'on_track' || 'good' => tokens.paid,
    'at_risk' || 'warning' => tokens.warning,
    'critical' || 'off_track' => tokens.overdue,
    _ => tokens.ink3,
  };
}

// ── shared bits ─────────────────────────────────────────────────────────

/// KPI cells that reflow instead of overflowing. Same visual language as
/// `ProjectProgressCard`'s hero strip.
class _KpiWrap extends StatelessWidget {
  const _KpiWrap({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: InSpacing.xl,
    runSpacing: InSpacing.md(context),
    children: cells,
  );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final isPlaceholder = value == '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isPlaceholder ? tokens.ink3 : (valueColor ?? tokens.ink),
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _BarSegment {
  const _BarSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final Decimal value;
  final Color color;
}

/// Proportional stacked bar with a legend underneath. Segments are clamped to
/// the total so an over-budget project fills the bar rather than overflowing
/// the row.
class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.segments,
    required this.total,
    required this.money,
  });

  final List<_BarSegment> segments;
  final Decimal total;
  final String Function(Decimal) money;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final visible = segments
        .where((s) => s.value > Decimal.zero)
        .toList(growable: false);
    if (visible.isEmpty || total <= Decimal.zero) {
      return const SizedBox.shrink();
    }
    // Flex weights must be ints; scale to basis points for smooth widths.
    int weight(Decimal v) {
      final ratio = (v / total).toDouble().clamp(0.0, 1.0);
      return (ratio * 10000).round().clamp(1, 10000);
    }

    final used = visible.fold<int>(0, (sum, s) => sum + weight(s.value));
    final remainder = (10000 - used).clamp(0, 10000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final s in visible)
                  Expanded(
                    flex: weight(s.value),
                    child: ColoredBox(color: s.color),
                  ),
                if (remainder > 0)
                  Expanded(
                    flex: remainder,
                    child: ColoredBox(color: tokens.border),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.lg(context),
          runSpacing: 4,
          children: [
            for (final s in visible)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(width: InSpacing.sm),
                  Text(
                    '${s.label} · ${money(s.value)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

// ── formatting helpers ──────────────────────────────────────────────────

/// Money through the company [Formatter] so the currency cascade + Euro
/// override apply. Falls back to the raw Decimal when no formatter is
/// available (same fallback the detail cards use).
String Function(Decimal) _moneyFormatter(Formatter? f, String currencyId) {
  if (f == null) return (d) => d.toString();
  return (d) =>
      f.money(d, clientCurrencyId: currencyId.isEmpty ? null : currencyId);
}

String _hours(double h) {
  if (h.truncate().toDouble() == h) return '${h.toInt()} h';
  return '${h.toStringAsFixed(1)} h';
}

/// Server ratios are 0..1+ (already rounded to 4 places).
String _percent(double ratio) => '${(ratio * 100).toStringAsFixed(0)}%';

/// `at_risk` → `At risk`. The server sends snake_case tokens with no
/// translation key of their own.
String _humanize(String token) {
  if (token.isEmpty) return token;
  final spaced = token.replaceAll('_', ' ');
  return spaced[0].toUpperCase() + spaced.substring(1);
}
