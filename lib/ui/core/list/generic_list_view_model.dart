import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;

final _log = Logger('GenericListViewModel');

/// One bulk operation entity list screens expose to the user (Archive,
/// Restore, Delete, future per-entity actions like "Mark Sent"). Each entity
/// declares its own set; the screen lays them out as the multiselect-AppBar
/// buttons and the generic base applies them via [GenericListViewModel.applyBulkAction].
@immutable
class BulkAction<T> {
  const BulkAction({
    required this.id,
    required this.labelKey,
    required this.eligible,
    this.apply,
    this.applyArg,
    this.requiresPassword = false,
  }) : assert(
         apply != null || applyArg != null,
         'BulkAction needs either apply or applyArg',
       );

  /// Stable identifier used for logging + analytics (`archive`, `restore`,
  /// `mark_sent`). Not user-facing.
  final String id;

  /// Localization key for the user-facing label rendered on the AppBar button.
  /// Resolve via `context.tr(action.labelKey)`.
  final String labelKey;

  /// True when [item] is in a state where this action is legal. The base VM
  /// uses this to bucket the selection into eligible/skipped before firing
  /// the per-id mutations.
  final bool Function(T item) eligible;

  /// Per-id apply function — the concrete subclass binds this to its repo
  /// (e.g. `(id) => repo.archive(companyId: companyId, id: id)`). Null only
  /// when [applyArg] is supplied instead (prep-dialog actions).
  final Future<void> Function(String id)? apply;

  /// Per-id apply that also receives the one-shot value gathered by the
  /// screen's prep dialog (email template/subject/body, chosen group id,
  /// chosen template id, …). When non-null this takes precedence over
  /// [apply]; the screen passes the prepared value via
  /// `applyBulkAction(action, arg: prepared)`. `arg` is `null` for actions
  /// with no prep step.
  final Future<void> Function(String id, Object? arg)? applyArg;

  /// True when the server requires `X-API-PASSWORD-BASE64` (destructive ops
  /// like delete/purge). `EntityListScreenScaffold._onBulk` primes the
  /// password cache via `showConfirmPasswordSheet` *before* enqueuing, so
  /// rows that drain within the cache window skip the 412 park path;
  /// cancelling the prompt aborts the whole bulk op. The base VM just
  /// carries the flag.
  final bool requiresPassword;
}

/// Generic list-screen ViewModel. Owns pagination, search, sort, filter,
/// multiselect, column selection, and the nav_state filter-persistence
/// machinery. Concrete subclasses (`ClientListViewModel`,
/// `InvoiceListViewModel`, …) plug in:
///   * the entity type + entity-specific column registry
///   * the repository calls (`fetchPage`, `watchPage`, `archive`, ...)
///   * the entity-specific eligibility predicates (via [bulkActions])
///   * the id / archived-at / is-deleted extractors
///
/// The base persists filters under `nav_state.filters_json` at
/// `companyId → <entityType.name> → {...}` so the shape lives in exactly one
/// place. Adding a new entity inherits restore-where-you-left-off for free.
abstract class GenericListViewModel<T> extends ChangeNotifier {
  GenericListViewModel({
    required this.companyId,
    required this.navStateDao,
    required this.userSettings,
    this.savedViews,
    Duration searchDebounce = const Duration(milliseconds: 250),
    Duration persistDebounce = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _searchDebounce = searchDebounce,
       _persistDebounce = persistDebounce,
       _now = now ?? DateTime.now {
    // Show a spinner from the very first frame; hydration + initial fetch
    // both clear it.
    isLoadingPage = true;
    _sortField = defaultSortField;
    _columnIds = List<String>.from(defaultColumnIds);
    unawaited(_init());
  }

  // ── Configuration (provided by concrete subclasses) ─────────────────

  /// The entity this VM lists. Used as the persistence sub-key and the
  /// user-settings entity discriminator. Must match the value the entity
  /// declares in [EntityRegistry].
  EntityType get entityType;

  /// Every column the entity knows how to render — used by the column-picker
  /// and to validate persisted sort fields. Mirrors `kAllClientColumns`.
  List<ColumnDefinition<T>> get allColumns;

  /// Columns shown when the user has never customised. Order matters.
  /// Mirrors `kDefaultClientColumns`.
  List<String> get defaultColumnIds;

  /// Column the list sorts by when no persisted preference exists. Must be
  /// a key in [allColumns].
  String get defaultSortField;

  /// True when [field] is a column id this entity recognises. The base uses
  /// this both as a sort-allowlist check and during hydration so a stale
  /// persisted blob can't drive the DAO with a garbage column id.
  bool isValidColumnId(String field);

  /// Extract the entity's id (real or `tmp_`). Used by the multiselect set.
  String idOf(T item);

  /// `true` when the entity is active (eligible for "Archive"). The base
  /// uses this only for [hasActiveFilters] / debug — the per-action
  /// eligibility check lives on [BulkAction.eligible].
  bool isArchived(T item);
  bool isDeleted(T item);

  // ── Data-source hooks (provided by concrete subclasses) ─────────────

  /// Watch the first `loadedPages` worth of rows under the current filter
  /// state. Called whenever filters change; the base owns the subscription
  /// lifecycle.
  Stream<List<T>> watchPage();

  /// Fetch one page from the server and upsert into Drift. Returns true
  /// when more pages may exist.
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  });

  /// Pull-to-refresh entry point.
  Future<void> refreshAll();

  /// Distinct non-empty values for the `customValue<columnIndex>` column,
  /// used by the custom-filter dropdown. Defaults to an empty stream so
  /// entities without custom-field filtering (most of them) don't need to
  /// override.
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      Stream<List<String>>.value(const <String>[]);

  /// Bulk actions the entity exposes. Each entity declares its own; the
  /// base renders / applies them generically.
  Iterable<BulkAction<T>> get bulkActions;

  /// Optional client-side transform applied on top of [watchPage]'s stream
  /// before items reach the view. Defaults to identity — Clients and Products
  /// override nothing.
  ///
  /// Use this only for filters / orderings the **server doesn't expose** (e.g.
  /// Invoice "unpaid" = `balance > 0` computed from already-fetched rows).
  /// Server-side filters belong in `extraFilters` so they ride the cursor —
  /// transforming after the fact breaks pagination counts.
  @protected
  Stream<List<T>> transformPage(Stream<List<T>> raw) => raw;

  /// True while a **local-only** filter (one the server can't evaluate, e.g.
  /// the products `stock:` predicate or the tasks/projects `tag:` filter) is
  /// active. When set, [_onItems] auto-chains [loadMore] while the filtered
  /// emission is shorter than a page and the server has more rows — without
  /// it a short filtered result has no scrollable extent, the scroll-driven
  /// load-more trigger never fires, and the list shows a false "No records
  /// found" while matches sit on unfetched pages. Bounded by
  /// [_kAutoChainMaxPages] per filter/search/sort change so completeness
  /// stays page-bounded (by design) instead of sweeping the whole table.
  @protected
  bool get localOnlyFilterActive => false;

