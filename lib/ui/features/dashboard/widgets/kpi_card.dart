import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_sparkline.dart';

/// Height floor of a metric tile — see [KpiCard].
const double kKpiCardMinHeight = 104;

/// One metric tile: label / value / captions. The user's own dashboard cards
/// are drawn with it; the dashboard's fixed figures have their own cards
/// (`dashboard_figures.dart`), in the same language.
///
/// It sizes to its content above a floor ([kKpiCardMinHeight]) rather than
/// filling a fixed 140 px grid cell, where a second caption at a larger text
/// size ran out of room and was clipped.
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
    this.trailingIcon = Icons.chevron_right,
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

  /// The glyph beside the label when [onTap] is set — a chevron for "opens a
  /// list", something else when the tap does something else.
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final sparkColor = tone == KpiTone.overdue ? tokens.overdue : tokens.paid;
    final radius = BorderRadius.circular(InRadii.r3);
    final clickable = onTap != null;
    final Widget inner = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kKpiCardMinHeight),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  // Small capitals in `ink2`, the caption the figures above use
                  // (`ink3` at this size is under 4:1 on a white card).
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.ink2,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (clickable) Icon(trailingIcon, size: 16, color: tokens.ink2),
              ],
            ),
            const SizedBox(height: 4),
            // Scaled down to fit, never ellipsised: `$1,234,5…` is not an
            // amount, and a duration like `21d 19h 45m` must not wrap either.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                softWrap: false,
                style: moneyTextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  height: 1.25,
                  color: tokens.ink,
                ),
              ),
            ),
            if (subcaption != null)
              Text(
                subcaption!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: tokens.ink2,
                ),
              ),
            if (secondCaption != null)
              Text(
                secondCaption!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.25,
                  color: tokens.ink2,
                ),
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
    // `onTap` is **re-declared**: `ExcludeSemantics` drops the whole subtree,
    // taking the `InkWell`'s own `Semantics(onTap:)` with it, so without this
    // a clickable card announces as a button that TalkBack and switch access
    // cannot invoke. Null when `clickable` is false, which is the same answer
    // `button: clickable` gives. See
    // `test/lint/semantics_excludes_need_ontap_test.dart`.
    return Semantics(
      container: true,
      label: semanticsLabel,
      button: clickable,
      onTap: onTap,
      child: ExcludeSemantics(child: result),
    );
  }
}

enum KpiTone { accent, overdue }
