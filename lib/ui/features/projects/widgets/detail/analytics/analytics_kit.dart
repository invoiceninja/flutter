import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// The pieces every Analytics section is made of: the card, its sub-headings
/// and captions, the figure cells, and the number formats.

/// One section of the tab: a titled card, an optional caption saying what the
/// figures are based on, and its body.
class AnalyticsSection extends StatelessWidget {
  const AnalyticsSection({
    super.key,
    required this.title,
    required this.children,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final gap = SizedBox(height: InSpacing.lg(context));
    return DashboardCardShell(
      title: title,
      trailing: trailing,
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (caption != null) ...[
              Text(
                caption!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
              SizedBox(height: InSpacing.md(context)),
            ],
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) gap,
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A heading inside a section, over one chart or list.
class AnalyticsSubheading extends StatelessWidget {
  const AnalyticsSubheading(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: context.inTheme.ink2,
      fontWeight: FontWeight.w600,
    );
    final label = Semantics(
      header: true,
      headingLevel: 2,
      child: Text(text, style: style),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.sm),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                trailing!,
              ],
            ),
    );
  }
}

/// A line of explanation where a figure cannot honestly be shown.
class AnalyticsNote extends StatelessWidget {
  const AnalyticsNote(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: tokens.ink2);
    if (icon == null) return Text(text, style: style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tokens.ink3),
        SizedBox(width: InSpacing.sm),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// Figure cells that reflow instead of overflowing. Same visual language as
/// the record screens' standing figures.
class KpiWrap extends StatelessWidget {
  const KpiWrap({super.key, required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: InSpacing.xl,
    runSpacing: InSpacing.md(context),
    children: cells,
  );
}

/// One labelled figure. [value] null is a figure with no basis — an em dash,
/// in the labelled slot (CLAUDE.md § An empty value is an em dash in a
/// labelled slot).
class Kpi extends StatelessWidget {
  const Kpi(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final v = value;
    return MergeSemantics(
      child: Column(
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
            v ?? '—',
            style: theme.textTheme.titleMedium?.copyWith(
              color: v == null ? tokens.ink3 : (valueColor ?? tokens.ink),
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── number formats ──────────────────────────────────────────────────────

/// Hours to one decimal, through the company's separators — `12,5 h` on a
/// decimal-comma company. The `h` is the record screens' own (see
/// `project_detail_standing.dart`).
String analyticsHours(Formatter? f, double h) {
  final rounded = (h * 10).round() / 10;
  final body =
      f?.decimal(rounded, maxDecimals: 1) ??
      (rounded == rounded.truncateToDouble()
          ? rounded.toInt().toString()
          : rounded.toStringAsFixed(1));
  return '$body h';
}

/// A 0..1 ratio as a whole percentage, through the company's separators.
String analyticsPercent(Formatter? f, double ratio) {
  final pct = (ratio * 100).round();
  return f?.percent(pct) ?? '$pct%';
}

/// Money through the company [Formatter], so the currency cascade and Euro
/// override apply. Falls back to the raw Decimal with no formatter.
String Function(Decimal) analyticsMoney(Formatter? f, String currencyId) {
  if (f == null) return (d) => d.toString();
  return (d) =>
      f.money(d, clientCurrencyId: currencyId.isEmpty ? null : currencyId);
}

/// A date the company's way.
String analyticsDate(Formatter? f, Date date) {
  final iso = date.toIso();
  final formatted = f?.date(iso) ?? '';
  return formatted.isEmpty ? iso : formatted;
}
