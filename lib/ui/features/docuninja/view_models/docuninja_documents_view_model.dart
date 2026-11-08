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

  int _generation = 0;
  Timer? _searchTimer;
  bool _disposed = false;

  /// Loads the first page again, keeping the rows on screen until it lands.
  Future<void> refresh() => _loadFirst();

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

  Future<void> _loadFirst() async {
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
      final page = await _fetch(1);
      if (generation != _generation) return;
      _items.clear();
      _apply(page, append: false);
      _itemsQuery = query;
      _loaded = true;
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
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Asks again for what failed: the next page, or the first.
  Future<void> retry() => _errorFromMore ? loadMore() : _loadFirst();

  Future<DnPage<T>> _fetch(int page) => fetchPage(
    page: page,
    perPage: pageSize,
    search: _search.trim(),
    status: [..._states, ..._statuses].join(','),
  );

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
      _log.warning('DocuNinja documents failed to load', e, st);
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
