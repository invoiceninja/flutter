import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';

/// One figure on a [StandingCard].
@immutable
class StandingFigure {
  const StandingFigure({
    required this.label,
    required this.value,
    this.onTap,
    this.semanticsHint,
    this.valueColor,
    this.copyable = true,
  });

  /// Already localized.
  final String label;

  /// Already formatted. **Empty means "not known yet"** (the formatter is
  /// still loading) and is drawn as a blank line of the right height — never
  /// as a dash, which on a card of balances would read as "nothing owed".
  final String value;

  /// Where the figure leads — normally the tab that lists what it adds up.
  /// Null draws a plain figure with no chevron.
  final VoidCallback? onTap;

  /// What tapping does, for a screen reader ("View invoices").
  final String? semanticsHint;

  final Color? valueColor;

  /// False for a value that is a placeholder rather than a figure — the dash
  /// under "Last Expense" for a vendor with none. There is nothing there to
  /// copy, and "Copied —" is noise.
  final bool copyable;
}

/// The two numbers that answer a record's main question, plus whatever
/// secondary balances happen to be non-zero.
///
/// It replaces the four-equal-cells strip on the client screen for three
/// reasons, each visible in a normal account:
///
///  * two of the four cells (credit and payment balance) are zero for almost
///    every client, so half of the most prominent card on the page was dashes;
///  * the figures led nowhere, though each is a sum of rows one tab away;
///  * a long amount was ellipsized — and a balance with its tail cut off is
///    a wrong number, not a short one.
///
/// **Zero rules.** A primary figure always renders, zero included: on this
/// card `$0.00` *is* the answer. A [secondary] figure is the caller's to
/// include or not — pass only the non-zero ones. See
/// `docs/row-actions-and-values.md` § A zero in a detail KPI cell.
///
/// The primary row goes through [KpiStripLayout], so the count-agnostic grid
/// is not solved a second time here; the secondary figures are a `Wrap`, which
/// is count-agnostic by construction.
class StandingCard extends StatelessWidget {
  const StandingCard({
    super.key,
    required this.primary,
    this.secondary = const [],
    this.footnote,
  });

  final List<StandingFigure> primary;
  final List<StandingFigure> secondary;

  /// A full-width line under the primary row — the past-due summary.
  ///
  /// **It owns its leading gap** (see [kStandingFootnoteGap]). Whether it has
  /// anything to say is usually decided after this card is laid out — the
  /// figure it reports arrives from a fetch — so a gap paid here would be
  /// paid for a line that then draws nothing.
  final Widget? footnote;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // The card's own box rather than `DashboardCardShell`, for one reason:
    // the shell lays its child out at the child's own height whatever height
    // the shell is given, so a card stretched by its host kept its figures at
    // the top above a blank strip. `alignment` centres them instead, and
    // costs nothing when the card is its natural height. Same surface,
    // radius, border and shadow as the shell.
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow1,
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          KpiStripLayout(
            cells: [for (final f in primary) _PrimaryFigure(figure: f)],
          ),
          ?footnote,
          if (secondary.isNotEmpty) ...[
            SizedBox(height: InSpacing.md(context)),
            Divider(height: 1, thickness: 1, color: tokens.border),
            const SizedBox(height: InSpacing.xs),
            Wrap(
              spacing: InSpacing.lg(context),
              children: [
                for (final f in secondary) _SecondaryFigure(figure: f),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The space a [StandingCard.footnote] leaves above itself when it draws.
const double kStandingFootnoteGap = InSpacing.sm;

/// Caption over a large amount. The whole figure is the tap target; the
/// chevron on the caption line says so without taking width from the amount.
class _PrimaryFigure extends StatelessWidget {
  const _PrimaryFigure({required this.figure});

  final StandingFigure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final valueStyle = theme.textTheme.titleLarge
        ?.copyWith(
          color: figure.valueColor ?? tokens.ink,
          fontWeight: FontWeight.w600,
        )
        .merge(moneyTextStyle());
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Caption(label: figure.label, linked: figure.onTap != null),
        const SizedBox(height: 4),
        // Scales down, never ellipsizes — see the class doc. Empty keeps the
        // line box so the card does not jump when the formatter arrives.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            figure.value.isEmpty ? ' ' : figure.value,
            maxLines: 1,
            softWrap: false,
            style: valueStyle,
          ),
        ),
      ],
    );
    return _FigureTarget(figure: figure, child: body);
  }
}

/// Label and amount on one line, for the balances that only sometimes exist.
class _SecondaryFigure extends StatelessWidget {
  const _SecondaryFigure({required this.figure});

  final StandingFigure figure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final floor = Env.isTouchPrimary ? InSizes.touchTarget : 32.0;
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: floor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The label gives way, never the amount: at a large text scale on a
          // narrow card the two do not fit, and a clipped amount is a wrong
          // one.
          Flexible(
            child: Text(
              figure.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          Text(
            figure.value.isEmpty ? ' ' : figure.value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
                  color: figure.valueColor ?? tokens.ink,
                  fontWeight: FontWeight.w600,
                )
                .merge(moneyTextStyle()),
          ),
          if (figure.onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: tokens.ink3),
          ],
        ],
      ),
    );
    return _FigureTarget(figure: figure, child: body);
  }
}

/// `ink2`, not the `ink3` the KPI strips this replaced used: at 11 px the muted
/// tone is 3.98:1 on a card in the default light theme.
class _Caption extends StatelessWidget {
  const _Caption({required this.label, required this.linked});

  final String label;
  final bool linked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final text = Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: tokens.ink2,
        fontWeight: FontWeight.w600,
        fontSize: 11,
        letterSpacing: 0.4,
      ),
    );
    if (!linked) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        const SizedBox(width: 2),
        Icon(Icons.chevron_right, size: 14, color: tokens.ink2),
      ],
    );
  }
}

/// Makes a figure navigate on tap while keeping it copyable.
///
/// The same split `DetailInfoRow` uses for a row with its own `onTap`: the tap
/// goes to the action, and the value is still reachable by the hover copy icon
/// with a pointer or a long-press on touch. Without the second half, making a
/// balance a link would have taken away the only way to copy it.
class _FigureTarget extends StatelessWidget {
  const _FigureTarget({required this.figure, required this.child});

  final StandingFigure figure;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onTap = figure.onTap;
    final copyable = figure.value.isEmpty || !figure.copyable
        ? child
        : CopyableValue(
            value: figure.value,
            enableTapToCopy: onTap == null,
            enableLongPressToCopy: onTap != null,
            fillWidth: false,
            child: child,
          );
    if (onTap == null) return copyable;
    return Semantics(
      button: true,
      label: '${figure.label} ${figure.value}',
      hint: figure.semanticsHint,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: copyable,
        ),
      ),
    );
  }
}
