import 'dart:convert';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/company_gateways_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Pins the Stripe Connect routes. Both live inside the server's `api/v1`
/// route group (`routes/api.php`, `stripe/verify` + `stripe/disconnect/{id}`);
/// they shipped at the web root, where nothing answers, so Disconnect and
/// Verify customers had never once worked.
void main() {
  late List<http.Request> captured;

  CompanyGatewaysApi buildApi(http.Response Function() respond) {
    captured = [];
    final cache = PasswordCache()..set('secret');
    final client = ApiClient(
      credentials: ValueNotifier<ApiCredentials?>(
        const ApiCredentials(baseUrl: 'https://test', token: 't'),
      ),
      passwordCache: cache,
      onUnauthorized: () async {},
      httpClient: MockClient((req) async {
        captured.add(req);
        return respond();
      }),
    );
    return CompanyGatewaysApi(client);
  }

  test('disconnectStripe POSTs /api/v1/stripe/disconnect/{id}', () async {
    final api = buildApi(
      () => http.Response(
        jsonEncode({'message': 'success'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    await api.disconnectStripe(id: 'Wpmbk5ezJn');

    expect(captured, hasLength(1));
    expect(captured.single.method, 'POST');
    expect(captured.single.url.path, '/api/v1/stripe/disconnect/Wpmbk5ezJn');
  });

  test('verifyStripeCustomers POSTs /api/v1/stripe/verify', () async {
    final api = buildApi(
      () => http.Response(
        jsonEncode({
          'stripe_customer_count': 3,
          'stripe_customers': [<String, dynamic>{}, <String, dynamic>{}],
        }),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final counts = await api.verifyStripeCustomers();

    expect(captured.single.method, 'POST');
    expect(captured.single.url.path, '/api/v1/stripe/verify');
    expect(counts.stripeCount, 3);
    expect(counts.localCount, 2);
  });
}
