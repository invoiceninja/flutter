import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_top_row.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// The header of every entity list: the normal chrome (title / "New X" /
/// search / columns) and, while the user is in multi-select, the selection
/// chrome (Cancel-X, "N selected", bulk actions).
///
/// Wide: "New X" + search + columns + views all on one row, in the band the
/// sidebar's company row lines up with. Narrow: hamburger + title + sort
/// action, with the token search field in a row below.
///
/// **It grows.** The search field wraps its filter chips, and this header is
/// as tall as that needs — `InSizes.headerBand` is its floor, not its height.
/// It used to be a Material `AppBar` with a fixed `toolbarHeight`, which gave
/// the search row 45 px however many chips it held: a second line of chips
/// was laid out anyway, painted outside the box over the first rows of the
/// table, and — being outside the bar's bounds — could not be clicked. On a
/// touch platform a single chip (50 px with its padded ✕) already spilled.
///
/// The mechanism is that `Scaffold` treats [preferredSize] as a **ceiling**:
/// it wraps the bar in `ConstrainedBox(maxHeight:)` and places the body under
/// whatever height the bar actually took, in the same layout pass. Material's
/// `AppBar` only ever looked fixed because it expands to fill that ceiling.
/// So this widget shrink-wraps, and [maxExtent] is how tall it MAY get. No
/// measuring, no state, no frame of lag.
///
/// **Both modes are one widget, and both stay mounted** (an `IndexedStack`,
/// which sizes to the taller of its children). That is what keeps the list
/// from moving when the user ticks a row: the selection chrome is exactly as
/// tall as the normal chrome it covers, wrapped chips included, by
/// construction rather than by two classes agreeing on a number. It also keeps
/// the search field's state alive across a selection; the hidden half is
/// excluded from focus, pointers and semantics.
///
/// Generic over the [GenericListViewModel] — every entity list screen
/// shares the same chrome; only the per-entity title key, "new" route, sort
/// options, and search field differ.
class EntityListAppBar<T> extends StatelessWidget
    implements PreferredSizeWidget {
  const EntityListAppBar({
    super.key,
    required this.vm,
    required this.wide,
    required this.selecting,
    required this.maxExtent,
    required this.titleKey,
    required this.newRoute,
    required this.newLabelKey,
    required this.sortOptions,
    this.groupOptions = const [],
    required this.searchField,
    this.selectionItems = const [],
    this.extraActions = const [],
    this.showHamburger = true,
    this.settingsBackTarget,
    this.canCreate = true,
  });

  /// The height the header takes with nothing wrapped — and never less.
  static double minExtentFor({required bool wide}) =>
      wide ? InSizes.headerBand : kToolbarHeight + kNarrowSearchRowHeight;

  /// The ceiling to pass as [maxExtent]: under half of the [available] height,
  /// so a pile of filters on a short window cannot push the list off screen.
  /// Past it the search field scrolls its chips instead of growing.
  static double maxExtentFor({required bool wide, required double available}) {
    final floor = minExtentFor(wide: wide);
    if (!available.isFinite) return floor * 3;
    return math.max(floor, available * 0.45);
  }

  /// The narrow layout's search row: 48 px of field above 8 px of padding.
  static const double kNarrowSearchRowHeight = 56;

  /// Per-entity actions rendered at the *trailing edge* of the row
  /// in both narrow (after Sort) and wide (after Saved Views). Used by the
  /// Tasks list to surface the list ↔ kanban toggle anchored to the right
  /// so it doesn't shift when the user navigates between sections that
  /// drop the standard chrome (e.g. switching to the kanban view).
  final List<Widget> extraActions;

  final GenericListViewModel<T> vm;
  final bool wide;

  /// Whether the list is in multi-select — which half of the header shows.
  final bool selecting;

  /// The most this header may grow to, excluding the status-bar inset. See
  /// [maxExtentFor].
  final double maxExtent;

  /// The bulk actions of the selection chrome. Only read while [selecting].
  final List<EntityActionItem<String>> selectionItems;

  /// Whether the narrow-mode header leads with a [DrawerHamburger]. Pass
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

  /// Grouping dimensions offered inside the narrow sort sheet. Empty hides
  /// the section; wide screens use the entity's own `extraAppBarActions`
  /// control instead (this sheet is mobile-only — desktop sorts by clicking
  /// column headers).
  final List<GroupOption> groupOptions;

  /// Feature-built token search field. Sized the same in both modes — the
  /// caller decides whether to pass a wide or narrow flavor.
  final Widget searchField;

  // `preferredSize` is load-bearing, and it is a CEILING: `Scaffold` clamps
  // the app bar to `AppBar.preferredHeightFor(context, appBar.preferredSize)`
  // — for a custom PreferredSizeWidget this value verbatim — and lays the
  // body out under the height the bar actually reports. Hand it the floor
  // (`InSizes.headerBand`) and a wrapped search field is clamped right back to
  // one row, which is the bug this widget replaced.
  @override
  Size get preferredSize => Size.fromHeight(maxExtent);

  @override
  Widget build(BuildContext context) =>
      wide ? _buildWide(context) : _buildNarrow(context);

  // ── Wide ─────────────────────────────────────────────────────────────

  Widget _buildWide(BuildContext context) {
    return _HeaderSurface(
      // The shared header band, so this lines up with the sidebar's company
      // row across the seam — see InSizes.headerBand. A floor: the row below
      // grows past it when the search field wraps.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: InSizes.headerBand),
        // The horizontal 24 aligns the row's outer edges with the table
        // card below (also 24 px from the screen) — and, on the frameless
        // desktop runners, is what the title bar's nav arrows align to.
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          child: IndexedStack(
            index: selecting ? 1 : 0,
            alignment: AlignmentDirectional.topStart,
            children: [
              EntityListTopRow<T>(
                vm: vm,
                newRoute: newRoute,
                newLabelKey: newLabelKey,
                searchField: searchField,
                extraActions: extraActions,
                canCreate: canCreate,
              ),
              _wideSelectionRow(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wideSelectionRow(BuildContext context) {
    // One first-row slot tall, like every sibling of the search field: its
    // 48-px touch buttons must not be what sets the header's height.
    return HeaderRowSlot(
      expand: true,
      child: Row(
        children: [
          _closeButton(context),
          const SizedBox(width: 8),
          _countText(context),
          const SizedBox(width: 8),
          _selectAllButton(context),
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
                child: EntityOverflowActionBar<String>(items: selectionItems),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow ───────────────────────────────────────────────────────────

  Widget _buildNarrow(BuildContext context) {
    final appBarTheme = AppBarTheme.of(context);
    return Material(
      color:
          appBarTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Two real `AppBar`s, which shrink-wrap to their toolbar under the
          // Column's unbounded height (and each pads the status bar itself).
          IndexedStack(
            index: selecting ? 1 : 0,
            children: [
              _narrowToolbar(context),
              _narrowSelectionToolbar(context),
            ],
          ),
          // The token search field carries every filter dimension. It is
          // hidden — not removed — while selecting, so the row keeps its
          // height (whatever that currently is) and the list body's top
          // offset is identical in both modes.
          //
          // `Flexible`, or the row is a non-flex child of this Column and is
          // laid out with UNBOUNDED height: the inline field (a 600–840 px
          // window gets it under this bar) then never meets the header's
          // ceiling, never scrolls its chips, and overflows the bar onto the
          // list — the bug the growing header exists to remove. And an
          // `Align(heightFactor: 1)` rather than a `Container(alignment:)`,
          // which under a bounded height expands to fill it: every narrow
          // header would sit at its ceiling.
          Flexible(
            child: Visibility(
              visible: !selecting,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kNarrowSearchRowHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 1,
                    child: searchField,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrowToolbar(BuildContext context) {
    return AppBar(
      // Hamburger on narrow only — wide has the persistent rail. Selection
      // mode swaps to a different toolbar (Cancel-X leading), so this only
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
        // selection mode, swapping in the selection toolbar + row checkboxes.
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
    );
  }

  Widget _narrowSelectionToolbar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: _closeButton(context),
      title: _countText(context),
      actions: [
        _selectAllButton(context),
        EntityActionsPopupButton<String>(items: selectionItems),
      ],
    );
  }

  // ── Selection pieces ─────────────────────────────────────────────────

  Widget _closeButton(BuildContext context) => IconButton(
    icon: const Icon(Icons.close),
    tooltip: context.tr('cancel'),
    onPressed: vm.clearSelection,
  );

  Widget _countText(BuildContext context) => Text(
    context.tr('count_selected', {'count': vm.countSelected.toString()}),
  );

  Widget _selectAllButton(BuildContext context) => IconButton(
    icon: const Icon(Icons.checklist_outlined),
    tooltip: context.tr('select_all_visible'),
    onPressed: vm.selectAllVisible,
  );

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
        groupOptions: groupOptions,
        initialGroup: vm.groupField,
        onApplyGroup: vm.setGroupField,
      ),
    );
  }
}

/// What Material's `AppBar` supplied around the wide header's row, now that
/// the row is not inside one: the app-bar surface colour, the status-bar
/// inset, the system-overlay style that follows the surface's brightness, and
/// the semantics container.
class _HeaderSurface extends StatelessWidget {
  const _HeaderSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        AppBarTheme.of(context).backgroundColor ?? theme.colorScheme.surface;
    // The same derivation `AppBar` makes: icons that contrast with the
    // surface, over a transparent status bar.
    final base =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: base.statusBarBrightness,
      statusBarIconBrightness: base.statusBarIconBrightness,
      systemStatusBarContrastEnforced: base.systemStatusBarContrastEnforced,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Material(
          color: background,
          child: SafeArea(bottom: false, child: child),
        ),
      ),
    );
  }
}
