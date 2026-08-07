import 'package:flutter/material.dart' show IconData;
import 'package:go_router/go_router.dart' show GoRouterWidgetBuilder, RouteBase;

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';

/// Where an entity lives in the persistent sidebar nav.
///
/// - [top]: the workspace section (Clients, Products, Invoices, …).
/// - [bottom]: pinned to the bottom group (rare; reserved for future use).
/// - [none]: registered for sync only (e.g. [EntityType.company],
///   [EntityType.user]). No sidebar entry, no list screen, no branch.
enum SidebarSection { top, bottom, none }

/// Per-entity metadata + the sync dispatcher that knows how to talk to the
/// server for this entity. The sync engine, outbox screen, permissions
/// checks, router, and shell navigation all read from here so adding a new
/// entity is mechanical.
///
/// **Layering note**: this type carries UI concerns (icons, `labelKey`,
/// screen builders) alongside data-layer concerns (`wireName`, `dispatcher`,
/// `requiresPasswordFor`). The file lives under `lib/domain/` for historical
/// reasons; conceptually it's an app-level registry. We accept the mixed
/// coupling rather than splitting into parallel domain + UI registries that
/// would have to be kept in sync.
class EntityHandlers {
  const EntityHandlers({
    required this.type,
    required this.wireName,
    required this.apiPath,
    required this.routePath,
    required this.icon,
    required this.dispatcher,
    this.extraWireNames = const <String>[],
    this.outlinedIcon,
    this.labelKey,
    this.pluralLabelKey,
    this.requiresPasswordFor = const {},
    this.sidebarSection = SidebarSection.none,
    this.sidebarOrder = 100,
    this.disabled = false,
    this.listBuilder,
    this.createBuilder,
    this.detailBuilder,
    this.editBuilder,
    this.extraChildRoutes = const [],
    this.badgeStream,
    this.badgeModes = kDefaultBadgeModes,
  });

  final EntityType type;

  /// Stored in `outbox.entity_type`; sent in some API filter params; never
  /// changed once an entity ships (rename would break existing outbox rows).
  final String wireName;

  /// Additional `outbox.entity_type` values that resolve to this handler. Used
  /// when a single [EntityType] slot needs to route multiple wire flows
  /// through one dispatcher — see the user slot, which carries both
  /// `'user_settings'` (per-company-user PUTs hitting `/company_users/{id}`)
  /// and `'user'` (full-user PUTs hitting `/users/{id}`). The handler's
  /// [dispatcher] is responsible for branching on `row.entityType`.
  final List<String> extraWireNames;

  /// Server collection path, e.g. `/api/v1/clients`.
  final String apiPath;

  /// Top-level UI route, e.g. `/clients`. Empty for entities that have no
  /// list screen (e.g. `EntityType.company`).
  final String routePath;

  /// Sidebar icon when this entry is active (filled variant).
  final IconData icon;

  /// Sidebar icon when this entry is inactive (outlined variant). Falls back
  /// to [icon] when null.
  final IconData? outlinedIcon;

  /// Localization key for the sidebar label + AppBars (e.g. `'clients'`).
  /// Falls back to [wireName] when null.
  final String? labelKey;

  /// Plural localization key (e.g. `'clients'` — usually identical to
  /// [labelKey] for English). Reserved for future use where a list-screen
  /// title needs the plural form distinct from the sidebar singular.
  final String? pluralLabelKey;

  final Set<MutationKind> requiresPasswordFor;
  final SyncDispatcher dispatcher;

  /// Where this entity appears in the persistent sidebar. Defaults to
  /// [SidebarSection.none] so sync-only registrations (company, user) don't
  /// accidentally surface in the rail.
  final SidebarSection sidebarSection;

  /// Display order within [sidebarSection]. Decoupled from the router's
  /// branch index so visual order can differ from branch order.
  final int sidebarOrder;

  /// `true` for entities whose screens haven't shipped yet (invoices,
  /// quotes, …). Renders in the sidebar with a `coming_soon` tooltip and
  /// no branch — drop to `false` and supply the screen builders when the
  /// module lands.
  final bool disabled;

  /// `/<routePath>` — list screen. Required for non-disabled entities with
  /// [sidebarSection] != none.
  final GoRouterWidgetBuilder? listBuilder;

  /// `/<routePath>/new` — create screen.
  final GoRouterWidgetBuilder? createBuilder;

  /// `/<routePath>/:id` — detail screen.
  final GoRouterWidgetBuilder? detailBuilder;