  /// Rows per fetched page — the auto-chain's "shorter than a page" fill
  /// target. Repos default to 50; override only if an entity pages
  /// differently.
  @protected
  int get pageSize => 50;

  /// [filters] without [key] — for a [localOnlyFilterActive] VM's
  /// `fetchPage` to strip its local-only key (products `stock`,
  /// tasks/projects `tag_ids`) from the network fetch. Load-bearing:
  /// keeping the server filter alongside a post-LIMIT local filter freezes
  /// the window after ⌈matches/pageSize⌉ pages (`hasMore` goes false while
  /// the local window still shows unfiltered rows); fully-local keeps
  /// window ↔ pages aligned so scroll + the auto-chain converge. Returns
  /// the same instance when [key] is absent.
  @protected
  static Map<String, Set<String>> extraFiltersWithout(
    Map<String, Set<String>> filters,
    String key,
  ) => filters.containsKey(key)
      ? (Map<String, Set<String>>.from(filters)..remove(key))
      : filters;

  // ── Inputs ──────────────────────────────────────────────────────────

  final String companyId;
  final NavStateDao navStateDao;
  final UserSettingsRepository userSettings;

  /// Saved-view repository, used by the list-screen toolbar to capture and
  /// recall named filter snapshots. Optional so existing tests don't have
  /// to construct one — production wiring always supplies it.
  final SavedViewsRepository? savedViews;

  final Duration _searchDebounce;
  final Duration _persistDebounce;
  final DateTime Function() _now;

  // ── State (read by the view) ────────────────────────────────────────

  int loadedPages = 1;
  bool hasMore = true;
  bool isLoadingPage = false;
  String? initialError;

  /// Monotonic generation counter for page fetches. Every [_resetAndReload]
  /// (and the initial load) bumps it; an in-flight [loadMore] — or an older
  /// reset — whose `await fetchPage` returns *after* a newer reset started
  /// sees the epoch advanced and discards its result. Without this a filter /
  /// search / sort change during an in-flight `loadMore` (which guards on
  /// `isLoadingPage`, but `_resetAndReload` does not) would let two fetches
  /// race and clobber `loadedPages` / `hasMore` or leave a stuck spinner. The
  /// repo-level keyset-cursor read-modify-write stays regress-only and safe.
  int _fetchEpoch = 0;

  /// Auto-chain allowance for [localOnlyFilterActive] mode, re-armed on every
  /// epoch bump (initial load + any filter/search/sort reset). Caps the
  /// number of pages fetched without a user scroll so an offline failure or
  /// a huge table can't turn the chain into a hot loop / full-table sweep.
  static const int _kAutoChainMaxPages = 5;
  int _autoChainBudget = _kAutoChainMaxPages;

  String _search = '';
  String get search => _search;

  Set<EntityState> _states = const {EntityState.active};
  Set<EntityState> get states => _states;

  late String _sortField;
  String get sortField => _sortField;

  bool _sortAscending = true;
  bool get sortAscending => _sortAscending;

  Map<int, Set<String>> _customFilters = const {};
  Map<int, Set<String>> get customFilters => _customFilters;

  /// `extraFilters` for the server fetch, with single-value custom-field
  /// slots folded in as `custom_value{n}`. The backend `custom_value{n}`
  /// filter is a single substring `LIKE %v%`, so only a slot with exactly
  /// one selected value is sent; multi-value slots stay local-only (the
  /// Drift `customValuesN` predicate is the source of truth — same
  /// local-cache-bounded limitation class as partial-sync). Returns the
  /// unmodified `_extraFilters` when there are no custom filters.
  Map<String, Set<String>> _serverExtraFilters() {
    if (_customFilters.isEmpty) return _extraFilters;
    final merged = Map<String, Set<String>>.from(_extraFilters);
    _customFilters.forEach((slot, values) {
      if (values.length == 1) {
        merged['custom_value$slot'] = values;
      }
    });
    return merged;
  }

  /// Open-ended filter slots keyed by the server param name
  /// (`country_id`, `group_settings_id`, …). Each [FilterKey] that doesn't
  /// have a dedicated slot on this VM (states / customFilters) writes here
  /// instead. The map's keys are the flat query-string keys the v2 API
  /// expects — no wrapping (`filter[country_id]` is wrong; `country_id` is
  /// right).
  Map<String, Set<String>> _extraFilters = const {};
  Map<String, Set<String>> get extraFilters => _extraFilters;

  /// Filter-key ids ([FilterKey.id]) suppressed because this list is
  /// already scoped to a parent record (embedded on a detail page) —
  /// every row matches that dimension, so offering it as a filter is
  /// noise. Default empty (top-level lists filter freely).
  Set<String> get lockedFilterKeyIds => const {};

  /// True when this list is embedded inside a parent detail page (scoped to a
  /// parent record). Derived from [lockedFilterKeyIds] — by design every
  /// embedded list locks at least one filter dimension and every standalone
  /// list locks none, and the getter resolves correctly at base-constructor
  /// time (the subclass's scoping fields are assigned before `super()` runs).
  ///
  /// Embedded lists must NOT read or write the shared per-entity `nav_state`
  /// slot: that slot is the *standalone* list's "resume where you left off"
  /// view. Sharing it lets a detail tab inherit (and, on interaction,
  /// overwrite) the main list's saved search/sort/filters. So embedded lists
  /// keep filter state purely in memory, starting from their locked scope.
  bool get isEmbedded => lockedFilterKeyIds.isNotEmpty;

  List<T> _items = const [];
  List<T> get items => _items;

  /// Number of items currently loaded (the visible / paged-in slice).
  /// Drives the "Showing N of M" footer text.
  int get count => _items.length;

  /// Total row count if the server has reported one. Currently null
  /// until the server-side total endpoint is wired (M3+); the footer
  /// renders "Showing N" without "of M" when this is null.
  int? get total => null;

  /// Resolve the next item's id after [currentId], optionally
  /// constrained by [where]. Returns null when [currentId] isn't in
  /// the list, when there's no next item, or when no subsequent item
  /// matches [where]. Used by:
  ///   * Auto-advance after Convert / Save / Archive in the right pane
  ///     (route to the next eligible row instead of collapsing the
  ///     pane back to the bare URL).
  ///   * J / `↓` keyboard nav in master-detail mode.
  String? nextItemIdAfter(String currentId, {bool Function(T)? where}) {
    final i = _items.indexWhere((e) => idOf(e) == currentId);
    if (i < 0) return null;
    for (var j = i + 1; j < _items.length; j++) {
      final cand = _items[j];
      if (where == null || where(cand)) return idOf(cand);
    }
    return null;
  }

