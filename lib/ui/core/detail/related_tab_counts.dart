import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// One count as the cache remembers it: the number, which state of the record
/// it was taken for, and when.
typedef CachedTabCount = ({int count, Object? revision, DateTime at});

/// What the app has learned this session about how many related records a
/// record has — so a re-opened record shows its tab counts in its first frame
/// instead of having them pop in a moment later, and is not asked about again
/// while what it knows is fresh.
///
/// In memory only, and cleared when the session ends: the numbers describe
/// what one signed-in user is allowed to see.
class RelatedTabCountsCache {
  final Map<String, CachedTabCount> _counts = {};
  int _generation = 0;

  /// Bumped by [clear]. A request captures it when it goes out and writes its
  /// answer back only if it has not moved — otherwise a response still on the
  /// wire at sign-out would put the outgoing user's number back.
  int get generation => _generation;

  /// A head start for the first frame, never the answer on its own. (Not
  /// named `peek` — that name is reserved for the repositories' first-frame
  /// seed, which a lint polices.)
  CachedTabCount? lastKnown(String scope, String tabId) =>
      _counts['$scope|$tabId'];

  void put(
    String scope,
    String tabId,
    int count, {
    Object? revision,
    DateTime? at,
  }) => _counts['$scope|$tabId'] = (
    count: count,
    revision: revision,
    at: at ?? DateTime.now(),
  );

  void clear() {
    _counts.clear();
    _generation++;
  }
}

/// What a tab strip needs from whoever knows the counts: a number per tab id,
/// null while it is not known, and a ping when one changes.
abstract interface class TabCounts implements Listenable {
  int? countFor(String tabId);
}

/// Asks the server how many records match — `BaseEntityApi.count`, bound to
/// one entity.
typedef RelatedCountFetcher =
    Future<int?> Function({Map<String, String> filters});

/// The counts on a record screen's related tabs ("Invoices 12").
///
/// **These are server totals**, one tiny request per tab, and that is the
/// whole reason this is not a `watchCount` on the local database: a client's
/// Invoices tab pages its rows in fifty at a time, so the local table knows
/// how many it has *fetched*, not how many there *are*. (The sidebar's
/// counters make the opposite trade and say so — they are local and can
/// under-report.) The price is that a count is unknown offline and for a
/// record the server has not seen, and then **no badge is drawn** — a missing
/// number is not a zero.
///
/// **Requests are rationed**, because eight per record opened adds up against
/// a hosted limit of 1,000 a minute per token *and* per IP — an office shares
/// one:
///
///  * a count taken for this state of the record within [freshFor] is not
///    asked for again;
///  * at most [maxConcurrent] are on the wire at once;
///  * [debounce] is long enough that stepping through a list fires none;
///  * the host kicks only after its own re-check of the record has settled,
///    so a newer `revision` cannot land mid-flight and ask all eight twice.
///
/// Owned by the screen and armed from its build with [kick], like the
/// activity view model.
class RelatedTabCountsViewModel extends ChangeNotifier implements TabCounts {
  RelatedTabCountsViewModel({
    required this.cache,
    required this.scope,
    required this.filters,
    required this.fetchers,
    this.filterOverrides = const {},
    this.isOnline,
    this.isCurrent,
    this.debounce = const Duration(seconds: 1),
    this.freshFor = const Duration(seconds: 60),
    this.maxConcurrent = 3,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RelatedTabCountsCache cache;

  /// Identifies whose counts these are in [cache] — the signed-in user, the
  /// company, the parent kind and the parent's id.
  final String scope;

  /// The query every tab's list starts from: the parent's id and the default
  /// lifecycle state. A count taken with any other filters would not be the
  /// number of rows the tab is about to show.
  final Map<String, String> filters;

  /// Tab id → the count request for the entity that tab lists.
  final Map<String, RelatedCountFetcher> fetchers;

  /// Tab id → the whole filter map for that tab, where [filters] does not
  /// fit. A project's tabs are the case: the server scopes invoices by
  /// `project_id`, tasks by `project_tasks` and expenses by `project_ids`, so
  /// no one map is right for all three.
  final Map<String, Map<String, String>> filterOverrides;

  /// Null means "assume online". Offline, nothing is asked and whatever is
  /// cached stays on screen.
  final Future<bool> Function()? isOnline;

  /// False once the company these counts belong to is no longer the active
  /// one. A request sent just before a company switch is answered under the
  /// new company's token, and that answer is not about this record.
  final bool Function()? isCurrent;

  final Duration debounce;
  final Duration freshFor;
  final int maxConcurrent;
  final DateTime Function() _now;

  final Map<String, int> _counts = {};
  Set<String> _tabIds = const {};
  Object? _revision;
  bool _kicked = false;

  /// Tabs whose last request got no answer (offline, an error) — what
  /// [retryIfUnanswered] is for.
  final Set<String> _unanswered = {};
  Timer? _timer;
  Future<void>? _refreshing;
  int _generation = 0;
  bool _disposed = false;

  /// Null until known.
  @override
  int? countFor(String tabId) => _counts[tabId];

  /// Call from build. [tabIds] are the tabs actually on screen (a module
  /// switched off has no tab and gets no request); [revision] is anything
  /// that changes when the record does — its `updatedAt` — so counts are
  /// asked for again when the server's copy moves.
  ///
  /// Never notifies synchronously: it runs inside the host's build. Cached
  /// counts are adopted silently, which is safe because the tabs are built
  /// after this returns and read [countFor] directly.
  void kick({required Set<String> tabIds, Object? revision}) {
    if (_disposed) return;
    final first = !_kicked;
    if (first) {
      _kicked = true;
      for (final id in fetchers.keys) {
        final cached = cache.lastKnown(scope, id);
        if (cached != null) _counts[id] = cached.count;
      }
    }
    final changed =
        first || revision != _revision || !setEquals(tabIds, _tabIds);
    _tabIds = tabIds;
    _revision = revision;
    if (!changed) return;
    // Everything on screen is already a fresh answer for this record as it
    // is now: nothing to ask.
    if (_stale().isEmpty) return;
    _schedule();
  }

  /// The user refreshed the record: ask for every tab again, now. One at a
  /// time — a second refresh while the first is out joins it.
  Future<void> refresh() {
    if (_disposed || !_kicked) return Future<void>.value();
    _timer?.cancel();
    return _refreshing ??= _fetch(
      force: true,
    ).whenComplete(() => _refreshing = null);
  }

  /// The device is back online. Asks again only for tabs whose last request
  /// got no answer.
  void retryIfUnanswered() {
    if (_disposed || !_kicked || _unanswered.isEmpty) return;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_fetch()));
  }

