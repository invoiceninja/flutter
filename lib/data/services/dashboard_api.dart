import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/value/dashboard_comparison.dart';
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

/// Rows one dashboard list fetch asks for. A list that comes back shorter than
/// this is the whole answer; one that comes back this long may have more behind
/// it, and only the paginator's total (`DashboardRows.total`) says how many.
const int kDashboardListPageSize = 50;

/// The window the Outstanding figure sums over: every invoice date a company
/// could plausibly hold, past and post-dated alike. Fixed strings rather than
/// offsets from today, so the request — and with it the cache key — is the
/// same from one day to the next.
const String kOutstandingWindowStart = '1970-01-01';
const String kOutstandingWindowEnd = '2099-12-31';

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
  /// When [previousPeriod] is true the window is the one the trend compares
  /// against — `DashboardFilter.comparison`, the same elapsed span of the
  /// period before, not the whole window shifted back. Returns null without a
  /// request when there is no such period ("All time"): nothing is cached, and
  /// the figures draw no trend.
  Future<Object?> fetchTotals(
    DashboardFilter filter, {
    bool previousPeriod = false,
  }) async {
    final Map<String, dynamic> body;
    if (previousPeriod) {
      final c = filter.comparison();
      if (c == null) return null;
      body = _customBody(c.previousStart, c.previousEnd);
    } else {
      body = _windowBody(filter);
    }
    final raw = await client.postJson(
      '/api/v1/charts/totals_v2',
      body: body,
      query: {'include_drafts': filter.includeDrafts.toString()},
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `POST /api/v1/charts/totals_v2` over every date there is — what is unpaid
  /// *today*.
  ///
  /// `outstanding` in the totals response is the balance of invoices **dated
  /// inside the window** (`ChartQueries::getOutstandingQuery`), so on "This
  /// Month" it leaves out everything still unpaid from before the 1st: an
  /// overdue August invoice was listed under "Needs attention" and missing from
  /// the Outstanding figure beside it. The same query over an open-ended
  /// window is every unpaid invoice there is, in the same currency buckets and
  /// with the same scoping as the period totals.
  ///
  /// **Not the `all_time` preset: that one ends today.** An invoice dated next
  /// week and already sent is owed, and `all_time` drops it — measured on the
  /// demo account, whose seed data is post-dated: `all_time` returned 334.00
  /// across one invoice while the unpaid list held four, 9,727.00. So the
  /// window is spelled out, [kOutstandingWindowStart] to
  /// [kOutstandingWindowEnd], as `custom`.
  ///
  /// Only `outstanding` is meaningful in what comes back; the other buckets are
  /// sums over that same open window, which nothing here shows.
  Future<Object?> fetchOutstandingTotals({required bool includeDrafts}) async {
    final raw = await client.postJson(
      '/api/v1/charts/totals_v2',
      body: const {
        'date_range': 'custom',
        'start_date': kOutstandingWindowStart,
        'end_date': kOutstandingWindowEnd,
      },
      query: {'include_drafts': includeDrafts.toString()},
      readOnly: true,
    );
    return _unwrap(raw);
  }

  /// `POST /api/v1/charts/chart_summary_v2`. Returns the time-series payload
  /// (start/end dates + per-currency arrays of {date, total, currency}).
  Future<Object?> fetchChartSummary(DashboardFilter filter) async {
    final body = _windowBody(filter);
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
      // The task *count* fields reject `format` when the key is merely present
      // — `ShowCalculatedFieldRequest`'s `after()` validator fails on
      // `$this->has('format')`, not on its value — so omit it rather than
      // sending `none` or null. Every other field requires it.
      if (config.format != CardFormat.none) 'format': config.format.name,
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
        'per_page': '$kDashboardListPageSize',
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
        'per_page': '$kDashboardListPageSize',
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
      'per_page': '$kDashboardListPageSize',
      'page': '1',
    },
  );

  Future<Object?> fetchExpiredQuotes() => _fetchList('/api/v1/quotes', const {
    'include': 'client',
    'client_status': 'expired',
    'without_deleted_clients': 'true',
    'per_page': '$kDashboardListPageSize',
    'page': '1',
    'sort': 'id|desc',
  });

  Future<Object?> fetchUpcomingQuotes() => _fetchList('/api/v1/quotes', const {
    'include': 'client',
    // Only sent quotes whose valid-until is today or later — matches React.
    'client_status': 'upcoming',
    'without_deleted_clients': 'true',
    'per_page': '$kDashboardListPageSize',
    'page': '1',
  });

  Future<Object?> fetchUpcomingRecurringInvoices() =>
      _fetchList('/api/v1/recurring_invoices', const {
        'include': 'client',
        // Only active recurring invoices, soonest next-send first — matches
        // React (the server otherwise returns every status in id-desc order).
        'client_status': 'active',
        'without_deleted_clients': 'true',
        'per_page': '$kDashboardListPageSize',
        'page': '1',
        'sort': 'next_send_date_client|asc',
      });

  // ---------------------------------------------------------------------------

  /// One page of a dashboard list, as `{rows, total}`.
  ///
  /// The paginator's total rides along rather than being dropped with the
  /// envelope: a panel shows five of the fifty rows fetched, and without the
  /// total it could say neither how many there really are nor whether a sum
  /// over the rows covers all of them (`DashboardRows`). A response with no
  /// total keeps the bare list, which decodes as "total unknown".
  Future<Object?> _fetchList(String path, Map<String, String> query) async {
    final raw = await client.getOneWithQuery(path, query: query);
    final rows = _unwrap(raw);
    if (raw is! Map || rows is! List) return rows;
    final meta = raw['meta'];
    final pagination = meta is Map ? meta['pagination'] : null;
    final total = pagination is Map ? pagination['total'] : null;
    final asInt = total is int ? total : int.tryParse('$total');
    if (asInt == null || asInt < 0) return rows;
    return {'rows': rows, 'total': asInt};
  }

  /// The selected window for the totals and the chart.
  ///
  /// Sent as `custom` with the app's own dates for every range but "All time".
  /// Given a preset name the server ignores `start_date` / `end_date` and works
  /// the window out again from its own clock (`ShowChartRequest` →
  /// `MakesDates::calculateStartAndEndDates`) — and its "last 7 days" is eight
  /// (`now()->subDays(7)` to today), its "today" the server's. The figures were
  /// then summed over a window the header, the chart axis and every "view all"
  /// link did not show. "All time" stays a name: the server's start for it
  /// (2000-01-01) is the one answer the app has no better version of.
  Map<String, dynamic> _windowBody(DashboardFilter filter) {
    final range = filter.range;
    if (range is DashboardPresetRange &&
        range.preset == DashboardDatePreset.allTime) {
      return _periodBody(filter);
    }
    final (start, end) = filter.resolveDates();
    return _customBody(start, end);
  }

  Map<String, dynamic> _customBody(Date start, Date end) => {
    'start_date': start.toIso(),
    'end_date': end.toIso(),
    'date_range': 'custom',
  };

  /// The selected window **by preset name**, for the configured cards only.
  ///
  /// `calculated_fields` derives a card's `previous` period on the server from
  /// that name (`calculatePreviousPeriodStartAndEndDates`), and for `custom` it
  /// hands back the same window — so a card set to "previous period" would
  /// silently show the current one. The cards therefore keep the name, and the
  /// server's reading of it.
  Map<String, dynamic> _periodBody(DashboardFilter filter) {
    final (start, end) = filter.resolveDates();
    return {
      'start_date': start.toIso(),
      'end_date': end.toIso(),
      'date_range': _serverDateRangeName(filter.range),
    };
  }

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
