import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/activity/views/activity_screen.dart';
import 'package:admin/ui/features/auth/views/client_too_old_screen.dart';
import 'package:admin/ui/features/auth/views/lock_screen.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';
import 'package:admin/ui/features/auth/views/setup_wizard_screen.dart';
import 'package:admin/ui/features/auth/views/signup_screen.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:admin/ui/features/reports/views/reports_screen.dart';
import 'package:admin/ui/features/settings/settings_routes.dart';
import 'package:admin/ui/features/settings/views/settings_screen.dart';
import 'package:admin/ui/features/settings/views/settings_shell.dart';
import 'package:admin/ui/features/shell/scaffold_with_nav.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart'
    show kInSidebarWidth, kInSidebarCollapsedWidth;
import 'package:admin/ui/features/sync/views/outbox_screen.dart';
import 'package:admin/ui/features/tasks/views/calendar_connection_complete_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Post-login landing: dashboard when the active company can view it,
/// clients otherwise. Mirrors admin-portal's behavior — `AuthCompany.can`
/// treats admins and owners as having every permission.
String defaultPostLoginRoute(AuthSession? session) {
  final canViewDashboard =
      session?.currentCompany?.can('view_dashboard') ?? false;
  return canViewDashboard ? '/dashboard' : '/clients';
}

/// True when the active company is freshly-created and still needs the
/// user to name it. Both admin-portal (`dashboard_screen.dart:96`) and React
/// (`App.tsx:190`) trigger their setup prompts on the same predicate — empty
/// settings.name or the server's default `'Untitled Company'` seed. The bare
/// `'Untitled'` fallback returned by `companyDisplayName` when *all* name
/// fields are empty is also treated as "needs setup"; a user-typed
/// `'Untitled'` passes through (real value lives in the row's name column).
bool isCompanySetupRequired(AuthSession? session) {
  final c = session?.currentCompany;
  if (c == null) return false;
  final name = c.displayName.trim();
  // Empty AND the resolved-fallback case both mean no real name set.
  // `companyDisplayName` returns `'Untitled'` only when settings.name,
  // displayName, and name on the row are all empty (see `auth_helpers.dart`).
  if (name.isEmpty || name == 'Untitled Company') return true;
  // A row whose stored `name` is non-empty but the resolved value is the
  // bare `'Untitled'` fallback means every name source is empty.
  if (name == 'Untitled' && c.name.isEmpty) return true;
  return false;
}

/// Returns the route to land on after a company switch from [currentLocation].
/// Any path under one of the [entityRoots] entries that references a specific
/// entity is stripped back to that list root — that includes `<root>/new`
/// create forms, which bind the active company once at mount (see the note in
/// the loop). Anything else (arbitrary settings sub-routes, the dashboard, …)
/// passes through unchanged, query string and all. Note that a stripped path
/// loses its query string along with its trailing segment.
///
/// Pass `services.entityRegistry.uiRoutePaths` for [entityRoots] in
/// production — keeping this function dependency-free of the registry makes
/// it trivially testable.
String companySafeLocation(
  String currentLocation,
  Iterable<String> entityRoots,
) {
  final uri = Uri.tryParse(currentLocation);
  if (uri == null || uri.path.isEmpty) return '/clients';
  // Longest root first: `/settings/bank_accounts/transaction_rules` nests
  // under `/settings/bank_accounts`, and matching the shorter root first
  // would mis-strip the nested entity's own list (and its ids) to the
  // parent's list root.
  final roots = entityRoots.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  // A list root itself is always safe — without this, a nested root's own
  // list would match its parent root's `<root>/` prefix and get stripped.
  if (roots.contains(uri.path)) return currentLocation;
  for (final root in roots) {
    final prefix = '$root/';
    if (!uri.path.startsWith(prefix)) continue;
    // `/x/new` is stripped just like `/x/<id>`: the create screen captures the
    // active company ONCE at mount (`EntityEditScreenScaffold._companyId` is
    // `late final`, behind the `_bootstrapped` latch) and never listens to the
    // session. Keeping the location meant go_router short-circuited the
    // navigation (same path), so the form stayed bound to the PREVIOUS company
    // while the list behind it switched — and saving queued the record into
    // the wrong workspace. The unsaved-changes guard already prompts before a
    // switch when the form is dirty, so nothing is lost by leaving.
    return root;
  }
  return currentLocation;
}

