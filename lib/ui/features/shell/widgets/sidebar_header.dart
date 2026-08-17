import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/shell/widgets/company_switcher_button.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_sync_button.dart';

/// Top of the sidebar: the company switcher paired with the one-tap Sync
/// button (issue #14 — syncing used to be four taps deep in Settings), plus
/// a Search button on touch.
///
/// The children are *siblings*, never nested: [CompanySwitcherButton]'s
/// `InkWell` covers its whole box and would swallow a tap landing on a child.
///
/// **Why Search is touch-only.** The command palette had exactly two entry
/// points — the `⌘/` shortcut and a hover-revealed icon on the Dashboard row
/// (`_SidebarSearchButton`, gated on `MouseRegion.onEnter`). Neither exists on
/// a phone, so global search across every entity type — plus the persisted
/// "Recent" list — was unreachable on mobile. On desktop those two affordances
/// already work and the header deliberately stays uncluttered, so this button
/// doesn't render there.
///
/// Pure and directly pumpable — callbacks arrive as parameters rather than
/// this widget reaching for `Services`, matching `SidebarNavItem` /
/// `NavHistoryButtons` / `SidebarSyncButton`.
class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    required this.session,
    required this.resync,
    required this.onSync,
    this.onSearch,
    this.onBeforeModal,
    this.compact = false,
    this.touch = false,
    super.key,
  });

  final AuthSession session;
  final ValueListenable<ResyncProgress> resync;
  final VoidCallback onSync;

  /// Opens the command palette. Rendered only when [touch] is true — see the
  /// class doc.
  final VoidCallback? onSearch;
  final VoidCallback? onBeforeModal;
  final bool compact;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final switcher = CompanySwitcherButton(
      session: session,
      onBeforeOpen: onBeforeModal,
      compact: compact,
      touch: touch,
    );
    final sync = SidebarSyncButton(
      progress: resync,
      companyId: session.currentCompanyId,
      compact: compact,
      touch: touch,
      onSync: onSync,
    );
    // `compact` is the 64-px desktop rail, which the drawer never uses (it
    // passes `width: null`, disabling collapse), so this and `touch` don't
    // co-occur in practice — the guard just keeps the rail unaffected.
    final search = (touch && !compact && onSearch != null)
        ? _SidebarHeaderSearchButton(onTap: onSearch!)
        : null;

    if (compact) {
      // The 64-px rail leaves 64 − 28 padding = 36 px, which the avatar-only
      // switcher already fills exactly — so Sync stacks under it, not beside.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switcher,
          SizedBox(height: InSpacing.sm),
          sync,
        ],
      );
    }
    // IntrinsicHeight is what makes `stretch` usable here: a bare Row inherits
    // `maxHeight: infinity` from the sidebar's Column, and `stretch` would
    // resolve to an infinite tight height. With it, the Sync box is exactly as
    // tall as the switcher — including at large text scale, where the company
    // name's line box pushes the switcher past 44. Cheap at this size because
    // the name is `maxLines: 1` + ellipsis, so its intrinsic height is one line
    // box at any width.
    final topRow = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: switcher),
          SizedBox(width: InSpacing.sm),
          sync,
        ],
      ),
    );
    if (search == null) return topRow;
    // Search gets its own full-width row rather than a third seat in the top
    // row. A 44 px touch button beside the switcher and Sync left the name
    // ~100 px in a 232 px rail, which truncated "Walker, Jakubowski and
    // Wilderman" to "W…" — the switcher's whole job is naming the company you
    // are in. Full width also lets it carry a label, which is a better
    // affordance than a bare glyph anyway.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topRow,
        SizedBox(height: InSpacing.sm),
        search,
      ],
    );
  }
}

/// Search affordance in the touch header. Deliberately mirrors
/// [SidebarSyncButton]'s box — same `surfaceAlt` ground, `InRadii.r2` corners,
/// border, and **minimum**-only constraints so `CrossAxisAlignment.stretch`
/// can size it to the company switcher (which grows with text scale; a fixed
/// height would fight that and clip the switcher's descenders).
class _SidebarHeaderSearchButton extends StatelessWidget {
  const _SidebarHeaderSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      // Also the screen-reader label — this is an icon-only control.
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
            padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 18, color: tokens.ink2),
                SizedBox(width: InSpacing.sm),
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
