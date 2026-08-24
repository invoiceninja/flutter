import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';

final _log = Logger('ActivityViewModel');

/// `activity_type_id` the server writes for a user comment posted through
/// `POST /api/v1/activities/notes` (see `ActivitiesApi.addNote`).
const int kCommentActivityTypeId = 141;

/// The four client-side predicates the `/activity` screen narrows with.
///
/// All four are local by necessity: `GET /api/v1/activities` accepts **no**
/// filters at all — no `ActivityFilters` class exists server-side and
/// `QueryFilters::apply` drops unknown params silently (BACKEND.md § F3) — so
/// they operate over the most recent `kActivityFeedRows` company rows.
@immutable
class ActivityFilters {
  const ActivityFilters({
    this.userId,
    this.typeIds = const <int>{},
    this.search = '',
    this.commentsOnly = false,
  });

  final String? userId;
  final Set<int> typeIds;
  final String search;

  /// Restricts to comment rows. ANDs with the rest, and the screen **disables**
  /// the type picker while it is on — otherwise picking types here would be
  /// silently discarded by the `activity_type_id == 141` test.
  final bool commentsOnly;

  bool get isActive =>
      userId != null ||
      typeIds.isNotEmpty ||
      search.trim().isNotEmpty ||
      commentsOnly;

  int get activeCount =>
      (userId != null ? 1 : 0) +
      (typeIds.isNotEmpty ? 1 : 0) +
      (search.trim().isNotEmpty ? 1 : 0) +
      (commentsOnly ? 1 : 0);

  ActivityFilters copyWith({
    String? Function()? userId,
    Set<int>? typeIds,
    String? search,
    bool? commentsOnly,
  }) => ActivityFilters(
    userId: userId != null ? userId() : this.userId,
    typeIds: typeIds ?? this.typeIds,
    search: search ?? this.search,
    commentsOnly: commentsOnly ?? this.commentsOnly,
  );

  Map<String, dynamic> toJson() => {
    if (userId != null) 'user': userId,
    if (typeIds.isNotEmpty) 'types': typeIds.toList()..sort(),
    if (search.isNotEmpty) 'search': search,
    if (commentsOnly) 'comments': true,
  };

  static ActivityFilters fromJson(Map<String, dynamic> json) {
    final rawTypes = json['types'];
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
      commentsOnly: json['comments'] == true,
    );
  }
}

/// One entry in the flattened feed: either a day separator or a row. Flattened
/// in the ViewModel so the screen can drive a plain `ListView.builder`.
sealed class ActivityFeedEntry {
  const ActivityFeedEntry();
}

/// Local-calendar-day separator. [day] is midnight in the *device's* zone.
class ActivityDayHeader extends ActivityFeedEntry {
  const ActivityDayHeader(this.day);
  final DateTime day;
}

class ActivityFeedItem extends ActivityFeedEntry {
  const ActivityFeedItem(this.activity);
  final DashboardActivity activity;
}

/// State holder for the `/activity` screen.
///
/// Reads the **same** Drift cache row as the dashboard's Activity card
/// (`dashboard_cache`, kind `activities`), so the screen paints instantly from
/// cache and a refresh on either surface updates both.
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

  Future<void> refresh() async {
    if (companyId.isEmpty || _disposed) return;
    _isRefreshing = true;
    notifyListeners();
    try {
      await repo.refreshActivities(companyId);
      _lastRefreshed = _now();
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
      // notify, so guard it, exactly as `ClientActivityViewModel.refresh` does.
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

  String _title(DashboardActivity a) =>
      _titleCache[a.id] ??= _titleResolver?.call(a) ?? '';

  bool matches(DashboardActivity a) {
    final f = _filters;
    if (f.commentsOnly && a.activityTypeId != kCommentActivityTypeId) {
      return false;
    }
    if (f.userId != null && a.userId != f.userId) return false;
    // The type picker is inert while comments-only is on (see
    // [ActivityFilters.commentsOnly]) — honour that here too, so a persisted
    // combination can't resurrect a filter the UI is hiding.
    if (!f.commentsOnly &&
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
      notifyListeners();
      return;
    }
    final kept = rows.where(matches).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final out = <ActivityFeedEntry>[];
    DateTime? currentDay;
    for (final a in kept) {
      final day = localDayOf(a);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        out.add(ActivityDayHeader(day));
      }
      out.add(ActivityFeedItem(a));
    }
    _entries = List.unmodifiable(out);
    _matchCount = kept.length;
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

  void setCommentsOnly(bool value) =>
      _apply(_filters.copyWith(commentsOnly: value));

  void clearFilters() => _apply(const ActivityFilters());

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
