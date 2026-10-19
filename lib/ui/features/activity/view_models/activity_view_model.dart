import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/models/api/activity_api_model.dart'
    show kCommentActivityTypeId;
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';

// `kCommentActivityTypeId` is re-exported for the screen + tests that already
// import it off this file. The constant itself lives beside the DTO that reads
// it (`activity_api_model.dart`) — it used to be declared here as well, and a
// third copy is exactly how two would drift apart.
export 'package:admin/data/models/api/activity_api_model.dart'
    show kCommentActivityTypeId;

final _log = Logger('ActivityViewModel');

/// Which slice of the feed the human-written lens is showing.
///
/// One enum rather than two booleans because the buckets **nest**: every logged
/// call is a comment (both are `activity_type_id == 141`; the wire has no note
/// subtype, so `calls` tests the marker in the text — see `call_note.dart`).
/// Two independent switches would let a user ask for "calls but not comments",
/// which selects nothing and looks like a bug.
enum ActivityLens {
  /// No narrowing — the type picker is live.
  all,

  /// Anything a person typed: comments and logged calls alike.
  comments,

  /// Logged calls only.
  calls,
}

/// The client-side predicates the `/activity` screen narrows with.
///
/// All of them are local by necessity: `GET /api/v1/activities` accepts **no**
/// filters at all — no `ActivityFilters` class exists server-side and
/// `QueryFilters::apply` drops unknown params silently (BACKEND.md § F3) — so
/// they operate over the window held — the most recent `kActivityFeedRows`
/// company rows, grown by Load more up to `kActivityWindowMax`.
@immutable
class ActivityFilters {
  const ActivityFilters({
    this.userId,
    this.typeIds = const <int>{},
    this.search = '',
    this.lens = ActivityLens.all,
    this.from,
    this.until,
    this.categories = const <ActivityCategory>{},
  });

  final String? userId;
  final Set<int> typeIds;
  final String search;

  /// Local-time half-open window `[from, until)`; either end may be open.
  ///
  /// Instants, not days, because a timeline bar can be an *hour* on a busy
  /// account — a day-granular range could not say "the 3 PM bar". A range
  /// picked from the calendar is whole days: midnight to the next midnight.
  final DateTime? from;
  final DateTime? until;

  /// What kind of event to keep; empty keeps every kind. ANDs with the lens
  /// and the type picker — they narrow by *type*, this by *meaning*.
  final Set<ActivityCategory> categories;

  bool get hasRange => from != null || until != null;

  /// Restricts to human-written rows. ANDs with the rest, and the screen
  /// **disables** the type picker while it is not [ActivityLens.all] —
  /// otherwise picking types here would be silently discarded by the
  /// `activity_type_id == 141` test.
  final ActivityLens lens;

  bool get isActive =>
      userId != null ||
      typeIds.isNotEmpty ||
      search.trim().isNotEmpty ||
      lens != ActivityLens.all ||
      hasRange ||
      categories.isNotEmpty;

  int get activeCount =>
      (userId != null ? 1 : 0) +
      (typeIds.isNotEmpty ? 1 : 0) +
      (search.trim().isNotEmpty ? 1 : 0) +
      (lens != ActivityLens.all ? 1 : 0) +
      (hasRange ? 1 : 0) +
      (categories.isNotEmpty ? 1 : 0);

  ActivityFilters copyWith({
    String? Function()? userId,
    Set<int>? typeIds,
    String? search,
    ActivityLens? lens,
    (DateTime?, DateTime?)? range,
    Set<ActivityCategory>? categories,
  }) => ActivityFilters(
    userId: userId != null ? userId() : this.userId,
    typeIds: typeIds ?? this.typeIds,
    search: search ?? this.search,
    lens: lens ?? this.lens,
    from: range != null ? range.$1 : from,
    until: range != null ? range.$2 : until,
    categories: categories ?? this.categories,
  );

