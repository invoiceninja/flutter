import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// Shared shell every dashboard card uses: bordered surface card with an
/// optional title row + trailing link, optional inner padding override, and a
/// content body. Matches the v2 mockup's pattern (surface + 1px border + r3
/// + shadow1).
class DashboardCardShell extends StatelessWidget {
  const DashboardCardShell({
    super.key,
    this.title,
    this.trailing,
    this.padding,
    this.onHeaderTap,
    required this.child,
  }) : assert(
         onHeaderTap == null || title != null || trailing != null,
         'onHeaderTap needs a header to sit in: the whole band is gated on '
         '`title != null || trailing != null`, so on a bare shell it would '
         'compile, analyze clean and do nothing.',
       );

  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  /// Makes the whole header band a tap target for whatever [trailing] already
  /// links to, at no extra height (invoiceninja/flutter#145).
  ///
  /// **Only valid when [trailing] NAVIGATES to a superset of the card body**,
  /// and that is a narrow licence: of the ten shells that pass a [trailing]
  /// today, **six** would be actively wrong here. A header reads as a label, so
  /// a tap on it may only do what the visible affordance beside it promises —
  /// `project_detail_cards_grid.dart` would *create* a task,
  /// `client_edit_shipping_address_section.dart` would overwrite the shipping
  /// address, the two expense edit layouts would toggle a collapse,
  /// `reports_chart_card.dart` has two pickers and no single answer, and
  /// `project_progress_card.dart`'s status pill is not interactive at all.
  /// Leave this null wherever the trailing widget is an action rather than a
  /// destination, and never hand it to a card whose body carries a
  /// `CopyableValue`.
  ///
  /// It is also the shape CLAUDE.md's #128 paragraph bans — an opaque
  /// `GestureDetector` and an `InkWell` nested over one another, where the
  /// innermost recognizer wins the arena — with the operands swapped. The one
  /// property that redeems it is that **both edges resolve to the same
  /// callback**, so "the innermost wins" decides nothing. Delete or re-point
  /// either handler and the ban applies again in full.
  ///
  /// Deliberately **not** a second `InkWell`. One over the same destination
  /// adds a tab stop (`canRequestFocus` defaults true), paints a second hover
  /// wash under the link (`handleMouseEnter` has no child-pressed guard, unlike
  /// `handleAnyTapDown`), puts the click cursor on the card title, and — since
  /// `TapGestureRecognizer` splashes on its 100 ms deadline, before the drag
  /// recognizer wins — flashes the whole band whenever a thumb rests on it
  /// mid-scroll. The affordance stays the link; this is invisible forgiveness
  /// around it.
  final VoidCallback? onHeaderTap;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final hasHeader = title != null || trailing != null;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow1,
      ),
      // Transparent Material so descendant ListTiles/InkWells have a Material
      // ancestor for ink — Flutter 3.44 asserts otherwise (the Container
      // background would hide the ink).
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader) ...[
              _header(context, theme, tokens),
              Divider(height: 1, thickness: 1, color: tokens.border),
            ],
            Padding(
              padding:
                  padding ??
                  EdgeInsets.symmetric(
                    horizontal: InSpacing.lg(context),
                    vertical: InSpacing.md(context),
                  ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ThemeData theme, InTheme tokens) {
    final row = Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.lg(context),
        InSpacing.lg(context),
        InSpacing.md(context),
      ),
      child: Row(
        children: [
          if (title != null)
            Expanded(
              child: Text(
                title!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
    if (onHeaderTap == null) return row;
    return GestureDetector(
      onTap: onHeaderTap,
      // `deferToChild`, the default, would leave the title's slack and the
      // padding unhit — which is most of the target this exists to add.
      behavior: HitTestBehavior.opaque,
      // The wrapper's own node would carry a tap action with neither a role nor
      // a label (`GestureDetector` declares neither), so TalkBack would
      // enumerate a second actionable for one destination and VoiceOver would
      // focus an element that announces nothing. Excluding drops only that
      // node: unlike `ExcludeSemantics` the subtree survives, so [trailing]
      // stays the single announced, activatable target and the semantics tree
      // is exactly what it was before.
      excludeFromSemantics: true,
      child: ConstrainedBox(
        // Around the `Padding`, never the `Row` inside it — applied to the row
        // the band would come to 64. Measured, it binds in exactly one case: a
        // header carrying a `DashboardCardFooterLink` is 45 px on a phone and
        // 53 px at >= 600, so the floor costs nothing there, while a header
        // with a title and no trailing is 40 and is raised to 44. That 1 px of
        // margin in the case that matters is the argument for pinning it: the
        // band is *derived* from `titleSmall`, the ambient text height and two
        // spacing tokens, any of which can move it under the floor silently.
        constraints: BoxConstraints(
          minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
        ),
        child: row,
      ),
    );
  }
}

/// Standard "View all"-style footer link. Capitalisation and copy varies by
/// card — pass the desired label.
class DashboardCardFooterLink extends StatelessWidget {
  const DashboardCardFooterLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(InRadii.r1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinkText(
              label: label,
              style: TextStyle(fontSize: 12, color: tokens.ink3),
            ),
            Icon(Icons.chevron_right, size: 14, color: tokens.ink3),
          ],
        ),
      ),
    );
  }
}