/// Rewrites a legacy `/settings/integrations[/…]` location onto its current
/// home under Account Management, or returns null when [uri] isn't one.
///
/// The Integrations destinations used to hang off a top-level
/// `/settings/integrations` route. Its page was an orphan — the sidebar section
/// had been removed — but go_router still synthesized it as the parent page of
/// every child, so back from Analytics landed on a screen the user had never
/// visited (issue #8). Re-parenting them fixed that and changed their URLs;
/// this keeps old deep links and, more importantly, a restored "where you left
/// off" route (`nav_state_persister` saves only the location, and an unmatched
/// one renders the route-error view) working.
String? legacyIntegrationsRedirect(Uri uri) {
  const legacyRoot = '/settings/integrations';
  const currentRoot = '/settings/account_management/integrations';
  final path = uri.path;
  if (path != legacyRoot && !path.startsWith('$legacyRoot/')) return null;
  return uri
      .replace(path: '$currentRoot${path.substring(legacyRoot.length)}')
      .toString();
}

/// Redirect target for the `/settings` index.
///
/// On viewports wide enough for the two-pane settings layout — shell width
/// (window width minus the global `InSidebar`) ≥ [Breakpoints.settingsTwoPane]
/// — land directly on Company Details; the persistent `SettingsListSidebar`
/// makes the "select a setting" hint redundant. Below that, return null so the
/// full-screen `SettingsScreen` list renders and push-nav reaches each section.
///
/// The threshold MUST stay equal to `SettingsShell`'s `LayoutBuilder` gate
/// (also [Breakpoints.settingsTwoPane]): both split the same shell width, and a
/// drift between them strands the user on a section page with no menu list
/// (redirected past the `/settings` list, but below the width that shows the
/// sidebar). [kInSidebarWidth] / [kInSidebarCollapsedWidth] must match the inset
/// `ScaffoldWithNav` applies to the routed content in its wide layout.
String? settingsIndexRedirect({
  required double screenWidth,
  required bool sidebarCollapsed,
}) {
  final sidebarWidth = sidebarCollapsed
      ? kInSidebarCollapsedWidth
      : kInSidebarWidth;
  final shellWidth = screenWidth - sidebarWidth;
  return shellWidth >= Breakpoints.settingsTwoPane
      ? '/settings/company_details'
      : null;
}

/// Top-level route paths whose backing module is disabled for a company with
/// the given [enabledModules] mask. Used by the router's `redirect` to bounce
/// a deep link / restored route that points at a now-hidden module. Kept
/// registry-aware but dependency-light so it's unit-testable in isolation.
Iterable<String> disabledEntityRoots(
  EntityRegistry registry,
  int enabledModules,
) sync* {
  for (final h in registry.all) {
    if (h.disabled || h.routePath.isEmpty) continue;
    if (h.sidebarSection == SidebarSection.none) continue;
    if (!isEntityModuleEnabledForCompany(h.type, enabledModules)) {
      yield h.routePath;
    }
  }
}

/// True when [location] is the list/detail/edit/create route of a
/// module-disabled entity (an exact match or a `<root>/…` sub-path).
bool _isUnderDisabledRoot(String location, Set<String> disabledRoots) {
  for (final root in disabledRoots) {
    if (location == root || location.startsWith('$root/')) return true;
  }
  return false;
}

/// `GoRoute.onExit` callback for edit screens. Defers to the global
/// [UnsavedChangesGuard] so a stray `context.go(...)` that bypasses the
/// explicit entry-point guards (sidebar, picker, branch switch) still
/// prompts. Not attached to `/settings/company_details` — its tab variants
/// are sibling routes that would each fire `onExit` on every tab switch.
Future<bool> _confirmExitIfDirty(BuildContext context, GoRouterState state) {
  return context.read<Services>().unsavedChangesGuard.confirmIfDirty(context);
}

