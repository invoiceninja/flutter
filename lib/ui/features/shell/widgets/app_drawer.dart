import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/shell/branch_company_gate.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';

/// Mobile drawer that consolidates what desktop shows in the persistent
/// `InSidebar`: company switcher + branch nav + trial footer.
///
/// On a single-company account the switcher is not the header row it is on the
/// rail — issue #104 drops that row here and re-homes the control as
/// `SidebarCompanyFooterAction` in the footer, with Sync moving up beside
/// Search. `InSidebar` owns that branch; this class only passes `width: null`,
/// which is what selects it.
///
/// Reads the active `StatefulNavigationShell` from a `Provider` rooted on
/// `ScaffoldWithNav` so branch swaps go through `goBranch(...)` —
/// preserving each branch's inner navigator stack (e.g. an open client
/// detail survives a Dashboard detour).
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<StatefulNavigationShell>();
    return Drawer(
      width: 280,
      child: InSidebar(
        // Null = stretch to fill the drawer's 280 instead of the desktop 232.
        width: null,
        currentBranch: nav.currentIndex,
        onBeforeModal: () => Navigator.pop(context),
        onSelectBranch: (index) async {
          // Drawer's BuildContext is destroyed by `Navigator.pop`, so resolve
          // every context-dependent value *before* the pop. The dialog is
          // shown from the root navigator (passed via the captured navState),
          // which survives the drawer dismissal.
          final services = context.read<Services>();
          final guard = services.unsavedChangesGuard;
          final branchGate = context.read<BranchCompanyGate>();
          final rootContext = Navigator.of(
            context,
            rootNavigator: true,
          ).context;
          Navigator.pop(context);
          if (!await guard.confirmIfDirty(rootContext)) return;
          // Re-entering a branch last visited under a different company must
          // drop its preserved stack (see [BranchCompanyGate]).
          final staleCompanyStack = branchGate.shouldResetOnEnter(
            index: index,
            companyId: services.auth.session.value?.currentCompanyId ?? '',
          );
          nav.goBranch(
            index,
            initialLocation: staleCompanyStack || index == nav.currentIndex,
          );
        },
      ),
    );
  }
}

/// Convenience hamburger that opens the nearest `Scaffold`'s drawer.
/// Drop into an `AppBar.leading` on top-level mobile screens. Wraps a
/// `Builder` so `Scaffold.of(context)` finds the surrounding Scaffold
/// instead of looking above it.
class DrawerHamburger extends StatelessWidget {
  const DrawerHamburger({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => IconButton(
        icon: const Icon(Icons.menu),
        tooltip: context.tr('menu'),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );
  }
}
