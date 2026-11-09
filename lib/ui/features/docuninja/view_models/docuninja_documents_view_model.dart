import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';

final _log = Logger('DnListViewModel');

/// Why the documents list could not be read.
enum DnListError { offline, failed }

/// The DocuNinja documents list (React's `Documents.tsx` table): a page at a
/// time from DocuNinja, newest first, with a search, the lifecycle states
/// and React's status filter.
class DocuNinjaDocumentsViewModel extends DnListViewModel<DnDocument> {
  DocuNinjaDocumentsViewModel({
    required DocuNinjaApi api,
    super.pageSize,
    super.searchDelay,
  }) : _api = api;

  final DocuNinjaApi _api;

  @override
  String idOf(DnDocument item) => item.id;

  @override
  Future<void> sendBulk(String action, List<String> ids) =>
      _api.bulk(action, ids);

  @override
  Future<DnPage<DnDocument>> fetchPage({
    required int page,
    required int perPage,
    required String search,
    required String status,
  }) => _api.documents(
    page: page,
    perPage: perPage,
    search: search,
    status: status,
  );
}

/// The DocuNinja templates list (React's `Blueprints.tsx`): the same paging,
/// search and lifecycle states, no status filter.
class DocuNinjaTemplatesViewModel extends DnListViewModel<DnBlueprint> {
  DocuNinjaTemplatesViewModel({
    required DocuNinjaApi api,
    super.pageSize,
    super.searchDelay,
  }) : _api = api;

  final DocuNinjaApi _api;

  @override
  String idOf(DnBlueprint item) => item.id;

  @override
  Future<void> sendBulk(String action, List<String> ids) =>
      _api.blueprintBulk(action, ids);

  @override
  Future<DnPage<DnBlueprint>> fetchPage({
    required int page,
    required int perPage,
    required String search,
    required String status,
  }) => _api.blueprints(
    page: page,
    perPage: perPage,
    search: search,
    status: status,
  );
}

/// The DocuNinja users list (React's `Users.tsx`): the users of the
/// DocuNinja company paired with [ninjaCompanyKey]'s Invoice Ninja company.
class DocuNinjaUsersViewModel extends DnListViewModel<DnUser> {
  DocuNinjaUsersViewModel({
    required DocuNinjaApi api,
    required this.ninjaCompanyKey,
    super.pageSize,
    super.searchDelay,
  }) : _api = api;

  final DocuNinjaApi _api;
  final String ninjaCompanyKey;

  @override
  String idOf(DnUser item) => item.id;

  @override
  Future<void> sendBulk(String action, List<String> ids) =>
      _api.userBulk(action, ids);

  @override
  Future<DnPage<DnUser>> fetchPage({
    required int page,
    required int perPage,
    required String search,
    required String status,
  }) => _api.users(
    ninjaCompanyKey: ninjaCompanyKey,
    page: page,
    perPage: perPage,
    search: search,
    status: status,
  );
}

/// A DocuNinja list: a page at a time, newest first, with a search, the
/// lifecycle states and (documents only) React's status filter.
///
/// Online-only and held in memory (docs/docuninja.md). Each query carries a
/// generation, so a page that lands after the search or filter changed is
/// dropped instead of mixed in.
abstract class DnListViewModel<T> extends ChangeNotifier {
  DnListViewModel({
    this.pageSize = 20,
    this.searchDelay = const Duration(milliseconds: 300),
  });

  final int pageSize;
  final Duration searchDelay;

  /// One page, as DocuNinja's list endpoints take it.
  @protected
  Future<DnPage<T>> fetchPage({
    required int page,
    required int perPage,
    required String search,
    required String status,
  });

  /// The row's id, so a page that overlaps the last one adds no duplicate.
  @protected
  String idOf(T item);

  /// `archive`, `restore` or `delete` on [ids], in one request (React's
  /// `POST <resource>/bulk {action, ids}`).
  @protected
  Future<void> sendBulk(String action, List<String> ids);

  final List<T> _items = [];
  List<T> get items => List.unmodifiable(_items);

  String _search = '';
  String get search => _search;

  /// React's status filter values (`useDocumentFilters.ts`): draft, sent,
  /// pending_approval, completed, approved, voided, expired, rejected.
  Set<String> _statuses = const {};
  Set<String> get statuses => _statuses;

  /// The lifecycle states listed: active, archived, deleted. React's table
  /// starts on `active` and always sends a state with the statuses; the
  /// service matches a document whose state and status are both listed.
  /// Never empty (an empty choice falls back to active).
  Set<String> _states = const {'active'};
  Set<String> get states => _states;

  /// Filters other than the default (active, any status), for the filter
  /// button's dot.
  int get activeFilterCount =>
      (_statuses.isEmpty ? 0 : 1) +
      (setEquals(_states, const {'active'}) ? 0 : 1);

