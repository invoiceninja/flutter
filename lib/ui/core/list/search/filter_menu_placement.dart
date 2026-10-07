import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Which side of its anchor a floating filter menu hangs from.
enum FilterMenuSide { below, above }

/// Where a floating filter menu goes, in the hosting Overlay's coordinates.
@immutable
class FilterMenuPlacement {
  const FilterMenuPlacement({
    required this.left,
    required this.width,
    required this.maxHeight,
    required this.side,
    required this.edge,
  });

  final double left;
  final double width;

  /// Room the menu may grow into before it meets the viewport edge or the
  /// soft keyboard. The menu shrink-wraps under this.
  final double maxHeight;

  final FilterMenuSide side;

  /// `Positioned.top` when [side] is [FilterMenuSide.below]; the distance from
  /// the overlay's bottom (`Positioned.bottom`) when it is
  /// [FilterMenuSide.above], because the menu's own height is only known once
  /// it has shrink-wrapped.
  final double edge;

  double? get top => side == FilterMenuSide.below ? edge : null;
  double? get bottom => side == FilterMenuSide.above ? edge : null;
}

/// Places the suggestion menu (and the per-chip segment menus) of the token
/// search field. Pure geometry, so the whole placement rule is unit-testable
/// without pumping the field — which is where every past regression lived:
/// the menu used to be positioned inline from `localToGlobal` reads, anchored
/// at the caret and clamped to the Overlay, and "appears too far over" was the
/// result.
///
/// The rule:
///  * the menu's row content starts at [anchorStart] — the leading edge of
///    whatever it belongs to (the text being typed, the tapped chip), so the
///    painted edge sits [rowInset] before it;
///  * it never leaves the search box horizontally when the box is at least as
///    wide as the menu ([containInField]); a box narrower than the menu falls
///    back to the Overlay's extent, start-aligned with the box;
///  * it hangs below the anchor, capped to the room above [bottomInset] (the
///    soft keyboard). It flips above only when below is too short to be usable
///    and above is roomier — and [latchedSide] pins that choice for as long as
///    the menu stays open, so a rising keyboard cannot flip it mid-aim.
FilterMenuPlacement placeFilterMenu({
  required Rect field,
  required double anchorStart,
  required double anchorTop,
  required double anchorBottom,
  required Size overlay,
  required double preferredWidth,
  double preferredMaxHeight = 320,
  double bottomInset = 0,
  TextDirection textDirection = TextDirection.ltr,
  bool containInField = true,
  FilterMenuSide? latchedSide,
  double rowInset = 12,
  double gap = 4,
  double margin = 8,
  double minUsableHeight = 132,
}) {
  final overlayLo = margin;
  final overlayHi = math.max(overlayLo, overlay.width - margin);
  final width = math.min(preferredWidth, overlayHi - overlayLo);

  // Horizontal bounds: the field when it can hold the menu, else the Overlay.
  final fits = containInField && field.width >= width;
  final lo = fits ? math.max(field.left, overlayLo) : overlayLo;
  final hi = fits ? math.min(field.right, overlayHi) : overlayHi;
  final maxLeft = math.max(lo, hi - width);

  final double wanted;
  if (textDirection == TextDirection.rtl) {
    // The token starts at its RIGHT edge, so the menu's right edge follows it.
    wanted = anchorStart + rowInset - width;
  } else {
    wanted = anchorStart - rowInset;
  }
  final left = wanted.clamp(lo, maxLeft).toDouble();

  final usableBottom = overlay.height - bottomInset - margin;
  final roomBelow = usableBottom - (anchorBottom + gap);
  final roomAbove = (anchorTop - gap) - margin;
  final side =
      latchedSide ??
      (roomBelow < minUsableHeight && roomAbove > roomBelow
          ? FilterMenuSide.above
          : FilterMenuSide.below);

  // Never collapse below a few rows: a menu squeezed to nothing is worse than
  // one that runs under the keyboard, which the user can still scroll.
  final floor = math.min(preferredMaxHeight, 96.0);
  final room = side == FilterMenuSide.below ? roomBelow : roomAbove;
  final maxHeight = room.clamp(floor, preferredMaxHeight).toDouble();

  return FilterMenuPlacement(
    left: left,
    width: width,
    maxHeight: maxHeight,
    side: side,
    edge: side == FilterMenuSide.below
        ? anchorBottom + gap
        : overlay.height - (anchorTop - gap),
  );
}