  /// The enabled tabs with no count fresh enough to stand on.
  List<String> _stale() {
    final now = _now();
    return [
      for (final id in fetchers.keys)
        if (_tabIds.contains(id) && !_isFresh(cache.lastKnown(scope, id), now))
          id,
    ];
  }

  bool _isFresh(CachedTabCount? cached, DateTime now) =>
      cached != null &&
      cached.revision == _revision &&
      now.difference(cached.at) < freshFor;

  Future<void> _fetch({bool force = false}) async {
    final generation = ++_generation;
    final cacheGeneration = cache.generation;
    final ids = force
        ? [
            for (final id in fetchers.keys)
              if (_tabIds.contains(id)) id,
          ]
        : _stale();
    if (ids.isEmpty) return;
    if (isOnline != null && !await isOnline!()) {
      _unanswered.addAll(ids);
      return;
    }
    var changed = false;

    Future<void> ask(String id) async {
      int? count;
      try {
        count = await fetchers[id]!(filters: filterOverrides[id] ?? filters);
      } catch (_) {
        // One tab's count failing says nothing about the others, and nothing
        // worth a toast: the tab simply keeps what it had.
        _unanswered.add(id);
        return;
      }
      _unanswered.remove(id);
      if (count == null || _disposed || generation != _generation) return;
      if (isCurrent != null && !isCurrent!()) return;
      if (cache.generation == cacheGeneration) {
        // Filed under the revision as it is *now*, not as it was when the
        // request went out. A manual refresh fetches the record and these
        // together, and the record's newer `updatedAt` usually lands first:
        // filing the answer under the old one would leave it looking stale,
        // and the next kick would ask all over again.
        cache.put(scope, id, count, revision: _revision, at: _now());
      }
      if (_counts[id] == count) return;
      _counts[id] = count;
      changed = true;
    }

    // A small pool rather than `Future.wait` over all of them: eight at once
    // is a burst against a shared rate limit for the sake of a few badges.
    final queue = [...ids];
    Future<void> worker() async {
      while (queue.isNotEmpty && !_disposed) {
        await ask(queue.removeAt(0));
      }
    }

    await Future.wait([
      for (var i = 0; i < math.min(maxConcurrent, ids.length); i++) worker(),
    ]);
    if (changed && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
