import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Global-search affordance in the sidebar's top toolbar row — the labelled box
/// that opens the command palette, sitting beside the browser-style
/// back/forward arrows.
///
/// **Why it exists, and why it's touch-only.** The command palette had exactly
/// two entry points — the `⌘/` shortcut and a hover-revealed icon on the
/// Dashboard row (`_DashboardRowSearchButton`, gated on `MouseRegion.onEnter`).
/// Neither exists on a phone, so global search across every entity type — plus
/// the persisted "Recent" list — was unreachable on mobile. On desktop those two
/// affordances already work and the rail deliberately stays uncluttered, so
/// `InSidebar` doesn't mount this there.
///
/// **Why it kept its label**, when issue #101 asked for a bare icon. It first
/// shipped as a full-width row of its own beneath the company switcher, and
/// #101 is about the vertical space that row cost. Moving it into the arrows'
/// empty row reclaims all of it; deleting the label would buy nothing further,
/// because the space reclaimed there is *horizontal*. And the label earns its
/// keep: it holds a ~168×44 target instead of 44×44 at the least
/// thumb-reachable part of the screen, and in this app a bare magnifier in
/// chrome already means "search *this* list" (`TokenSearchField`, Settings)
/// rather than "search everything".
///
/// **The label survived issue #104 too**, but only just — and that is now the
/// binding constraint on this row. A single-company drawer drops the sidebar
/// header and moves Sync in here, which takes the label slot from 130 px to 84.
/// The 232-px rail, which the note above calls the tightest surface, gets 82,
/// so the drawer stays a hair wider — but only because that layout spends
/// `InSpacing.xs` on the Sync gap rather than `sm`, and trims its right inset
/// from 14 to 12 (both rationalised in `in_sidebar.dart`). Give **both** back
/// and the slot is 78, where French ("Rechercher", 64.5 px) ellipsizes at
/// 1.21x — the app's own Large is 1.2. Either one alone still clears it.
///
/// **`MainAxisAlignment.center` is load-bearing.** A *full-width* bordered box
/// with a magnifier reads as a text field — precisely the complaint in #101. At
/// button width with a centred icon + label it reads as a button, and it shares
/// the `SidebarSyncButton` chrome it now sits directly above: same `surfaceAlt`
/// ground, `InRadii.r2` corners, border, and 44-px floor. Don't left-align it.
///
/// The **ink deliberately differs** from that pairing: Sync is a bare glyph at
/// `ink3`, this is `ink2` because it carries a word meant to be read at 13 pt.
/// The right inset in `in_sidebar.dart` aligns the two trailing edges, so the
/// contrast gap is visible — it is a choice, not drift.
///
/// Sizing is **minimum-only** so the box grows with the text scaler; a fixed
/// height would clamp the label's line box and slice Inter Tight's descenders.
/// `minWidth` is defensive only: the sole mount is `Expanded`, which supplies a
/// *tight* width, and `BoxConstraints.enforce` clamps a minimum into `[W, W]`.
/// The 44 floor is hardcoded rather than taken as a `touch:` parameter (which
/// is what `SidebarSyncButton` and `_HistoryButton` do) because this is only
/// ever mounted on touch — relaxing that gate means adding the parameter first,
/// or a 44-px box lands beside 32-px arrows and grows the desktop row to 44.
///
/// Absent from the 64-px collapsed rail because there is no horizontal slack
/// there: the two arrows are 2×32 in a 64-px box with no horizontal padding.
/// (Note that `compact` and `touch` *do* co-occur — a tablet gets the persistent
/// rail with a working collapse toggle — so that rail is a real state, not a
/// theoretical one.)
///
/// Pure and directly pumpable — the callback arrives as a parameter rather than
/// this widget reaching for `Services`, matching `SidebarNavItem` /
/// `NavHistoryButtons` / `SidebarSyncButton`.
class SidebarSearchBox extends StatelessWidget {
  const SidebarSearchBox({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      // The visible label already carries the semantics, so exclude this or a
      // screen reader announces "Search" twice. It stays for the case the label
      // can't cover: on the 232-px rail the label slot is 82 px, so a long
      // translation ellipsizes past ~1.27× text scale and a long-press is then
      // the only way to read it whole.
      excludeFromSemantics: true,
      message: context.tr('search'),
      child: Material(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(color: tokens.border),
            ),
            constraints: const BoxConstraints(
              minWidth: InSizes.touchTarget,
              minHeight: InSizes.touchTarget,
            ),
            // 6, not InSpacing.sm — the tightest surface is the 232-px rail,
            // where the box is 120 wide. `Container` folds the 1-px border into
            // the padding, so at 8 the label slot is 76 px and "Rechercher"
            // (the widest bundled label, 64.5 px at 13 pt) ellipsizes from
            // ~1.18× text scale — below the app's own Large setting of 1.2×.
            // Dropping this and the icon gap to 6 takes the slot to 82 and buys
            // one notch of that ladder back. InSpacing has no 6 (xs 4, sm 8).
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 18, color: tokens.ink2),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.tr('search'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: tokens.ink2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
