import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';

/// How many of the most-recent company activity rows one fetch pulls down.
///
/// `GET /api/v1/activities?reactv2` is **unpaginated** — the server does
/// `->take($rows)` and defaults to 75 (`ActivityController::index`) — so this
/// is the whole window the app ever sees, and every filter on the `/activity`
/// screen narrows *within* it. Sibling of `kUserActivityScanRows` in
/// `activities_api.dart`, which scans the same endpoint for one actor.
const int kActivityFeedRows = 250;

/// Thin service for the read-only dashboard endpoints. Does **not** extend
/// `BaseEntityApi` — these aren't CRUD resources, there's no keyset cursor,
/// and the responses don't fit the standard list/item envelope shape.
///
/// Every method returns the **unwrapped** server payload (the inner `data`
/// object/array), so the dashboard repo can cache and decode it without
/// re-stripping the envelope. Network exceptions, 401 single-flight, and
/// version negotiation all flow through `ApiClient`.
class DashboardApi {
  DashboardApi(this.client);

  final ApiClient client;

  /// `POST /api/v1/charts/totals_v2`. Returns the totals map keyed by
  /// currency-id (plus a `currencies` id→label map).
  ///
  /// When [previousPeriod] is true, both dates are shifted back by the
  /// window length so the ViewModel can compute period-over-period deltas.
  Future<Object?> fetchTotals(
    DashboardFilter filter, {
    bool previousPeriod = false,
  }) async {
    final body = _periodBody(filter, previousPeriod: previousPeriod);
    final raw = await client.postJson(
      '/api/v1/charts/totals_v2',
      body: body,
      query: {'include_drafts': filter.includeDrafts.toString()},
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `POST /api/v1/charts/chart_summary_v2`. Returns the time-series payload
  /// (start/end dates + per-currency arrays of {date, total, currency}).
  Future<Object?> fetchChartSummary(DashboardFilter filter) async {
    final body = _periodBody(filter);
    final raw = await client.postJson(
      '/api/v1/charts/chart_summary_v2',
      body: body,
      query: {'include_drafts': filter.includeDrafts.toString()},
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `POST /api/v1/charts/calculated_fields`. One configured dashboard card.
  /// Returns a bare scalar (verified against the demo API). `period`
  /// (current/previous/total) is computed server-side from the same
  /// start/end — no client date-shift, unlike `totals_v2` previous.
  Future<Object?> fetchCalculatedField(
    DashboardFilter filter,
    DashboardCardConfig config,
  ) async {
    final body = {
      ..._periodBody(filter),
      'field': config.field,
      'calculation': config.calculate.name,
      'period': config.period.name,
      'format': config.format.name,
      'currency_id': filter.currencyId.toString(),
    };
    final raw = await client.postJson(
      '/api/v1/charts/calculated_fields',
      body: body,
      query: {'include_drafts': filter.includeDrafts.toString()},
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `GET /api/v1/activities?reactv2&rows=$kActivityFeedRows`. Returns a list
  /// of activity objects.
  ///
  /// One cache row (`dashboard_cache`, kind `activities`) serves **both** the
  /// dashboard's 5-row card and the full `/activity` screen, so there is a
  /// single window size — see [kActivityFeedRows].
  Future<Object?> fetchActivities() async {
    final raw = await client.getOneWithQuery(
      '/api/v1/activities',
      query: const {'reactv2': '', 'rows': '$kActivityFeedRows'},
    );
    return _unwrap(raw);
  }

  Future<Object?> fetchPastDueInvoices() =>
      _fetchList('/api/v1/invoices', const {
        'include': 'client.group_settings',
        'overdue': 'true',
        'without_deleted_clients': 'true',
        'per_page': '50',
        'page': '1',
        'sort': 'due_date|asc',
      });

  Future<Object?> fetchUpcomingInvoices() =>
      _fetchList('/api/v1/invoices', const {
        'include': 'client.group_settings',
        // `upcoming` filters to sent/partial invoices with a future (or null)
        // due date and applies its own server-side ordering — matches React.
        // Do NOT also send `sort`, or it competes with that ordering.
        'upcoming': 'true',
        'without_deleted_clients': 'true',
        'per_page': '50',
        'page': '1',
      });

  Future<Object?> fetchRecentPayments() => _fetchList(
    '/api/v1/payments',
    const {
      'include': 'client',
      // Most-recent first by payment date (the server otherwise defaults to
      // id-desc) and exclude payments whose client was deleted — matches React.
      'sort': 'date|desc',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
    },
  );

  Future<Object?> fetchExpiredQuotes() => _fetchList('/api/v1/quotes', const {
    'include': 'client',
    'client_status': 'expired',
    'without_deleted_clients': 'true',
    'per_page': '50',
    'page': '1',
    'sort': 'id|desc',
  });

  Future<Object?> fetchUpcomingQuotes() => _fetchList('/api/v1/quotes', const {
    'include': 'client',
    // Only sent quotes whose valid-until is today or later — matches React.
    'client_status': 'upcoming',
    'without_deleted_clients': 'true',
    'per_page': '50',
    'page': '1',
  });

  Future<Object?> fetchUpcomingRecurringInvoices() =>
      _fetchList('/api/v1/recurring_invoices', const {
        'include': 'client',
        // Only active recurring invoices, soonest next-send first — matches
        // React (the server otherwise returns every status in id-desc order).
        'client_status': 'active',
        'without_deleted_clients': 'true',
        'per_page': '50',
        'page': '1',
        'sort': 'next_send_date_client|asc',
      });

  // ---------------------------------------------------------------------------

  Future<Object?> _fetchList(String path, Map<String, String> query) async {
    final raw = await client.getOneWithQuery(path, query: query);
    return _unwrap(raw);
  }

  Map<String, dynamic> _periodBody(
    DashboardFilter filter, {
    bool previousPeriod = false,
  }) {
    final (start, end) = filter.resolveDates();
    var startDate = start;
    var endDate = end;
    if (previousPeriod) {
      final days = _windowDays(start, end);
      startDate = _shiftBack(start, days);
      endDate = _shiftBack(end, days);
    }
    return {
      'start_date': startDate.toIso(),
      'end_date': endDate.toIso(),
      'date_range': previousPeriod
          ? 'custom'
          : _serverDateRangeName(filter.range),
    };
  }

  int _windowDays(Date start, Date end) {
    // Date-space math (UTC) — local-midnight + Duration drifts an hour across
    // a DST transition and `.inDays` truncates to N-1, so the previous-period
    // comparison window would be a day short twice a year (M5).
    final days = end.differenceInDays(start) + 1;
    return days <= 0 ? 1 : days;
  }

  Date _shiftBack(Date date, int days) => date.addDays(-days);

  /// Map a [DashboardDateRange] to the server's `date_range` string. Server
  /// accepts presets (`this_month`, etc.) or `custom`.
  String _serverDateRangeName(DashboardDateRange range) {
    if (range is DashboardPresetRange) return range.preset.serverName;
    return 'custom';
  }

  /// Unwrap the standard `{data: ...}` envelope. Pass-through if the server
  /// returns an unwrapped payload (e.g. some endpoints).
  Object? _unwrap(Object? raw) {
    if (raw is Map && raw['data'] != null) return raw['data'];
    return raw;
  }
}
