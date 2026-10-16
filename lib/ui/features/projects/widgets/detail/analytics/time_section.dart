import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/bar_list.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_figures.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_kit.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart'
    show ReportTimeChartStyle;
import 'package:admin/ui/features/reports/widgets/charts/report_series_plot.dart';
import 'package:admin/utils/formatting.dart';

/// Where the project's time went — React's Time tab: hours against the
/// budget, the server's health score and what it was docked for, who logged
/// the time, which tasks took it, and the pace day by day. Mounted only for a
/// user who may see the money: the server sends none of this to anyone else.
class TimeSection extends StatelessWidget {
  const TimeSection({
    super.key,
    required this.analytics,
    required this.formatter,
    required this.today,
  });

  final ProjectAnalytics analytics;
  final Formatter? formatter;
  final Date today;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    String hours(double h) => analyticsHours(formatter, h);
    final h = a.hours;
    final children = <Widget>[
      if (h != null && (h.loggedHours > 0 || h.budgetedHours > 0))
        _HoursBars(hours: h, formatter: formatter),
      if (a.health != null)
        _HealthBlock(
          health: a.health!,
          // A ratio over nothing is unknown, not 0%.
          hasMoneyBudget:
              (a.budgetVsActual?.budgetedAmount ?? Decimal.zero) > Decimal.zero,
          hasInvoiced:
              (a.profitability?.invoicedAmount ?? Decimal.zero) > Decimal.zero,
          hasWorkValue:
              (a.invoiceProgress?.workValue ?? Decimal.zero) > Decimal.zero,
          formatter: formatter,
        ),
      if (a.team.any((m) => m.loggedHours > 0))
        _Ranked<ProjectTeamMember>(
          title: context.tr('team_distribution'),
          rows: rankWithOther(a.team, (m) => m.loggedHours),
          labelOf: (m) => m.userName.trim().isEmpty ? '—' : m.userName,
          valueText: hours,
        ),
      if (a.tasks.any((t) => t.loggedHours > 0))
        _Ranked<ProjectTaskTime>(
          title: context.tr('task_distribution'),
          rows: rankWithOther(a.tasks, (t) => t.loggedHours),
          labelOf: (t) {
            final d = t.description.trim();
            if (d.isNotEmpty) return d.split('\n').first;
            return t.number.isEmpty ? '—' : '#${t.number}';
          },
          valueText: hours,
          onTap: (t) =>
              t.taskId.isEmpty ? null : () => context.go('/tasks/${t.taskId}'),
        ),
      if (a.velocity.isNotEmpty)
        _Velocity(days: a.velocity, today: today, formatter: formatter),
    ];
    return AnalyticsSection(title: context.tr('time'), children: children);
  }
}

/// Budgeted, logged, billable and remaining hours on one scale.
class _HoursBars extends StatelessWidget {
  const _HoursBars({required this.hours, required this.formatter});

