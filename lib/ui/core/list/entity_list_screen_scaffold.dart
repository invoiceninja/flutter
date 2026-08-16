import 'dart:math' as math;

import 'package:admin/app/router.dart'
    show
        entityRecordPath,
        goEntityRecord,
        highlightSelectedIdFromRoute,
        selectedIdFromRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/permissions.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/list/entity_bulk_message.dart';
import 'package:admin/ui/core/list/embedded_list_scope.dart';
import 'package:admin/ui/core/list/entity_list_result_scope.dart';
import 'package:admin/ui/core/list/entity_list_app_bar.dart';
import 'package:admin/ui/core/list/entity_list_top_row.dart';
import 'package:admin/ui/core/list/entity_list_column_headers.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/entity_list_footer.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart'
    show MasterDetailNavScope, goToCreateRoute;
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/widgets/confirm_password_sheet.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/utils/formatting.dart';

// ─── Callbacks ───────────────────────────────────────────────────────────

/// Builds the concrete [GenericListViewModel] for an entity list screen.
/// Called from `initState` and from the company-switch listener.
typedef EntityVmBuilder<T, VM extends GenericListViewModel<T>> =
    VM Function(Services services, String companyId);

/// Renders one row in the list. Pulled out as a builder (rather than a
/// `Widget`) so the scaffold can supply per-row state — wide/narrow,
/// whether this row is the last, and the resolved currency formatter (null
/// when [EntityListScreenScaffold.wantsFormatter] is false).
typedef EntityTileBuilder<T, VM extends GenericListViewModel<T>> =
    Widget Function(
      BuildContext context,
      VM vm,
      T item,
      int index,
      EntityListTileOptions options,
    );

/// Builds the per-entity token search field. Lives outside the scaffold
/// because every entity has a different `FilterKey` set.
typedef EntitySearchFieldBuilder<VM> =
    Widget Function(BuildContext context, VM vm, bool wide);

/// Builds the localized list of sort options. Called every build so locale
/// changes take effect without a hot reload.
typedef EntitySortOptionsBuilder =
    List<SortOption> Function(BuildContext context);

/// Overrides the default "no rows" widget. Use this when an entity has
/// filter-aware empty copy ("no clients match these filters" vs "no clients
/// yet"); most entities can rely on the default ([EmptyState] with the
/// supplied icon + title key).
typedef EntityEmptyStateBuilder<VM> =
    Widget Function(BuildContext context, VM vm);

/// Overrides the default wide-mode column header strip. Defaults to
/// [EntityListColumnHeaders<T>]; supply only when the entity needs a custom
/// header row (e.g. typedef'd wrapper like `ClientListColumnHeaders`).
typedef EntityWideColumnHeadersBuilder<VM> =
    Widget Function(BuildContext context, VM vm);

/// Builds entity-specific AppBar trailing actions (e.g. the Tasks list
/// view's list/kanban segmented button). The scaffold passes the resolved
/// `wide` flag so callers can render a SegmentedButton on wide and a
/// compact IconButton on narrow.
typedef EntityExtraAppBarActionsBuilder<VM> =
    List<Widget> Function(BuildContext context, VM vm, bool wide);

// ─── Config records ──────────────────────────────────────────────────────

/// Per-row state supplied to the [EntityTileBuilder] every build.
@immutable
class EntityListTileOptions {
  const EntityListTileOptions({
    required this.wide,
    required this.isLast,
    required this.selecting,
    required this.formatter,
    this.editable = true,
    this.selectedId,
    this.bottomDividerHidden = false,
  });

  final bool wide;

  /// `false` when the row is archived or soft-deleted — editing it makes
  /// little sense, so the wide-table standalone edit pencil renders disabled.
  /// Computed once by the scaffold from the VM's `isArchived` / `isDeleted`
  /// so per-entity tiles don't each re-derive the lifecycle predicate.
  final bool editable;

  /// True for the row at index `items.length - 1`. The tile uses this to
  /// suppress its bottom border so the table doesn't double-line.
  final bool isLast;

  /// True when the screen is in multi-select mode. Convenience flag so the
  /// tile doesn't have to call `vm.isInMultiselect` itself.
  final bool selecting;

  /// Resolved currency formatter, or null when the scaffold wasn't asked
  /// to load one (`wantsFormatter: false`) or while the future is in
  /// flight. Tiles that render money use this; tiles that don't can ignore.
  final Formatter? formatter;

  /// The URL-derived `:id` of the currently-selected row in master-detail
  /// mode, or null when the bare list URL is active. Per-entity tile
  /// widgets compare their own id to this string to render the
  /// selection styling (background + accent stripe). Always null on
  /// narrow viewports / single-pane navigation.
  final String? selectedId;

  /// True when this row should NOT draw its bottom hairline: it's the last
  /// row, it's the URL-selected row, or it's the row directly above the
  /// URL-selected one. Suppressing the neighbour's divider too is what keeps
  /// the selected-row highlight chip from being clipped by a stray line — a
  /// tile can't derive this alone (it can't see its neighbour's selection
  /// state), so the scaffold computes it. `SelectableListRow` consumes it.
  final bool bottomDividerHidden;
}

/// One bulk action surfaced in the selection-mode AppBar overflow cluster.
///
/// Standard path: the scaffold looks up the matching [BulkAction] on the VM
/// by [actionId], invokes `applyBulkAction(...)`, and renders the localized
/// result via [formatBulkMessage].
///
/// Opt-in hook: [prepare] — a one-shot dialog run *once* before the per-id
/// loop (email compose sheet, group picker, template picker). Returns the
/// value to thread into the matching `BulkAction.applyArg`; returning `null`
/// cancels the whole action (selection untouched, no toast).
@immutable
class EntityListBulkAction {
  const EntityListBulkAction({
    required this.actionId,
    required this.icon,
    required this.tooltipKey,
    required this.singleSuccessKey,
    required this.pluralSuccessKey,
    required this.nothingKey,
    this.prepare,
    this.onSelection,
  });

  /// Must match a `BulkAction.id` registered on `vm.bulkActions`. Stable
  /// across locales (`archive`, `restore`, `delete`, …).
  final String actionId;

  final IconData icon;

