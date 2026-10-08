import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';

/// One line of a [ReportBarList], ready to draw.
class ReportBarListItem {
  const ReportBarListItem({
    required this.label,
    required this.valueText,
    required this.fraction,
    this.shareText,
    this.color,
    this.muted = false,
    this.dimmed = false,
    this.trailing,
    this.onTap,
    this.semanticsHint,
  });

  final String label;

  /// The figure, formatted. Always shown: the bar is a comparison, the
  /// number is the answer.
  final String valueText;

  /// The bar's length as a fraction of the longest, 0–1.
  final double fraction;

  /// "31%" — the line's part of the whole, when there is a whole.
  final String? shareText;

  /// The series colour, when the lines are series of a chart beside the
  /// list — then the list is that chart's legend and each line leads with a
  /// swatch. Null draws every bar in the one accent hue.
  final Color? color;

  /// The "Other" line: neutral, since it is not one of the things compared.
  final bool muted;

  /// A series switched off in the chart.
  final bool dimmed;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticsHint;
}

/// Groups compared by one measure: a name, a bar, the figure.
///
/// Built from plain widgets rather than a chart library, because that is
/// what the form needs: the names are real text (a client's name does not fit
/// under a column, and rotated ninety degrees it does not read), every line
/// is a control a finger can hit, and the figure sits at the end of its bar
/// instead of in a tooltip.
///
/// **One colour for every bar.** The groups have no order of their own, so
/// shading them by size would spend the only free channel re-saying what the
/// bar's length already says. Colour appears only when the lines are the
/// series of a chart next to the list ([ReportBarListItem.color]).
class ReportBarList extends StatelessWidget {
  const ReportBarList({super.key, required this.items, this.barColor});

  final List<ReportBarListItem> items;

  /// The bars' colour when an item names none.
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final single = barColor ?? tokens.series.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The name takes about a third, within limits: enough for a company
        // name on a wide card, not so much the bars have nothing to say on a
        // phone.
        final labelWidth = (constraints.maxWidth * 0.34).clamp(88.0, 260.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in items)
              _Line(
                item: item,
                labelWidth: labelWidth,
                barColor: item.muted
                    ? tokens.seriesOther
                    : (item.color ?? single),
              ),
          ],
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.item,
    required this.labelWidth,
    required this.barColor,
  });

  final ReportBarListItem item;
  final double labelWidth;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final onTap = item.onTap;
    final ink = item.dimmed ? tokens.ink3 : tokens.ink;
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 30,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: Row(
                children: [
                  if (item.color != null || item.muted) ...[
                    ChartSwatch(color: barColor, filled: !item.dimmed),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: item.muted ? tokens.ink2 : ink,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: InSpacing.sm),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  // Never nothing: a line that is on the list has a value,
                  // and a bar of no length says it has none.
                  widthFactor: item.fraction.clamp(0.012, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: item.dimmed
                          ? barColor.withValues(alpha: 0.35)
                          : barColor,
                      // Rounded at the data end, square at the baseline.
                      borderRadius: const BorderRadiusDirectional.horizontal(
                        end: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: InSpacing.sm),
            // Text wears text colours, never the series colour: a yellow
            // figure on a white card is not a figure anyone can read.
            Text(
              item.valueText,
              maxLines: 1,
              softWrap: false,
              style: moneyTextStyle(fontSize: 13, color: ink),
            ),
            if (item.shareText != null)
              SizedBox(
                width: 44,
                child: Text(
                  item.shareText!,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: tokens.ink3),
                ),
              ),
            ?item.trailing,
          ],
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(
        label: _spoken(),
        child: ExcludeSemantics(child: content),
      );
    }
    return Semantics(
      button: true,
      label: _spoken(),
      hint: item.semanticsHint,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: content,
        ),
      ),
    );
  }

  String _spoken() => [item.label, item.valueText, ?item.shareText].join(', ');
}
