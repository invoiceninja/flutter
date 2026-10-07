import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/value/dashboard_comparison.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the dashboard endpoints' request contract to the React app
/// (`/Users/hillel/Code/react/src/pages/dashboard/components/*`). These query
/// maps are the single seam the repo + ViewModel + every desktop **and** mobile
/// card flow from. Four of them silently diverged from React before this guard
/// existed — upcoming invoices, recent payments, upcoming quotes, upcoming
/// recurring — so each card fetched the wrong rows (wrong status / wrong order).
/// Every param asserted here was verified as honored against the server filter
/// classes (`InvoiceFilters`, `QuoteFilters`, `PaymentFilters`,
/// `RecurringInvoiceFilters`, `QueryFilters`).

class _CapturingClient extends ApiClient {
  _CapturingClient()
    : super(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://test', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: _noop,
      );

  final List<({String path, Map<String, String>? query})> gets = [];
  final List<
    ({String path, Map<String, dynamic>? body, Map<String, String>? query})
  >
  posts = [];

  @override
  Future<dynamic> getOneWithQuery(
    String path, {
    Map<String, String>? query,
  }) async {
    gets.add((path: path, query: query));
    return nextGet ?? const {'data': <Object?>[]};
  }

  /// What the next GET answers with; the empty envelope when null.
  Object? nextGet;

  @override
  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool readOnly = false,
    bool requiresPassword = false,
  }) async {
    posts.add((path: path, body: body, query: query));
    return const {'data': <String, Object?>{}};
  }
}

Future<void> _noop() async {}