/// Build the standard entity route block:
///
/// ```
/// /<basePath>            -> list (master pane)
/// /<basePath>/new        -> create form (right pane)  (onExit guard)
/// /<basePath>/:id        -> detail (right pane)
/// /<basePath>/:id/edit   -> edit form (right pane)    (onExit guard)
/// /<basePath>/:id/<...>  -> [extraChildRoutes]        (full-screen, outside split)
/// ```
///
/// On wide desktop windows (≥ `Breakpoints.slideOver`) the list stays
/// mounted at full width and the detail / edit / create floats above
/// it as a slide-over pane (or fills the screen when `?view=full`).
/// On narrower windows the layout collapses to today's full-page
/// navigation.
///
/// Built around go_router's [ShellRoute]: the shell's `pageBuilder`
/// constructs the list once and reuses its Element across child route
/// changes, so list state (selection, scroll, multi-select, filters)
/// survives every row click. The right-pane child changes per navigation;
/// the bare URL routes a const sentinel widget, and [MasterDetailLayout]
/// takes "is there a pane" from `hasPane` (the matched location) rather than
/// from the child, which it must keep mounted either way.
///
/// `extraChildRoutes` (e.g. `/invoices/:id/pdf`) live as siblings to
/// the ShellRoute, so they take the full screen and don't inherit the
/// split chrome.
///
/// **The list and `:id` routes are siblings, not parent/child**, so `/x/:id`
/// matches a *single* page and no navigator in the app can pop it — unlike
/// `/x/:id/edit` (nested under `:id`) or the settings tree (`settings_routes
/// .dart`, which nests and therefore pops natively). System back is handled for
/// them by `SystemBackGate`, which walks `NavHistoryController` instead; see
/// CLAUDE.md § Strict rules for the invariants that keeps alive.
ShellRoute buildEntityRouteBlock({
  required String basePath,
  required GoRouterWidgetBuilder list,
  required GoRouterWidgetBuilder create,
  required GoRouterWidgetBuilder detail,
  required GoRouterWidgetBuilder edit,
  List<RouteBase> extraChildRoutes = const [],
}) {
  return ShellRoute(
    pageBuilder: (context, state, child) => NoTransitionPage<void>(
      key: ValueKey('master_detail:$basePath'),
      child: Builder(
        builder: (ctx) {
          // Read the URL :id once so the list-tile selection highlight
          // stays in sync with browser back / forward without every
          // tile establishing its own router dependency.
          final selectedId = state.pathParameters['id'];
          // On the way to a full-width editor the editor covers the whole
          // list, so painting the row "selected" only produces a transient
          // highlight flash before the list is hidden. Flag it so the tile
          // highlight can be suppressed — while the raw `selectedId` above
          // stays intact for J/K nav + keep-in-view auto-scroll. Slide-over
          // editors (products, transactions, payments) keep the highlight:
          // their list stays visible beside the form.
          final editorCoversList =
              state.matchedLocation.endsWith('/edit') &&
              editOpensFullWidth(basePath);
          // The pane is visible iff the URL has navigated past the bare
          // list path. We can't `is`-check `child` against
          // `_NoPaneSentinel` here — go_router's `ShellRoute.pageBuilder`
          // hands us the inner Navigator widget, not the matched
          // sub-route's widget (see go_router/lib/src/route.dart's
          // `ShellRoute.buildPage`). The matched location is the
          // canonical signal.
          final hasPane = state.matchedLocation != basePath;
          // Read the `?view=full` flag from the URL so MasterDetailLayout
          // can render the pane in full-screen mode when set.
          final viewMode = state.uri.queryParameters['view'];
          return MasterDetailLayout(
            basePath: basePath,
            list: _SelectedIdScope(
              selectedId: selectedId,
              editorCoversList: editorCoversList,
              child: list(ctx, state),
            ),
            // `child` is this ShellRoute's Navigator and is handed over
            // unconditionally — `hasPane` decides visibility. Keeping it
            // mounted on the bare list URL is what lets go_router resolve its
            // navigatorKey when the platform asks us to pop (see
            // `MasterDetailLayout._hiddenPaneHost`).
            rightPane: child,
            hasPane: hasPane,
            viewMode: viewMode,
          );
        },
      ),
    ),
    routes: [
      // Bare list URL — the shell renders only the list, no right pane.
      GoRoute(path: basePath, builder: (_, _) => const _NoPaneSentinel()),
      GoRoute(
        path: '$basePath/new',
        // Re-key the create screen on the seed generation so a "New X" that
        // targets an already-mounted create route recreates its State —
        // go_router reuses the mounted screen otherwise, skipping `buildVm`
        // (and the staged client seed). Mirrors the `:id` KeyedSubtree on the
        // detail/edit routes below.
        builder: (context, state) {
          final services = context.read<Services>();
          return ValueListenableBuilder<int>(
            valueListenable: services.seedGenTick,
            builder: (context, _, _) => KeyedSubtree(
              key: ValueKey('new:$basePath:${services.seedGenFor(basePath)}'),
              child: create(context, state),
            ),
          );
        },
        onExit: _confirmExitIfDirty,
      ),
      GoRoute(
        path: '$basePath/:id',
        // Wrap in a KeyedSubtree whose key includes the URL's `:id` so
        // navigating between rows of the same entity rebuilds the
        // screen's State from scratch. Detail / edit screens capture
        // `widget.id` at `initState` to build their VM — without a
        // fresh State the pane visually sticks on the previous row
        // when the user clicks a different row or presses J / K.
        builder: (context, state) => KeyedSubtree(
          key: ValueKey('detail:$basePath:${state.pathParameters['id']}'),
          child: detail(context, state),
        ),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => KeyedSubtree(
              key: ValueKey('edit:$basePath:${state.pathParameters['id']}'),
              child: edit(context, state),
            ),
            onExit: _confirmExitIfDirty,
          ),
          ...extraChildRoutes,
        ],
      ),
    ],
  );
}

