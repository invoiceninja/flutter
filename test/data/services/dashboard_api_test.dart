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
    return const {'data': <Object?>[]};
  }

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

  test('totals — period body + include_drafts query', () async {
    await api.fetchTotals(DashboardFilter.defaults());
    final call = client.posts.single;
    expect(call.path, '/api/v1/charts/totals_v2');
    expect(call.body!['date_range'], 'this_month');
    expect(call.body, contains('start_date'));
    expect(call.body, contains('end_date'));
    expect(call.query, {'include_drafts': 'false'});
  });

  test('totals previous period — custom range, back-shifted', () async {
    await api.fetchTotals(DashboardFilter.defaults(), previousPeriod: true);
    final body = client.posts.single.body!;
    // Previous-period uses `custom` so the server honors our shifted dates
    // instead of recomputing the window from the preset name.
    expect(body['date_range'], 'custom');
  });
}
