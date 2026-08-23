import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_top_row.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// AppBar shown when the user isn't in multi-select.
///
/// Wide: title + search + filters + columns + "New X" all on one row
/// (rendered via `flexibleSpace` because `AppBar.title` lays out its child
/// with unbounded width first, which blows up `Expanded` inside our search
/// row). Narrow: hamburger + title + sort action, with the token search
/// field hanging below in `bottom`.
///
/// Generic over the [GenericListViewModel] — every entity list screen
/// shares the same chrome; only the per-entity title key, "new" route, sort
/// options, and search field differ.
class EntityListNormalAppBar<T> extends StatelessWidget
    implements PreferredSizeWidget {
  const EntityListNormalAppBar({
    super.key,
    required this.vm,
    required this.wide,
    required this.titleKey,
    required this.newRoute,
    required this.newLabelKey,
    required this.sortOptions,
    required this.searchField,
    this.extraActions = const [],
    this.showHamburger = true,
    this.settingsBackTarget,
    this.canCreate = true,
  });

  /// Per-entity AppBar actions rendered at the *trailing edge* of the row
  /// in both narrow (after Sort) and wide (after Saved Views). Used by the
  /// Tasks list to surface the list ↔ kanban toggle anchored to the right
  /// so it doesn't shift when the user navigates between sections that
  /// drop the standard chrome (e.g. switching to the kanban view).
  final List<Widget> extraActions;

  final GenericListViewModel<T> vm;
  final bool wide;

  /// Whether the narrow-mode AppBar leads with a [DrawerHamburger]. Pass
  /// `false` from screens whose host shell already shows a persistent nav
  /// (i.e. when the global `InSidebar` is visible at the current window
  /// width) — otherwise the hamburger opens a Drawer that just renders the
  /// same nav again.
  final bool showHamburger;

  /// Set on the entity lists that are **Settings destinations**
  /// (`/settings/company_gateways`, `/settings/payment_links`,
  /// `/settings/expense_categories`): the leading slot becomes a back arrow to
  /// the Settings menu instead of the hamburger, so they match every other
  /// settings page (issue #40). `null` on a normal entity list, which keeps
  /// today's hamburger. The value is where to `go()` when the route can't pop
  /// — Expense Categories is a sibling branch outside the settings shell, so a
  /// pop has nothing to land on.
  final String? settingsBackTarget;

  /// Localization key for the narrow-mode title (e.g. `clients`, `products`).
  final String titleKey;

  /// Route the wide-mode "New X" button navigates to (e.g. `/clients/new`).
  final String newRoute;

  /// Localization key for the wide-mode primary button label.
  final String newLabelKey;

  /// When false, the wide-mode "New X" button renders disabled. Used by
  /// plan-gated screens so a free-plan user cannot tap into the new-entity
  /// route.
  final bool canCreate;

  /// Options shown in the narrow-mode sort sheet.
  final List<SortOption> sortOptions;

  /// Feature-built token search field. Sized the same in both modes — the
  /// caller decides whether to pass a wide or narrow flavor.
  final Widget searchField;

  @override
  Size get preferredSize => wide
      ? const Size.fromHeight(64)
      : const Size.fromHeight(kToolbarHeight + 56);

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        flexibleSpace: SafeArea(
          bottom: false,
          // `symmetric(horizontal: 24, vertical: 12)` does two things at
          // once: the horizontal 24 aligns the Row's outer edges with the
          // table card below (also 24 px from the screen), and the
          // vertical 12 centers the 40 px Row inside the 64 px toolbar
          // (12 + 40 + 12 = 64) so the toggle / buttons get breathing
          // room above and below instead of hugging the AppBar's top
          // edge. No `Center` wrapper — the Row already fills the padded
          // width (mainAxisSize.max), and the symmetric vertical padding
          // is the centering.
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            child: EntityListTopRow<T>(
              vm: vm,
              newRoute: newRoute,
              newLabelKey: newLabelKey,
              searchField: searchField,
              extraActions: extraActions,
              canCreate: canCreate,
            ),
          ),
        ),
      );
    }
    return AppBar(
      // Hamburger on narrow only — wide has the persistent rail. Selection
      // mode swaps to a different AppBar (Cancel-X leading), so this only
      // shows when neither selecting nor wide. Suppressed via
      // [showHamburger] when the host shell already shows a persistent nav.
      // A Settings destination takes a back arrow in that slot instead — see
      // [settingsBackTarget]. Gateways and Payment Links are nested settings
      // routes and can pop (which is also what the system back gesture does);
      // Expense Categories is its own branch, so it navigates.
      leading: settingsBackTarget != null
          ? BackButton(
              onPressed: () => Navigator.of(context).canPop()
                  ? Navigator.of(context).pop()
                  : GoRouter.of(context).go(settingsBackTarget!),
            )
          : (showHamburger ? const DrawerHamburger() : null),
      automaticallyImplyLeading: false,
      title: Text(context.tr(titleKey)),
      actions: [
        // Visible entry into multi-select on mobile. On touch there's no
        // hover-reveal checkbox, so the only other way in is the
        // undiscoverable row long-press; this button makes selection obvious.
        // Hidden on an empty list (nothing to select). Tapping it enters
        // selection mode, swapping in the selection AppBar + row checkboxes.
        if (vm.items.isNotEmpty)
          IconButton(
            tooltip: context.tr('select'),
            icon: const Icon(Icons.checklist),
            onPressed: vm.enterSelectionMode,
          ),
        IconButton(
          tooltip: context.tr('sort'),
          icon: const Icon(Icons.sort),
          onPressed: () => _openSortSheet(context),
        ),
        ...extraActions,
      ],

      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        // The token search field carries every filter dimension; tapping it
        // opens the full-screen `FilterEntrySheet` for editing.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: searchField,
        ),
      ),
    );
  }

  Future<void> _openSortSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => EntitySortFilterSheet(
        initialField: vm.sortField,
        initialAscending: vm.sortAscending,
        options: sortOptions,
        onApply: ({required field, required ascending}) =>
            vm.setSort(field: field, ascending: ascending),
      ),
    );
  }
}