  /// Resolve the previous item's id before [currentId], optionally
  /// constrained by [where]. Returns null when [currentId] isn't in
  /// the list, when there's no previous item, or when no preceding
  /// item matches [where]. Used by `K` / `↑` keyboard nav.
  String? prevItemIdBefore(String currentId, {bool Function(T)? where}) {
    final i = _items.indexWhere((e) => idOf(e) == currentId);
    if (i <= 0) return null;
    for (var j = i - 1; j >= 0; j--) {
      final cand = _items[j];
      if (where == null || where(cand)) return idOf(cand);
    }
    return null;
  }

  late List<String> _columnIds;
  List<ColumnDefinition<T>> get columns => _resolveColumns(_columnIds);
  List<String> get columnIds => List.unmodifiable(_columnIds);

  /// Whether the user has an explicit stored column preference (vs sitting on
  /// the registry default). A saved view only persists `columnIds` when this
  /// is true — otherwise applying the view would force the default layout
  /// into `user_settings` and queue a no-op `user_settings` PUT.
  bool _columnsCustomized = false;

  String? _transientNotice;

  String? consumeTransientNotice() {
    final n = _transientNotice;
    _transientNotice = null;
    return n;
  }

  /// One-shot background-failure record (pull-to-refresh / load-more),
  /// consumed by the scaffold on the rebuild the [_flashError] notify
  /// triggers — same idiom as [consumeTransientNotice]. A plain getter that
  /// nulls itself synchronously could never be observed by a
  /// `ListenableBuilder` (builders run next frame); the consume shape is
  /// what makes the failure actually reach the user. `message` is already
  /// prefix-stripped via [formatNotifyError]; `kind` (`refresh` /
  /// `load_more`) selects the localized headline + retry callback.
  ({String kind, String message})? _transientError;

  ({String kind, String message})? consumeTransientError() {
    final e = _transientError;
    _transientError = null;
    return e;
  }

  /// True when any filter is non-default. Drives the clear-filters button and
  /// the filtered-empty-state copy.
  ///
  /// A changed SORT is deliberately NOT counted: sorting never changes whether
  /// a filter is applied or whether a list is empty, so it isn't an "active
  /// filter" (and the clear button shouldn't appear for a sort-only change).
  /// `clearAllFilters` still resets sort via its own independent check.
  bool get hasActiveFilters {
    // `{}` (empty) and `{active}` are both "no status filter": the
    // server-side `client_status` param is omitted and the watch query
    // doesn't constrain. Treat them equivalently so removing the only
    // status chip doesn't flip the empty-state copy to "no matches".
    if (_states.isNotEmpty &&
        (_states.length != 1 || !_states.contains(EntityState.active))) {
      return true;
    }
    for (final values in _customFilters.values) {
      if (values.isNotEmpty) return true;
    }
    for (final values in _extraFilters.values) {
      if (values.isNotEmpty) return true;
    }
    return _search.isNotEmpty;
  }

  // ── Internals ───────────────────────────────────────────────────────

  StreamSubscription<List<T>>? _watchSub;
  StreamSubscription<List<String>?>? _columnsSub;
  StreamSubscription<NavStateData?>? _navStateSub;
  final List<StreamSubscription<List<String>>> _customValuesSubs = [];
  Timer? _searchTimer;
  Timer? _persistTimer;
  bool _hydrated = false;

  /// Discard the very first `watchCurrent` emission. Drift fires the current
  /// row right after subscription, but [_hydrate] already read that exact
  /// row synchronously. If the user mutates a filter in the few microtasks
  /// between subscription and first emission, the listener would otherwise
  /// see slot != currentSnapshot and overwrite the user's change with the
  /// stale on-disk value.
  bool _navStateSeen = false;

  /// The last `filters_json` slot for this entity the VM has observed on
  /// disk or written itself. The nav_state watch reacts only when an
  /// emission's decoded slot differs from this — so a write that touched
  /// the shared `nav_state` row for an unrelated reason (route change,
  /// another entity's filter persist, our own debounced echo) can't clobber
  /// in-memory filters not yet persisted (e.g. a freshly applied dashboard
  /// deep-link intent).
  Map<String, dynamic>? _lastSeenSlot;

  /// Synchronous cache of the most recently emitted distinct custom values
  /// per column (1..4). Populated by subscribing to
  /// [watchDistinctCustomValues] in [_init]; cleared on dispose. Powers
  /// the cross-key picker's `quickValueSuggestions` for `CustomFieldFilterKey`
  /// (it needs same-frame results per keystroke, which the async stream
  /// path can't provide).
  ///
  /// Entities whose [watchDistinctCustomValues] returns empty streams
  /// (e.g. Product) leave the corresponding entries empty — the lookup
  /// then surfaces nothing, matching today's behaviour.
  Map<int, List<String>> _distinctCustomValuesCache = const {};

  /// Latest distinct custom values cached for [columnIndex] (1..4), or
  /// empty if the stream hasn't emitted yet or the entity doesn't have
  /// custom values. Synchronous — safe to call from build/rebuild hot
  /// paths.
  List<String> distinctCustomValues(int columnIndex) =>
      _distinctCustomValuesCache[columnIndex] ?? const [];

  Future<void> _init() async {
    await _hydrate();
    // A deep-link intent that arrived before hydration finished is applied
    // here — *after* the on-disk filters, *before* the first fetch — so a
    // dashboard tap doesn't fetch twice on cold start, and the persisted
    // working filter is replaced by the panel's filter (not merged onto it).
    final pending = _pendingIntent;
    if (pending != null) {
      _pendingIntent = null;
      _applyIntentState(pending);
      _schedulePersist();
    }
    _subscribeColumns();
    _subscribe();
    _subscribeCustomValues();
    // Embedded lists ignore saved-view / nav_state writes — they're scoped to
    // a parent record, not the user's standalone "resume where you left off".
    if (!isEmbedded) _subscribeNavState();
    await _loadInitialPage();
  }

  void _subscribeCustomValues() {
    for (var i = 1; i <= 4; i++) {
      final columnIndex = i;
      _customValuesSubs.add(
        watchDistinctCustomValues(columnIndex).listen((values) {
          // Skip the rebuild when the cache content is unchanged — Drift
          // streams re-emit on every page load + watch invalidation, and
          // the cross-key picker doesn't care about identity stability.
          final existing =
              _distinctCustomValuesCache[columnIndex] ?? const <String>[];
          if (listEquals(existing, values)) return;
          _distinctCustomValuesCache = {
            ..._distinctCustomValuesCache,
            columnIndex: values,
          };
          notifyListeners();
        }),
      );
    }
  }

  void _subscribeColumns() {
    _columnsSub = userSettings
        .watchColumns(companyId: companyId, entityType: entityType)
        .listen((ids) {
          // Track customization independently of the layout diff below: a
          // stored preference that happens to equal the default still means
          // the user has an explicit preference.
          _columnsCustomized = ids != null && ids.isNotEmpty;
          final next = ids == null || ids.isEmpty
              ? List<String>.from(defaultColumnIds)
              : List<String>.from(ids);
          if (listEquals(next, _columnIds)) return;
          _columnIds = next;
          notifyListeners();
        });
  }

