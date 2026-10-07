import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';

/// One period figure: what it is called, what it is, and how it moved.
class PeriodFigure {
  const PeriodFigure({
    required this.label,
    required this.value,
    required this.deltaPercent,
    required this.goodDirection,
    this.onTap,
  });

  final String label;

  /// The formatted amount. Only read when the section is ready or stale.
  final String value;

  /// Change against the compared period, or null when there is nothing to
  /// compare with — in which case no trend is drawn at all, rather than a
  /// dash that reads as "no change".
  final double? deltaPercent;
  final GoodDirection goodDirection;

  /// Opens the list behind the figure. Null draws no chevron: a figure with no
  /// list that can show the same rows is not dressed up as a link.
  final VoidCallback? onTap;
}

/// Height floor of a figure card. A floor, not an extent — the fixed 140 px
/// cell this replaced clipped its last line as soon as a caption met a larger
/// text size.
const double kFigureCardMinHeight = 104;

/// The card surface every figure sits on: surface, hairline border, the card
/// radius and the resting shadow.
class _FigureSurface extends StatelessWidget {
  const _FigureSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r3);
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
        child: child,
      ),
    );
  }
}

/// A figure's caption — small capitals in `ink2`, the record screens' standing
/// card treatment (`ink3` at this size is under 4:1 on a white card).
class _FigureCaption extends StatelessWidget {
  const _FigureCaption({required this.label, required this.linked});

  final String label;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final text = Text(
      label.toUpperCase(),
      maxLines: 1,
      softWrap: false,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: tokens.ink2,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.4,
      ),
    );
    // Scaled down to fit, like the figure beneath it, never ellipsised: three
    // cells across a phone at 140% text leave a caption about 75 px, and
    // "RECHNU…" over a number does not say what the number is.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: linked
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                text,
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 14, color: tokens.ink2),
              ],
            )
          : text,
    );
  }
}

/// A figure's value in each of the states it can honestly be in.
///
/// * `loading` — a bar where the number will be. Never a zero: `$0.00` is an
///   answer, and before the fetch returns there isn't one.
/// * `failed` — a dash. The card it sits in offers the retry.
/// * `ready` / `stale` — the number, scaled down to fit rather than
///   ellipsised: `$1,234,5…` is not an amount.
class FigureValue extends StatelessWidget {
  const FigureValue({
    super.key,
    required this.state,
    required this.value,
    this.fontSize = 24,
  });

  final ValueSectionState state;
  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style = moneyTextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.4,
      height: 1.25,
      color: tokens.ink,
    );
    switch (state) {
      case ValueSectionState.loading:
        // Sized by the same line box as the number it stands in for, so the
        // card does not change height when the value lands.
        return Semantics(
          label: context.tr('loading_ellipsis'),
          child: SizedBox(
            height:
                (fontSize * 1.25) * MediaQuery.textScalerOf(context).scale(1),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FigureSkeletonBar(width: fontSize * 4.5, height: 14),
            ),
          ),
        );
      case ValueSectionState.failed:
        return Text(
          '—',
          maxLines: 1,
          style: style.copyWith(color: tokens.ink3),
        );
      case ValueSectionState.stale:
      case ValueSectionState.ready:
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(value, maxLines: 1, softWrap: false, style: style),
        );
    }
  }
}

/// A placeholder bar for something still loading. Drawn in the border tone:
/// the alternate surface the old skeletons used is 1.04–1.22:1 against a card,
/// which is to say invisible.
class FigureSkeletonBar extends StatelessWidget {
  const FigureSkeletonBar({super.key, required this.width, this.height = 12});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.inTheme.border,
      borderRadius: BorderRadius.circular(InRadii.r1),
    ),
  );
}

/// The small control in a card's corner when its figures could not be loaded:
/// "Retry" when there is nothing to show, a warning glyph when an older answer
/// is still on screen.
class _FigureRetry extends StatelessWidget {
  const _FigureRetry({required this.state, required this.onRetry});

  final ValueSectionState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final onRetry = this.onRetry;
    if (onRetry == null) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final extent = Env.isTouchPrimary ? InSizes.touchTarget : 28.0;
    switch (state) {
      case ValueSectionState.failed:
        return TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            minimumSize: Size(48, extent),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(context.tr('retry')),
        );
      case ValueSectionState.stale:
        return IconButton(
          // The figure is real, but not current: the last refresh failed.
          tooltip:
              '${context.tr('could_not_load_label')} · ${context.tr('retry')}',
          onPressed: onRetry,
          icon: Icon(Icons.sync_problem, size: 16, color: tokens.warning),
          constraints: BoxConstraints.tightFor(width: extent, height: extent),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      case ValueSectionState.loading:
      case ValueSectionState.ready:
        return const SizedBox.shrink();
    }
  }
}