  /// Locale key for the overflow button / menu label.
  ///
  /// Must resolve to a **placeholder-free** string — this surface renders it
  /// with no substitutions. Where the obvious key carries a `:token` the bulk
  /// bar can't fill, point at a key that doesn't (`action_add_to_invoice`
  /// rather than `add_to_invoice`, `download_documents_label` rather than
  /// `download_documents`); `no_unsubstituted_placeholders_test` fails the
  /// build otherwise.
  final String tooltipKey;

  /// One-shot prep dialog run before the per-id loop. `null` value cancels.
  final Future<Object?> Function(BuildContext context)? prepare;

  /// Locale key shown when exactly one row was affected (e.g. `archived_client`).
  final String singleSuccessKey;

  /// Locale key shown when more than one row was affected. The string
  /// should accept either `:count` or `:value` — the scaffold substitutes
  /// both so different locales can pick their preferred placeholder.
  final String pluralSuccessKey;

  /// Locale key shown when no eligible rows were affected (`nothing_to_archive`).
  final String nothingKey;

  /// Selection-level handler — receives the whole eligible selection at once
  /// instead of the per-id loop. For aggregate / navigating / download actions
  /// that don't fit a per-id mutation (e.g. "Invoice Project(s)" → one
  /// pre-filled invoice; "Download Documents"). When set, the scaffold calls
  /// this and skips the per-id `apply` path; the matching `BulkAction` still
  /// supplies `eligible` (so the empty-selection guard works) and may use a
  /// no-op `apply`. Items arrive as `List<Object?>` (covariant) — cast to the
  /// entity type in the handler.
  final Future<void> Function(BuildContext context, List<Object?> selected)?
  onSelection;
}

// ─── Scaffold ────────────────────────────────────────────────────────────

/// Generic list-screen chrome. Owns every piece of boilerplate that's the
/// same across entity list screens — VM lifecycle, scroll controllers,
/// company-switch tracking, Scaffold + AppBar + FAB + drawer, body
/// switching (error / loading / empty / wide table / narrow list),
/// bulk-action dispatch, and transient notice rendering.
///
/// The concrete list screen becomes a `StatelessWidget` that constructs
/// one of these with entity-specific config + callbacks. See
/// `client_list_screen.dart` and `product_list_screen.dart` for the two
/// reference invocations.
class EntityListScreenScaffold<T, VM extends GenericListViewModel<T>>
    extends StatefulWidget {
  const EntityListScreenScaffold({
    super.key,
    required this.titleKey,
    required this.newRoute,
    required this.newLabelKey,
    required this.buildVm,
    required this.sortOptions,
    required this.searchFieldBuilder,
    required this.tileBuilder,
    required this.bulkActions,
    this.emptyIcon,
    this.emptyTitleKey,
    this.emptyStateBuilder,
    this.wideColumnHeadersBuilder,
    this.extraAppBarActions,
    this.wantsFormatter = true,
    this.embedded = false,
    this.headerBanner,
    this.canCreate = true,
    this.embeddedNewOverride,
    this.selectionShortcuts,
  });

  /// Localization key for the narrow-mode AppBar title (e.g. `clients`).
  final String titleKey;

  /// Route the wide-mode "New X" button + narrow-mode FAB navigate to
  /// (e.g. `/clients/new`).
  final String newRoute;

  /// Localization key for the "New X" button + FAB tooltip
  /// (e.g. `new_client`).
  final String newLabelKey;

  /// Embedded-only: overrides what the slim toolbar's "New X" button does.
  /// Set by a parent-scoped list screen (e.g. a client's Invoices tab) to
  /// open the create form with the parent pre-filled —
  /// `(ctx) => ctx.go('/invoices/new', extra: emptyInvoice().copyWith(...))`.
  /// When null the button falls back to `context.go(newRoute)`.
  final void Function(BuildContext context)? embeddedNewOverride;

  /// Optional extra single-key shortcuts that act on the URL-selected row.
  /// Each activator's callback receives the resolved selected item (or null
  /// when no row is selected). Guarded like `keyN` — suppressed while a text
  /// input is focused so the key still types. Tasks binds `S` here to
  /// start/stop the selected task's timer.
  final Map<ShortcutActivator, void Function(BuildContext, T?)>?
  selectionShortcuts;

  /// Constructs the VM. Called from `initState` with the resolved
  /// `Services` and the session's `currentCompanyId`; re-called on company
  /// switch.
  final EntityVmBuilder<T, VM> buildVm;

  /// Sort options shown in the narrow-mode sort sheet.
  final EntitySortOptionsBuilder sortOptions;

  /// Builds the entity-specific token search field.
  final EntitySearchFieldBuilder<VM> searchFieldBuilder;

  /// Builds each row. The scaffold supplies per-row state via
  /// [EntityListTileOptions].
  final EntityTileBuilder<T, VM> tileBuilder;

  /// Bulk actions exposed in the multi-select AppBar. Each entry maps a
  /// `BulkAction.id` on the VM to a button + locale keys.
  final List<EntityListBulkAction> bulkActions;

  /// Icon for the default `EmptyState`. Ignored when [emptyStateBuilder]
  /// is supplied.
  final IconData? emptyIcon;

  /// Localization key for the default `EmptyState` title. Ignored when
  /// [emptyStateBuilder] is supplied.
  final String? emptyTitleKey;

  /// Custom empty-state widget. Use this when the empty state needs to
  /// differ between "no rows at all" and "no rows match the active
  /// filters" — see `ClientListEmptyState` for the reference.
  final EntityEmptyStateBuilder<VM>? emptyStateBuilder;

  /// Custom wide-mode column header strip. Defaults to
  /// `EntityListColumnHeaders<T>(vm: vm)`; override only when the entity
  /// has a typedef'd wrapper.
  final EntityWideColumnHeadersBuilder<VM>? wideColumnHeadersBuilder;

  /// Optional entity-specific AppBar trailing actions. Threaded into both
  /// the wide-mode top row (between search + columns picker) and the
  /// narrow-mode actions list. Used by the Tasks list to surface the
  /// list ↔ kanban toggle; future entities can use the same hook (e.g.
  /// Invoice's table vs cards toggle).
  final EntityExtraAppBarActionsBuilder<VM>? extraAppBarActions;

  /// When `true` (the default), the scaffold wires `FormatterHostMixin`,
  /// provides a `FormatterScope` over the table, and supplies the resolved
  /// [Formatter] to [tileBuilder] via [EntityListTileOptions]. ON by
  /// default: `cellDate`/`cellMoney` silently fall back to locale formats
  /// without it (ignoring `date_format_id` / `use_comma_as_decimal_place`),
  /// and that opt-in trap had to be re-fixed on four screens — every list
  /// screen in the app wants it. The lookup is one cached future per
  /// company; opt out only for a list that truly renders no dates/money.
  final bool wantsFormatter;

  /// When `true`, the scaffold returns only its body — no outer
  /// `Scaffold`, no `AppBar`, no `FloatingActionButton`, no `Drawer`.
  /// Use when the list is embedded inside another screen (e.g. the
  /// recent-transactions section on `BankAccountDetailScreen`) so the
  /// parent's chrome isn't duplicated.
  final bool embedded;

  /// Optional full-width widget rendered above the list body (below the
  /// AppBar). Used by plan-gated settings list screens (payment_links,
  /// transaction_rules, user_management) to render a `PlanGateBanner`.
  final Widget? headerBanner;

  /// When `false`, the wide-mode "New X" inline button and the narrow-mode
  /// FAB are hidden / inert. Used by plan-gated screens so a free-plan user
  /// can still browse existing rows but cannot start a new one.
  final bool canCreate;

  @override
  State<EntityListScreenScaffold<T, VM>> createState() =>
      _EntityListScreenScaffoldState<T, VM>();
}