  Future<void> _hydrate() async {
    if (isEmbedded) {
      // Don't read the shared standalone-list filter slot. Mark ready (so the
      // watch subscription + actions engage) with the in-memory default state
      // (the locked parent scope) as the baseline.
      _hydrated = true;
      _lastSeenSlot = currentSnapshot();
      return;
    }
    try {
      final row = await navStateDao.current();
      final raw = row?.filtersJson;
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final company = decoded[companyId];
      if (company is! Map) return;
      final entity = company[entityType.name];
      if (entity is! Map) return;
      _applyDecoded(Map<String, dynamic>.from(entity));
    } catch (e, st) {
      // Treat a corrupt blob as "no saved filters" — better to fall back to
      // defaults than to crash the list screen.
      _log.warning('Failed to hydrate filters_json; using defaults', e, st);
    } finally {
      _hydrated = true;
      // Baseline = the real on-disk slot (defaults when no row). Any
      // `_pendingIntent` is applied later in `_init`, so this deliberately
      // reflects the pre-intent disk state.
      _lastSeenSlot = currentSnapshot();
    }
  }

  /// Overwrite the VM's filter+sort+search state from a snapshot map (the
  /// per-entity slot inside `nav_state.filters_json`). Used both by initial
  /// hydration and by the saved-view apply path.
  ///
  /// Crucially, every field is **reset to its constructor default first**
  /// before reading from [entity]. Without that, applying a snapshot that
  /// omits a key (e.g. `extraFilters: {}`) would silently leave the previous
  /// in-memory value in place — applying a "clean" saved view would carry
  /// over yesterday's stale country filter.
  void _applyDecoded(Map<String, dynamic> entity) {
    _search = '';
    _states = const {EntityState.active};
    _sortField = defaultSortField;
    _sortAscending = true;
    _customFilters = const {};
    _extraFilters = const {};

    final search = entity['search'];
    if (search is String) _search = search;

    final statesList = entity['states'];
    if (statesList is List) {
      final hydrated = <EntityState>{};
      for (final name in statesList) {
        for (final s in EntityState.values) {
          if (s.name == name) hydrated.add(s);
        }
      }
      _states = hydrated;
    }

    final sortField = entity['sortField'];
    if (sortField is String && isValidColumnId(sortField)) {
      _sortField = sortField;
    }

    final ascending = entity['sortAscending'];
    if (ascending is bool) _sortAscending = ascending;

    final customs = entity['customFilters'];
    if (customs is Map) {
      final next = <int, Set<String>>{};
      customs.forEach((key, value) {
        final idx = int.tryParse(key.toString());
        if (idx == null || idx < 1 || idx > 4) return;
        if (value is List) {
          final values = value.whereType<String>().toSet();
          if (values.isNotEmpty) next[idx] = values;
        }
      });
      _customFilters = next;
    }

    // `extraFilters` was introduced after `customFilters` — missing key
    // means a pre-extraFilters blob, which hydrates to an empty map.
    // Backward-compatible read; no version discriminator needed.
    final extras = entity['extraFilters'];
    if (extras is Map) {
      final next = <String, Set<String>>{};
      extras.forEach((key, value) {
        if (key is! String || key.isEmpty) return;
        if (value is List) {
          final values = value.whereType<String>().toSet();
          if (values.isNotEmpty) next[key] = values;
        }
      });
      _migrateLegacyUpdatedBetween(next);
      _extraFilters = next;
    }
  }

  /// One-time migration of a persisted legacy `updated_between` filter into
  /// the `updated_at_range` window the `updated` [DateColumnFilterKey] now
  /// uses. The clients list used to expose a standalone "Updated between"
  /// dropdown entry whose 2-part `start,end` wire lived under
  /// `updated_between`; it's now folded into the `updated` key's `between`
  /// operator (3-part `updated_at,start,end` under `updated_at_range`).
  ///
  /// Without this rewrite an upgrading user's saved filter would become a
  /// stuck, chip-less filter — no key reads `updated_between` anymore, so it
  /// renders no chip yet still rides to the server fetch, with the global
  /// "Clear filters" the only escape. Only the clients list ever persisted
  /// this key, so the migration is a no-op everywhere else. Mutates [next]
  /// in place; drops the legacy slot even when malformed (so it can't linger).
  static void _migrateLegacyUpdatedBetween(Map<String, Set<String>> next) {
    final legacy = next['updated_between'];
    if (legacy == null || legacy.isEmpty) return;
    if ((next['updated_at_range'] ?? const <String>{}).isNotEmpty) {
      // A real new-style window already exists — don't clobber it.
      next.remove('updated_between');
      return;
    }
    final parts = legacy.first.split(',');
    if (parts.length >= 2) {
      final start = parts[parts.length - 2].trim();
      final end = parts[parts.length - 1].trim();
      if (start.isNotEmpty && end.isNotEmpty) {
        next['updated_at_range'] = {'updated_at,$start,$end'};
      }
    }
    next.remove('updated_between');
  }

  /// The filter+sort+search payload as it would be written to
  /// `nav_state.filters_json`. Six fields, no columns — columns are stored
  /// separately in [UserSettings] and changing one shouldn't cause a
  /// nav_state rewrite. Saved views capture more than this; see
  /// [savedViewSnapshot].
  Map<String, dynamic> currentSnapshot() => <String, dynamic>{
    'search': _search,
    'states': _states.map((s) => s.name).toList(),
    'sortField': _sortField,
    'sortAscending': _sortAscending,
    'customFilters': <String, List<String>>{
      for (final entry in _customFilters.entries)
        entry.key.toString(): entry.value.toList(),
    },
    'extraFilters': <String, List<String>>{
      for (final entry in _extraFilters.entries)
        entry.key: entry.value.toList(),
    },
  };

  /// [currentSnapshot]'s shape at the constructor defaults. The `nav_state`
  /// listener uses this as the stand-in slot when this entity's slot is
  /// absent, so its existing `eq.equals(slot, currentSnapshot())` dedupe
  /// stays accurate (no spurious reload when already at defaults).
  Map<String, dynamic> _defaultSnapshot() => <String, dynamic>{
    'search': '',
    'states': [EntityState.active.name],
    'sortField': defaultSortField,
    'sortAscending': true,
    'customFilters': <String, List<String>>{},
    'extraFilters': <String, List<String>>{},
  };

