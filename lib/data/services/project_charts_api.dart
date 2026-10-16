import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';

/// Bucket granularity for the burn-up series. Wire values match
/// `ShowProjectBurnUpRequest`'s `in:daily,weekly,monthly`.
enum BurnupBucket {
  daily,
  weekly,
  monthly;

  String get wireName => name;

  /// The bucket that suits a window [days] long: one bar a day up to three
  /// months, one a week up to two years, then one a month — so neither a
  /// week-old project is three dots nor a five-year one 1,800 buckets.
  static BurnupBucket forSpan(int days) {
    if (days <= 90) return BurnupBucket.daily;
    if (days <= 730) return BurnupBucket.weekly;
    return BurnupBucket.monthly;
  }
}

/// Read-only service for the per-project chart endpoints
/// (`POST /api/v1/charts/project_analytics/{project}` and
/// `.../project_burnup/{project}`, server 5.13.27+ —
/// `ServerFeatures.projectAnalytics`).
///
/// Deliberately shaped like [DashboardApi] rather than `BaseEntityApi`: these
/// aren't CRUD resources, there's no keyset cursor, and the payloads don't fit
/// the list/item envelope. Like the dashboard charts, results are **live
/// server reads and are never written to Drift** — the "Drift is the only
/// thing the UI reads from" rule governs entity state, not derived analytics.
///
/// Both methods return the **unwrapped** payload (the inner `data` when the
/// server wraps it), so callers decode without re-stripping an envelope.
/// Network exceptions, 401 single-flight, and version negotiation all flow
/// through [ApiClient].
class ProjectChartsApi {
  ProjectChartsApi(this.client);

  final ApiClient client;

  /// `POST /api/v1/charts/project_analytics/{projectId}`.
  ///
  /// Returns a map of 14 analytics blocks, each a list of per-project rows
  /// (exactly one row here, since the route is project-scoped), plus
  /// `metadata`. **No dates:** `ProjectAnalyticsService` reads none, so every
  /// figure is the project's lifetime whatever window is sent — sending one
  /// only made the screen look as if it narrowed something.
  Future<Object?> fetchAnalytics({
    required String projectId,
    bool includeDrafts = false,
  }) async {
    final raw = await client.postJson(
      '/api/v1/charts/project_analytics/$projectId',
      body: {'include_drafts': includeDrafts},
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `POST /api/v1/charts/project_burnup/{projectId}`.
  ///
  /// Returns `{start_date, end_date, bucket_type, project{…}, markers{…},
  /// series[], totals, metadata}`.
  ///
  /// [startDate] / [endDate] null leaves the window to the server, which
  /// spans the project's life: created → the later of today and the due date
  /// (`ShowProjectBurnUpRequest::prepareForValidation`). That is the default,
  /// and the reason it is not computed here: the server reads the project's
  /// own timestamps, with no device time zone in between.
  Future<Object?> fetchBurnup({
    required String projectId,
    Date? startDate,
    Date? endDate,
    BurnupBucket bucket = BurnupBucket.daily,
    bool includeDrafts = false,
  }) async {
    final raw = await client.postJson(
      '/api/v1/charts/project_burnup/$projectId',
      body: {
        if (startDate != null && endDate != null) ...{
          'date_range': 'custom',
          'start_date': startDate.toIso(),
          'end_date': endDate.toIso(),
        },
        'include_drafts': includeDrafts,
        'bucket_type': bucket.wireName,
      },
      readOnly: true,
    );
    return _unwrap(raw);
  }

  Object? _unwrap(Object? raw) {
    if (raw is Map && raw['data'] != null) return raw['data'];
    return raw;
  }
}