/// Empty placeholder rendered by the Navigator at the bare list URL.
/// The slide-over pane is gated on `state.matchedLocation != basePath`
/// (see `buildEntityRouteBlock`'s pageBuilder), so this widget never paints
/// anything user-visible: `MasterDetailLayout` keeps the host Navigator
/// mounted but hidden there (`HiddenShellNavigator` — go_router needs the
/// `navigatorKey` resolvable), and this is what that Navigator renders. Kept
/// as a named class so the route definition reads
/// `builder: ... const _NoPaneSentinel()` rather than a bare `SizedBox.shrink`.
class _NoPaneSentinel extends StatelessWidget {
  const _NoPaneSentinel();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Inherits the URL-derived `selectedId` so list tiles can read it via
/// [_SelectedIdScope.maybeOf] without each tile registering as a
/// `GoRouterState` listener. Updating tiles on URL change is one frame
/// for the scope + one frame for each tile — same cost as today's
/// multi-select selection rebuild.
class _SelectedIdScope extends InheritedWidget {
  const _SelectedIdScope({
    required this.selectedId,
    required this.editorCoversList,
    required super.child,
  });

  final String? selectedId;

  /// True when the current route is a full-width-editor `/edit` route
  /// whose editor will cover the list. Used to suppress the *visual*
  /// row-selection highlight (not the raw [selectedId], which still drives
  /// J/K nav + auto-scroll).
  final bool editorCoversList;

  static _SelectedIdScope? _maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SelectedIdScope>();