  /// The full payload a Saved View captures: [currentSnapshot] plus the
  /// current column selection. Columns are deliberately *not* in
  /// [currentSnapshot] (which writes to `nav_state.filters_json` on every
  /// filter change) — they already live in [UserSettings]. Saved views are
  /// the one place that needs both, so the column list is added here.
  Map<String, dynamic> savedViewSnapshot() => <String, dynamic>{
    ...currentSnapshot(),
    // Only persist a column override when the user actually has one. On the
    // default layout, omitting the key makes `apply()` leave columns
    // untouched (its legacy no-`columnIds` path) instead of forcing the
    // default into `user_settings` and queuing a no-op PUT.
    if (_columnsCustomized) 'columnIds': List<String>.from(_columnIds),
  };

  /// Overwrite the VM's filter state from [snapshot] and reload page 1.
  /// Production code drives this via the nav-state watch subscription
  /// (the saved-view repo writes through to `nav_state.filters_json`); this
  /// is exposed for tests and direct in-process use.
  Future<void> applySnapshot(Map<String, dynamic> snapshot) async {
    _applyDecoded(snapshot);
    await _resetAndReload(ignoreCursor: true);
  }

  // ── Dashboard deep-link intents ─────────────────────────────────────

  /// The most recent [ListFilterIntent.token] this VM has consumed. The
  /// scaffold reads `GoRouterState.extra` on every build and calls
  /// [applyDeepLinkIntent]; this guard makes a repeat call with the same
  /// token a no-op so a rebuild can't re-apply (and clobber) a filter the
  /// user has since changed by hand.
  String? lastConsumedIntentToken;

  /// Set when a deep-link intent arrives before [_hydrate] has completed.
  /// [_init] applies it right after hydration so cold-start navigation
  /// doesn't double-fetch.
  ListFilterIntent? _pendingIntent;

  /// Overwrite filter+sort+search state from a dashboard [ListFilterIntent].
  /// Like [_applyDecoded] this resets every dimension to its default first,
  /// then applies the intent — a "show me exactly the panel's records"
  /// directive must not inherit the user's leftover client/status filter,
  /// so this is a replace, not a merge.
  void _applyIntentState(ListFilterIntent intent) {
    _search = '';
    _states = intent.states != null
        ? Set<EntityState>.unmodifiable(intent.states!)
        : const {EntityState.active};
    _sortField =
        (intent.sortField != null && isValidColumnId(intent.sortField!))
        ? intent.sortField!
        : defaultSortField;
    _sortAscending = intent.sortAscending ?? true;
    _customFilters = const {};
    _extraFilters = Map<String, Set<String>>.unmodifiable({
      for (final e in intent.extraFilters.entries)
        if (e.value.isNotEmpty) e.key: Set<String>.unmodifiable(e.value),
    });
  }

  /// Apply a dashboard deep-link [intent] and reload page 1. Idempotent per
  /// [ListFilterIntent.token]; the applied filter persists as the user's
  /// working filter (via [_resetAndReload] → [_schedulePersist]), matching
  /// the "resume where you left off" contract.
  Future<void> applyDeepLinkIntent(ListFilterIntent intent) async {
    if (intent.token == lastConsumedIntentToken) return;
    lastConsumedIntentToken = intent.token;
    if (!_hydrated) {
      // _init() applies it after hydrate, before the first fetch.
      _pendingIntent = intent;
      return;
    }
    _applyIntentState(intent);
    await _resetAndReload(ignoreCursor: true);
  }

  // ── Public actions ──────────────────────────────────────────────────

  Future<void> refresh() async {
    try {
      await refreshAll();
    } catch (e) {
      _flashError('refresh', e);
    }
  }

  Future<void> loadMore() async {
    if (isLoadingPage || !hasMore) return;
    final epoch = _fetchEpoch;
    isLoadingPage = true;
    notifyListeners();
    try {
      final more = await fetchPage(
        page: loadedPages + 1,
        search: _search.isEmpty ? null : _search,
        states: _states,
        extraFilters: _serverExtraFilters(),
        ignoreCursor: false,
      );
      // A reset (filter/search/sort/saved-view change) started while this page
      // was in flight — its result is authoritative, so discard ours.
      if (_fetchEpoch != epoch) return;
      loadedPages += 1;
      hasMore = more;
      // Re-subscribe so the Drift watch widens its `LIMIT` to the new
      // `pageSize * loadedPages` window. watchPage() captures `loadedPages`
      // at subscription time, so without this the newly-fetched rows land in
      // Drift but never reach the UI (the stream keeps emitting only page 1).
      _resubscribe();
    } catch (e) {
      if (_fetchEpoch != epoch) return;
      _flashError('load_more', e);
    } finally {
      if (_fetchEpoch == epoch) {
        isLoadingPage = false;
        notifyListeners();
      }
    }
  }

  void setSearch(String value, {bool immediate = false}) {
    final next = value.trim();
    if (next == _search) return;
    _searchTimer?.cancel();
    if (immediate) {
      // Explicit commit (Enter / "Search for" row / soft-keyboard Done):
      // apply now instead of debouncing, so the result is deterministic and
      // the list shows it the instant we pop back to it. Search-as-you-type
      // keeps the default debounced path.
      unawaited(_applySearch(next));
      return;
    }
    _searchTimer = Timer(_searchDebounce, () => _applySearch(next));
  }

  Future<void> _applySearch(String value) async {
    _search = value;
    // A non-empty search is a filtered VIEW: ignore the keyset cursor so the
    // server searches across full history (not just the delta window) and the
    // matches are pulled into Drift for the local watch. The repo also treats
    // `search != null/isNotEmpty` as a view and refuses to ADVANCE the cursor,
    // so this `ignoreCursor: true` can't corrupt the global delta watermark.
    // Clearing the search (empty value) returns to the normal page-1 delta.
    await _resetAndReload(ignoreCursor: value.isNotEmpty);
  }

  Future<void> setStates(Set<EntityState> next) async {
    if (setEquals(next, _states)) return;
    final isWidening = next.isEmpty || next.difference(_states).isNotEmpty;
    _states = Set.unmodifiable(next);
    await _resetAndReload(ignoreCursor: isWidening);
  }

  void toggleState(EntityState s) {
    final next = Set<EntityState>.from(_states);
    if (!next.remove(s)) next.add(s);
    unawaited(setStates(next));
  }

  Future<void> setSort({required String field, required bool ascending}) async {
    if (!isValidColumnId(field)) return;
    if (field == _sortField && ascending == _sortAscending) return;
    _sortField = field;
    _sortAscending = ascending;
    await _resetAndReload(ignoreCursor: false);
  }

  Future<void> setCustomFilter({
    required int columnIndex,
    required Set<String> values,
  }) async {
    assert(columnIndex >= 1 && columnIndex <= 4);
    final next = Map<int, Set<String>>.from(_customFilters);
    if (values.isEmpty) {
      if (next.remove(columnIndex) == null) return;
    } else {
      if (setEquals(next[columnIndex], values)) return;
      next[columnIndex] = Set.unmodifiable(values);
    }
    _customFilters = Map.unmodifiable(next);
    await _resetAndReload(ignoreCursor: false);
  }

