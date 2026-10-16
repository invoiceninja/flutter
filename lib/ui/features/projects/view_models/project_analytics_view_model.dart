import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/data/services/realtime/realtime_service.dart';

/// The burn-up's window. The rest of the tab has none: the analytics endpoint
/// reads no dates, so its figures are the project's lifetime whatever this
/// says — which is why the control sits on the burn-up alone.
enum ProjectBurnupRange {
  /// Created → the later of today and the due date, the server's own window
  /// when it is sent no dates.
  projectLife,
  last30Days,
  last365Days;

  String get labelKey => switch (this) {
    ProjectBurnupRange.projectLife => 'all_time',
    ProjectBurnupRange.last30Days => 'last_30_days',
    ProjectBurnupRange.last365Days => 'last365_days',
  };
}

/// Why a fetch came back with nothing, by what the user can do about it.
enum ProjectAnalyticsFailure {
  /// No connection: Retry when there is one.
  offline,

  /// The server has no such endpoint (a 404) — an install older than the
  /// version gate thought, or one that reports a version it does not run.
  unavailable,

  /// The server refused this user. The tab is gated so this should not
  /// happen; when it does there is nothing to retry.
  forbidden,

  /// Anything else — a 5xx, a refused request. [ProjectAnalyticsViewModel]
  /// keeps the server's message.
  other,
}

/// Drives the project Analytics tab: fetches
/// `charts/project_analytics/{id}` + `charts/project_burnup/{id}` and holds
/// the burn-up's window / bucket and the include-drafts switch.
///
/// Both payloads are **live server reads, never persisted to Drift** — the
/// same status as the dashboard charts.
///
/// **It refetches on its own.** A tab stays mounted once it has been opened,
/// so this view model can outlive the figures it fetched by hours: time
/// logged in the Tasks tab, a payment entered, a Sync. It follows the three
/// signals the dashboard does — a completed Sync pass, a pushed server
/// change, a change of the user's own leaving the outbox — plus
/// [refreshQuietly], which the tab calls when the project row itself changes.
///
/// **A failed refresh keeps what was on screen.** Each payload's last good
/// answer stays until a newer one replaces it; the failure is reported beside
/// it ([analyticsFailure], [burnupFailure]) rather than in its place.
class ProjectAnalyticsViewModel extends ChangeNotifier {
  ProjectAnalyticsViewModel({
    required this.api,
    required this.projectId,
    required this.companyId,
    Date? projectStart,
    Date? projectDue,

    /// A fixed day for tests; the app reads the clock each time, so a tab
    /// left open past midnight moves with it.
    Date? today,
    ValueListenable<ResyncCompletion?>? resyncCompletions,
    ValueListenable<RealtimeRefresh?>? realtimeRefreshes,
    Stream<int>? outboxActive,
    this.refetchDelay = const Duration(seconds: 2),
  }) : _todayOf = today == null ? Date.today : (() => today),
       _projectStart = projectStart,
       _projectDue = projectDue,
       _resyncCompletions = resyncCompletions,
       _realtimeRefreshes = realtimeRefreshes {
    _bucket = _autoBucket();
    resyncCompletions?.addListener(_onResyncCompleted);
    realtimeRefreshes?.addListener(_onRealtimeRefresh);
    _outboxSub = outboxActive?.listen(_onOutboxActive);
  }

  final ProjectChartsApi api;
  final String projectId;
  final String companyId;
  final Date Function() _todayOf;
  Date? _projectStart;
  Date? _projectDue;
  final ValueListenable<ResyncCompletion?>? _resyncCompletions;
  final ValueListenable<RealtimeRefresh?>? _realtimeRefreshes;
  StreamSubscription<int>? _outboxSub;
  int? _outboxActive;
  Timer? _refetchTimer;

