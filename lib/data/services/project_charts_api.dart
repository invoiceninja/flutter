import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';

/// Bucket granularity for the burn-up series. Wire values match
/// `ShowProjectBurnUpRequest`'s `in:daily,weekly,monthly`.
enum BurnupBucket {
  daily,
  weekly,
  monthly;

  String get wireName => name;
}

/// Read-only service for the per-project chart endpoints
/// (`POST /api/v1/charts/project_analytics/{project}` and
/// `.../project_burnup/{project}`, both added server-side 2026-06-30).
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
///
/// **Server availability:** verified 404 on `demo.invoiceninja.com`
/// (2026-07-24) — the demo host runs an older build than `v5-develop`. The
/// shapes below are modelled from the server source
/// (`app/Services/Chart/ProjectAnalyticsService.php` /
/// `ProjectBurnUpService.php`); decoding is tolerant throughout so a partial
/// or evolving payload degrades to empty cards instead of throwing.
class ProjectChartsApi {
  ProjectChartsApi(this.client);

  final ApiClient client;

  /// `POST /api/v1/charts/project_analytics/{projectId}`.
  ///
  /// Returns a map of 14 analytics blocks, each a list of per-project rows
  /// (exactly one row here, since the route is project-scoped).
  Future<Object?> fetchAnalytics({
    required String projectId,
    required Date startDate,
    required Date endDate,
    bool includeDrafts = false,
  }) async {
    final raw = await client.postJson(
      '/api/v1/charts/project_analytics/$projectId',
      body: _periodBody(
        startDate: startDate,
        endDate: endDate,
        includeDrafts: includeDrafts,
      ),
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `POST /api/v1/charts/project_burnup/{projectId}`.
  ///
  /// Returns `{start_date, end_date, bucket_type, project{…}, markers{…},
  /// series[]}` where each series bucket carries per-bucket and cumulative
  /// hours/money plus the `ideal_hours` / `ideal_amount` pace lines.
  Future<Object?> fetchBurnup({
    required String projectId,
    required Date startDate,
    required Date endDate,
    BurnupBucket bucket = BurnupBucket.weekly,
    bool includeDrafts = false,
  }) async {
    final raw = await client.postJson(
      '/api/v1/charts/project_burnup/$projectId',
      body: {
        ..._periodBody(
          startDate: startDate,
          endDate: endDate,
          includeDrafts: includeDrafts,
        ),
        'bucket_type': bucket.wireName,
      },
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// Both requests share this body. `date_range: custom` with explicit dates
  /// keeps the window under our control rather than re-deriving the server's
  /// named ranges — the request classes accept `custom` alongside the named
  /// set, and `include_drafts` goes in the body (not the query) for these two
  /// routes.
  Map<String, dynamic> _periodBody({
    required Date startDate,
    required Date endDate,
    required bool includeDrafts,
  }) => {
    'date_range': 'custom',
    'start_date': startDate.toIso(),
    'end_date': endDate.toIso(),
    'include_drafts': includeDrafts,
  };

  Object? _unwrap(Object? raw) {
    if (raw is Map && raw['data'] != null) return raw['data'];
    return raw;
  }
}