  /// Set / clear the value set under `serverKey` in [extraFilters]. The
  /// caller is responsible for using a key the API actually accepts as a
  /// flat query param (`country_id`, `group_settings_id`). Passing an
  /// empty set removes the entry entirely.
  Future<void> setExtraFilter({
    required String serverKey,
    required Set<String> values,
  }) async {
    assert(serverKey.isNotEmpty);
    final next = Map<String, Set<String>>.from(_extraFilters);
    if (values.isEmpty) {
      if (next.remove(serverKey) == null) return;
    } else {
      if (setEquals(next[serverKey], values)) return;
      next[serverKey] = Set.unmodifiable(values);
    }
    _extraFilters = Map.unmodifiable(next);
    await _resetAndReload(ignoreCursor: false);
  }

  /// Move a single comparable filter from one server key to another in
  /// one shot: clear `fromServerKey` (and optionally `alsoClearServerKey`,
  /// e.g. the target's `_range` window slot) and set `toServerKey` to
  /// `{wireValue}`. One [_resetAndReload] / notify — used by the chip
  /// field-segment switcher so a swap doesn't double-fetch.
  Future<void> swapExtraFilter({
    required String fromServerKey,
    required String toServerKey,
    required String wireValue,
    String? alsoClearServerKey,
  }) async {
    assert(fromServerKey.isNotEmpty && toServerKey.isNotEmpty);
    assert(wireValue.isNotEmpty);
    final next = Map<String, Set<String>>.from(_extraFilters)
      ..remove(fromServerKey);
    if (alsoClearServerKey != null) next.remove(alsoClearServerKey);
    final values = {wireValue};
    if (setEquals(next[toServerKey], values) &&
        !_extraFilters.containsKey(fromServerKey) &&
        (alsoClearServerKey == null ||
            !_extraFilters.containsKey(alsoClearServerKey))) {
      return;
    }
    next[toServerKey] = Set.unmodifiable(values);
    _extraFilters = Map.unmodifiable(next);
    await _resetAndReload(ignoreCursor: false);
  }

  Future<void> clearAllFilters() async {
    // Gate the early-return on whether any field actually differs from its
    // cleared target — NOT on `hasActiveFilters`. The cleared target for
    // state is `{active}` (the default), so "state differs" means the
    // current set is anything other than exactly `{active}` (`{}`,
    // `{archived}`, `{active, deleted}`, …). Without this an explicit
    // clear from `{}` or `{archived}` would be a silent no-op.
    final statesAtDefault =
        _states.length == 1 && _states.contains(EntityState.active);
    final changed =
        _search.isNotEmpty ||
        !statesAtDefault ||
        _sortField != defaultSortField ||
        !_sortAscending ||
        _customFilters.isNotEmpty ||
        _extraFilters.isNotEmpty;
    _search = '';
    // Reset state to the default `{active}` rather than dropping the
    // dimension. "Clear filters" means "show me the normal list", which
    // for state is active-only — leaving a single removable `State:
    // Active` chip (the clear button hides itself in that case, so it
    // doesn't read as "a filter is still applied").
    _states = const {EntityState.active};
    _sortField = defaultSortField;
    _sortAscending = true;
    _customFilters = const {};
    _extraFilters = const {};
    if (!changed) return;
    await _resetAndReload(ignoreCursor: false);
  }

  Stream<List<String>> watchCustomValueOptions(int columnIndex) =>
      watchDistinctCustomValues(columnIndex);

  Future<void> setColumns(List<String> ids) async {
    final next = List<String>.unmodifiable(ids);
    if (listEquals(next, _columnIds)) return;
    _columnIds = next;
    // Explicit user choice — mark eagerly so a saved view captured before the
    // userSettings watch round-trips still records the column override.
    _columnsCustomized = true;
    notifyListeners();
    await userSettings.setColumns(
      companyId: companyId,
      entityType: entityType,
      columns: next,
    );
  }

  Future<void> resetColumns() async {
    _columnIds = List<String>.from(defaultColumnIds);
    _columnsCustomized = false;
    notifyListeners();
    await userSettings.resetColumns(
      companyId: companyId,
      entityType: entityType,
    );
  }

  Future<void> retryInitial() async {
    initialError = null;
    notifyListeners();
    await _loadInitialPage();
  }

  Future<void> _loadInitialPage() async {
    final epoch = ++_fetchEpoch;
    _autoChainBudget = _kAutoChainMaxPages;
    isLoadingPage = true;
    notifyListeners();
    try {
      final more = await fetchPage(
        page: 1,
        search: _search.isEmpty ? null : _search,
        states: _states,
        extraFilters: _serverExtraFilters(),
        ignoreCursor: false,
      );
      if (_fetchEpoch != epoch) return;
      hasMore = more;
    } catch (e) {
      if (_fetchEpoch != epoch) return;
      initialError = formatNotifyError(e);
    } finally {
      if (_fetchEpoch == epoch) {
        isLoadingPage = false;
        notifyListeners();
        // #25: the page-1 watch emission arrives *mid-load* (while
        // `isLoadingPage` was still true), so `_maybeAutoChain` bailed and a
        // short local-only-filtered page (`stock:`/`tag:`) would dead-end on a
        // false "No records found". Re-run the watch now that the load has
        // settled so the replayed emission drives the auto-chain — mirrors the
        // post-fetch `_resubscribe()` `loadMore` already does. Gated on
        // `localOnlyFilterActive` so ordinary lists are untouched.
        if (localOnlyFilterActive) _resubscribe();
      }
    }
  }

  Future<void> _resetAndReload({required bool ignoreCursor}) async {
    final epoch = ++_fetchEpoch;
    _autoChainBudget = _kAutoChainMaxPages;
    _selectedIds.clear();
    _selectionMode = false;
    loadedPages = 1;
    hasMore = true;
    isLoadingPage = true;
    initialError = null;
    _resubscribe();
    notifyListeners();
    _schedulePersist();
    try {
      final more = await fetchPage(
        page: 1,
        search: _search.isEmpty ? null : _search,
        states: _states,
        extraFilters: _serverExtraFilters(),
        ignoreCursor: ignoreCursor,
      );
      // A newer reset superseded this one while the fetch was in flight.
      if (_fetchEpoch != epoch) return;
      hasMore = more;
    } catch (e) {
      if (_fetchEpoch != epoch) return;
      // Store the error MESSAGE (exception-type prefix stripped); the UI
      // prepends a localized "Failed to load:" prefix when rendering — a
      // bare toString() leaked "NetworkException: ClientException with
      // SocketException: …" into the full-pane error on every entity list.
      initialError = formatNotifyError(e);
    } finally {
      if (_fetchEpoch == epoch) {
        isLoadingPage = false;
        notifyListeners();
        // #25: same as _loadInitialPage — the pre-fetch `_resubscribe()` above
        // (:1021) subscribes while `isLoadingPage` is still true, so that
        // emission bails the auto-chain. Re-run the watch post-settle so a
        // short local-only-filtered page chains instead of dead-ending.
        if (localOnlyFilterActive) _resubscribe();
      }
    }
  }