  Map<String, dynamic> toJson() => {
    if (userId != null) 'user': userId,
    if (typeIds.isNotEmpty) 'types': typeIds.toList()..sort(),
    if (search.isNotEmpty) 'search': search,
    // `comments` predates the lens and is still what a `nav_state` blob written
    // by an older build carries, so the comments case keeps writing it and a
    // downgrade doesn't silently drop that filter. The two keys are
    // **exclusive**: a `calls` blob carries no `comments`, so an older build
    // ignores the key it doesn't know and lands on `all` — a wider result
    // rather than a wrong one, which is the safe direction to fail.
    if (lens == ActivityLens.comments) 'comments': true,
    if (lens == ActivityLens.calls) 'calls': true,
    // Local wall-clock ISO with no `Z`, so `DateTime.parse` reads it back as
    // the same local instant the user picked — a bar is a local period.
    if (from != null) 'from': from!.toIso8601String(),
    if (until != null) 'until': until!.toIso8601String(),
    if (categories.isNotEmpty)
      'cats': [for (final c in categories) c.name]..sort(),
  };

  static ActivityFilters fromJson(Map<String, dynamic> json) {
    final rawTypes = json['types'];
    final rawCats = json['cats'];
    return ActivityFilters(
      userId: json['user'] is String && (json['user'] as String).isNotEmpty
          ? json['user'] as String
          : null,
      typeIds: rawTypes is List
          ? rawTypes
                .map((e) => e is int ? e : int.tryParse('$e'))
                .whereType<int>()
                .toSet()
          : const <int>{},
      search: json['search'] is String ? json['search'] as String : '',
      lens: json['calls'] == true
          ? ActivityLens.calls
          : (json['comments'] == true
                ? ActivityLens.comments
                : ActivityLens.all),
      from: _localInstant(json['from']),
      until: _localInstant(json['until']),
      categories: rawCats is List
          ? {
              for (final name in rawCats)
                for (final c in ActivityCategory.values)
                  if (c.name == name) c,
            }
          : const <ActivityCategory>{},
    );
  }

  static DateTime? _localInstant(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.isUtc == true ? parsed!.toLocal() : parsed;
  }
}

/// One entry in the flattened feed: either a day separator or a row. Flattened
/// in the ViewModel so the screen can drive a plain `ListView.builder`.
sealed class ActivityFeedEntry {
  const ActivityFeedEntry();
}

/// Local-calendar-day separator. [day] is midnight in the *device's* zone;
/// [count] is every matching row that day, folded runs included.
class ActivityDayHeader extends ActivityFeedEntry {
  const ActivityDayHeader(this.day, {this.count = 0});
  final DateTime day;
  final int count;
}

class ActivityFeedItem extends ActivityFeedEntry {
  const ActivityFeedItem(this.activity);
  final DashboardActivity activity;
}

/// The "+N more" / "Collapse" line under a folded run (see `collapseRuns`).
/// [runId] is the run's newest row id — stable while the window is.
class ActivityRunToggle extends ActivityFeedEntry {
  const ActivityRunToggle({
    required this.runId,
    required this.hidden,
    required this.expanded,
  });
  final String runId;

  /// Rows beyond the first — what "+N more" counts.
  final int hidden;
  final bool expanded;
}

/// State holder for the `/activity` screen.
///
/// Reads the **same** Drift cache row as the dashboard's Activity card
/// (`dashboard_cache`, kind `activities`), so the screen paints instantly from
/// cache and a refresh on either surface updates both — the freshness label
/// included (see [lastRefreshed]).
class ActivityViewModel extends ChangeNotifier {
  ActivityViewModel({
    required this.repo,
    required this.companyId,
    this.navStateDao,
    DateTime Function()? now,
    Duration persistDebounce = const Duration(milliseconds: 600),
  }) : _now = now ?? DateTime.now,
       _persistDebounce = persistDebounce {
    if (navStateDao != null && companyId.isNotEmpty) {
      _hydration = _hydrate();
    } else {
      _hydrated = true;
      _hydration = Future.value();
    }
    if (companyId.isNotEmpty) {
      // VM-level, never re-opened per build: every emission re-runs
      // `jsonDecode` + `listFromJson` over the whole window.
      _sub = repo.watchActivities(companyId).listen(_onRows, onError: _onError);
      _fetchedAtSub = repo
          .watchActivitiesFetchedAt(companyId)
          .listen(_onFetchedAt, onError: _onFetchedAtError);
      unawaited(refresh());
    }
  }

  final DashboardRepository repo;
  final String companyId;

  /// Local-only restore-on-restart store. Keyed by
  /// `companyId → 'activity' → snapshot` inside the shared `filters_json`
  /// blob — the same mechanism list ViewModels and Reports use, so this
  /// needs no schema change.
  final NavStateDao? navStateDao;
  final DateTime Function() _now;
  final Duration _persistDebounce;