  @override
  bool updateShouldNotify(_SelectedIdScope oldWidget) =>
      selectedId != oldWidget.selectedId ||
      editorCoversList != oldWidget.editorCoversList;
}

/// Public read-only access to the URL-derived `selectedId`. Drives the
/// master-detail J/K nav controller and the keep-active-row-in-view
/// auto-scroll — always the raw id, regardless of editor mode.
String? selectedIdFromRoute(BuildContext context) =>
    _SelectedIdScope._maybeOf(context)?.selectedId;

/// The `selectedId` to use for the **visual** row-selection highlight.
/// Null while navigating to a full-width editor (the editor covers the
/// list, so the highlight would only flash); otherwise identical to
/// [selectedIdFromRoute]. Slide-over editors keep the highlight.
String? highlightSelectedIdFromRoute(BuildContext context) {
  final scope = _SelectedIdScope._maybeOf(context);
  if (scope == null || scope.editorCoversList) return null;
  return scope.selectedId;
}

/// Pure decision for [goEntityRecord]'s target path. Extracted so the
/// rule is unit-testable without a widget tree.
///
/// Row-click always opens the read-only **view** (detail) screen. The
/// only exception is the no-detail-screen guard: entities that have no
/// detail screen fall back to edit so the route is never dead.
String entityRecordPath({
  required String routePath,
  required String id,
  required bool hasDetailScreen,
}) => hasDetailScreen ? '$routePath/$id' : '$routePath/$id/edit';

/// Navigate to a record from a **datatable row tap** (or any
/// equivalent same-entity record jump — kanban cards, next/prev
/// actions). Resolves the entity's `routePath` from the registry
/// verbatim (settings entities are deeply nested, e.g.
/// `/settings/company_gateways`).
///
/// Always the view/detail screen (the resolver in `MasterDetailLayout`
/// decides slide-over vs full-screen). Entities with no detail screen
/// fall back to `/:id/edit` so the route is never dead. Never appends
/// `?view`.
///
/// Not for `EntityType.transactionRule` — that entity is owned by the
/// settings router with no `MasterDetailLayout`; its list keeps a raw
/// `context.go`.
void goEntityRecord(BuildContext context, EntityType type, String id) {
  final handlers = context.read<Services>().entityRegistry[type];
  if (handlers == null || handlers.routePath.isEmpty) return;
  GoRouter.of(context).go(
    entityRecordPath(
      routePath: handlers.routePath,
      id: id,
      hasDetailScreen: handlers.detailBuilder != null,
    ),
  );
}

/// Navigate to a record's **full-width view** (detail) screen. Used by
/// every in-cell link: the Number/identifier cell and cross-entity
/// references (client / vendor / project / category) all open the
/// referenced record's full-width view — editing is reached from the
/// view's Edit button. `?view=full` is explicit so it survives the
/// cross-entity hop (unlike [goEntity], which drops `view`).
void goEntityFullDetail(BuildContext context, String basePath, String id) {
  GoRouter.of(context).go('$basePath/$id?view=full');
}

/// Navigate to a record's **edit** screen from a detail-screen "Edit"
/// action, preserving the current pane mode: a full-screen view becomes
/// a full-screen edit; a slide-over view becomes a slide-over edit.
/// ([goEntity]'s same-entity branch does not re-add `?view`, so the
/// mode must be carried explicitly here.)
void goEntityEdit(BuildContext context, String basePath, String id) {
  final isFull =
      GoRouterState.of(context).uri.queryParameters['view'] == 'full';
  GoRouter.of(
    context,
  ).go(isFull ? '$basePath/$id/edit?view=full' : '$basePath/$id/edit');
}

/// Navigate to an **existing** record's edit screen with [draft] as the seed,
/// so the form opens showing changes the user hasn't saved yet.
///
/// This is the "Add to invoice" shape: a task / expense / project appends its
/// line items to an invoice the user picked and hands the modified copy over
/// for review rather than saving behind their back. The edit route reads
/// `state.extra` as `cloneFrom` while still loading the row for `existingId`,
/// so the VM gets `initialDraft: draft, original: existing` — Save issues an
/// update (not a create) and the unsaved-changes guard covers the additions.
///
/// `?view=full` is explicit for the same reason as [goEntityCreateFullWidth]:
/// the auto-promote redirect is dedup-suppressible across a cross-branch jump.
/// (`MasterDetailLayout` re-attaches `state.extra` to its internal `go(...)`,
/// so the draft survives either way — this just avoids the extra hop.)
void goEntityEditWithDraft(
  BuildContext context,
  String basePath,
  String id,
  Object draft,
) {
  GoRouter.of(context).go('$basePath/$id/edit?view=full', extra: draft);
}

/// Navigate to an entity's create route with an explicit `?view=full`,
/// passing [extra] as the seed draft. Use this for every cross-entity /
/// clone "new \<thing\>" navigation whose destination defaults to
/// full-width on desktop — `?view=full` is explicit so the editor opens
/// full-width without relying on `MasterDetailLayout`'s auto-promote
/// redirect (which can be dedup-suppressed across cross-branch re-entry,
/// and which silently strips `state.extra` from its own internal
/// `go(...)` call — fixed defensively, but a no-redirect path is more
/// reliable still).
///
/// Do **not** use for entities whose edit defaults to the slide-over
/// panel (`/products`, `/payments`, `/transactions` — see
/// `_kEditDefaultsToSlide` in `master_detail_layout.dart`). For those,
/// plain `context.go('$basePath/new', extra: …)` is correct so the
/// sidebar default is preserved.
void goEntityCreateFullWidth(
  BuildContext context,
  String basePath, {
  Object? extra,
}) {
  // Stage the seed draft on `Services` (immune to the cross-branch jump that
  // drops route `extra:`/query) and bump the route generation so the keyed
  // `/new` route recreates the create screen and its `buildVm` re-reads it —
  // go_router reuses an already-mounted create screen otherwise. `extra:` is
  // still passed on the route for create screens not yet migrated to read the
  // staged draft (transitional; works same-branch only).
  context.read<Services>().stageCreateDraft(basePath, extra);
  GoRouter.of(context).go('$basePath/new?view=full', extra: extra);
}

/// Build the app's [GoRouter].
///
/// `isAuthenticated` is read from `AuthRepository`. The `registry` drives
/// the [StatefulShellRoute.indexedStack] branch list — adding an entity
/// module is one new `EntityBranch` in the registry's branch order, not
/// 30 lines of copy-pasted branch wiring.
GoRouter buildRouter({
  required bool Function() isAuthenticated,
  required String Function() postLoginRoute,
  required Listenable refreshListenable,
  required EntityRegistry registry,
  bool Function()? isClientTooOld,
  bool Function()? isBiometricLockRequired,
  bool Function()? isCompanySetupRequired,
  Set<String> Function()? disabledModuleRoots,
  String initialLocation = '/clients',
}) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      // Server-rejected-our-version wins over every other redirect: a new
      // login or list page would just bounce the same way.
      final tooOld = isClientTooOld?.call() ?? false;
      final atTooOld = state.matchedLocation == '/too-old';
      if (tooOld) {
        // `/too-old` is terminal while the flag is up: the later gates
        // (login, setup, biometric) know nothing about it and would bounce
        // the user straight back off the update screen — a redirect loop
        // for logged-out or biometric-locked users, which go_router renders
        // as the generic route-error view. The screen carries its own
        // sign-out escape hatch, so staying put is always safe.
        return atTooOld ? null : '/too-old';
      }
      if (atTooOld) {
        return isAuthenticated() ? postLoginRoute() : '/login';
      }
      final loggedIn = isAuthenticated();
      // `/login` and `/signup` are the only routes reachable while
      // unauthenticated. After signup, `_persistAndActivate` flips
      // `isAuthenticated()` → the `loggedIn && atAuthPage` rule below
      // bounces to the post-login route automatically (no manual nav).
      final loc = state.matchedLocation;
      final atAuthPage = loc == '/login' || loc == '/signup';
      if (!loggedIn && !atAuthPage) return '/login';
      if (loggedIn && atAuthPage) return postLoginRoute();
      // Biometric gate — only when logged in. Sits *after* the login check
      // (so logout from the lock screen still routes to `/login`) and
      // *before* the setup gate: a biometric-locked user must unlock before
      // being asked to name the company. With both flags up the reverse
      // order looped forever (/setup → /lock → /setup — neither screen
      // could mount, so neither flag could ever clear).
      //
      // We round-trip the intended destination on the `/lock` URL so the
      // unlock can resume the user's deep link rather than dumping them on
      // `postLoginRoute()` — admin-portal's "resume where you left off" is a
      // non-negotiable contract (CLAUDE.md).
      final lockRequired = isBiometricLockRequired?.call() ?? false;
      final atLock = state.matchedLocation == '/lock';
      if (loggedIn && lockRequired) {
        if (!atLock) {
          return '/lock?from=${Uri.encodeQueryComponent(state.uri.toString())}';
        }
        // Locked and at /lock: terminal — no later gate may bounce the user
        // off the lock screen.
        return null;
      }
      if (loggedIn && atLock) {
        final from = state.uri.queryParameters['from'];
        // Guard against `from` pointing back at `/lock` (defence-in-depth —
        // would only happen if the persister somehow saved a `/lock` deep
        // link, which `nav_state_persister.dart` already filters).
        if (from != null && from.isNotEmpty && !from.startsWith('/lock')) {
          return from;
        }
        return postLoginRoute();
      }
      // Setup-wizard gate — when the active company hasn't been named yet,
      // gate every authenticated route behind `/setup`. Sits *after* the
      // login and biometric checks (see above). Matches admin-portal's
      // non-dismissible `SettingsWizard` dialog and React's CompanyEdit
      // modal — same trigger condition, full-screen presentation instead.
      final setupNeeded = loggedIn && (isCompanySetupRequired?.call() ?? false);
      final atSetup = state.matchedLocation == '/setup';
      if (setupNeeded && !atSetup) return '/setup';
      if (!setupNeeded && atSetup) return postLoginRoute();
      // Module gate — a deep link or restored "where you left off" route that
      // points at an entity whose module is now disabled for the active
      // company. Bounce to the safe post-login route (dashboard / clients —
      // both always-on) and carry the entity label so the landing frame can
      // surface a one-time "<Module> is disabled" notice instead of a silent
      // teleport. Sits last: login / setup / biometric gates must win.
      if (loggedIn) {
        final disabledRoots = disabledModuleRoots?.call() ?? const <String>{};
        if (disabledRoots.isNotEmpty &&
            _isUnderDisabledRoot(state.matchedLocation, disabledRoots)) {
          final root = disabledRoots.firstWhere(
            (r) =>
                state.matchedLocation == r ||
                state.matchedLocation.startsWith('$r/'),
          );
          final matches = registry.all.where((e) => e.routePath == root);
          final label = matches.isEmpty ? '' : matches.first.effectiveLabelKey;
          final dest = postLoginRoute();
          return label.isEmpty
              ? dest
              : Uri.parse(
                  dest,
                ).replace(queryParameters: {'module_off': label}).toString();
        }
      }
      // Legacy Integrations URLs. Sits last so the auth / setup gates still win,
      // and works even though these paths no longer match any route: go_router
      // runs the top-level redirect on an error match list too, with
      // `uri` carrying the requested location.
      final legacy = legacyIntegrationsRedirect(state.uri);
      if (legacy != null) return legacy;
      return null;
    },
    errorBuilder: (context, state) => _RouteErrorView(error: state.error),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(path: '/lock', builder: (context, state) => const LockScreen()),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupWizardScreen(),
      ),
      GoRoute(
        path: '/too-old',
        builder: (context, state) => const ClientTooOldScreen(),
      ),
      // Calendar OAuth return. Top-level (outside the shell) so it survives a
      // full-page web reload before the shell/company context is ready; it
      // reads the handoff from the URL, completes, and self-routes to the
      // calendar. Native deep links are bridged here by `CalendarDeepLinks`.
      GoRoute(
        path: '/calendar_connection/complete',
        builder: (context, state) => const CalendarConnectionCompleteScreen(),
      ),
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (context, state, navigationShell) =>
            ScaffoldWithNav(navigationShell: navigationShell),
        branches: [
          for (final spec in registry.branchOrder) _buildBranch(spec, registry),
        ],
      ),
    ],
  );
}