  void _subscribe() {
    // Never (re)subscribe after dispose. `dispose()` doesn't bump `_fetchEpoch`
    // or clear the filter, so a post-settle `_resubscribe()` in a finally whose
    // fetch resolved after the VM was torn down (a mid-fetch navigate-away on a
    // `stock:`/`tag:`-filtered list) would otherwise open a fresh, never-
    // cancelled Drift subscription and drive post-dispose `loadMore()` fetches.
    // Guarding here covers every resubscribe path (initial-load + reset finally,
    // and the pre-existing loadMore re-subscribe).
    if (_disposed) return;
    // A throw inside the watch pipeline (e.g. `_fromRow` failing to map a
    // newly-shaped row) must NOT be swallowed: without an onError the
    // subscription would silently stop delivering, leaving an empty list
    // with no ErrorView (the fetch's own try/catch only guards the network
    // call, not the stream). Surface it the same way a failed fetch does so
    // the failure is loud instead of an inexplicably empty screen.
    _watchSub = transformPage(watchPage()).listen(
      _onItems,
      onError: (Object e) {
        initialError = formatNotifyError(e);
        notifyListeners();
      },
    );
  }

  void _resubscribe() {
    _watchSub?.cancel();
    _subscribe();
  }

  /// Local-only filter refill: when a `stock:` / `tag:` chip filters the page
  /// down to fewer than [pageSize] visible rows AND the server has more, pull
  /// the next page so the list doesn't dead-end on a false "No records found".
  /// Driven off each Drift emission via [_onItems] (see the note there on why
  /// it must run before the identity early-return) — that includes the
  /// initial/reset load's post-upsert emission, which is what chains the FIRST
  /// page. `loadMore`'s own `hasMore`/`isLoadingPage` guards and the
  /// [_autoChainBudget] ceiling keep it from looping.
  void _maybeAutoChain(int visibleCount) {
    if (localOnlyFilterActive &&
        hasMore &&
        !isLoadingPage &&
        visibleCount < pageSize &&
        _autoChainBudget > 0) {
      _autoChainBudget--;
      unawaited(loadMore());
    }
  }

  void _onItems(List<T> next) {
    // Local-only filter refill: BEFORE the identity early-return below — a
    // fetched page whose rows are all filtered out locally produces a
    // byte-identical emission, and returning early would stall the chain
    // exactly when it must continue. loadMore()'s own isLoadingPage/hasMore
    // guards serialize this against the scroll trigger and embedded priming;
    // a failed fetch produces no Drift emission, so there is no retry loop.
    _maybeAutoChain(next.length);
    // Drift watches are table-grained: any write to the table re-emits
    // this query even when the result set is byte-identical (a write to
    // another company, a filtered-out row, or an outbox-drain upsert that
    // didn't change a visible field). Domain models are freezed, so
    // `listEquals` is exact value equality across every rendered field —
    // including the `is_dirty` flag overlaid in `_fromRow` and
    // `updated_at` — so we only rebuild when something actually changed.
    if (listEquals(next, _items)) return;
    _items = next;
    notifyListeners();
  }