class _EntityListScreenScaffoldState<T, VM extends GenericListViewModel<T>>
    extends State<EntityListScreenScaffold<T, VM>>
    with FormatterHostMixin {
  late VM _vm;
  late final Services _services;
  late String _companyId;

  /// Vertical scroll. Triggers `loadMore()` when the viewport is within
  /// [_loadMoreThresholdPx] of the bottom — the next page is in flight
  /// before the user hits the spinner.
  final ScrollController _vScroll = ScrollController();

  /// Horizontal scroll for the wide-mode bordered card. Shared by the
  /// column header strip and the rows so they pan in lock-step.
  final ScrollController _hScroll = ScrollController();

  static const double _loadMoreThresholdPx = 600;

  /// One-shot guard for the load-more trigger. The scroll listener fires
  /// every frame; without this it would call `loadMore()` on every frame
  /// the user lingers inside the threshold band. We disarm on trigger and
  /// only re-arm once the position climbs back out of the band.
  bool _loadMoreArmed = true;

  /// In embedded mode the list shrink-wraps into the detail page's scroll,
  /// so pagination is driven off the *page* controller (published via
  /// [DetailScrollScope]) instead of `_vScroll`. Captured in
  /// `didChangeDependencies`; not owned here (the detail scaffold disposes
  /// it), so we only add/remove our listener.
  ScrollController? _outerScroll;

  /// Whether this embedded list is the visible tab. Several tabs stay
  /// mounted (alive for state), but only the active one should consume the
  /// shared page-scroll "load next page" signal. Tracked from
  /// `TickerMode.of` during build (the detail tab strip disables the ticker
  /// for off-screen tabs).
  bool _tickerActive = true;

  /// One-shot: after the first embedded build, prime pagination once so a
  /// list shorter than the page still loads page 2 (the page may already be
  /// at/near its end, so no scroll event would ever fire).
  bool _embeddedPrimed = false;

  /// Last URL-derived selected id we observed during a build, used to
  /// detect selection changes for the auto-scroll-to-selected behavior
  /// (slide-over UX) — animating the list whenever a row enters/exits the
  /// pane keeps the active row in view as the user presses J/K.
  String? _lastSelectedId;
  bool _lastSelectedSeen = true;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    // A null session here means the router failed its redirect — but the
    // screen is built lazily, so by the time we reach here the session
    // value is always set.
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = widget.buildVm(_services, _companyId);
    // A completed Sync re-arms the VM's pagination — see
    // `GenericListViewModel.bindResync`.
    _vm.bindResync(_services.resync);
    // Embedded lists don't scroll themselves (they grow with the detail
    // page); their pagination is wired to the page controller in
    // didChangeDependencies instead.
    if (!widget.embedded) _vScroll.addListener(_onScroll);
    _services.auth.session.addListener(_onSessionChanged);
    if (widget.wantsFormatter) loadFormatter(_services, _companyId);
  }

  /// Rebuild the VM when the user switches workspaces. The screen survives
  /// a company switch because every entity branch's `Navigator` has a
  /// `GlobalKey` in `router.dart`, which preserves `State` across the
  /// rebuild — so the scaffold has to track `auth.session` itself.
  void _onSessionChanged() {
    final s = _services.auth.session.value;
    if (s == null || s.currentCompanyId == _companyId) return;
    final oldVm = _vm;
    setState(() {
      _companyId = s.currentCompanyId;
      _vm = widget.buildVm(_services, _companyId);
      _vm.bindResync(_services.resync);
    });
    // Dispose AFTER swapping in the new VM so any in-flight rebuild keyed
    // on the old `_vm` reference has already moved on.
    oldVm.dispose();
    if (widget.wantsFormatter) {
      // Drop the previous company's formatter so money renders as `—`
      // while the new one resolves — otherwise the wrong currency briefly
      // shows.
      clearFormatter();
      loadFormatter(_services, _companyId);
    }
  }

  /// Animate-scroll the list so row [index] is on-screen. Approximates
  /// row height (the scaffold doesn't know the per-tile size — values
  /// vary by entity), so the result lands the row roughly in the upper
  /// third of the viewport rather than perfectly centered.
  void _ensureRowVisible(int index) {
    if (!_vScroll.hasClients) return;
    const estimatedRowPx = kEntityListRowHeight;
    final pos = _vScroll.position;
    final target = (index * estimatedRowPx).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    final viewportTop = pos.pixels;
    final viewportBottom = viewportTop + pos.viewportDimension;
    if (target >= viewportTop && target + estimatedRowPx <= viewportBottom) {
      return; // Already on screen — don't snap-scroll for no reason.
    }
    _vScroll.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.embedded) return;
    final outer = DetailScrollScope.maybeOf(context);
    if (identical(outer, _outerScroll)) return;
    _outerScroll?.removeListener(_onOuterScroll);
    _outerScroll = outer;
    _outerScroll?.addListener(_onOuterScroll);
  }

  /// Shared near-bottom load-more logic, parameterised on the controller so
  /// standalone (`_vScroll`) and embedded (page `_outerScroll`) reuse it.
  void _checkLoadMore(ScrollController c) {
    if (!c.hasClients) return;
    final inBand =
        c.position.pixels >= c.position.maxScrollExtent - _loadMoreThresholdPx;
    if (inBand) {
      // Consume the latch only when the VM will actually do something.
      // Disarming on a call that immediately no-ops used to strand a user
      // parked at the bottom of an exhausted list: the latch re-arms only on
      // the way back OUT of the band, so once more rows became reachable
      // (a Sync landing rows behind an active filter — flutter#32) no further
      // trigger ever fired. Now any later scroll re-evaluates.
      if (_loadMoreArmed && _vm.canLoadMore) {
        _loadMoreArmed = false;
        _vm.loadMore();
      }
    } else {
      // Out of the band again (user scrolled up, or the freshly loaded
      // page pushed maxScrollExtent down) — re-arm for the next crossing.
      _loadMoreArmed = true;
    }
  }

  void _onScroll() => _checkLoadMore(_vScroll);

  /// Page-scroll listener for embedded lists. Only the visible tab reacts —
  /// other mounted-but-offstage embedded lists must not all fire `loadMore`
  /// off the one shared page controller.
  void _onOuterScroll() {
    if (!_tickerActive) return;
    final c = _outerScroll;
    if (c != null) _checkLoadMore(c);
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSessionChanged);
    _vScroll.removeListener(_onScroll);
    _vScroll.dispose();
    // _outerScroll is owned by EntityDetailScaffold — detach only.
    _outerScroll?.removeListener(_onOuterScroll);
    _hScroll.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Whether the current user is allowed to fire [actionId] on this
  /// entity's selection. Mirrors the per-action permission gate the entity
  /// detail/action surfaces use (`me.can('edit_invoice')` etc.): admin /
  /// owner bypass, otherwise the comma-separated `permissions` string.
  ///
  /// Only the 14 entities the server models in [kPermissionEntities] carry
  /// `<verb>_<entity>` tokens; for everything else (settings-area entities
  /// with no permission tokens) this fails open and lets the server be the
  /// authority — matching how those screens already behave. `archive` /
  /// `restore` and every entity-specific action (`email`, `mark_sent`,
  /// `convert_to_invoice`, …) are edits → `edit_<entity>`, and so is `delete`:
  /// there is no `delete_*` permission in the product, and the server
  /// authorizes a destroy through `EntityPolicy::edit`. ([AuthCompany.can]
  /// resolves a `delete_<entity>` probe the same way, so either spelling
  /// works — this asks the question directly.)
  bool _bulkActionAllowed(String actionId) {
    final wire = _services.entityRegistry[_vm.entityType]?.wireName;
    if (wire == null || !kPermissionEntities.contains(wire)) return true;
    final me = _services.auth.session.value?.currentCompany;
    if (me == null) return true; // server still enforces
    return me.can('edit_$wire');
  }

  /// Maps the entity's [EntityListBulkAction] descriptors onto the shared
  /// overflow `EntityActionItem` surface (`A == String` actionId). Actions
  /// the user lacks permission for are dropped entirely; the rest are gated
  /// off (without a misleading "coming soon" tooltip) while a bulk op is in
  /// flight.
  List<EntityActionItem<String>> _bulkActionItems(BuildContext context) => [
    for (final a in widget.bulkActions)
      if (_bulkActionAllowed(a.actionId))
        EntityActionItem<String>(
          kind: a.actionId,
          icon: a.icon,
          label: context.tr(a.tooltipKey),
          enabled: !_vm.bulkInFlight,
          // In-flight is a transient busy state, not an unimplemented
          // action — suppress the `coming_soon` tooltip.
          disabledTooltipKey: null,
          onTap: () => _onBulk(a),
        ),
  ];

  Future<void> _onBulk(EntityListBulkAction action) async {
    if (_vm.bulkInFlight) return;

    final bulk = _vm.bulkActionById(action.actionId);
    if (bulk == null) return;

    // Nothing in the selection is actionable — say so up front instead of
    // walking the user through a compose/picker dialog only to no-op after.
    if (_vm.countEligibleSelected(bulk) == 0) {
      Notify.info(context, context.tr(action.nothingKey));
      return;
    }

    // Selection-level action (aggregate / navigate / download): hand the whole
    // eligible selection to the screen's handler and skip the per-id loop.
    // `runSelectionAction` raises `bulkInFlight` for the duration so the bulk
    // buttons disable and a second tap can't re-fire a slow request (e.g. the
    // synchronous bulk-print merge).
    if (action.onSelection != null) {
      final selected = _vm.selectedItems.where(bulk.eligible).toList();
      await _vm.runSelectionAction(
        () => action.onSelection!(context, selected),
      );
      // Exit multiselect (React parity, `setSelected([])`) and close the
      // double-tap window — the handler ran once on this selection.
      if (mounted) _vm.clearSelection();
      return;
    }

    // Destructive ops need `X-API-PASSWORD-BASE64`. Prime the password
    // cache up front so the outbox drain doesn't park every row on the 412
    // path. Cancelling leaves the selection intact and fires nothing.
    if (bulk.requiresPassword) {
      final ok = await showConfirmPasswordSheet(
        context,
        cache: _services.passwordCache,
      );
      if (!mounted || !ok) return;
    }

    // One-shot prep dialog (email compose / group picker / template picker).
    // A null result means the user cancelled — leave the selection intact and
    // fire nothing.
    Object? prepared;
    if (action.prepare != null) {
      prepared = await action.prepare!(context);
      if (!mounted || prepared == null) return;
    }

    // Capture the eligible ids before applying — `applyBulkAction` clears the
    // selection, and a possible Undo needs them.
    final affectedIds = _vm.selectedItems
        .where(bulk.eligible)
        .map(_vm.idOf)
        .toList();

    final result = await _vm.applyBulkAction(bulk, arg: prepared);
    if (!mounted) return;

    // Offer Undo for reversible bulk verbs (archive / delete) when the entity
    // exposes a `restore` bulk action — restore nets the archive/delete out in
    // the FIFO outbox. Best-effort: a failed restore is swallowed (the watch
    // stream is the source of truth); the rows reappearing is the feedback.
    NotifyAction? undo;
    if (result.ok > 0 &&
        (bulk.id == 'archive' || bulk.id == 'delete') &&
        affectedIds.isNotEmpty) {
      final restoreApply = _vm.bulkActionById('restore')?.apply;
      if (restoreApply != null) {
        undo = NotifyAction(context.tr('undo'), () async {
          for (final id in affectedIds) {
            try {
              await restoreApply(id);
            } catch (_) {
              // Best-effort — keep restoring the rest.
            }
          }
        });
      }
    }

    Notify.success(
      context,
      formatBulkMessage(
        context,
        singleKey: action.singleSuccessKey,
        pluralKey: action.pluralSuccessKey,
        nothingKey: action.nothingKey,
        result: result,
      ),
      action: undo,
    );
  }

  /// Consume a dashboard deep-link [ListFilterIntent] carried via GoRouter
  /// `extra`. Read on every build so it fires on cold start, on a warm
  /// cross-branch jump, and when the list is already mounted in the
  /// master-detail shell (same-route navigation reuses this State). The
  /// VM's per-token guard makes repeat reads of the same intent a no-op.
  void _maybeApplyListIntent(BuildContext context) {
    Object? extra;
    try {
      extra = GoRouterState.of(context).extra;
    } catch (_) {
      // No GoRouterState above us (e.g. a widget test pumping the scaffold
      // without a router). Nothing to consume.
      return;
    }
    if (extra is! ListFilterIntent) return;
    if (extra.token == _vm.lastConsumedIntentToken) return;
    // applyDeepLinkIntent reloads + notifies; defer past this build so we
    // don't re-enter the ListenableBuilder synchronously.
    final intent = extra;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vm.applyDeepLinkIntent(intent);
    });
  }

  /// Wrap the search field in an [EntityListResultScope] so the narrow
  /// `FilterEntrySheet` it opens can render live matching results as the real
  /// per-entity tiles and open a tapped record. The closures capture this
  /// scaffold's tile builder + VM + formatter + navigation, none of which the
  /// pushed sheet route can reach through the element tree.
  Widget _withResultScope(Widget searchField) {
    return EntityListResultScope(
      resultTile: (ctx, item, index) => widget.tileBuilder(
        ctx,
        _vm,
        item as T,
        index,
        EntityListTileOptions(
          wide: false,
          isLast: true,
          selecting: false,
          formatter: widget.wantsFormatter ? formatter : null,
        ),
      ),
      // Pop happens in the sheet before this fires; navigate from the
      // scaffold's (still-mounted) context — goEntityRecord needs Services +
      // GoRouter from above the popped route.
      onOpenRecord: (id) => goEntityRecord(context, _vm.entityType, id),
      child: searchField,
    );
  }

  @override
  Widget build(BuildContext context) {
    _maybeApplyListIntent(context);
    final selectionShortcuts = widget.selectionShortcuts;
    assert(
      selectionShortcuts == null ||
          !selectionShortcuts.keys.any(
            (a) =>
                a == const SingleActivator(LogicalKeyboardKey.keyN) ||
                a == const SingleActivator(LogicalKeyboardKey.arrowDown) ||
                a == const SingleActivator(LogicalKeyboardKey.arrowUp),
          ),
      'selectionShortcuts must not reuse the built-in keyN / arrow '
      'activators — a duplicate map key would silently override them.',
    );
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN):
            const _NewRecordIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _NextRowIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _PrevRowIntent(),
        if (selectionShortcuts != null)
          for (final activator in selectionShortcuts.keys)
            activator: _CustomSelectionIntent(activator),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // `n` is a single-key shortcut — disable the action while a
          // text input has focus so the keystroke falls through and
          // inserts `n`. (Arrow keys can't fall through here without
          // risking the DirectionalFocusAction crash described on
          // `_stepSelection` — they keep the in-handler guard.)
          _NewRecordIntent: GuardedShortcutAction<_NewRecordIntent>(
            onInvoke: (_) {
              if (!widget.canCreate) return null;
              goToCreateRoute(context, widget.newRoute);
              return null;
            },
          ),
          _NextRowIntent: CallbackAction<_NextRowIntent>(
            onInvoke: (_) => _stepSelection(context, forward: true),
          ),
          _PrevRowIntent: CallbackAction<_PrevRowIntent>(
            onInvoke: (_) => _stepSelection(context, forward: false),
          ),
          // Entity-supplied single-key shortcuts on the selected row (e.g.
          // Tasks' `S` → toggle timer). Guarded like `n` so the key still
          // types in the search box.
          if (selectionShortcuts != null)
            _CustomSelectionIntent:
                GuardedShortcutAction<_CustomSelectionIntent>(
                  onInvoke: (intent) {
                    final cb = selectionShortcuts[intent.tag];
                    if (cb == null) return null;
                    final id = selectedIdFromRoute(context);
                    T? item;
                    if (id != null) {
                      for (final e in _vm.items) {
                        if (_vm.idOf(e) == id) {
                          item = e;
                          break;
                        }
                      }
                    }
                    cb(context, item);
                    return null;
                  },
                ),
        },
        child: _buildBody(context),
      ),
    );
  }

  /// Move the URL-selected row one step (↓ / ↑). Mirrors the pane's
  /// `MasterDetailLayout._navigateRelative` + `MasterDetailNavController`
  /// prev/next math, but computed locally — the nav controller is null
  /// when the list renders standalone (no detail pane open).
  ///
  /// Always returns a non-null result so the keystroke is *consumed*:
  /// that's what keeps Flutter's default `DirectionalFocusAction` from
  /// running, which otherwise asserts on an unlaid-out off-screen row
  /// (`RenderSemanticsAnnotations` NEEDS-LAYOUT) and swallows the key.
  Object? _stepSelection(BuildContext context, {required bool forward}) {
    // Typing in the search box (or any inline field): consume + no-op so
    // the arrow neither navigates nor falls through to the crashing
    // default focus traversal. Single-line caret movement isn't needed.
    if (isTextInputFocused()) return const Object();
    // Don't fight checkbox bulk-select mode.
    if (_vm.isInMultiselect) return const Object();

    final ids = [for (final item in _vm.items) _vm.idOf(item)];
    if (ids.isEmpty) return const Object();
    final cur = selectedIdFromRoute(context);
    final String? target;
    if (cur == null) {
      target = forward ? ids.first : ids.last;
    } else {
      final i = ids.indexOf(cur);
      if (forward) {
        target = (i < 0 || i >= ids.length - 1) ? null : ids[i + 1];
      } else {
        target = (i <= 0) ? null : ids[i - 1];
      }
    }
    if (target == null) return const Object();

    // Resolve the entity's base route from the registry, exactly like
    // `goEntityRecord` does for a row tap.
    final handlers = _services.entityRegistry[_vm.entityType];
    final routePath = handlers?.routePath ?? '';
    if (routePath.isEmpty) return const Object();

    // Preserve edit-vs-detail mode while stepping (mirrors
    // MasterDetailLayout._navigateRelative): an `/edit` route steps to
    // the next row's edit form, not its read-only detail. `uri.replace`
    // carries query params (e.g. `?view=full`).
    final uri = GoRouterState.of(context).uri;
    final newPath = uri.path.endsWith('/edit')
        ? '$routePath/$target/edit'
        : entityRecordPath(
            routePath: routePath,
            id: target,
            hasDetailScreen: handlers?.detailBuilder != null,
          );
    GoRouter.of(context).go(uri.replace(path: newPath).toString());
    return const Object();
  }

  Widget _buildBody(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        // One-shot transient notices (e.g. "Showing active" after the user
        // unchecks the last state) flow through here. Schedule the
        // SnackBar for the next frame so the rebuild that surfaced the
        // notice finishes first.
        final notice = _vm.consumeTransientNotice();
        if (notice != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Notify.info(context, notice);
          });
        }
        // Background refresh / load-more failures — without this toast a
        // pull-to-refresh or page-N+1 fetch that fails offline ends its
        // spinner with zero feedback.
        final transientError = _vm.consumeTransientError();
        if (transientError != null) {
          final isRefresh = transientError.kind == 'refresh';
          // The toast lives on the global ToastHost (above the Navigator) and
          // OUTLIVES this screen — a bare `_vm.refresh` tear-off would invoke
          // a disposed ChangeNotifier if Retry is tapped after navigating
          // away. Capture the VM and no-op unless this State is still mounted
          // AND still bound to that same VM instance.
          final vm = _vm;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Notify.error(
              context,
              context.tr(
                isRefresh
                    ? 'refresh_failed_with_error'
                    : 'load_more_failed_with_error',
                {'error': transientError.message},
              ),
              retryOp: () async {
                if (!mounted || !identical(_vm, vm)) return;
                await (isRefresh ? vm.refresh() : vm.loadMore());
              },
            );
          });
        }
        // Push the visible row ids + URL-derived selection to the
        // master-detail nav controller so the pane's J/K shortcuts can
        // walk the same ordering the user sees. Called every rebuild —
        // cheap (one List<String> alloc), and the controller stores
        // refs without notifying so it doesn't trigger a loop.
        final selectedId = selectedIdFromRoute(context);
        final navController = MasterDetailNavScope.maybeOf(context);
        if (navController != null) {
          navController.update(
            selectedId: selectedId,
            itemIds: [for (final item in _vm.items) _vm.idOf(item)],
          );
        }
        // Auto-scroll the list to keep the URL-active row in view (slide-
        // over UX). Fires only on selection-changed, not on user scroll —
        // the user can scroll away from the active row freely. Embedded
        // lists have no own scroll and no pane J/K navigation, so skip it.
        if (!widget.embedded) {
          if (selectedId != _lastSelectedId) {
            _lastSelectedId = selectedId;
            _lastSelectedSeen = false;
          }
          if (selectedId != null && !_lastSelectedSeen) {
            final idx = _vm.items.indexWhere((e) => _vm.idOf(e) == selectedId);
            if (idx >= 0) {
              _lastSelectedSeen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _ensureRowVisible(idx);
              });
            }
          }
        }
        // Embedded: track tab visibility (only the active tab paginates the
        // shared page scroll) and prime pagination once so a short list
        // still loads page 2.
        if (widget.embedded) {
          _tickerActive = TickerMode.valuesOf(context).enabled;
          if (!_embeddedPrimed) {
            _embeddedPrimed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onOuterScroll();
            });
          }
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = Breakpoints.isWide(constraints);
            final globalNav = Breakpoints.isGlobalNavVisible(context);
            // The token search field uses the inline desktop chrome (chip
            // field + anchored dropdown) on any desktop-class window, even
            // when the locally allocated width is < 600 — the slide-over
            // pane is hard-clamped to ≤560 px (`master_detail_layout.dart`
            // `_paneWidth`), which would otherwise drop every embedded list
            // inside a pane to the full-screen phone `FilterEntrySheet`.
            // Table / column / AppBar layout still follows `wide`.
            final searchWide = wide || globalNav;
            final selecting = _vm.isInMultiselect;
            // Embedded mode: skip the outer Scaffold (no AppBar / FAB /
            // drawer) so the parent screen's chrome isn't duplicated.
            // The list body owns its own scrolling, so a tall parent is
            // unaffected.
            if (widget.embedded) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: InSpacing.lg(context),
                    ),
                    child: EmbeddedListTopRow(
                      wide: wide,
                      newRoute: widget.newRoute,
                      newLabelKey: widget.newLabelKey,
                      canCreate: widget.canCreate,
                      onNewPressed: widget.embeddedNewOverride,
                      // Key by company so the search field's State (which
                      // binds its TokenSearchController to the VM ONCE in
                      // initState — `TokenSearchController.vm` is final) is
                      // recreated on a company switch. Without this the same
                      // element is reused via didUpdateWidget with the new
                      // `_vm`, but the controller + its VM listener still
                      // point at the old, now-disposed VM, so chips reflect
                      // the previous workspace and chip edits no-op. Same
                      // value-keyed-identity idiom as the row KeyedSubtree.
                      searchField: KeyedSubtree(
                        key: ValueKey(_companyId),
                        child: _withResultScope(
                          widget.searchFieldBuilder(context, _vm, searchWide),
                        ),
                      ),
                    ),
                  ),
                  // Scope only the rows (not the toolbar above) so tiles +
                  // their action menu adopt the Client-datatable look, and so
                  // money cells resolve the per-client/vendor currency cascade
                  // (`cellMoney` / `PartyCurrencyBuilder` read it via
                  // FormatterScope) — the standalone path wraps the same way.
                  EmbeddedListScope(
                    child: () {
                      final body = _bodyWithBanner(
                        context,
                        wide: wide,
                        selecting: selecting,
                      );
                      final f = formatter;
                      return (widget.wantsFormatter && f != null)
                          ? FormatterScope(formatter: f, child: body)
                          : body;
                    }(),
                  ),
                ],
              );
            }
            return Scaffold(
              // The shell's company switcher + branch nav live in this
              // drawer when the global persistent rail isn't shown. Keying
              // off the *window* width (via [globalNav]) — not the local
              // [wide] — avoids a redundant hamburger at medium widths
              // where the rail is visible but our pane is < 600 px.
              drawer: globalNav ? null : const AppDrawer(),
              // Wide hosts an inline "New X" button inside the top row, so
              // the FAB is mobile-only. Selection mode hides it either way.
              // When `canCreate` is false (plan-gated), the FAB is also
              // hidden so a free-plan user can't start a new entity.
              floatingActionButton: (selecting || wide || !widget.canCreate)
                  ? null
                  : FloatingActionButton(
                      tooltip: context.tr(widget.newLabelKey),
                      onPressed: () =>
                          goToCreateRoute(context, widget.newRoute),
                      child: const Icon(Icons.add),
                    ),
              // endFloat lifts the FAB above the bottom filter bar on mobile.
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              appBar: selecting
                  ? EntityListSelectionAppBar<T>(
                      vm: _vm,
                      wide: wide,
                      items: _bulkActionItems(context),
                    )
                  : EntityListNormalAppBar<T>(
                      vm: _vm,
                      wide: wide,
                      showHamburger: !globalNav,
                      titleKey: widget.titleKey,
                      newRoute: widget.newRoute,
                      newLabelKey: widget.newLabelKey,
                      sortOptions: widget.sortOptions(context),
                      // See the embedded-list searchField above: key by
                      // company so the token-search State is recreated (and
                      // its controller rebound to the new VM) on a company
                      // switch rather than reused with a stale, disposed VM.
                      searchField: KeyedSubtree(
                        key: ValueKey(_companyId),
                        child: _withResultScope(
                          widget.searchFieldBuilder(context, _vm, searchWide),
                        ),
                      ),
                      extraActions:
                          widget.extraAppBarActions?.call(context, _vm, wide) ??
                          const <Widget>[],
                      canCreate: widget.canCreate,
                    ),
              body: () {
                final body = _bodyWithBanner(
                  context,
                  wide: wide,
                  selecting: selecting,
                );
                // Expose the resolved Formatter to descendant money cells
                // (`cellMoney` reads it via FormatterScope) so the wide
                // table renders the per-client→company currency cascade
                // instead of locale-blind numbers. Reuses the
                // FormatterHostMixin-resolved instance (already
                // invalidated on company-switch); only wraps once.
                final f = formatter;
                if (widget.wantsFormatter && f != null) {
                  return FormatterScope(formatter: f, child: body);
                }
                return body;
              }(),
            );
          },
        );
      },
    );
  }

  /// Wraps [_body] with the optional plan-gate header banner. Pulled out of
  /// the build path so embedded mode (no Scaffold) and standalone mode share
  /// the same banner placement.
  Widget _bodyWithBanner(
    BuildContext context, {
    required bool wide,
    required bool selecting,
  }) {
    final body = _body(context, wide: wide, selecting: selecting);
    final banner = widget.headerBanner;
    if (banner == null) return body;
    // Embedded shrink-wraps (no bounded height) so the body can't be
    // Expanded; stack at intrinsic height instead.
    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.min : MainAxisSize.max,
      children: [
        banner,
        if (widget.embedded) body else Expanded(child: body),
      ],
    );
  }

  Widget _body(
    BuildContext context, {
    required bool wide,
    required bool selecting,
  }) {
    if (_vm.initialError != null && _vm.items.isEmpty) {
      return ErrorView(
        message: context.tr('failed_to_load_with_error', {
          'error': _vm.initialError!,
        }),
        onRetry: _vm.retryInitial,
      );
    }
    if (_vm.items.isEmpty && !_vm.isLoadingPage) {
      // Embedded: no own scroll, no pull-to-refresh — render the empty
      // state at intrinsic height so the page (and the slim toolbar above
      // it, so the user can still create the first row) stays put.
      if (widget.embedded) {
        return _embeddedListCard(
          context,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: _emptyState(context),
          ),
        );
      }
      return RefreshIndicator(
        // `refresh` does a full server-side sweep across every state — it
        // intentionally ignores the current filter selection so the local
        // cache stays complete.
        onRefresh: _vm.refresh,
        child: ListView(
          // RefreshIndicator needs a scrollable child; a single sliver-free
          // ListView with one centered tile gives the empty state without
          // breaking pull-to-refresh.
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _emptyState(context),
            ),
          ],
        ),
      );
    }

    final listView = ListView.builder(
      // Embedded: shrink-wrap into the detail page's scroll (single
      // scrollbar, React-like). Standalone: own scrollable + pull-to-
      // refresh.
      shrinkWrap: widget.embedded,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      controller: widget.embedded ? null : _vScroll,
      itemCount: _vm.items.length + 1, // +1 for the footer slot
      itemBuilder: (context, index) {
        if (index >= _vm.items.length) return _footer();
        final item = _vm.items[index];
        final selId = highlightSelectedIdFromRoute(context);
        final isLast = index == _vm.items.length - 1;
        // Hide this row's hairline when it's the last row, when it's the
        // selected row, or when the *next* row is selected — the last case
        // is the divider directly above the highlight chip, which a tile
        // can't suppress on its own.
        final bottomDividerHidden =
            isLast ||
            _vm.idOf(item) == selId ||
            (index + 1 < _vm.items.length &&
                _vm.idOf(_vm.items[index + 1]) == selId);
        // Key by entity identity (not list position) so a full-page
        // re-emit from the Drift watch reuses unchanged tile elements
        // instead of rebinding state by index. RepaintBoundary keeps a
        // single-row change from repainting the whole viewport.
        return KeyedSubtree(
          key: ValueKey(_vm.idOf(item)),
          child: RepaintBoundary(
            // minHeight (not a fixed height) gives every row a stable
            // taller floor so toggling the leading avatar↔checkbox never
            // reflows the list, while tall tiles (2-line identity + money
            // column) are never clipped.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kEntityListRowHeight,
              ),
              child: widget.tileBuilder(
                context,
                _vm,
                item,
                index,
                EntityListTileOptions(
                  wide: wide,
                  isLast: isLast,
                  selecting: selecting,
                  formatter: widget.wantsFormatter ? formatter : null,
                  // Archived entities stay editable (matches legacy
                  // Invoice Ninja: `isEditable => !isDeleted`); only
                  // soft-deleted rows grey out the edit pencil.
                  editable: !_vm.isDeleted(item),
                  // Highlight variant: null while navigating to a
                  // full-width editor so the row doesn't flash selected
                  // before the editor covers the list.
                  selectedId: selId,
                  bottomDividerHidden: bottomDividerHidden,
                ),
              ),
            ),
          ),
        );
      },
    );

    // Embedded shrink-wraps with no pull-to-refresh; standalone keeps the
    // RefreshIndicator wrapping its own scrollable.
    final Widget list = widget.embedded
        ? listView
        : RefreshIndicator(onRefresh: _vm.refresh, child: listView);

    if (!wide) {
      return widget.embedded ? _embeddedListCard(context, list) : list;
    }
    return _wideTable(context, list);
  }

  /// The v2 white rounded card chrome shared by every embedded list (wide
  /// table + narrow list + empty state). Matches the `DashboardCardShell`
  /// Details/Address/Contacts cards above it (`surface` + `border` + `r3` +
  /// `shadow1`) so the detail page reads as one consistent design.
  ///
  /// The inner `Material(type: transparency)` is the InkFeatures host for
  /// every row `InkWell` in the table. Without it, the InkWell's nearest
  /// `Material` is the Scaffold's body Material — far above this card — and
  /// hover/focus/splash paint at that ancestor, BEFORE the card's `surface`
  /// fill paints over them. The fill then hides the hover inside the card
  /// while any geometric overshoot leaks past the card's edges. A local
  /// transparency Material moves the ink painting INSIDE the clip so hover
  /// is visible on the row and never leaks outside.
  Widget _embeddedListCard(BuildContext context, Widget child) {
    final tokens = context.inTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
        boxShadow: tokens.shadow1,
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }

  Widget _emptyState(BuildContext context) {
    final builder = widget.emptyStateBuilder;
    if (builder != null) return builder(context, _vm);
    // Default: a generic `EmptyState` driven by the icon + title key the
    // caller supplied. Entities with filter-aware copy supply
    // `emptyStateBuilder` instead.
    assert(
      widget.emptyIcon != null && widget.emptyTitleKey != null,
      'EntityListScreenScaffold needs either `emptyStateBuilder` or both '
      '`emptyIcon` and `emptyTitleKey`.',
    );
    return EmptyState(
      icon: widget.emptyIcon!,
      title: context.tr(widget.emptyTitleKey!),
    );
  }

  Widget _footer() {
    if (_vm.isLoadingPage) return const EntityListLoadingFooter();
    return const SizedBox.shrink();
  }

  /// Wide: wrap the list in the v2 card chrome with a column header strip
  /// above the rows. Mirrors `docs/design/v2/screens.jsx:557-601`.
  ///
  /// The header + rows live inside a horizontal `SingleChildScrollView` so
  /// the table can pan sideways when the selected columns sum to wider
  /// than the viewport. A `SizedBox(width: tableWidth)` gives the inner
  /// `Column` bounded width regardless of viewport — without it, the row
  /// `Flexible`s and `SizedBox`es would lay out against an unbounded
  /// parent and the nested Flex Row would overflow.
  Widget _wideTable(BuildContext context, Widget list) {
    final columns = _vm.columns;
    final minWidth = computeTableMinWidth(columns);
    final headersBuilder = widget.wideColumnHeadersBuilder;
    final headers = headersBuilder != null
        ? headersBuilder(context, _vm)
        : EntityListColumnHeaders<T>(vm: _vm);
    final inner = LayoutBuilder(
      builder: (context, c) {
        final tableWidth = math.max(c.maxWidth, minWidth);
        return Scrollbar(
          controller: _hScroll,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _hScroll,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                // Embedded sits in the page's unbounded-height scroll, so
                // it must shrink-wrap; standalone fills the bounded card.
                mainAxisSize: widget.embedded
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  headers,
                  if (widget.embedded) list else Expanded(child: list),
                ],
              ),
            ),
          ),
        );
      },
    );
    final card = _embeddedListCard(context, inner);
    // Embedded: full content width so the card lines up with the toolbar,
    // tab strip, and Details/Address/Contacts cards (the detail page
    // already insets everything via its SingleChildScrollView padding, and
    // the toolbar supplies the gap above). Standalone: keep the 24 px
    // inset inside its bare Scaffold body.
    if (widget.embedded) return card;
    return Padding(padding: const EdgeInsetsDirectional.all(24), child: card);
  }
}

class _NewRecordIntent extends Intent {
  const _NewRecordIntent();
}

class _NextRowIntent extends Intent {
  const _NextRowIntent();
}

class _PrevRowIntent extends Intent {
  const _PrevRowIntent();
}

/// Carries the matched activator so one action can serve every entry in
/// [EntityListScreenScaffold.selectionShortcuts]. `Actions` dispatches by
/// intent *type*, so all custom selection shortcuts share this type and the
/// action reads [tag] to find the right callback.
class _CustomSelectionIntent extends Intent {
  const _CustomSelectionIntent(this.tag);
  final ShortcutActivator tag;
}