  int _page = 0;
  int _lastPage = 1;
  int _total = 0;
  int get total => _total;
  bool get hasMore => _page < _lastPage;

  bool _loading = false;
  bool get isLoading => _loading;
  bool _loadingMore = false;
  bool get isLoadingMore => _loadingMore;

  /// Set once the first page has answered.
  bool _loaded = false;
  bool get hasLoaded => _loaded;

  DnListError? _error;
  DnListError? get error => _error;

  /// The failure was the next page's, not the first page's: [retry] asks
  /// for that page again.
  bool _errorFromMore = false;

  /// The failure was the next page's (shown under the rows), not a refresh
  /// of the first one (shown above them, where the pull happened).
  bool get errorFromMore => _errorFromMore;

  /// The query the rows on screen answer. A failed first page for another
  /// query clears them, so they never sit under a search they don't match.
  String? _itemsQuery;
  String get _query =>
      '${_search.trim()}|${(_states.toList()..sort()).join(',')}|'
      '${(_statuses.toList()..sort()).join(',')}';

  /// A new search or filter is loading: the rows on screen (if any) answer
  /// the previous one. A refresh of the same query is not this; its rows
  /// stay current while it runs.
  bool get isRequerying =>
      _loaded &&
      (_loading || (_searchTimer?.isActive ?? false)) &&
      _itemsQuery != _query;

  int _generation = 0;
  Timer? _searchTimer;
  bool _disposed = false;

  /// How many pages a [refresh] reloads at most, so a deep scroll is kept
  /// without one refresh turning into a long run of requests.
  static const kRefreshMaxPages = 5;

  /// Loads the rows again, keeping them on screen until the new ones land,
  /// and as many pages as are showing (up to [kRefreshMaxPages]): a refresh
  /// a teammate's event or a return from the browser starts must not drop a
  /// user sixty rows down back to the first page.
  ///
  /// A refresh asked while one for the same query is in flight waits for it
  /// and then reads once more: that load started before the request (a
  /// write just landed, a signature arrived), so its rows may predate what
  /// the request is for. A burst still costs one extra load, never a stream
  /// of restarted five-page ones.
  Future<void> refresh() {
    final inFlight = _inFlight;
    if (_loading && inFlight != null && _inFlightQuery == _query) {
      return _again ??= inFlight.then((_) {
        _again = null;
        if (_disposed || _inFlightQuery != _query) return null;
        return _loadFirst(depth: _refreshDepth);
      });
    }
    return _loadFirst(depth: _refreshDepth);
  }

  /// The one read queued behind the load in flight.
  Future<void>? _again;

  int get _refreshDepth => _page.clamp(1, kRefreshMaxPages);
  Future<void>? _inFlight;
  String? _inFlightQuery;

