import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Row-hover background color for unselected rows.
///
/// Light mode reuses `surfaceAlt` — same value the column-headers strip
/// uses, so hover reads as part of the same surface family. Dark mode
/// can't use `surfaceAlt`: its delta from `surface` is ~3 % per channel
/// (e.g. `#28261F` vs `#1F1E18` on espresso) and is perceptually
/// invisible as a hover affordance over the card surface. Instead we
/// blend ~8 % of `ink` over `surface`, matching the Material 3 hover
/// state opacity and producing a clearly readable lift in every dark
/// palette.
Color _rowHoverColor(BuildContext context, InTheme tokens) {
  if (Theme.of(context).brightness == Brightness.light) {
    return tokens.surfaceAlt;
  }
  return Color.alphaBlend(tokens.ink.withAlpha(0x14), tokens.surface);
}

/// Shared selected-row chrome for every entity list tile.
///
/// Replaces the per-tile hand-rolled `Material`/`InkWell`/`DecoratedBox`
/// selection styling that previously diverged across the 17 list tiles.
///
/// Design (see `docs/.../when-i-select-a-wiggly-crescent.md` plan):
///
/// * **Selected** → a flat full-bleed `accentSoft` fill with a solid 3px
///   [accent] bar on the leading edge, both painted by a single paint-only
///   `DecoratedBox` (`BorderDirectional(start: …)`). Because `DecoratedBox`
///   never affects `child`'s layout, the [child] keeps its own padding and
///   the exact same constraint flow as the unselected branch — columns stay
///   pixel-aligned with the fixed `EntityListColumnHeaders` strip and the
///   text does not shift vertically on select. No rounding, no inset, no
///   `ClipRRect` — square and flat, the classic data-table selection idiom.
/// * **Not selected** → the [child] edge-to-edge with a full-bleed bottom
///   hairline, suppressed via [hideBottomDivider] (last row, the selected
///   row itself, or the row directly above the selected one — the scaffold
///   computes this since a tile can't see its neighbour's selection state).
///   Suppressing the neighbour's hairline too is what keeps the selected
///   fill bounded by a colour change only, never trapped between gray lines.
/// * **Ink / hover** → selected rows use a bare [GestureDetector]: on macOS,
///   Material 3 paints an opaque hover overlay over a non-transparent
///   Material color and `overlayColor: transparent` does not suppress it.
///   With no `InkWell` in the tree no overlay can fire, so `accentSoft`
///   stays readable on hover. Unselected rows keep the `InkWell` (its
///   hover overlay via [_rowHoverColor] + the Material focus highlight
///   for keyboard nav). The hover color is brightness-aware: light mode
///   uses `surfaceAlt`; dark mode uses a computed `ink @ 8% over surface`
///   blend, because raw `surfaceAlt` is perceptually invisible against
///   the dark card surface.
///
/// No animation: selection snaps. Arrow-key / J-K navigation in the
/// master-detail list moves selection on every keypress; an implicit tween
/// would smear and trail the focused row.
class SelectableListRow extends StatelessWidget {
  const SelectableListRow({
    super.key,
    required this.selected,
    required this.urlSelected,
    required this.hideBottomDivider,
    required this.onTap,
    required this.child,
    this.onLongPress,
  });

  /// Drives the `accentSoft` fill. True for both multi-select members and the
  /// master-detail-active row (every screen passes
  /// `selected: vm.isSelected(id) || isUrlSelected`).
  final bool selected;

  /// Retained on the API (every screen passes it) but **not used for
  /// rendering**: the selected treatment is a single flat look, identical for
  /// a multi-select member and the master-detail-active row.
  final bool urlSelected;

  /// Suppresses the bottom hairline. Computed by the list scaffold as
  /// `isLast || thisRowSelected || nextRowSelected`.
  final bool hideBottomDivider;

  /// Null for a row that opens nothing (it may still be long-pressed): no
  /// ripple, and not announced as a button that does nothing.
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The tile's own already-padded row content. Its interior padding is left
  /// untouched so column cells stay aligned with the header strip.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;

    final Widget body;
    if (selected) {
      // Flat, full-bleed accentSoft fill with a 3px accent bar on the leading
      // edge. The bar is a painted `BorderDirectional` on a paint-only
      // `DecoratedBox` — NOT a `Stack`/positioned overlay. A Stack would
      // re-layout `child` with loosened constraints (dropping the scaffold's
      // `ConstrainedBox(minHeight)`), so the centered Row would shrink to
      // intrinsic height and ride up — the "text raises on select" bug.
      // `DecoratedBox` never touches `child`'s layout, so the selected and
      // unselected branches give `child` an identical constraint flow.
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.accentSoft,
          border: BorderDirectional(
            start: BorderSide(color: tokens.accent, width: 3),
          ),
        ),
        child: child,
      );
    } else {
      body = DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: hideBottomDivider
                ? BorderSide.none
                : BorderSide(color: tokens.border),
          ),
        ),
        child: child,
      );
    }

    if (selected) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: body,
      );
    }
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      // A row that opens nothing (it may still be long-pressed): no hand
      // cursor and no ripple on a tap that does nothing.
      mouseCursor: onTap == null ? SystemMouseCursors.basic : null,
      splashFactory: onTap == null ? NoSplash.splashFactory : null,
      hoverColor: _rowHoverColor(context, tokens),
      child: body,
    );
  }
}
