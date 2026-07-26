import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/project_charts_api.dart';

/// Window presets for the Analytics tab. Kept local (rather than reusing the
/// dashboard's `DashboardFilter`) because this tab has no currency selector,
/// no compare-to-previous, and its natural default is the project's whole
/// life rather than a calendar month.
enum ProjectAnalyticsRange {
  last30Days,
  last365Days,
  allTime;

  /// Start date for the window, relative to [today]. `allTime` reaches far
  /// enough back to cover any project; the server clamps to real data.
  Date startFrom(Date today) => switch (this) {
    ProjectAnalyticsRange.last30Days => today.addDays(-30),
    ProjectAnalyticsRange.last365Days => today.addDays(-365),
    ProjectAnalyticsRange.allTime => Date(today.year - 20, 1, 1),
  };

  String get labelKey => switch (this) {
    ProjectAnalyticsRange.last30Days => 'last_30_days',
    ProjectAnalyticsRange.last365Days => 'last365_days',
    ProjectAnalyticsRange.allTime => 'all_time',
  };
}

/// Drives the project Analytics tab: fetches
/// `charts/project_analytics/{id}` + `charts/project_burnup/{id}` and holds
/// the window / bucket / include-drafts controls.
///
/// Both payloads are **live server reads, never persisted to Drift** — the
/// same status as the dashboard charts. That means the tab needs a network
/// round-trip to show anything; [errorMessage] carries the failure so the view
/// can offer Retry instead of an empty card.
class ProjectAnalyticsViewModel extends ChangeNotifier {
  ProjectAnalyticsViewModel({
    required this.api,
    required this.projectId,
    Date? today,
  }) : _today = today ?? Date.today();

  final ProjectChartsApi api;
  final String projectId;
  final Date _today;

  ProjectAnalyticsRange _range = ProjectAnalyticsRange.allTime;
  ProjectAnalyticsRange get range => _range;

  BurnupBucket _bucket = BurnupBucket.weekly;
  BurnupBucket get bucket => _bucket;

  bool _includeDrafts = false;
  bool get includeDrafts => _includeDrafts;

  /// Set in [dispose] so the async [load] can bail instead of notifying a
  /// dead notifier — navigating off the project detail screen mid-request
  /// disposes this VM while both chart calls are still in flight. Mirrors the
  /// guard on `GenericDetailViewModel` / `GenericListViewModel`.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _loading = false;
  bool get loading => _loading;

  /// True only for the very first load, so the view can show a full-tab
  /// spinner once and then refresh in place without blanking the cards.
  bool get initialLoading => _loading && !_loadedOnce;
  bool _loadedOnce = false;

  /// A server-formatted failure message, shown verbatim. Null when the failure
  /// has no message of its own — see [errorKey].
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Localization key for a failure with no server message (the view resolves
  /// it via `context.tr`). Exactly one of this and [errorMessage] is non-null
  /// while [hasError] is true.
  String? _errorKey;
  String? get errorKey => _errorKey;

  bool get hasError => _errorMessage != null || _errorKey != null;

  ProjectAnalytics? _analytics;
  ProjectAnalytics? get analytics => _analytics;

  ProjectBurnup? _burnup;
  ProjectBurnup? get burnup => _burnup;

  /// True when the server answered but there is nothing to draw — a project
  /// with no tasks, invoices or expenses in the window.
  bool get isEmpty =>
      _loadedOnce &&
      !hasError &&
      (_analytics?.isEmpty ?? true) &&
      (_burnup?.isEmpty ?? true);

  /// Guards against an out-of-order response overwriting a newer one when the
  /// user flips controls faster than the network answers.
  int _requestSeq = 0;

  void setRange(ProjectAnalyticsRange value) {
    if (_range == value) return;
    _range = value;
    notifyListeners();
    load();
  }

  void setBucket(BurnupBucket value) {
    if (_bucket == value) return;
    _bucket = value;
    notifyListeners();
    load();
  }

  void setIncludeDrafts(bool value) {
    if (_includeDrafts == value) return;
    _includeDrafts = value;
    notifyListeners();
    load();
  }

  /// Fetch both payloads. The two calls run concurrently and are decoded
  /// independently, so one endpoint failing (or not being deployed yet) still
  /// renders the other's cards.
  Future<void> load() async {
    if (_disposed) return;
    final seq = ++_requestSeq;
    _loading = true;
    _errorMessage = null;
    _errorKey = null;
    notifyListeners();

    final start = _range.startFrom(_today);
    // Request-local, so an abandoned load's failures can't be attributed to a
    // newer one that happens to finish first.
    final errors = <String>[];
    final results = await Future.wait<Object?>([
      _guard(
        () => api.fetchAnalytics(
          projectId: projectId,
          startDate: start,
          endDate: _today,
          includeDrafts: _includeDrafts,
        ),
        errors,
      ),
      _guard(
        () => api.fetchBurnup(
          projectId: projectId,
          startDate: start,
          endDate: _today,
          bucket: _bucket,
          includeDrafts: _includeDrafts,
        ),
        errors,
      ),
    ]);

    // Disposed while in flight (the user navigated away), or a newer request
    // superseded this one — either way, drop the answer without touching
    // state. Notifying past dispose throws `debugAssertNotDisposed`.
    if (_disposed || seq != _requestSeq) return;

    final analyticsRaw = results[0];
    final burnupRaw = results[1];
    _analytics = analyticsRaw is Map
        ? ProjectAnalytics.fromJson(_asMap(analyticsRaw))
        : null;
    _burnup = burnupRaw is Map
        ? ProjectBurnup.fromJson(_asMap(burnupRaw))
        : null;

    // Only surface an error when BOTH calls came back empty — a partial
    // answer is still worth rendering.
    if (_analytics == null && _burnup == null) {
      // A server-formatted message is shown as-is; with none (both calls
      // returned 200 carrying nothing decodable) fall back to a localization
      // KEY the view resolves — a bare slug used to reach the screen.
      _errorMessage = errors.isEmpty ? null : errors.first;
      _errorKey = errors.isEmpty ? 'analytics_unexpected_response' : null;
    }
    _loading = false;
    _loadedOnce = true;
    notifyListeners();
  }

  /// Runs one fetch, converting any failure into a null result plus a message
  /// appended to [errors]. Keeps `Future.wait` from short-circuiting on the
  /// first throw.
  ///
  /// [errors] is created per `load()` rather than being a field: two loads can
  /// be in flight at once (flip a control while the first is still parked on
  /// the network), and a shared stash let the *abandoned* request's message
  /// surface as the reason a newer one failed.
  Future<Object?> _guard(
    Future<Object?> Function() fetch,
    List<String> errors,
  ) async {
    try {
      return await fetch();
    } on ApiException catch (e) {
      errors.add(e.message);
      return null;
    } catch (e) {
      errors.add(e.toString());
      return null;
    }
  }

  static Map<String, dynamic> _asMap(Object raw) {
    if (raw is Map<String, dynamic>) return raw;
    return (raw as Map).map((k, v) => MapEntry(k.toString(), v));
  }
}