  static const String _persistKey = 'activity';

  StreamSubscription<List<DashboardActivity>?>? _sub;
  StreamSubscription<DateTime?>? _fetchedAtSub;
  Timer? _persistTimer;
  bool _hydrated = false;
  bool _userTouched = false;
  bool _disposed = false;
  bool _recomputeScheduled = false;
  late final Future<void> _hydration;

  /// Completes once the hydration attempt has run. Tests await it.
  Future<void> get hydration => _hydration;

  AsyncSection<List<DashboardActivity>> _section =
      const AsyncSection<List<DashboardActivity>>.idle();
  AsyncSection<List<DashboardActivity>> get section => _section;

  ActivityFilters _filters = const ActivityFilters();
  ActivityFilters get filters => _filters;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  /// When the rows on screen were fetched — the cache row's `fetched_at`, not a
  /// stamp this view model keeps (bar [refresh]'s provisional one, for the
  /// moment before a first row's time arrives).
  ///
  /// It used to be one, set only by [refresh], so the label went on reading
  /// "Updated 2h ago" over rows the Sync pass had just rewritten
  /// (invoiceninja/flutter#162); every dashboard load of the same feed left it
  /// alone too. Following the row moves it for every writer. The price is on a
  /// cold start with a cached row: the label shows that row's age while the
  /// first refresh runs, rather than "Loading…".
  DateTime? _lastRefreshed;
  DateTime? get lastRefreshed => _lastRefreshed;

  /// Renders a row's localized sentence, so the text filter can match what the
  /// user actually reads. Injected (rather than built here) because
  /// `ActivityFormatter` needs a `BuildContext`; the screen assigns it from
  /// `didChangeDependencies`, which is also what re-fires on a locale change.
  String Function(DashboardActivity)? _titleResolver;
  final Map<String, String> _titleCache = <String, String>{};

  /// Swap in a new renderer (locale change, or a company switch rebuilding the
  /// screen's formatter).
  ///
  /// Deliberately **not** a setter with an `identical` guard: the screen builds
  /// a fresh closure on every `didChangeDependencies`, so that guard never fired
  /// and every theme toggle / rotation / window-resize frame cleared the memo
  /// and re-rendered the whole window — the exact cost the memo exists to avoid.
  ///
  /// Rendered titles feed **only** the text filter, so with no active search
  /// there is nothing to recompute and nothing to notify; that early return is
  /// what makes a resize-drag free. When a search *is* active the recompute is
  /// routed through [_recomputeSoon], because `didChangeDependencies` runs
  /// inside the build phase and this notifier has a listener outside this
  /// screen's subtree (the filter sheet mounts on the root navigator), whose
  /// `setState` would then be out of scope.
  void setTitleResolver(String Function(DashboardActivity) resolver) {
    _titleResolver = resolver;
    _titleCache.clear();
    if (_filters.search.trim().isEmpty) return;
    _recomputeSoon();
  }

