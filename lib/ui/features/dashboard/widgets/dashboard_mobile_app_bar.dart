import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/settings_popover.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// Narrow-layout `AppBar` for the dashboard: hamburger + title + icon actions.
/// Wide layouts use the bespoke `DashboardTopBar` inside the body instead — see
/// `DashboardScreen`. Since flutter#51 a phone renders this bar in *either*
/// orientation, so the landscape case arrives here through `Breakpoints.isPhone`
/// rather than through a narrow pane — and with the rail up (window ≥ 600) it
/// arrives in the no-hamburger shape below.
///
/// **The title is the page name, not the company name** (flutter#50). It used
/// to be the active company, which truncated on most real company names and
/// made this the only screen in the app whose mobile bar isn't its own page
/// name — every other one titles with a localized key
/// (`entity_list_app_bar`, Reports, Outbox, Settings, Tasks). The key here is
/// the same `'dashboard'` the sidebar nav row uses (`in_sidebar.dart`), so the
/// bar and the nav label can't drift apart. The company is one tap away in the
/// drawer — the `CompanySwitcherButton` header on a multi-company account, and
/// `SidebarCompanyFooterAction` on a single-company one, which drops the header
/// row for the space (issue #104) and shows the name in the picker sheet it
/// opens rather than in the drawer itself.
///
/// Split out of `DashboardScreen` so it can be pumped without a
/// `Provider<Services>` harness, exactly like its wide sibling — the screen
/// itself is untestable in a widget test (its VM constructor runs
/// `unawaited(_init())` into real Drift watch streams).
class DashboardMobileAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DashboardMobileAppBar({
    super.key,
    required this.vm,
    required this.showHamburger,
    this.onNewInvoice,
    this.formatter,
  });

  final DashboardViewModel vm;

  /// False once the persistent `InSidebar` rail is up. The drawer is attached
  /// on the same condition, so an unguarded hamburger here would be a dead
  /// button: `Scaffold.of(context).openDrawer()` silently no-ops against a
  /// null drawer. That band is real — the app bar is chosen from this screen's
  /// *local* constraints while the drawer follows *window* width, so a window
  /// between 600 and ~832 px renders both the rail and this bar. See
  /// `Breakpoints.isGlobalNavVisible`.
  final bool showHamburger;

  /// Null when the invoices module is disabled — the "+" action is then
  /// omitted entirely. Mirrors `DashboardTopBar.onNewInvoice`.
  ///
  /// Since flutter#52 this is a phone's **only** New Invoice affordance. The
  /// mobile body's quick-action row used to carry a labelled tile to the same
  /// route, gated on the same module flag, and that duplicate was the one
  /// removed — an `AppBar` action stays reachable at any scroll position,
  /// whereas the row scrolls away with the page. So don't drop this action to
  /// buy back bar width (the title arithmetic above is a standing motive to
  /// try) without restoring that tile first.
  final VoidCallback? onNewInvoice;

  final Formatter? formatter;

  /// No `bottom:`, so this is the plain toolbar height — none of the
  /// hand-maintained `kToolbarHeight + 56` arithmetic `EntityListNormalAppBar`
  /// has to keep in sync.
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Pinned rather than left to the theme: `preferredSize` below is a plain
      // `Size`, and `AppBar.preferredHeightFor` only consults
      // `AppBarTheme.toolbarHeight` for its own `_PreferredAppBarSize`. Stating
      // the height on both sides keeps them equal by construction — otherwise
      // a future `toolbarHeight` in `theme.dart` would size the bar one way and
      // the Scaffold's slot another, and the bar would silently clip.
      toolbarHeight: kToolbarHeight,
      leading: showHamburger ? const DrawerHamburger() : null,
      // Dead in both branches — an explicit `leading` wins when there is one,
      // and when there isn't, the Scaffold's drawer is null on the same
      // condition (so `hasDrawer` is false) and a shell-branch root has nothing
      // to pop. Kept as a statement of intent, not a working guard.
      automaticallyImplyLeading: showHamburger,
      // Material's default 16 dp gap either side of the title is 24 dp this bar
      // can't spare *on a phone*: a hamburger plus four actions leaves the
      // title 80 dp on a 360 dp phone (the most common Android width) and
      // "Dashboard" measures 104 dp in Inter Tight, so the default truncates it
      // to "Dashboa…" — the exact ellipsis flutter#50 was filed about.
      //
      // Conditional, because `NavigationToolbar` starts the title at
      // `leadingWidth + middleSpacing`: with no hamburger that is 0 + 0, and
      // the title renders hard against the pane edge — which in the rail band
      // is the sidebar's right border, since the shell insets content with a
      // bare `Positioned.fill(left: railWidth)`. There is also nothing to buy
      // there: no leading and a ≥368 dp bar leaves the default 16 ample room.
      // No other bar in the app pairs `titleSpacing: 0` with a real `title:` —
      // the `entity_list_app_bar` / `tasks_view_toggle` uses of that value are
      // wide bars that render through `flexibleSpace` and pass no title at all,
      // and the narrow bar this one mirrors (`tasks_view_toggle`, same
      // nullable-leading shape) keeps the default.
      titleSpacing: showHamburger ? 0 : null,
      // Still ellipsised, unlike the other screens' bare `Text` titles: 320 dp
      // handsets remain too narrow for the full word with every action shown,
      // and the longest translation ("Pannello di Controllo", it, 192 dp)
      // overruns every phone.
      title: Text(context.tr('dashboard'), overflow: TextOverflow.ellipsis),
      actions: [
        Builder(
          builder: (iconContext) => IconButton(
            tooltip: context.tr('date_range'),
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => openDateRangePicker(
              iconContext,
              current: vm.filter.range,
              onChange: vm.setDateRange,
              formatter: formatter,
            ),
          ),
        ),
        Builder(
          builder: (iconContext) => IconButton(
            tooltip: context.tr('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => openDashboardSettingsPopover(iconContext, vm: vm),
          ),
        ),
        IconButton(
          tooltip: context.tr('customize'),
          icon: const Icon(Icons.dashboard_customize_outlined),
          onPressed: () =>
              openManageDashboardCards(context, vm: vm, mobileLayout: true),
        ),
        if (onNewInvoice != null)
          IconButton(
            tooltip: context.tr('new_invoice'),
            icon: const Icon(Icons.add),
            onPressed: onNewInvoice,
          ),
      ],
    );
  }
}
