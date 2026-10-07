import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// Narrow-layout `AppBar` for the dashboard: hamburger + title + Customize.
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
/// **There is no create action here** (invoiceninja/flutter#164). The bar
/// used to end in a `+` that went straight to New Invoice. It is now the
/// screen's bottom-right `DashboardCreateFab`, which opens a choice of
/// everything the user may create and sits where a thumb can reach it.
///
/// **Nor a date range, a currency or a drafts switch.** They were a funnel
/// icon and a cog up here, each hiding its state behind a tap; they are now
/// controls in the page, above the figures they change, showing their value at
/// rest (`DashboardPeriodBar`). The range was shown only as an untappable line
/// of small capitals under this bar — the one place that said what it was could
/// not change it.
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
      // Material's default 16 dp gap either side of the title costs more width
      // than this bar had on the narrowest phones. With a hamburger and three
      // actions (it carries one now), the default left the title 88 dp on a
      // 320 dp handset.
      // "Dashboard" measures 104 dp in Inter Tight, so the default truncates it
      // to "Dashboa…", the exact ellipsis flutter#50 was filed about. When
      // flutter#50 was filed it took a 360 dp phone to do this, because the
      // bar had a fourth action (New Invoice). That action became the
      // screen's FAB in flutter#164.
      //
      // Conditional, because `NavigationToolbar` starts the title at
      // `leadingWidth + middleSpacing`: with no hamburger that is 0 + 0, and
      // the title renders hard against the pane edge — which in the rail band
      // is the sidebar's right border, since the shell insets content with a
      // bare `Positioned.fill(left: railWidth)`. There is also nothing to buy
      // there: no leading and a ≥368 dp bar leaves the default 16 ample room.
      // Three other bars pair `titleSpacing: 0` with a real `title:` for the
      // same reason — `billing_doc_email_screen.dart`, the command palette's
      // phone page (whose title *is* its search field), and (since #136 gave it
      // a second action) the narrow `tasks_view_toggle` bar this one mirrors.
      // The remaining uses of that value are a different case: bars that render
      // through `flexibleSpace` and pass no title at all, i.e. both in
      // `entity_list_app_bar.dart` and `tasks_view_toggle`'s *wide* branch —
      // so that file belongs to both sets, one branch each.
      titleSpacing: showHamburger ? 0 : null,
      // Still ellipsised, unlike the other screens' bare `Text` titles: 320 dp
      // handsets remain too narrow for the full word with every action shown,
      // and the longest translation ("Pannello di Controllo", it, 192 dp)
      // overruns every phone.
      //
      // Under it, how fresh the data is — the same stamp the wide bar carries
      // under the company's name. It used to ride an untappable line of small
      // capitals at the top of the page, which the needs-attention band now
      // leads.
      //
      // Two lines in a 56 px toolbar: at the default text size they fit with
      // room to spare, and at 140% they do not — the page name lost its top.
      // So the pair scales down together to the height it has (and only then;
      // `scaleDown` never enlarges), while each line still ellipsises on width.
      title: _FitToolbar(
        children: [
          Text(context.tr('dashboard'), overflow: TextOverflow.ellipsis),
          // Its own listener: the screen builds this bar outside the
          // builder that follows the view model, and the cached-figures time
          // lands on the totals' section notifier.
          ListenableBuilder(
            listenable: Listenable.merge([
              vm,
              vm.listenableFor(DashboardKind.totalsCurrent),
            ]),
            builder: (context, _) => FreshnessTicker(
              builder: (context) => Text(
                freshnessText(
                  context,
                  lastRefreshed: vm.lastRefreshed,
                  isRefreshing: vm.isAnyRefreshing,
                  cachedAt: vm.figuresFetchedAt,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.tr('customize'),
          icon: const Icon(Icons.dashboard_customize_outlined),
          onPressed: () => openManageDashboardCards(context, vm: vm),
        ),
      ],
    );
  }
}

/// The app bar's two-line title, kept inside the toolbar's height.
///
/// A `LayoutBuilder` rather than a bare `FittedBox`: a `FittedBox` hands its
/// child unbounded width, which would let a long title run on instead of
/// ellipsising. Here the lines keep the width they are given and only the
/// height is fitted.
class _FitToolbar extends StatelessWidget {
  const _FitToolbar({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
        final scale = MediaQuery.textScalerOf(context).scale(1);
        // Both lines at scale 1 are about 40 px; past ~1.3x they outgrow the
        // toolbar. Draw them at the size that fits, in a box that much wider,
        // so the text still wraps to the same visual width.
        const fits = 1.3;
        if (scale <= fits || !constraints.hasBoundedWidth) return column;
        final shrink = fits / scale;
        // The height is stated: the toolbar lets its title be taller than
        // itself, so without a bound there is nothing for the fit to fit to.
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: kToolbarHeight),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(
              width: constraints.maxWidth / shrink,
              child: column,
            ),
          ),
        );
      },
    );
  }
}