/// AppBar shown while the user is in multi-select. Cancel-X leading,
/// "N selected" title, select-all visible, plus the entity-supplied bulk
/// actions rendered through the *same* overflow surface the detail-screen
/// action row uses ([EntityOverflowActionBar] wide / [EntityActionsPopupButton]
/// narrow). Items carry their own enabled state — the scaffold gates them
/// off while `vm.bulkInFlight` and renders unwired ones as `coming_soon`
/// placeholders.
class EntityListSelectionAppBar<T> extends StatelessWidget
    implements PreferredSizeWidget {
  const EntityListSelectionAppBar({
    super.key,
    required this.vm,
    required this.wide,
    required this.items,
  });

  final GenericListViewModel<T> vm;
  final bool wide;
  final List<EntityActionItem<String>> items;

  // Match [EntityListNormalAppBar]'s height *exactly* so the body doesn't
  // jump when the user enters / exits multi-select. Wide is 64; narrow is
  // `kToolbarHeight + 56` because the normal narrow AppBar carries the
  // search field in a 56 px `bottom:` — we reserve the same 56 px here.
  @override
  Size get preferredSize => wide
      ? const Size.fromHeight(64)
      : const Size.fromHeight(kToolbarHeight + 56);

  @override
  Widget build(BuildContext context) {
    final closeButton = IconButton(
      icon: const Icon(Icons.close),
      tooltip: context.tr('cancel'),
      onPressed: vm.clearSelection,
    );
    final countText = Text(
      context.tr('count_selected', {'count': vm.countSelected.toString()}),
    );
    final selectAll = IconButton(
      icon: const Icon(Icons.checklist_outlined),
      tooltip: context.tr('select_all_visible'),
      onPressed: vm.selectAllVisible,
    );

    if (wide) {
      return AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        flexibleSpace: SafeArea(
          bottom: false,
          child: Padding(
            // Match EntityListNormalAppBar wide: horizontal 24 aligns with
            // the table card; vertical 12 centers the 40 px row in 64 px.
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
            child: Row(
              children: [
                closeButton,
                const SizedBox(width: 8),
                countText,
                const SizedBox(width: 8),
                selectAll,
                const SizedBox(width: 8),
                // Bulk actions have no primary Edit, so they keep the
                // spread-inline-then-collapse-into-"More" overflow bar — the
                // detail header now uses a dedicated Edit + ⋮ cluster instead.
                // Right-aligned within the Expanded, matching the old layout.
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: EntityOverflowActionBar<String>(items: items),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppBar(
      automaticallyImplyLeading: false,
      leading: closeButton,
      title: countText,
      actions: [
        selectAll,
        EntityActionsPopupButton<String>(items: items),
      ],
      bottom: const PreferredSize(
        // Reserve the same 56 px the normal AppBar's search field occupies
        // so the list body's top offset is identical in both modes.
        preferredSize: Size.fromHeight(56),
        child: SizedBox(height: 56),
      ),
    );
  }
}
