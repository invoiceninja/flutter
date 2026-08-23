import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/widgets/settings_scope_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_two_pane_scope.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// Shared chrome for every settings screen: a [Scaffold] whose AppBar leading
/// adapts to where the page sits (back arrow on a sub-page, hamburger +
/// [AppDrawer] only at a nav root — see `build`) and a consistent [AppBar] that
/// localizes its title via [titleKey]. Use [actions] and [bottom] to extend
/// the AppBar (e.g. a Save button + TabBar on Company Details).
class SettingsScreenScaffold extends StatelessWidget {
  const SettingsScreenScaffold({
    super.key,
    required this.titleKey,
    required this.body,
    this.actions,
    this.bottom,
    this.leading,
  });

  final String titleKey;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  /// Optional explicit AppBar leading. When non-null it wins on **every**
  /// width — for drill-in screens that want a back affordance even on the
  /// two-pane layout, where the default below deliberately shows none.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // Which leading a settings page gets is *not* a pure width question.
    //
    //  * With the section list beside us (two-pane) there is nothing to go
    //    back to — and an arrow would be actively wrong there, since
    //    `/settings` redirects straight back out to Company Details at that
    //    width (`settingsIndexRedirect`).
    //  * Everywhere else a sub-page is a dead end without one. Settings routes
    //    are genuinely nested, so `canPop` is what distinguishes a sub-page
    //    from the `/settings` index (which renders its own Scaffold and keeps
    //    the hamburger — it's a nav root). This is issue #40: the leading slot
    //    used to be taken by the hamburger at every narrow width, so the arrow
    //    could never appear, and `automaticallyImplyLeading` below was dead
    //    code because `AppBar` only consults it when `leading` is null.
    final singlePane = !SettingsTwoPaneScope.of(context);
    // `impliesAppBarDismissal`, not `Navigator.of(context).canPop()`: it is the
    // value `AppBar`'s own auto-leading reads, it is per-route rather than
    // per-navigator, and `ModalRoute.of` registers a dependency so a change
    // actually rebuilds us — `Navigator.of` is a bare ancestor lookup.
    final showBack =
        singlePane && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
    final showHamburger = !showBack && !Breakpoints.isGlobalNavVisible(context);
    // `BackButton` — not a hand-rolled arrow — for the platform-adaptive
    // glyph, the built-in `maybePop` (which runs the page's `PopScope` discard
    // guard), and consistency with the drill-in screens that already pass one.
    final resolvedLeading =
        leading ??
        (showBack
            ? const BackButton()
            : (showHamburger ? const DrawerHamburger() : null));
    return Scaffold(
      // Dropped along with the hamburger: an attached drawer still opens on a
      // left-edge drag (`drawerEnableOpenDragGesture` defaults to true), which
      // would fight Android's back gesture on exactly the screens that just
      // gained a back arrow. The drawer stays one tap away via the Settings
      // menu.
      drawer: showHamburger ? const AppDrawer() : null,
      appBar: AppBar(
        title: Text(context.tr(titleKey)),
        leading: resolvedLeading,
        // Explicit rather than inferred. It was previously inert — `AppBar`
        // only consults it when `leading` is null, which the old code never
        // was on narrow — but now that the resolved leading CAN be null (the
        // two-pane case), leaving it inferred would let `AppBar` synthesize its
        // own back button from `impliesAppBarDismissal`, true on every nested
        // settings page, and paint an arrow onto the one layout we deliberately
        // leave without one.
        automaticallyImplyLeading: false,
        actions: actions,
        bottom: bottom,
      ),
      // Banner sits above the body so the user always sees the scope they're
      // editing. The widget self-hides at company scope, so wide-mode (where
      // the shell renders its own banner) doesn't get a duplicate — narrow
      // mode bypasses the shell entirely and this is the only path.
      body: Column(
        children: [
          const SettingsScopeBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}