  void _schedulePersist() {
    // Embedded lists never write the shared standalone-list slot.
    if (isEmbedded || !_hydrated) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _persist);
  }

  Future<void> _persist() async {
    try {
      final row = await navStateDao.current();
      final existing = row?.filtersJson;
      Map<String, dynamic> doc;
      if (existing == null || existing.isEmpty) {
        doc = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(existing);
        doc = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      }
      final companyBlob = doc[companyId];
      final companyMap = companyBlob is Map<String, dynamic>
          ? Map<String, dynamic>.from(companyBlob)
          : <String, dynamic>{};
      companyMap[entityType.name] = currentSnapshot();
      doc[companyId] = companyMap;
      await navStateDao.saveFilters(
        filtersJson: jsonEncode(doc),
        now: _now().millisecondsSinceEpoch,
      );
      // Record what we just wrote so the watch's own echo is skipped.
      _lastSeenSlot = currentSnapshot();
    } catch (e, st) {
      _log.warning('Failed to persist filters_json', e, st);
    }
  }

  /// Subscribe to `nav_state.filters_json` so saved-view applies (which write
  /// through this same blob via [SavedViewsRepository.apply]) cause the
  /// running list VM to re-hydrate. The snapshot-equality check below is
  /// what prevents a feedback loop with the VM's own [_persist] writes —
  /// the next emission after our own write sees an unchanged slot and bails.
  void _subscribeNavState() {
    _navStateSub = navStateDao.watchCurrent().listen((row) {
      // First emission is the row we just read in [_hydrate]; ignore it so a
      // user mutation made between hydrate and this microtask doesn't get
      // overwritten by the still-stale slot.
      if (!_navStateSeen) {
        _navStateSeen = true;
        return;
      }
      // An absent slot (no row, this company/entity never persisted, or its
      // slot was deliberately removed by SavedViewsRepository
      // .clearAppliedViewFilters) means "reset to defaults" — fall back to
      // the canonical default snapshot so the dedupe below no-ops when the
      // VM is already at defaults and resets it otherwise. A *corrupt* blob
      // still bails (return) so it never nukes the user's live filters.
      final raw = row?.filtersJson;
      Map<String, dynamic> slot;
      if (raw == null || raw.isEmpty) {
        slot = _defaultSnapshot();
      } else {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) {
            slot = _defaultSnapshot();
          } else {
            final company = decoded[companyId];
            final entity = company is Map ? company[entityType.name] : null;
            slot = entity is Map
                ? Map<String, dynamic>.from(entity)
                : _defaultSnapshot();
          }
        } catch (e, st) {
          _log.warning(
            'nav_state listener: failed to decode filters_json',
            e,
            st,
          );
          return;
        }
      }
      const eq = DeepCollectionEquality();
      // Skip when this entity's persisted slot didn't actually change — the
      // shared `nav_state` row was touched for an unrelated reason (route
      // write, another entity's filter persist, our own debounced echo).
      // Without this, a stale on-disk slot clobbers in-memory filters not
      // yet persisted (e.g. a freshly applied dashboard deep-link intent).
      if (eq.equals(slot, _lastSeenSlot)) {
        return;
      }
      // Secondary guard: slot already matches in-memory state (keystroke /
      // own write race) — nothing to apply.
      if (eq.equals(slot, currentSnapshot())) {
        _lastSeenSlot = slot;
        return;
      }
      // A genuine external change to this entity's slot (saved-view apply).
      _applyDecoded(slot);
      _lastSeenSlot = currentSnapshot();
      unawaited(_resetAndReload(ignoreCursor: true));
    });
  }

  void _flashError(String kind, Object error) {
    _transientError = (kind: kind, message: formatNotifyError(error));
    notifyListeners();
  }

  List<ColumnDefinition<T>> _resolveColumns(List<String> ids) {
    final byId = {for (final c in allColumns) c.id: c};
    final out = <ColumnDefinition<T>>[];
    for (final id in ids) {
      final col = byId[id];
      if (col != null) out.add(col);
    }
    return out;
  }

  /// Localization key for a column id, or the id itself if the registry
  /// doesn't recognise it (so a stale persisted value stays readable in
  /// active-filter chips). Resolve via
  /// `context.tr(vm.columnLabelKeyById(id))` at render time.
  String columnLabelKeyById(String id) {
    for (final c in allColumns) {
      if (c.id == id) return c.labelKey;
    }
    return id;
  }

  // ── Multiselect / bulk actions ──────────────────────────────────────

  final Set<String> _selectedIds = <String>{};

  /// Explicit selection-mode latch. Lets the list enter multi-select with
  /// *zero* rows selected so the checkboxes appear before the user has picked
  /// anything — the mobile top-bar "Select" button sets this. (Desktop still
  /// enters by clicking a hover-revealed checkbox, which selects a row
  /// directly.) Without it `isInMultiselect` was purely `_selectedIds`-derived,
  /// so on touch — where there's no hover-reveal — selection was only reachable
  /// via the undiscoverable row long-press. Cleared whenever the selection
  /// clears or the list reloads.
  bool _selectionMode = false;

  bool get isInMultiselect => _selectionMode || _selectedIds.isNotEmpty;
  int get countSelected => _selectedIds.length;
  bool isSelected(String id) => _selectedIds.contains(id);

  /// Enter multi-select with nothing selected yet (the mobile "Select"
  /// affordance). No-op when already selecting.
  void enterSelectionMode() {
    if (isInMultiselect) return;
    _selectionMode = true;
    notifyListeners();
  }

  /// Snapshot of the currently-selected items, in list order. Backs
  /// selection-level bulk actions (`EntityListBulkAction.onSelection`) that
  /// operate on the whole selection at once instead of the per-id loop.
  List<T> get selectedItems =>
      _items.where((i) => _selectedIds.contains(idOf(i))).toList();

  bool _bulkInFlight = false;
  bool get bulkInFlight => _bulkInFlight;

  void toggleSelected(String id) {
    if (!_selectedIds.remove(id)) _selectedIds.add(id);
    notifyListeners();
  }

  void selectAllVisible() {
    var changed = false;
    for (final item in _items) {
      if (_selectedIds.add(idOf(item))) changed = true;
    }
    if (changed) notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty && !_selectionMode) return;
    _selectedIds.clear();
    _selectionMode = false;
    notifyListeners();
  }

  /// How many currently-selected, still-loaded rows satisfy [action]'s
  /// eligibility predicate. Used by the scaffold to short-circuit a
  /// prep-dialog action (email compose / template picker) before bothering
  /// the user with the dialog when nothing in the selection is actionable.
  /// Rows outside the loaded window are not counted (they'd be `skipped` by
  /// [applyBulkAction] anyway).
  int countEligibleSelected(BulkAction<T> action) {
    if (_selectedIds.isEmpty) return 0;
    final byId = <String, T>{for (final item in _items) idOf(item): item};
    var n = 0;
    for (final id in _selectedIds) {
      final item = byId[id];
      if (item != null && action.eligible(item)) n++;
    }
    return n;
  }

  /// Apply a [BulkAction] to every currently-selected entity that satisfies
  /// its predicate. Rows that are out of the visible window are counted as
  /// `skipped`; per-id failures bump `failed`. Selection is cleared on exit.
  Future<({int ok, int skipped, int failed})> applyBulkAction(
    BulkAction<T> action, {
    Object? arg,
  }) async {
    if (_bulkInFlight || _selectedIds.isEmpty) {
      return (ok: 0, skipped: 0, failed: 0);
    }
    _bulkInFlight = true;
    notifyListeners();

    try {
      final selectedIds = Set<String>.from(_selectedIds);
      final byId = <String, T>{for (final item in _items) idOf(item): item};

      final eligible = <String>[];
      var skipped = 0;
      for (final id in selectedIds) {
        final item = byId[id];
        if (item == null) {
          skipped++;
          continue;
        }
        if (action.eligible(item)) {
          eligible.add(id);
        } else {
          skipped++;
        }
      }

      var ok = 0;
      var failed = 0;
      final results = await Future.wait(
        eligible.map((id) async {
          try {
            await (action.applyArg != null
                ? action.applyArg!(id, arg)
                : action.apply!(id));
            return true;
          } catch (e, st) {
            _log.warning('Bulk op ${action.id} failed for $id', e, st);
            return false;
          }
        }),
      );
      for (final success in results) {
        if (success) {
          ok++;
        } else {
          failed++;
        }
      }
      return (ok: ok, skipped: skipped, failed: failed);
    } finally {
      _bulkInFlight = false;
      _selectedIds.clear();
      _selectionMode = false;
      notifyListeners();
    }
  }

  /// Run a selection-level action (the `EntityListBulkAction.onSelection` path —
  /// bulk PDF print/download, "Invoice Project(s)", "Download Documents") under
  /// the same in-flight latch the per-id loop uses, so the multiselect-AppBar
  /// bulk buttons disable for its duration and a second tap can't double-fire
  /// the (potentially slow) request. Unlike [applyBulkAction] it does NOT clear
  /// the selection — the scaffold owns that after the handler returns. The
  /// dispose guard covers navigating handlers (e.g. "Invoice Project") that pop
  /// the list mid-await.
  Future<void> runSelectionAction(Future<void> Function() action) async {
    if (_bulkInFlight) return;
    _bulkInFlight = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _bulkInFlight = false;
      if (!isDisposed) notifyListeners();
    }
  }

  /// Lookup a bulk action by id — convenience for entities that expose
  /// keyed actions on the screen (e.g. an `archive` button that just looks
  /// up the registered `BulkAction.id == 'archive'`).
  BulkAction<T>? bulkActionById(String id) {
    for (final a in bulkActions) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Tracks `dispose()` so async pagination work that returns after the
  /// VM has been torn down skips its trailing `notifyListeners()` (which
  /// would throw `was used after being disposed`). Async fetchPage calls
  /// that race with widget disposal happen routinely under tests; this
  /// gate keeps the production path untouched while making the lifecycle
  /// race safe.
  bool _disposed = false;

  /// Public read-only access — subclasses calling [notifyListeners] from
  /// their own async work should consult this before notifying.
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _persistTimer?.cancel();
    _watchSub?.cancel();
    _columnsSub?.cancel();
    _navStateSub?.cancel();
    for (final s in _customValuesSubs) {
      s.cancel();
    }
    _customValuesSubs.clear();
    super.dispose();
  }
}
