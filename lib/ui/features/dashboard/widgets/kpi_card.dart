import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_sparkline.dart';

/// One KPI tile: label / value / delta / sparkline. Renders inside the shared
/// card shell shape, sized by the parent grid.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.deltaPercent,
    required this.goodDirection,
    this.sparklineValues,
    this.tone,
    this.subcaption,
    this.secondCaption,
    this.showDelta = true,
    this.semanticsLabel,
    this.onTap,
  });

  final String label;

  /// Formatted value text (e.g. `$38,420`, `17` for days).
  final String value;

  /// Signed percent change vs prior period; null = no delta available.
  final double? deltaPercent;

  final GoodDirection goodDirection;

  /// Historical mini-trend. **Null renders no sparkline** — there is no
  /// real per-period series available today, and a fabricated constant
  /// trend misrepresents the data. The "vs prior" delta chip carries the
  /// real period-over-period signal.
  final List<double>? sparklineValues;

  /// Optional accent override. Default = `accent`; "Overdue" passes `overdue`.
  final KpiTone? tone;

  /// Optional below-value caption ("Mixed currencies — pick one ...").
  final String? subcaption;

  /// Optional second caption line below [subcaption] — used by configured
  /// cards to show the resolved date range for `current`-period cards.
  final String? secondCaption;

  /// When false the "vs prior" delta row is omitted entirely (configured
  /// dashboard cards have no period-over-period delta, matching React).
  final bool showDelta;

  final String? semanticsLabel;

  /// Optional tap target — when non-null, the card becomes a clickable link
  /// (typically to a filtered list view).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final sparkColor = tone == KpiTone.overdue ? tokens.overdue : tokens.paid;
    final radius = BorderRadius.circular(InRadii.r3);
    final clickable = onTap != null;
    final Widget inner = Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                    color: tokens.ink3,
                  ),
                ),
              ),
              if (clickable)
                Icon(Icons.chevron_right, size: 16, color: tokens.ink3),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: moneyTextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
              height: 1.3,
              color: tokens.ink,
            ),
          ),
          if (subcaption != null)
            Text(
              subcaption!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, height: 1.2, color: tokens.ink3),
            ),
          if (secondCaption != null)
            Text(
              secondCaption!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, height: 1.2, color: tokens.ink3),
            ),
          if (showDelta) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                DeltaChip(
                  percent: deltaPercent,
                  goodDirection: goodDirection,
                  suffix: context.tr('vs_prior'),
                ),
                if (sparklineValues != null) ...[
                  const Spacer(),
                  KpiSparkline(values: sparklineValues!, color: sparkColor),
                ],
              ],
            ),
          ],
        ],
      ),
    );
    final Widget surface = Material(
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: radius,
      ),
      child: clickable
          ? InkWell(
              onTap: onTap,
              overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.pressed)) return tokens.border;
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return tokens.surfaceAlt;
                }
                return null;
              }),
              child: inner,
            )
          : inner,
    );
    final Widget result = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.shadow1,
      ),
      child: surface,
    );
    if (semanticsLabel == null) return result;
    return Semantics(
      container: true,
      label: semanticsLabel,
      button: clickable,
      child: ExcludeSemantics(child: result),
    );
  }
}

enum KpiTone { accent, overdue }