  final ProjectHours hours;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final h = hours;
    final over = h.budgetedHours > 0 && h.loggedHours > h.budgetedHours;
    final lines = <(String, double, {bool overrun})>[
      if (h.budgetedHours > 0)
        (context.tr('budgeted_hours'), h.budgetedHours, overrun: false),
      (context.tr('logged_hours'), h.loggedHours, overrun: false),
      (context.tr('billable_hours'), h.billableHours, overrun: false),
      // Remaining is clamped at zero by the server — with no budget it is
      // meaningless, and over budget it is the overrun that matters.
      if (h.budgetedHours > 0 && !over)
        (context.tr('remaining_hours'), h.remainingHours, overrun: false),
      if (over)
        (
          context.tr('over_budget'),
          h.loggedHours - h.budgetedHours,
          overrun: true,
        ),
    ];
    final top = lines.fold<double>(0, (m, l) => l.$2 > m ? l.$2 : m);
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsSubheading(context.tr('hours')),
        BarList(
          items: [
            for (final (label, value, :overrun) in lines)
              BarListItem(
                label: label,
                valueText: analyticsHours(formatter, value),
                fraction: top <= 0 ? 0 : (value / top).clamp(0.0, 1.0),
                color: overrun ? tokens.overdue : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// The server's 0–100 score, in words of its own, with the five things it
/// is docked for underneath.
///
/// **Good / Fair / Poor, never "On track".** The standing card above the
/// tabs already says On track / Over budget about the HOURS; this score is
/// built from money, schedule and billing too, and a project 50% over its
/// money budget still scores 87.5. Sharing a word would set the two against
/// each other.
class _HealthBlock extends StatelessWidget {
  const _HealthBlock({
    required this.health,
    required this.hasMoneyBudget,
    required this.hasInvoiced,
    required this.hasWorkValue,
    required this.formatter,
  });

  final ProjectHealth health;
  final bool hasMoneyBudget;
  final bool hasInvoiced;
  final bool hasWorkValue;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final h = health;
    final (label, fg, bg) = switch (h.status) {
      ProjectHealthStatus.good => (
        context.tr('health_good'),
        tokens.paid,
        tokens.paidSoft,
      ),
      ProjectHealthStatus.fair => (
        context.tr('health_fair'),
        tokens.sent,
        tokens.sentSoft,
      ),
      ProjectHealthStatus.poor => (
        context.tr('health_poor'),
        tokens.overdue,
        tokens.overdueSoft,
      ),
      ProjectHealthStatus.unknown => (null, tokens.ink3, null),
    };

    BarListItem share(String name, double? ratio) {
      if (ratio == null) {
        return BarListItem(label: name, valueText: '—', fraction: 0);
      }
      return BarListItem(
        label: name,
        valueText: analyticsPercent(formatter, ratio),
        fraction: ratio.clamp(0.0, 1.0),
      );
    }

    final variance = h.scheduleVarianceDays;
    final score = formatter?.integer(h.score.round()) ?? '${h.score.round()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsSubheading(context.tr('project_health')),
        Wrap(
          spacing: InSpacing.md(context),
          runSpacing: InSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (label != null)
              StatusPill(label: label, fgColor: fg, bgColor: bg),
            Text(
              '$score / 100',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (variance != null)
              Text(
                '${context.tr(variance < 0 ? 'days_behind' : 'days_ahead')}: '
                '${formatter?.integer(variance.abs()) ?? variance.abs()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: variance < 0 ? tokens.overdue : tokens.ink2,
                ),
              ),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        BarList(
          items: [
            share(
              context.tr('budget_used'),
              shareOrNull(h.budgetUtilization, hasBasis: hasMoneyBudget),
            ),
            share(
              context.tr('margin'),
              shareOrNull(h.marginRatio, hasBasis: hasInvoiced),
            ),
            share(
              context.tr('unbilled'),
              shareOrNull(h.unbilledRatio, hasBasis: hasWorkValue),
            ),
            share(
              context.tr('outstanding'),
              shareOrNull(h.outstandingRatio, hasBasis: hasInvoiced),
            ),
          ],
        ),
      ],
    );
  }
}

/// A ranked breakdown: the largest few, the rest as "Other".
class _Ranked<T> extends StatelessWidget {
  const _Ranked({
    required this.title,
    required this.rows,
    required this.labelOf,
    required this.valueText,
    this.onTap,
  });

  final String title;
  final List<RankedRow<T>> rows;
  final String Function(T) labelOf;
  final String Function(double) valueText;
  final VoidCallback? Function(T)? onTap;

  @override
  Widget build(BuildContext context) {
    final top = rows.fold<double>(
      0,
      (m, r) => !r.isOther && r.value > m ? r.value : m,
    );
    final total = rows.fold<double>(0, (s, r) => s + r.value);
    String share(double v) => total <= 0 ? '' : '${(v / total * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsSubheading(title),
        BarList(
          items: [
            for (final r in rows)
              BarListItem(
                label: r.isOther
                    ? context.tr('other_count', {'count': '${r.foldedCount}'})
                    : labelOf(r.item as T),
                valueText: valueText(r.value),
                shareText: share(r.value),
                fraction: top <= 0 ? 0 : (r.value / top).clamp(0.0, 1.0),
                muted: r.isOther,
                onTap: r.isOther ? null : onTap?.call(r.item as T),
              ),
          ],
        ),
      ],
    );
  }
}

/// Hours logged per day — per week past two months — with the days nobody
/// logged anything shown as the gaps they are.
class _Velocity extends StatelessWidget {
  const _Velocity({
    required this.days,
    required this.today,
    required this.formatter,
  });

  final List<ProjectVelocityDay> days;
  final Date today;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final (:buckets, :weekly) = velocityBuckets(days, today: today);
    if (buckets.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final labels = [for (final b in buckets) analyticsDate(formatter, b.start)];
    final values = [for (final b in buckets) b.hours];
    final total = values.fold<double>(0, (s, v) => s + v);
    final title = context.tr(weekly ? 'weekly_velocity' : 'daily_velocity');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsSubheading(title),
        ReportSeriesPlot(
          labels: labels,
          series: [
            ReportPlotSeries(
              name: context.tr('logged_hours'),
              color: tokens.series.first,
              values: values,
            ),
          ],
          style: ReportTimeChartStyle.columns,
          axisText: (v) => analyticsHours(formatter, v),
          valueText: (v) => analyticsHours(formatter, v),
          semanticsLabel:
              '$title: ${analyticsHours(formatter, total)}, '
              '${labels.first} – ${labels.last}',
          height: 200,
        ),
      ],
    );
  }
}