  /// `/<routePath>/:id/edit` — edit screen.
  final GoRouterWidgetBuilder? editBuilder;

  /// Entity-specific child routes nested under `/<routePath>/:id/…`
  /// (e.g. `/clients/:id/statement`).
  final List<RouteBase> extraChildRoutes;

  /// Optional live count badge for the sidebar row. `null` means no badge.
  /// Receives the registry's [SidebarBadgeContext] so the callback can
  /// reach repositories or DAOs without an explicit `Services` dependency.
  final SidebarBadgeStream? badgeStream;

  /// What that badge is allowed to count — the choices offered in the row's
  /// right-click menu and in Settings → Device Settings → Sidebar counters.
  /// Both surfaces read this list, so they can't drift apart.
  final List<SidebarBadgeMode> badgeModes;

  /// Effective localization key for the sidebar / AppBar.
  String get effectiveLabelKey => labelKey ?? wireName;

  /// Effective sidebar icon when inactive — outlined variant if provided,
  /// otherwise the filled icon.
  IconData get effectiveOutlinedIcon => outlinedIcon ?? icon;

  /// `/<routePath>/new` for the hover-reveal "+" affordance in the sidebar.
  /// Returns null when there's no create route (disabled / sync-only).
  String? get newRoute {
    if (disabled || routePath.isEmpty) return null;
    return '$routePath/new';
  }
}

/// Callback signature for [EntityHandlers.badgeStream]. Receives the active
/// company id, the user's chosen [SidebarBadgeMode] id for this row, and a
/// lookup hook for repositories (the registry doesn't import `Services`
/// directly; the caller provides the lookup).
typedef SidebarBadgeStream =
    Stream<int> Function(
      SidebarBadgeContext context,
      String companyId,
      String modeId,
    );

/// Marker interface for whatever the badge callback needs to read counts.
/// Implemented by `Services` in `lib/app/services.dart`; defined here so the
/// registry stays free of an app-layer import.
abstract class SidebarBadgeContext {
  /// Live count of active rows of [type] for [companyId] matching [modeId]
  /// (one of the entity's [EntityHandlers.badgeModes] ids). Drives every
  /// per-entity sidebar badge. Returns `Stream.value(0)` for an entity that
  /// isn't wired with a sidebar count (settings-only, disabled, etc.) so
  /// callers don't need to null-check.
  Stream<int> watchEntityCount(
    EntityType type,
    String companyId, {
    String modeId = kBadgeModeTotal,
  });
  Stream<int> watchOutboxPending(String companyId);
  Stream<int> watchOutboxDead(String companyId);
}

/// One slot in the [StatefulShellRoute.indexedStack]'s branch list. Mixed
/// kinds: some branches host an entity (list/detail/edit), others host a
/// fixed feature (dashboard, settings, outbox).
sealed class BranchSpec {
  const BranchSpec();
}

/// Branch hosting an entity's list/detail/edit screens. The router looks
/// up the [EntityHandlers] by [type] at build time to fetch the screen
/// builders + extra child routes.
class EntityBranch extends BranchSpec {
  const EntityBranch(this.type);
  final EntityType type;
}

/// Branch hosting a fixed feature (not an entity). The router emits the
/// route tree inline by switching on [kind]; this keeps the UI-feature
/// route definitions out of the registry.
class FixedBranch extends BranchSpec {
  const FixedBranch(this.kind);
  final FixedBranchKind kind;
}

/// Kinds of fixed (non-entity) branches in the authenticated shell.
/// Adding a new fixed branch means adding a value here AND a case in the
/// router's `_buildFixedBranch` helper.
// IMPORTANT: append-only. The router uses the registry's `branchOrder`
// index for `StatefulShellRoute.indexedStack`, and existing persisted nav
// state references that index — inserting a value here shifts every later
// branch for every user on next launch.
//
// Note: this enum's positional indices (dashboard=0, settings=1, …) are
// independent from `kBranchOrder`'s branch indices. The sidebar's visual
// order and the router's branch positions don't need to align with the
// enum order; the registry resolves them via the `FixedBranch(kind)` spec.
enum FixedBranchKind { dashboard, settings, outbox, reports }

/// In-memory map populated at app start (DI). The map drives the entire
/// per-entity machinery — sync engine, outbox screen, router branches,
/// sidebar nav.
class EntityRegistry {
  EntityRegistry(
    Map<EntityType, EntityHandlers> initial, {
    List<BranchSpec> branchOrder = const [],
  }) : _byType = Map.of(initial),
       _byWire = _buildWireIndex(initial.values),
       _branchOrder = List.of(branchOrder);