  /// [_recompute] now, unless we're mid-frame — then once, at the end of it.
  /// Mirrors `ShortcutHintController._notify`, the same guard for the same
  /// reason.
  void _recomputeSoon() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (!building) {
      _recompute();
      return;
    }
    if (_recomputeScheduled) return;
    _recomputeScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _recomputeScheduled = false;
      if (_disposed) return;
      _recompute();
    });
  }

  // ─── Data ────────────────────────────────────────────────────────────

  void _onRows(List<DashboardActivity>? rows) {
    // Rows are id-keyed and immutable, but a refresh can replace the window —
    // clearing here keeps the cache bounded and costs one render pass, not one
    // per keystroke (which is the case this memo exists for).
    _titleCache.clear();
    _section = _section.withData(rows);
    _recompute();
  }

  void _onError(Object error, StackTrace st) {
    _log.warning('Activity watch failed', error, st);
    _section = AsyncSection<List<DashboardActivity>>.error(
      error,
      data: _section.data,
    );
    if (!_disposed) notifyListeners();
  }

  void _onFetchedAt(DateTime? fetchedAt) {
    if (_disposed || fetchedAt == _lastRefreshed) return;
    _lastRefreshed = fetchedAt;
    notifyListeners();
  }

  // Logged only: the label keeps its last value, and the rows' own watch is
  // what surfaces a broken cache.
  void _onFetchedAtError(Object error, StackTrace st) {
    _log.warning('Activity freshness watch failed', error, st);
  }

  Future<void> refresh() async {
    if (companyId.isEmpty || _disposed) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      final got = await repo.refreshActivities(companyId);
      // Fewer than asked is the company's whole history — nothing older to
      // load. Sticky: a later full answer means new activity, not old.
      if (got < kActivityFeedRows) _exhausted = true;
      // Provisional, and only while no row time is known: the write this made
      // reaches [lastRefreshed] through Drift, which re-queries asynchronously,
      // so without it the `finally` below would paint `lastRefreshed == null &&
      // !isRefreshing` — "Not yet loaded" — over a fetch that just succeeded.
      // The row's own time replaces it when it lands.
      _lastRefreshed ??= _now();
      if (_section.hasError) {
        _section = _section.withData(_section.data);
      }
    } catch (e, st) {
      _log.warning('Activity refresh failed', e, st);
      _section = AsyncSection<List<DashboardActivity>>.error(
        e,
        data: _section.data,
      );
    } finally {
      _isRefreshing = false;
      // The constructor starts a refresh, so this await is in flight every time
      // the screen is first opened — and a company switch or logout inside that
      // window disposes us mid-call. `ChangeNotifier` asserts on a post-dispose
      // notify, so guard it, exactly as `EntityActivityViewModel.refresh` does.
      if (!_disposed) notifyListeners();
    }
  }

  // ─── Load more ───────────────────────────────────────────────────────

  bool _loadingMore = false;
  bool get isLoadingMore => _loadingMore;

  bool _loadMoreFailed = false;

  /// The last Load more failed; the footer says so beside the button.
  bool get loadMoreFailed => _loadMoreFailed;

  bool _exhausted = false;

  /// The window's cap: [kActivityCursorWindowMax] unless the server is known
  /// not to page the feed with `before`, then [kActivityWindowMax] — without
  /// the cursor every Load more re-downloads the whole window. Unknown counts
  /// as paged, so the first Load more past the lower cap still asks.
  int get windowMax => repo.activityCursorSupported(companyId) == false
      ? kActivityWindowMax
      : kActivityCursorWindowMax;

  /// Whether older activity may exist that a Load more would bring in: the
  /// window is full (a short one is already everything), under the cap, and
  /// no fetch has come back short.
  bool get canLoadMore =>
      !_exhausted &&
      windowCount >= kActivityFeedRows &&
      windowCount < windowMax;

  /// The window has reached [windowMax] — older activity is the Activity
  /// report's.
  bool get atWindowMax => windowCount >= windowMax;

  /// Grows the window into older activity
  /// (`DashboardRepository.loadOlderActivities`): the next [kActivityFeedRows]
  /// rows by the feed's `before` cursor where the server has it, else the
  /// newest `N + 250` rows again. The rows arrive the way every other write
  /// does, through the watch.
  Future<void> loadMore() async {
    if (!canLoadMore || _loadingMore || _disposed) return;
    _loadingMore = true;
    _loadMoreFailed = false;
    notifyListeners();
    try {
      final page = await repo.loadOlderActivities(companyId);
      if (page.received < page.asked) _exhausted = true;
    } catch (e, st) {
      _log.warning('Activity load more failed', e, st);
      _loadMoreFailed = true;
    } finally {
      _loadingMore = false;
      if (!_disposed) notifyListeners();
    }
  }

  // ─── Filtering ───────────────────────────────────────────────────────

  List<ActivityFeedEntry> _entries = const <ActivityFeedEntry>[];

  /// The flattened, day-grouped, filtered feed.
  List<ActivityFeedEntry> get entries => _entries;

  int _matchCount = 0;

  /// How many rows survive the filters (headers excluded).
  int get matchCount => _matchCount;

  /// Total rows in the window before filtering — what the list footer reports.
  int get windowCount => _section.data?.length ?? 0;

  ActivityTimeline _timeline = ActivityTimeline.empty;

  /// The window cut into periods, counting rows that pass **every filter but
  /// the date range** — so the bars keep their context while the user picks
  /// one, and a category filter redraws the timeline as that category alone.
  ActivityTimeline get timeline => _timeline;

  Map<ActivityCategory, int> _categoryCounts = const {};

  /// Rows per category under **every filter but the category one** — the
  /// facet rule, so an unticked chip still says what ticking it would add.
  Map<ActivityCategory, int> get categoryCounts => _categoryCounts;

  DateTime? _oldestAt;

  /// When the oldest row in the window happened — where the timeline starts,
  /// and the earliest day the range picker offers.
  DateTime? get oldestAt => _oldestAt;

  final Set<String> _expandedRuns = <String>{};

  int _firstDayOfWeek = DateTime.monday;

  /// Which weekday a week-wide bar starts on (`DateTime.monday` …
  /// `DateTime.sunday`), from the locale. Same phase rules as
  /// [setTitleResolver]: the screen calls this from `didChangeDependencies`.
  void setFirstDayOfWeek(int weekday) {
    if (weekday == _firstDayOfWeek) return;
    _firstDayOfWeek = weekday;
    _recomputeSoon();
  }

  String _title(DashboardActivity a) =>
      _titleCache[a.id] ??= _titleResolver?.call(a) ?? '';

  bool matches(DashboardActivity a) =>
      _matchesBase(a) && _inRange(a) && _inCategories(a);

  bool _inRange(DashboardActivity a) {
    final f = _filters;
    if (!f.hasRange) return true;
    final t = activityTime(a);
    if (f.from != null && t.isBefore(f.from!)) return false;
    if (f.until != null && !t.isBefore(f.until!)) return false;
    return true;
  }

  bool _inCategories(DashboardActivity a) =>
      _filters.categories.isEmpty ||
      _filters.categories.contains(activityCategoryFor(a));

  /// Every predicate except the two the timeline and the category facet each
  /// leave out of their own counts.
  bool _matchesBase(DashboardActivity a) {
    final f = _filters;
    if (f.lens != ActivityLens.all &&
        a.activityTypeId != kCommentActivityTypeId) {
      return false;
    }
    // Calls are a content slice of the same activity type, not a type of their
    // own — the marker in the note is the only signal the wire carries.
    if (f.lens == ActivityLens.calls && !isCallNoteText(a.notes)) return false;
    if (f.userId != null && a.userId != f.userId) return false;
    // The type picker is inert under a narrowed lens (see
    // [ActivityFilters.lens]) — honour that here too, so a persisted
    // combination can't resurrect a filter the UI is hiding.
    if (f.lens == ActivityLens.all &&
        f.typeIds.isNotEmpty &&
        !f.typeIds.contains(a.activityTypeId)) {
      return false;
    }
    final needle = f.search.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (_title(a).toLowerCase().contains(needle)) return true;
    if (a.notes.toLowerCase().contains(needle)) return true;
    for (final label in a.labels.values) {
      if (label.toLowerCase().contains(needle)) return true;
    }
    return false;
  }

  void _recompute() {
    if (_disposed) return;
    final rows = _section.data;
    if (rows == null) {
      _entries = const <ActivityFeedEntry>[];
      _matchCount = 0;
      _timeline = ActivityTimeline.empty;
      _categoryCounts = const {};
      _oldestAt = null;
      notifyListeners();
      return;
    }
    // One pass, because `_matchesBase` is the expensive predicate (it renders
    // the sentence for the text search) and three outputs need it.
    final kept = <DashboardActivity>[];
    final forTimeline = <DashboardActivity>[];
    final counts = <ActivityCategory, int>{};
    for (final a in rows) {
      if (!_matchesBase(a)) continue;
      final inRange = _inRange(a);
      final inCategories = _inCategories(a);
      if (inCategories) forTimeline.add(a);
      if (inRange) {
        final c = activityCategoryFor(a);
        counts[c] = (counts[c] ?? 0) + 1;
      }
      if (inRange && inCategories) kept.add(a);
    }
    kept.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final perDay = <DateTime, int>{};
    for (final a in kept) {
      final day = localDayOf(a);
      perDay[day] = (perDay[day] ?? 0) + 1;
    }
    final out = <ActivityFeedEntry>[];
    DateTime? currentDay;
    // Runs never span a day (the day is part of their key), so a header can
    // only ever fall between two runs.
    for (final run in collapseRuns(kept, targetOf: activityDeepLinkTarget)) {
      final day = localDayOf(run.first);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        out.add(ActivityDayHeader(day, count: perDay[day] ?? 0));
      }
      if (run.length == 1) {
        out.add(ActivityFeedItem(run.first));
        continue;
      }
      final runId = run.first.id;
      final expanded = _expandedRuns.contains(runId);
      for (final a in expanded ? run : run.take(1)) {
        out.add(ActivityFeedItem(a));
      }
      out.add(
        ActivityRunToggle(
          runId: runId,
          hidden: run.length - 1,
          expanded: expanded,
        ),
      );
    }

    _entries = List.unmodifiable(out);
    _matchCount = kept.length;
    _categoryCounts = Map.unmodifiable(counts);
    _timeline = bucketize(
      forTimeline,
      now: _now(),
      spanOf: rows,
      firstDayOfWeek: _firstDayOfWeek,
    );
    DateTime? oldest;
    for (final a in rows) {
      final t = activityTime(a);
      if (oldest == null || t.isBefore(oldest)) oldest = t;
    }
    _oldestAt = oldest;
    notifyListeners();
  }

  // ─── Filter mutations ────────────────────────────────────────────────

  void _apply(ActivityFilters next) {
    _filters = next;
    _userTouched = true;
    _recompute();
    _schedulePersist();
  }

  void setUser(String? userId) =>
      _apply(_filters.copyWith(userId: () => userId));

  void setTypeIds(Set<int> ids) =>
      _apply(_filters.copyWith(typeIds: Set<int>.unmodifiable(ids)));

  void setSearch(String search) => _apply(_filters.copyWith(search: search));

  void setLens(ActivityLens lens) => _apply(_filters.copyWith(lens: lens));

  /// `[from, until)` in local time; `(null, null)` clears the range.
  void setRange(DateTime? from, DateTime? until) =>
      _apply(_filters.copyWith(range: (from, until)));

  void toggleCategory(ActivityCategory c) {
    final next = {..._filters.categories};
    if (!next.remove(c)) next.add(c);
    _apply(_filters.copyWith(categories: Set.unmodifiable(next)));
  }

  void clearCategories() =>
      _apply(_filters.copyWith(categories: const <ActivityCategory>{}));

  void clearFilters() => _apply(const ActivityFilters());

  /// Opens or folds a run. View state, not a filter: not persisted, and it
  /// survives a refresh only while the run's newest row does.
  void toggleRun(String runId) {
    if (!_expandedRuns.remove(runId)) _expandedRuns.add(runId);
    _recompute();
  }

  // ─── Restore-on-restart persistence ──────────────────────────────────

  Future<void> _hydrate() async {
    try {
      final row = await navStateDao!.current();
      final raw = row?.filtersJson;
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final company = decoded[companyId];
      if (company is! Map) return;
      final snap = company[_persistKey];
      if (snap is! Map) return;
      // The user acted before hydration resolved — restoring would clobber it.
      if (_userTouched) return;
      _filters = ActivityFilters.fromJson(Map<String, dynamic>.from(snap));
      _recompute();
    } catch (e, st) {
      _log.warning('Failed to hydrate activity filters; using defaults', e, st);
    } finally {
      _hydrated = true;
      if (!_disposed) notifyListeners();
    }
  }

  void _schedulePersist() {
    if (!_hydrated || navStateDao == null || companyId.isEmpty) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _persist);
  }

  Future<void> _persist() async {
    final dao = navStateDao;
    if (dao == null || companyId.isEmpty) return;
    try {
      final row = await dao.current();
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
      companyMap[_persistKey] = _filters.toJson();
      doc[companyId] = companyMap;
      await dao.saveFilters(
        filtersJson: jsonEncode(doc),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      _log.warning('Failed to persist activity filters', e, st);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final hadPending = _persistTimer?.isActive ?? false;
    _persistTimer?.cancel();
    // Flush a pending debounced write so leaving the screen (or switching
    // company) inside the debounce window doesn't drop the last filter change —
    // the same reason `ReportsViewModel.dispose` does it. Targets this VM's
    // captured `companyId`, so it can't cross-write another company.
    if (hadPending) unawaited(_persist());
    unawaited(_sub?.cancel());
    unawaited(_fetchedAtSub?.cancel());
    super.dispose();
  }
}

/// Local calendar day (device zone) an activity landed on.
///
/// `fromMillisecondsSinceEpoch` with the default `isUtc: false` already yields
/// the local-zone rendering of that instant, so the y/m/d below is the local
/// day — which is what a "Today / Yesterday" separator has to mean.
DateTime localDayOf(DashboardActivity a) {
  final at = DateTime.fromMillisecondsSinceEpoch(a.createdAt * 1000);
  return DateTime(at.year, at.month, at.day);
}
