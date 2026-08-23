import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/ui/core/widgets/hidden_shell_navigator.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/views/settings_screen.dart';
import 'package:admin/ui/features/settings/widgets/settings_scope_banner.dart';

/// Phase 12: transient flag flipped by design-edit entry helpers
/// (`showWysiwygDesignScreen` / `showDesignEditScreen` in
/// `custom_designs_body.dart`) so the wide-mode `SettingsListSidebar`
/// hides for the duration of the edit and the live preview can use
/// the reclaimed 280 px. Not persisted — auto-resets on pop via the
/// callers' try/finally wrappers.
final ValueNotifier<bool> hideSettingsListSidebar = ValueNotifier(false);

/// Master-detail shell for `/settings/*` on wide screens.
///
/// - **Wide (≥[Breakpoints.settingsTwoPane], 880 px)**: left pane is
///   `SettingsListSidebar` (always visible except while a design is being
///   edited — see [hideSettingsListSidebar]); right pane is the routed child,
///   or a "Select a setting" hint when the user is sitting on `/settings` with
///   no section chosen.
/// - **Narrow / tablet (<880 px)**: passes through so each section page (or
///   `SettingsScreen` at `/settings`) renders as its own full-screen Scaffold.
///   The 600–880 px band falls here too — the 280 px sidebar would otherwise
///   crush the form pane (the section list stays reachable via the full-screen
///   `/settings` page + push nav).
class SettingsShell extends StatelessWidget {
  const SettingsShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The settings two-pane needs more room than the generic 600 px wide
        // breakpoint: a fixed 280 px sidebar leaves the form pane cramped on
        // tablets, so gate the split at [Breakpoints.settingsTwoPane]. Below
        // it we pass through to single-pane full-screen navigation.
        final wide = constraints.maxWidth >= Breakpoints.settingsTwoPane;
        if (!wide) return child;

        final atIndex = GoRouterState.of(context).uri.path == '/settings';
        // The scope banner is rendered by `SettingsScreenScaffold`
        // (below the section's AppBar) so it appears in both wide
        // and narrow layouts. The select-a-hint pane gets its own
        // banner because the section scaffold path doesn't apply
        // when no section is chosen.
        // `child` is this ShellRoute's Navigator, so the select-a-hint branch
        // must keep it mounted rather than swap it out — see
        // [HiddenShellNavigator]. `settingsIndexRedirect` normally bounces the
        // user off `/settings` while wide, but it only runs on *navigation*:
        // resizing narrow → wide while sitting on the index (foldable,
        // split-screen, desktop mode) lands here, and a dropped Navigator makes
        // the next platform back press throw inside go_router.
        final rightPane = atIndex
            ? Stack(
                children: [
                  const Column(
                    children: [
                      SettingsScopeBanner(),
                      Expanded(child: _SelectAHint()),
                    ],
                  ),
                  Positioned.fill(child: HiddenShellNavigator(child: child)),
                ],
              )
            : child;
        return Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: hideSettingsListSidebar,
            builder: (context, hidden, _) {
              // Phase 13: slide the sidebar off the left edge instead
              // of popping it out — mirrors MaterialPageRoute's
              // 300 ms slide-in on the right pane so both halves of
              // the transition feel coordinated. Mirrors the same
              // AnimatedContainer + ClipRect + OverflowBox recipe
              // `in_sidebar.dart` uses for its rail collapse, but
              // pins to `centerRight` so contents drift LEFT as the
              // box shrinks (vs the rail's `centerLeft` accordion
              // close).
              return Row(
                children: [
                  RepaintBoundary(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      width: hidden ? 0 : 280,
                      color: Theme.of(context).colorScheme.surface,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.centerRight,
                          minWidth: 280,
                          maxWidth: 280,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            child: const SettingsListSidebar(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!hidden) const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: rightPane),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _SelectAHint extends StatelessWidget {
  const _SelectAHint();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.settings_outlined, size: 64, color: color),
          const SizedBox(height: 16),
          Text(
            context.tr('select_a_setting'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