StatefulShellBranch _buildBranch(BranchSpec spec, EntityRegistry registry) {
  switch (spec) {
    case EntityBranch():
      final h = registry[spec.type];
      assert(h != null, 'EntityBranch references unregistered ${spec.type}');
      assert(
        h!.listBuilder != null &&
            h.createBuilder != null &&
            h.detailBuilder != null &&
            h.editBuilder != null,
        'Entity ${spec.type} is in branchOrder but missing screen builders',
      );
      return StatefulShellBranch(
        routes: [
          buildEntityRouteBlock(
            basePath: h!.routePath,
            list: h.listBuilder!,
            create: h.createBuilder!,
            detail: h.detailBuilder!,
            edit: h.editBuilder!,
            extraChildRoutes: h.extraChildRoutes,
          ),
        ],
      );
    case FixedBranch():
      return _buildFixedBranch(spec.kind);
  }
}

StatefulShellBranch _buildFixedBranch(FixedBranchKind kind) {
  switch (kind) {
    case FixedBranchKind.dashboard:
      return StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      );
    case FixedBranchKind.settings:
      return StatefulShellBranch(
        routes: [
          ShellRoute(
            builder: (context, state, child) => SettingsShell(child: child),
            routes: [
              GoRoute(
                path: '/settings',
                // On viewports wide enough for the two-pane layout, the
                // persistent sidebar makes the "select a setting" hint
                // redundant — land directly on Company Details. Narrower
                // widths keep the full-screen master list as the index.
                // Only fires when the user is *exactly* on `/settings`;
                // deep paths pass through untouched. Threshold logic and
                // rationale live in [settingsIndexRedirect].
                redirect: (context, state) {
                  if (state.uri.path != '/settings') return null;
                  return settingsIndexRedirect(
                    screenWidth: MediaQuery.sizeOf(context).width,
                    sidebarCollapsed: context.read<Services>().sidebar.value,
                  );
                },
                builder: (context, state) => const SettingsScreen(),
                routes: settingsRoutes,
              ),
            ],
          ),
        ],
      );
    case FixedBranchKind.outbox:
      return StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/sync/outbox',
            builder: (context, state) => const OutboxScreen(),
          ),
        ],
      );
    case FixedBranchKind.reports:
      return StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      );
    case FixedBranchKind.activity:
      return StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/activity',
            builder: (context, state) => const ActivityScreen(),
          ),
        ],
      );
  }
}

/// Rendered for any URL go_router can't match — a stale bookmark, a bad deep
/// link, or a routing bug. Sits at the root, outside the `StatefulShellRoute`,
/// so it ships its own way home; without this the user loses the shell's
/// sidebar and gets stranded.
///
/// It used to say **"Coming soon"**, which read as *this feature isn't built
/// yet* in exactly the situation where the user needs to know something
/// broke — and it printed the raw `error.toString()` to end users.
class _RouteErrorView extends StatelessWidget {
  const _RouteErrorView({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: tokens.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.explore_off_outlined, size: 64, color: tokens.ink3),
              const SizedBox(height: 16),
              Text(
                context.tr('error_title'),
                style: theme.textTheme.titleMedium?.copyWith(color: tokens.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('error_refresh_page'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: tokens.ink3),
              ),
              // Debug only. This is a stale bookmark, a bad deep link, or a
              // routing bug — the raw exception helps whoever is debugging it
              // and means nothing to a user, so it stays out of release
              // builds. (It's still captured by the diagnostics log.)
              if (error != null && kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: tokens.ink4),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/dashboard'),
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                icon: const Icon(Icons.home_outlined, size: 16),
                label: Text(context.tr('dashboard')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
