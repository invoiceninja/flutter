import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Ghost "Refresh" button for the wide dashboard top bar (issue #26 — the
/// freshness line used to sit at the very bottom of the scroll, so refreshing
/// meant scrolling past every card and back).
///
/// Styled to match [DateRangePickerButton] so the header cluster reads as one
/// row of controls. The 14 px *glyph* swaps to a spinner while a pass is in
/// flight — never the label — which is the app's established vocabulary
/// (`SidebarSyncButton`, the entity-edit Save button) and keeps the button's
/// width constant, so an in-flight refresh can't reflow the header under the
/// user's cursor.
///
/// Being a real `TextButton` rather than a text link is deliberate: it is
/// keyboard-focusable, announces as a button, and picks up the platform's
/// touch sizing automatically (`adaptivePlatformDensity` + a `padded`
/// `materialTapTargetSize` on iOS/Android), so the CLAUDE.md touch-target rule
/// is satisfied without threading `Env.isTouchPrimary` down by hand.
class DashboardRefreshButton extends StatelessWidget {
  const DashboardRefreshButton({
    super.key,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Tooltip(
      // Scopes this against the sidebar's one-tap Sync, which sits a
      // screen-width away and re-downloads every entity — this only refetches
      // the dashboard's own sections. Plain Tooltip, not ShortcutTooltip:
      // there's no shortcut to advertise, and `richMessage` isn't matched by
      // `find.byTooltip`.
      message: context.tr('refresh_dashboard_data'),
      waitDuration: const Duration(milliseconds: 600),
      child: TextButton.icon(
        onPressed: isRefreshing ? null : onRefresh,
        style: TextButton.styleFrom(
          foregroundColor: tokens.ink2,
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InRadii.r2),
            side: BorderSide(color: tokens.border),
          ),
        ),
        icon: isRefreshing
            ? const RepaintBoundary(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Icon(Icons.refresh, size: 14),
        label: Text(
          context.tr('refresh'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