  void setSearch(String value) {
    if (value == _search) return;
    _search = value;
    // A page asked for under the old search must not land in the new list,
    // even before the debounce fires.
    _generation++;
    _loadingMore = false;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, _loadFirst);
    _notify();
  }

  /// Sets the status and lifecycle filters (React's status picker and the
  /// table's state filter). An empty [states] means active.
  void setFilters({
    required Set<String> statuses,
    required Set<String> states,
  }) {
    final nextStates = states.isEmpty ? const {'active'} : states;
    if (setEquals(statuses, _statuses) && setEquals(nextStates, _states)) {
      return;
    }
    _statuses = Set.unmodifiable(statuses);
    _states = Set.unmodifiable(nextStates);
    _loadFirst();
  }

  /// The next page, near the end of the list.
  Future<void> loadMore() async {
    // While a search waits out its debounce, the rows and the page count
    // are the old search's: a next page now would be the new search's
    // page N+1 appended to them.
    final searchPending = _searchTimer?.isActive ?? false;
    if (_loading || _loadingMore || searchPending || !hasMore) return;
    if (_items.isEmpty) return;
    final generation = _generation;
    _loadingMore = true;
    _error = null;
    _notify();
    try {
      final page = await _fetch(_page + 1);
      if (generation != _generation) return;
      _apply(page, append: true);
    } on Object catch (e, st) {
      if (generation != _generation) return;
      _fail(e, st);
      _errorFromMore = true;
    } finally {
      if (generation == _generation) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> _loadFirst({int depth = 1}) {
    final load = _loadPages(depth);
    _inFlight = load;
    _inFlightQuery = _query;
    return load;
  }

  Future<void> _loadPages(int depth) async {
    final generation = ++_generation;
    _searchTimer?.cancel();
    // A load-more of the previous query is now stale; its own `finally`
    // won't clear the flag (the generation moved on), so clear it here or
    // paging stops for good.
    _loadingMore = false;
    _loading = true;
    _error = null;
    _notify();
    final query = _query;
    try {
      final pages = [await _fetch(1)];
      while (pages.length < depth &&
          pages.last.currentPage < pages.last.lastPage) {
        if (generation != _generation) return;
        pages.add(await _fetch(pages.length + 1));
      }
      if (generation != _generation) return;
      _items.clear();
      for (final page in pages) {
        _apply(page, append: true);
      }
      _itemsQuery = query;
      _loaded = true;
      _pruneSelection();
    } on Object catch (e, st) {
      if (generation != _generation) return;
      _fail(e, st);
      _errorFromMore = false;
      if (_itemsQuery != query) {
        // The rows answer another search or filter; showing them under
        // this one would read as its results.
        _items.clear();
        _page = 0;
        _lastPage = 1;
        _total = 0;
        _itemsQuery = null;
        _pruneSelection();
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Asks again for what failed: the next page, or the first.
  Future<void> retry() =>
      _errorFromMore ? loadMore() : _loadFirst(depth: _refreshDepth);

  Future<DnPage<T>> _fetch(int page) => fetchPage(
    page: page,
    perPage: pageSize,
    search: _search.trim(),
    status: [..._states, ..._statuses].join(','),
  );

  // ── Selection (React's table checkboxes, for its bulk actions) ──────────

  final Set<String> _selected = {};
  bool _selecting = false;

  /// In selection mode: the rows show checkboxes, a tap ticks one, and the
  /// header offers the bulk actions. Entered with nothing ticked yet (the
  /// Select button) or by ticking a row.
  bool get isSelecting => _selecting || _selected.isNotEmpty;
  int get countSelected => _selected.length;
  bool isSelected(T item) => _selected.contains(idOf(item));

  /// The ticked rows still in the list, in list order.
  List<T> get selectedItems =>
      _items.where((i) => _selected.contains(idOf(i))).toList();

  /// The ids of the ticked rows that pass [test], in list order.
  List<String> selectedIdsWhere(bool Function(T item) test) => [
    for (final i in _items)
      if (_selected.contains(idOf(i)) && test(i)) idOf(i),
  ];

  void enterSelectionMode() {
    if (_selecting) return;
    _selecting = true;
    _notify();
  }

  void toggleSelected(T item) {
    final id = idOf(item);
    if (!_selected.remove(id)) _selected.add(id);
    _selecting = true;
    _notify();
  }

  /// Ticks every loaded row (React's header checkbox ticks the page).
  void selectAllVisible() {
    _selecting = true;
    _selected.addAll(_items.map(idOf));
    _notify();
  }

  void clearSelection() {
    if (!isSelecting) return;
    _selected.clear();
    _selecting = false;
    _notify();
  }

  bool _bulkInFlight = false;

  /// A bulk action is running: the bulk buttons are off meanwhile.
  bool get bulkInFlight => _bulkInFlight;

  /// Runs [action] on [ids] in one request, then unticks what was ticked
  /// when it went out, skipped rows included (as React clears its
  /// selection), keeping only rows ticked while it ran, and re-reads the rows
  /// on screen (as React refetches after a bulk action). The re-read runs
  /// whether or not the request failed: a request that timed out may have
  /// landed. Returns false, sending nothing, while another bulk runs;
  /// rethrows a failure for the screen's toast.
  Future<bool> applyBulk(String action, List<String> ids) async {
    if (_bulkInFlight || ids.isEmpty) return false;
    _bulkInFlight = true;
    final ticked = {..._selected};
    _notify();
    try {
      await sendBulk(action, ids);
      _selected.removeAll(ticked);
      _selecting = _selected.isNotEmpty;
      return true;
    } finally {
      _bulkInFlight = false;
      _notify();
      if (!_disposed) unawaited(refresh());
    }
  }

  /// A row that left the list (a new search, a filter, a refresh after it
  /// was deleted elsewhere) leaves the selection too: a bulk action must
  /// never reach a record the user can no longer see.
  void _pruneSelection() {
    if (_selected.isEmpty) return;
    final shown = {for (final i in _items) idOf(i)};
    _selected.removeWhere((id) => !shown.contains(id));
  }

  void _apply(DnPage<T> page, {required bool append}) {
    final seen = {for (final d in _items) idOf(d)};
    _items.addAll(page.items.where((d) => seen.add(idOf(d))));
    _page = page.currentPage;
    _lastPage = page.lastPage;
    _total = page.total;
  }

  void _fail(Object e, StackTrace st) {
    if (e is NetworkException) {
      _error = DnListError.offline;
    } else {
      _log.warning('DocuNinja list failed to load', e, st);
      _error = DnListError.failed;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }
}