/// **Outstanding** — everything unpaid today, whatever the date range.
///
/// It carries no trend. The figure is a balance, not a flow: there is no
/// "outstanding last month" in the totals to set it against, and the old chip
/// compared the unpaid remainder of two unrelated sets of invoices.
class OutstandingFigureCard extends StatelessWidget {
  const OutstandingFigureCard({
    super.key,
    required this.state,
    required this.value,
    required this.caption,
    this.onTap,
    this.onRetry,
    this.valueFontSize = 26,
  });

  final ValueSectionState state;
  final String value;

  /// "9 unpaid · 4 past due". Null while not known.
  final String? caption;

  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final double valueFontSize;

  /// Whether this card is showing a figure the server returned — as opposed to
  /// a placeholder or a dash. The integration suites wait on it as their
  /// "dashboard has loaded" signal: the card itself is on screen from the
  /// first frame, so its presence alone proves nothing.
  bool get showsLoadedValue =>
      state == ValueSectionState.ready || state == ValueSectionState.stale;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = context.tr('outstanding');
    final known = showsLoadedValue;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kFigureCardMinHeight),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // From the top, like the period cells beside it, so the captions of
          // the two cards sit on one line. Centred, the two differed by the
          // difference in their content heights — a pixel or two, and visible.
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _FigureCaption(label: label, linked: onTap != null),
                  ),
                ),
                _FigureRetry(state: state, onRetry: onRetry),
              ],
            ),
            const SizedBox(height: 4),
            FigureValue(state: state, value: value, fontSize: valueFontSize),
            if (known && caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
              ),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      label: known
          ? [label, value, ?caption].join(', ')
          : '$label, ${context.tr('loading_ellipsis')}',
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: _FigureSurface(
          child: onTap == null ? body : InkWell(onTap: onTap, child: body),
        ),
      ),
    );
  }
}

/// The period's figures — Invoices, Payments, Expenses — as cells of one card,
/// divided by hairlines.
///
/// One card rather than three tiles: they are one answer ("how did this period
/// go") from one request, they load and fail together, and a shared surface
/// lets them share a single retry instead of three.
class PeriodFiguresCard extends StatelessWidget {
  const PeriodFiguresCard({
    super.key,
    required this.state,
    required this.figures,
    this.onRetry,
    this.valueFontSize = 22,
  });

  final ValueSectionState state;
  final List<PeriodFigure> figures;

  final VoidCallback? onRetry;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return _FigureSurface(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kFigureCardMinHeight),
        child: Stack(
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < figures.length; i++) ...[
                    if (i > 0)
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: tokens.border,
                      ),
                    Expanded(
                      child: _PeriodCell(
                        figure: figures[i],
                        state: state,
                        valueFontSize: valueFontSize,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // In the corner, over the last cell's free space: one retry for
            // the three figures that fail together.
            PositionedDirectional(
              top: 4,
              end: 4,
              child: _FigureRetry(state: state, onRetry: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodCell extends StatelessWidget {
  const _PeriodCell({
    required this.figure,
    required this.state,
    required this.valueFontSize,
  });

  final PeriodFigure figure;
  final ValueSectionState state;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    final known =
        state == ValueSectionState.ready || state == ValueSectionState.stale;
    final delta = figure.deltaPercent;
    final onTap = known ? figure.onTap : null;
    final body = Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _FigureCaption(label: figure.label, linked: onTap != null),
          ),
          const SizedBox(height: 4),
          FigureValue(
            state: state,
            value: figure.value,
            fontSize: valueFontSize,
          ),
          const SizedBox(height: 2),
          // The line is kept even with no trend to draw, so the three cells
          // put their values on one baseline.
          SizedBox(
            height: 18 * MediaQuery.textScalerOf(context).scale(1),
            child: known && delta != null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DeltaChip(
                      percent: delta,
                      goodDirection: figure.goodDirection,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: known
          ? _spoken(context, delta)
          : '${figure.label}, ${context.tr('loading_ellipsis')}',
      button: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }

  String _spoken(BuildContext context, double? delta) {
    if (delta == null) {
      return context.tr('kpi_no_delta_semantic', {
        'label': figure.label,
        'value': figure.value,
      });
    }
    return context.tr('kpi_with_delta_semantic', {
      'label': figure.label,
      'value': figure.value,
      'direction': context.tr(delta > 0 ? 'delta_up' : 'delta_down'),
      'percent': delta.abs().toStringAsFixed(1),
    });
  }
}

/// Zero when the totals carry no bucket for the selected currency — a real
/// zero, since the totals did load. (Before they load the cards draw a
/// skeleton and never read this.)
Decimal figureAmount(Decimal? amount) => amount ?? Decimal.zero;
