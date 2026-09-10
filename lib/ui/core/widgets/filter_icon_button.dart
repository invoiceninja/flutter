import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// `AppBar` filter action: a `filter_alt` icon carrying a small accent dot
/// while any filter is applied.
///
/// Extracted from `activity_screen.dart`'s private `_FilterButton` when the
/// four custom Tasks views needed the same affordance
/// (invoiceninja/flutter#136), so the two surfaces cannot drift on the dot's
/// size, colour or placement.
///
/// Takes the **count**, not a bool, even though nothing renders the number:
/// `ActivityFilters.activeCount` is what the Activity screen already holds, so
/// narrowing the API here would foreclose a count badge for both callers. The
/// tooltip does use it.
class FilterIconButton extends StatelessWidget {
  const FilterIconButton({
    super.key,
    required this.activeCount,
    required this.onPressed,
    this.size,
  });

  /// Number of filter dimensions currently applied. Anything above zero paints
  /// the dot.
  final int activeCount;

  final VoidCallback onPressed;

  /// Rendered side length, or null for Flutter's default 48 px `IconButton`.
  ///
  /// Pass a number only where the host is height-constrained. The Tasks wide
  /// header band is `InSizes.headerBand` (69) minus 24 px of padding, so its
  /// `Row` gives children **45 px** — a default `IconButton` neither fits there
  /// *nor throws*: the incoming constraints clamp it and it renders short. Pass
  /// `actionButtonSize()` (44 on touch / 32 with a pointer) at such a site.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = context.tr('filters');
    final side = size;
    return IconButton(
      // State-bearing, because the dot is invisible to a screen reader and on a
      // phone this button is the *only* filter surface: without the count, a
      // narrowed board and an unfiltered one announce identically.
      tooltip: activeCount == 0 ? label : '$label ($activeCount)',
      onPressed: onPressed,
      // `fixedSize` + zeroed min/max + `shrinkWrap`, never `constraints:` +
      // `visualDensity:` — `EntityActionsPopupButton._buttonStyle` documents
      // why each of the three is load-bearing (the M3 default `minimumSize` is
      // `kMinInteractiveDimension`, and `fixedSize` is clamped *by* it).
      style: side == null
          ? null
          : IconButton.styleFrom(
              fixedSize: Size(side, side),
              minimumSize: Size.zero,
              maximumSize: Size.infinite,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.filter_alt_outlined),
          if (activeCount > 0)
            // Directional, not `Positioned(right:)`: the dot belongs on the
            // icon's trailing corner in Arabic and Hebrew too.
            PositionedDirectional(
              end: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