  static Map<String, EntityHandlers> _buildWireIndex(
    Iterable<EntityHandlers> handlers,
  ) {
    final out = <String, EntityHandlers>{};
    for (final h in handlers) {
      out[h.wireName] = h;
      for (final alias in h.extraWireNames) {
        out[alias] = h;
      }
    }
    return out;
  }

  final Map<EntityType, EntityHandlers> _byType;
  final Map<String, EntityHandlers> _byWire;
  List<BranchSpec> _branchOrder;

  EntityHandlers? operator [](EntityType type) => _byType[type];
  EntityHandlers? byWireName(String wireName) => _byWire[wireName];

  Iterable<EntityHandlers> get all => _byType.values;

  /// Router branch order. Each spec is either an [EntityBranch] (resolved
  /// against the registry to get screen builders) or a [FixedBranch] (the
  /// router emits the route tree inline). Index in this list = branch
  /// index in the [StatefulShellRoute.indexedStack].
  List<BranchSpec> get branchOrder => List.unmodifiable(_branchOrder);

  /// Branch index for [type] in the router's `indexedStack`, or null when
  /// the entity has no UI branch (disabled, or [SidebarSection.none]).
  int? branchIndexFor(EntityType type) {
    for (var i = 0; i < _branchOrder.length; i++) {
      final spec = _branchOrder[i];
      if (spec is EntityBranch && spec.type == type) return i;
    }
    return null;
  }

  /// Entities to render in the sidebar's workspace section, sorted by
  /// [EntityHandlers.sidebarOrder]. Includes [EntityHandlers.disabled]
  /// entries — they appear greyed out with a `coming_soon` tooltip so the
  /// full nav surface is discoverable.
  List<EntityHandlers> get sidebarTop => _sidebarEntries(SidebarSection.top);

  /// Entities pinned to the bottom group of the sidebar. Currently unused
  /// (Settings and Outbox are fixed nav entries, not entities) — kept for
  /// future symmetry.
  List<EntityHandlers> get sidebarBottom =>
      _sidebarEntries(SidebarSection.bottom);

  List<EntityHandlers> _sidebarEntries(SidebarSection section) {
    final entries =
        _byType.values.where((h) => h.sidebarSection == section).toList()
          ..sort((a, b) => a.sidebarOrder.compareTo(b.sidebarOrder));
    return entries;
  }

  /// Top-level route paths for entities that have a list screen. Used by
  /// `companySafeLocation` to strip stale entity IDs after a company
  /// switch / restore. Includes settings-hosted entities
  /// (`SidebarSection.none` — gateways, tax rates, tokens, …): their
  /// edit/detail screens bind the active company once at mount, so a stale
  /// `/settings/<entity>/<id>/edit` surviving a company switch would keep
  /// showing — and saving to — the previous company's record under the new
  /// company's chrome.
  Iterable<String> get uiRoutePaths sync* {
    for (final h in _byType.values) {
      // Include `disabled` entities that still have a wired route (tax_rates,
      // custom designs): their edit/detail screens ARE reachable from settings
      // and capture the active company once at mount, so companySafeLocation
      // must strip a stale `/settings/<entity>/<id>` on a company switch — else
      // the screen keeps reading from (and Save/Archive/Delete keeps writing
      // to) the previous company's record. Only skip routeless entities.
      if (h.routePath.isEmpty) continue;
      yield h.routePath;
    }
    // Users are a settings-hosted screen, NOT a registered entity module, so
    // they're not in `_byType` — but `/settings/users/:id[/edit]` binds the
    // active company at mount just like the entity screens above, so a stale
    // one surviving a company switch would read from (and save to) the previous
    // company's user under company B's token. Strip it too.
    yield '/settings/users';
  }

  /// Overwrite the registry contents. Used by DI to break the construction
  /// cycle between [SyncRepository] (needs the registry) and the per-entity
  /// repositories (need [SyncRepository.drainOnce] as their `onEnqueued`):
  /// build the registry empty, build sync, build repos, then call this with
  /// the dispatchers wired against the repos.
  void replaceAll(
    Map<EntityType, EntityHandlers> entries, {
    List<BranchSpec> branchOrder = const [],
  }) {
    _byType
      ..clear()
      ..addAll(entries);
    _byWire
      ..clear()
      ..addAll(_buildWireIndex(entries.values));
    _branchOrder = List.of(branchOrder);
  }
}
