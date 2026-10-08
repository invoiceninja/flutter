import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';

/// The parts of a chart that are not its data — grid, axis sizing, the legend
/// control — in one place, so every chart in the app draws them the same way.
///
/// A chart's *callbacks* cannot live here: fl_chart includes every callback in
/// its data's equality and restarts its tween whenever the data is not equal
/// to the last, so they have to be tear-offs of one `State`
/// (docs/dashboard-panels.md § A chart's callbacks are State tear-offs). What
/// lives here is what those tear-offs return.

/// A horizontal gridline: a solid hairline one step off the surface.
///
/// Solid, not dashed. A dashed rule reads as a threshold or a projection —
/// something the data is being measured against — and a grid is neither.
FlLine chartGridLine(InTheme tokens) =>
    FlLine(color: tokens.border, strokeWidth: 1);

/// Text style of an axis label.
TextStyle chartAxisStyle(InTheme tokens) =>
    TextStyle(fontSize: 10, color: tokens.ink3);

/// Room for the value axis, grown with the reader's text size. It was a fixed
/// 44 px sized for 10 px labels at scale 1; at 140% the labels lost their
/// ends to the card's edge.
double chartValueAxisWidth(BuildContext context, {double base = 44}) =>
    base * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

/// Room for one line of category labels under the plot.
double chartCategoryAxisHeight(BuildContext context, {double base = 18}) =>
    base * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

/// Label every [return]th category so at most [maxLabels] are drawn — never
/// more than fit side by side, so a year of daily buckets is not a wall of
/// overprinted dates.
int chartLabelStep(int count, {required int maxLabels}) {
  final cap = maxLabels < 2 ? 2 : maxLabels;
  return count <= cap ? 1 : (count / cap).ceil();
}

/// How many labels of [sampleLabel]'s width fit across [plotWidth].
///
/// One and a half widths each: a label is centred on its tick, except the
/// first and last, which are pushed inside the plot — so the first sits half
/// a width closer to its neighbour than the ticks are.
int chartLabelCapacity(
  BuildContext context, {
  required double plotWidth,
  required String sampleLabel,
  int max = 12,
}) {
  if (!plotWidth.isFinite || plotWidth <= 0) return 2;
  final painter = TextPainter(
    text: TextSpan(text: sampleLabel, style: const TextStyle(fontSize: 10)),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  if (width <= 0) return max;
  return (plotWidth / (width * 1.5)).floor().clamp(2, max);
}

/// One legend entry: a swatch and a name that switch a series on and off.
///
/// A real control — focusable, announced as a toggle, and a full-size target
/// on touch — not a dot and a word in a gesture detector.
class ChartLegendToggle extends StatelessWidget {
  const ChartLegendToggle({
    super.key,
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return MergeSemantics(
      child: Semantics(
        toggled: active,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 28,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChartSwatch(color: color, filled: active),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: active ? tokens.ink : tokens.ink2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A series' colour as a small square — filled when the series is shown,
/// outlined when it is not.
class ChartSwatch extends StatelessWidget {
  const ChartSwatch({super.key, required this.color, this.filled = true});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: filled ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color, width: 1.5),
    ),
  );
}
