import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// The small icon button a sidebar row carries at its right edge — the entity
/// rows' hover `+`, the Dashboard row's hover search, and the saved-view
/// rows' always-visible `⋮`.
///
/// One widget because the sizing is where these go wrong, and three private
/// copies of it had already drifted: the `⋮` carried the `shrinkWrap` below
/// and the two hover buttons did not, which is invoiceninja/flutter#171. A
/// button handed to `SidebarNavItem.trailing` / `trailingHover` sits inside
/// the row's `Row`, so its *layout* height drives the row's (CLAUDE.md
/// § Design system, trap 4) — it has to fit the row's content box.
///
/// [touchTarget] widens the button to [InSizes.touchTarget] for a finger. Set
/// it only for an always-visible button on a touch platform. A hover-revealed
/// one keeps the pointer footprint everywhere, touch platforms included: only
/// a pointer can reveal it, and widening it would ellipsize the label further
/// on every hover.
class SidebarRowIconButton extends StatelessWidget {
  const SidebarRowIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.touchTarget = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool touchTarget;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      iconSize: 16,
      padding: EdgeInsets.zero,
      // Without this the `constraints` below are advisory on touch platforms:
      // `ThemeData.materialTapTargetSize` is `padded` on android/iOS, which
      // wraps the button in `_InputPadding` and inflates its *layout* size
      // (not just its hit area) to `kMinInteractiveDimension` = 48 — 40 under
      // the `compact` density below. No-op on desktop, where the theme default
      // is already `shrinkWrap`.
      //
      // Unconditional, and that is the point of #171: a *hover*-revealed
      // button still gets the touch theme, because an iPad with a trackpad
      // (or an Android device with a mouse) hovers. There a 40-px `+` turned
      // the 44-px row into a 54-px one on every hover-in, and the rows below
      // it jumped by 10 px.
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // Deliberately unset for a touch target. Under Material 3 `IconButton`
      // converts `constraints` into ButtonStyle `minimumSize`/`maximumSize`,
      // and `ButtonStyleButton` runs *those* through
      // `visualDensity.effectiveConstraints` — so `compact`'s -8 would turn the
      // width below into a 36..44 range that the 16-px icon collapses back to
      // 36, silently undoing the bigger target. (The `effectiveConstraints`
      // call inside `icon_button.dart` is on the legacy pre-M3 branch and never
      // runs here.) Unset falls back to `ThemeData.visualDensity`, which is
      // `standard` — zero adjustment — on exactly the platforms `touch` covers.
      visualDensity: touchTarget ? null : VisualDensity.compact,
      // The pointer footprint fits the row's 18-px icon. The touch target's
      // height stays at the row's *content* box (44 floor − 7/7 padding = 30),
      // not 44: a 44-tall button would drive the Row to 44 and the row's own
      // padding would stack on top for a 58-px row — 32% taller than every
      // other row in the sidebar. Width is the axis a thumb misses on in a
      // vertical list anyway, and the row's own 44-px floor still governs what
      // the finger lands in.
      constraints: touchTarget
          ? const BoxConstraints.tightFor(
              width: InSizes.touchTarget,
              height: 30,
            )
          : const BoxConstraints.tightFor(width: 18, height: 18),
      // `ink3` is the established weight for sidebar trailing affordances.
      icon: Icon(icon, color: context.inTheme.ink3),
      onPressed: onPressed,
    );
  }
}