  /// How long a refetch trigger waits, so a burst — three saves draining —
  /// is one request, after the last.
  final Duration refetchDelay;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _refetchTimer?.cancel();
    _resyncCompletions?.removeListener(_onResyncCompleted);
    _realtimeRefreshes?.removeListener(_onRealtimeRefresh);
    unawaited(_outboxSub?.cancel());
    super.dispose();
  }

  // ── Controls ─────────────────────────────────────────────────────────

  ProjectBurnupRange _range = ProjectBurnupRange.projectLife;
  ProjectBurnupRange get range => _range;

  late BurnupBucket _bucket;
  BurnupBucket get bucket => _bucket;

  /// Set once the user picks a bucket; until then each window gets the one
  /// that suits its span ([BurnupBucket.forSpan]).
  bool _bucketChosen = false;

  bool _includeDrafts = false;
  bool get includeDrafts => _includeDrafts;

  /// The burn-up window's first and last day, as this view model reckons it —
  /// for choosing a bucket. The request itself sends no dates for
  /// [ProjectBurnupRange.projectLife].
  (Date, Date) get _window {
    final today = _todayOf();
    final due = _projectDue;
    final end = switch (_range) {
      ProjectBurnupRange.projectLife =>
        due != null && due.compareTo(today) > 0 ? due : today,
      _ => today,
    };
    final start = switch (_range) {
      ProjectBurnupRange.projectLife => _projectStart ?? today,
      ProjectBurnupRange.last30Days => today.addDays(-30),
      ProjectBurnupRange.last365Days => today.addDays(-365),
    };
    return (start, end);
  }

  BurnupBucket _autoBucket() {
    final (start, end) = _window;
    return BurnupBucket.forSpan(end.differenceInDays(start).abs());
  }

  void setRange(ProjectBurnupRange value) {
    if (_range == value) return;
    _range = value;
    if (!_bucketChosen) _bucket = _autoBucket();
    notifyListeners();
    unawaited(_loadBurnup());
  }

  void setBucket(BurnupBucket value) {
    _bucketChosen = true;
    if (_bucket == value) return;
    _bucket = value;
    notifyListeners();
    unawaited(_loadBurnup());
  }

  void setIncludeDrafts(bool value) {
    if (_includeDrafts == value) return;
    _includeDrafts = value;
    notifyListeners();
    unawaited(load());
  }

  /// The project's start or due date changed under a mounted tab. The
  /// project-life window is the server's and follows on its own; what does
  /// not is the bucket chosen for its span — extend the due date by two years
  /// and the daily bucket would ask for 700 of them. Re-picked unless the
  /// user chose one, then refetched.
  void updateProject({required Date? start, required Date? due}) {
    if (_disposed || (start == _projectStart && due == _projectDue)) return;
    _projectStart = start;
    _projectDue = due;
    if (!_bucketChosen) _bucket = _autoBucket();
    notifyListeners();
    refreshQuietly();
  }

  // ── State ────────────────────────────────────────────────────────────

  ProjectAnalytics? _analytics;
  ProjectAnalytics? get analytics => _analytics;

  ProjectBurnup? _burnup;
  ProjectBurnup? get burnup => _burnup;

  bool _loadingAnalytics = false;
  bool _loadingBurnup = false;
  bool get loading => _loadingAnalytics || _loadingBurnup;

  bool _analyticsTried = false;
  bool _burnupTried = false;

  /// Nothing to show yet and a first answer still coming — the one time the
  /// tab shows a spinner instead of its sections.
  bool get initialLoading =>
      _analytics == null &&
      _burnup == null &&
      (!_analyticsTried || !_burnupTried);

  ProjectAnalyticsFailure? _analyticsFailure;
  ProjectAnalyticsFailure? get analyticsFailure => _analyticsFailure;
  String? _analyticsMessage;

  ProjectAnalyticsFailure? _burnupFailure;
  ProjectAnalyticsFailure? get burnupFailure => _burnupFailure;
  String? _burnupMessage;

  /// The server's own words for an [ProjectAnalyticsFailure.other] failure.
  String? get failureMessage => _analyticsMessage ?? _burnupMessage;

  /// Both fetches failed and there is nothing from before to show.
  ProjectAnalyticsFailure? get blockingFailure {
    if (_analytics != null || _burnup != null) return null;
    if (!_analyticsTried || !_burnupTried) return null;
    return _analyticsFailure ?? _burnupFailure;
  }

  /// Whether the user may see money: the analytics answer's metadata, else
  /// the burn-up's, else — nothing known yet — yes.
  bool get canViewFinancials =>
      _analytics?.canViewFinancials ?? _burnup?.canViewFinancials ?? true;

  int _analyticsSeq = 0;
  int _burnupSeq = 0;

  /// Fetch both payloads. They run concurrently and land independently, so
  /// one endpoint failing still renders the other's sections.
  Future<void> load() =>
      Future.wait([_loadAnalytics(), _loadBurnup()]).then((_) {});

  /// [load], for a trigger the user did not pull — the same request; what
  /// is on screen stays there while it runs.
  void refreshQuietly() {
    if (_disposed) return;
    _refetchTimer?.cancel();
    _refetchTimer = Timer(refetchDelay, () => unawaited(load()));
  }

  Future<void> _loadAnalytics() async {
    if (_disposed) return;
    final seq = ++_analyticsSeq;
    _loadingAnalytics = true;
    notifyListeners();
    try {
      final raw = await api.fetchAnalytics(
        projectId: projectId,
        includeDrafts: _includeDrafts,
      );
      if (_disposed || seq != _analyticsSeq) return;
      if (raw is Map) {
        _analytics = ProjectAnalytics.fromJson(_asMap(raw));
        _analyticsFailure = null;
        _analyticsMessage = null;
      } else {
        _analyticsFailure = ProjectAnalyticsFailure.other;
        _analyticsMessage = null;
      }
    } catch (e) {
      if (_disposed || seq != _analyticsSeq) return;
      final (failure, message) = _classify(e);
      _analyticsFailure = failure;
      _analyticsMessage = message;
    }
    _analyticsTried = true;
    _loadingAnalytics = false;
    notifyListeners();
  }

  Future<void> _loadBurnup() async {
    if (_disposed) return;
    final seq = ++_burnupSeq;
    _loadingBurnup = true;
    notifyListeners();
    final (start, end) = _window;
    final life = _range == ProjectBurnupRange.projectLife;
    try {
      final raw = await api.fetchBurnup(
        projectId: projectId,
        startDate: life ? null : start,
        endDate: life ? null : end,
        bucket: _bucket,
        includeDrafts: _includeDrafts,
      );
      if (_disposed || seq != _burnupSeq) return;
      if (raw is Map) {
        _burnup = ProjectBurnup.fromJson(_asMap(raw));
        _burnupFailure = null;
        _burnupMessage = null;
      } else {
        _burnupFailure = ProjectAnalyticsFailure.other;
        _burnupMessage = null;
      }
    } catch (e) {
      if (_disposed || seq != _burnupSeq) return;
      final (failure, message) = _classify(e);
      _burnupFailure = failure;
      _burnupMessage = message;
    }
    _burnupTried = true;
    _loadingBurnup = false;
    notifyListeners();
  }

  /// The failure by what can be done about it. The type survives to here —
  /// it used to be flattened to its message, so being offline read "Analytics
  /// aren't available from this server yet".
  static (ProjectAnalyticsFailure, String?) _classify(Object e) => switch (e) {
    NetworkException() => (ProjectAnalyticsFailure.offline, null),
    PermissionDeniedException() => (ProjectAnalyticsFailure.forbidden, null),
    ServerException(statusCode: 404) => (
      ProjectAnalyticsFailure.unavailable,
      null,
    ),
    ServerException(statusCode: 403) => (
      ProjectAnalyticsFailure.forbidden,
      null,
    ),
    ApiException(:final message) => (
      ProjectAnalyticsFailure.other,
      message.trim().isEmpty ? null : message,
    ),
    _ => (ProjectAnalyticsFailure.other, null),
  };

  // ── Refetch triggers ─────────────────────────────────────────────────

  void _onResyncCompleted() {
    final done = _resyncCompletions?.value;
    if (_disposed || done == null || done.companyId != companyId) return;
    refreshQuietly();
  }

  void _onRealtimeRefresh() {
    final done = _realtimeRefreshes?.value;
    if (_disposed || done == null || done.companyId != companyId) return;
    refreshQuietly();
  }

  /// A drop in the count means a change has left the outbox: the server has
  /// it now. A rise — a save going in — is still queued and would be answered
  /// with the old figures.
  void _onOutboxActive(int count) {
    final before = _outboxActive;
    _outboxActive = count;
    if (_disposed || before == null || count >= before) return;
    refreshQuietly();
  }

  static Map<String, dynamic> _asMap(Object raw) {
    if (raw is Map<String, dynamic>) return raw;
    return (raw as Map).map((k, v) => MapEntry(k.toString(), v));
  }
}