void main() {
  late _CapturingClient client;
  late DashboardApi api;

  setUp(() {
    client = _CapturingClient();
    api = DashboardApi(client);
  });

  test('past due invoices — overdue, due-date asc', () async {
    await api.fetchPastDueInvoices();
    expect(client.gets.single.path, '/api/v1/invoices');
    expect(client.gets.single.query, {
      'include': 'client.group_settings',
      'overdue': 'true',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
      'sort': 'due_date|asc',
    });
  });

  test('upcoming invoices — upcoming=true, no competing sort', () async {
    await api.fetchUpcomingInvoices();
    final call = client.gets.single;
    expect(call.path, '/api/v1/invoices');
    expect(call.query, {
      'include': 'client.group_settings',
      'upcoming': 'true',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
    });
    // The server's `upcoming()` filter applies its own ordering; sending a
    // `sort` would compete with it — that was the original bug.
    expect(call.query!.containsKey('sort'), isFalse);
  });

  test('recent payments — date desc, deleted clients excluded', () async {
    await api.fetchRecentPayments();
    expect(client.gets.single.path, '/api/v1/payments');
    expect(client.gets.single.query, {
      'include': 'client',
      'sort': 'date|desc',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
    });
  });

  test('expired quotes — client_status=expired, id desc', () async {
    await api.fetchExpiredQuotes();
    expect(client.gets.single.path, '/api/v1/quotes');
    expect(client.gets.single.query, {
      'include': 'client',
      'client_status': 'expired',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
      'sort': 'id|desc',
    });
  });

  test('upcoming quotes — client_status=upcoming', () async {
    await api.fetchUpcomingQuotes();
    expect(client.gets.single.path, '/api/v1/quotes');
    expect(client.gets.single.query, {
      'include': 'client',
      'client_status': 'upcoming',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
    });
  });

  test('upcoming recurring — active, next-send asc', () async {
    await api.fetchUpcomingRecurringInvoices();
    expect(client.gets.single.path, '/api/v1/recurring_invoices');
    expect(client.gets.single.query, {
      'include': 'client',
      'client_status': 'active',
      'without_deleted_clients': 'true',
      'per_page': '50',
      'page': '1',
      'sort': 'next_send_date_client|asc',
    });
  });

  test('activities — reactv2 flag + explicit rows window', () async {
    await api.fetchActivities();
    expect(client.gets.single.path, '/api/v1/activities');
    // `rows` is load-bearing, not cosmetic: the `?reactv2` branch is
    // unpaginated, so this single number is the entire window the dashboard
    // card *and* the `/activity` screen can ever see. Dropping it silently
    // reverts both to the server's default of 75.
    expect(client.gets.single.query, {
      'reactv2': '',
      'rows': '$kActivityFeedRows',
    });
    expect(kActivityFeedRows, greaterThan(75));
  });

  test('totals — the app\'s own dates, sent as custom', () async {
    final filter = DashboardFilter.defaults();
    await api.fetchTotals(filter);
    final call = client.posts.single;
    final (start, end) = filter.resolveDates();
    expect(call.path, '/api/v1/charts/totals_v2');
    // Given `this_month` the server ignores the dates and works the window out
    // again from its own clock; `custom` makes it sum the window the header
    // shows.
    expect(call.body, {
      'start_date': start.toIso(),
      'end_date': end.toIso(),
      'date_range': 'custom',
    });
    expect(call.query, {'include_drafts': 'false'});
  });

  test('totals — a rolling preset is sent as custom too', () async {
    // The server's "last 7 days" is eight (`now()->subDays(7)` to today).
    const filter = DashboardFilter(
      range: DashboardPresetRange(DashboardDatePreset.last7),
    );
    await api.fetchTotals(filter);
    final body = client.posts.single.body!;
    final (start, end) = filter.resolveDates();
    expect(body['date_range'], 'custom');
    expect(body['start_date'], start.toIso());
    expect(body['end_date'], end.toIso());
    expect(end.differenceInDays(start), 6, reason: 'seven days, inclusive');
  });

  test('totals — all time stays a name', () async {
    const filter = DashboardFilter(
      range: DashboardPresetRange(DashboardDatePreset.allTime),
    );
    await api.fetchTotals(filter);
    expect(client.posts.single.body!['date_range'], 'all_time');
  });

  test('totals previous period — the like-for-like window', () async {
    final filter = DashboardFilter.defaults();
    await api.fetchTotals(filter, previousPeriod: true);
    final body = client.posts.single.body!;
    final c = filter.comparison()!;
    // Not the whole window shifted back: the same elapsed span of the month
    // before.
    expect(body, {
      'start_date': c.previousStart.toIso(),
      'end_date': c.previousEnd.toIso(),
      'date_range': 'custom',
    });
  });

  test('totals previous period — all time asks for nothing', () async {
    const filter = DashboardFilter(
      range: DashboardPresetRange(DashboardDatePreset.allTime),
    );
    final result = await api.fetchTotals(filter, previousPeriod: true);
    expect(result, isNull);
    expect(client.posts, isEmpty, reason: 'there is no period before all time');
  });

  // NOT the `all_time` preset: the server ends that one today, so an invoice
  // dated next week and already sent — owed, by any reading — was left out.
  // Measured on the demo account: `all_time` gave 334.00 across one invoice
  // while four were unpaid, 9,727.00.
  test('outstanding — the totals query over an open-ended window', () async {
    await api.fetchOutstandingTotals(includeDrafts: true);
    final call = client.posts.single;
    expect(call.path, '/api/v1/charts/totals_v2');
    expect(call.body, {
      'date_range': 'custom',
      'start_date': '1970-01-01',
      'end_date': '2099-12-31',
    });
    expect(call.query, {'include_drafts': 'true'});
  });

  test('chart — the app\'s own dates, sent as custom', () async {
    final filter = DashboardFilter.defaults();
    await api.fetchChartSummary(filter);
    final call = client.posts.single;
    final (start, end) = filter.resolveDates();
    expect(call.path, '/api/v1/charts/chart_summary_v2');
    expect(call.body!['date_range'], 'custom');
    expect(call.body!['start_date'], start.toIso());
    expect(call.body!['end_date'], end.toIso());
  });

  test('calculated_fields — keep the preset name', () async {
    // The server derives a card's `previous` period from the name; for
    // `custom` it hands back the same window.
    await api.fetchCalculatedField(
      DashboardFilter.defaults(),
      const DashboardCardConfig(
        field: 'active_invoices',
        period: CardPeriod.previous,
        calculate: CardCalc.sum,
        format: CardFormat.money,
      ),
    );
    expect(client.posts.single.body!['date_range'], 'this_month');
  });

  group('a list keeps the paginator total', () {
    test('rows and total, when the response carries one', () async {
      client.nextGet = const {
        'data': [
          {'id': 'a'},
          {'id': 'b'},
        ],
        'meta': {
          'pagination': {'total': 80, 'count': 2},
        },
      };
      expect(await api.fetchPastDueInvoices(), {
        'rows': [
          {'id': 'a'},
          {'id': 'b'},
        ],
        'total': 80,
      });
    });

    test('the bare list when it carries none', () async {
      client.nextGet = const {
        'data': [
          {'id': 'a'},
        ],
      };
      expect(await api.fetchPastDueInvoices(), [
        {'id': 'a'},
      ]);
    });

    test(
      'activities stay a bare list — that endpoint is not paginated',
      () async {
        client.nextGet = const {
          'data': [
            {'id': 'x'},
          ],
          'meta': {
            'pagination': {'total': 9},
          },
        };
        expect(await api.fetchActivities(), [
          {'id': 'x'},
        ]);
      },
    );
  });

  // --- calculated_fields: the server's per-field-class request rules ---
  //
  // `ShowCalculatedFieldRequest` enforces three shapes, and getting any of them
  // wrong is a 422 the user sees as a permanently-erroring card. These assert
  // the wire body, which is the only place the distinction is observable.

  test(
    'calculated_fields — a money field sends format + calculation',
    () async {
      await api.fetchCalculatedField(
        DashboardFilter.defaults(),
        const DashboardCardConfig(
          field: 'active_invoices',
          period: CardPeriod.current,
          calculate: CardCalc.sum,
          format: CardFormat.money,
        ),
      );
      final body = client.posts.single.body!;
      expect(body['field'], 'active_invoices');
      expect(body['calculation'], 'sum');
      expect(body['period'], 'current');
      expect(body['format'], 'money');
    },
  );

  test('calculated_fields — a duration field sends format: time', () async {
    await api.fetchCalculatedField(
      DashboardFilter.defaults(),
      const DashboardCardConfig(
        field: 'task_estimated_duration',
        period: CardPeriod.total,
        calculate: CardCalc.avg,
        format: CardFormat.time,
      ),
    );
    final body = client.posts.single.body!;
    expect(body['field'], 'task_estimated_duration');
    expect(body['calculation'], 'avg');
    expect(body['format'], 'time');
  });

  test(
    'calculated_fields — a count field OMITS the format key entirely',
    () async {
      // The server's `after()` validator fails on `$this->has('format')`, not on
      // its value, so sending `format: none` (or null) 422s just as hard as
      // sending `money`. The key must be absent from the body.
      await api.fetchCalculatedField(
        DashboardFilter.defaults(),
        const DashboardCardConfig(
          field: 'overdue_tasks',
          period: CardPeriod.current,
          calculate: CardCalc.count,
          format: CardFormat.none,
        ),
      );
      final body = client.posts.single.body!;
      expect(body['field'], 'overdue_tasks');
      expect(body['calculation'], 'count');
      expect(
        body.containsKey('format'),
        isFalse,
        reason: 'the count fields reject `format` when merely present',
      );
    },
  );
}
