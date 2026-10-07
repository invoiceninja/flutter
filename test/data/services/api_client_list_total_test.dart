import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';

/// `getListTotal` — the server's row count for a list query, read off the
/// paginator. The number goes on a tab label, so "not known" has to stay
/// distinguishable from zero.
ApiClient _client(String body, {List<Uri>? requests}) => ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
  httpClient: MockClient((req) async {
    requests?.add(req.url);
    return http.Response(
      body,
      200,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  test('asks for a single row, with the caller\'s filters', () async {
    final requests = <Uri>[];
    final total =
        await _client(
          '{"data":[{"id":"a"}],"meta":{"pagination":{"total":37,"count":1}}}',
          requests: requests,
        ).getListTotal(
          '/api/v1/invoices',
          filters: {'client_id': 'c1', 'status': 'active'},
        );
    expect(total, 37);
    final q = requests.single.queryParameters;
    expect(requests.single.path, '/api/v1/invoices');
    expect(q['per_page'], '1');
    expect(q['page'], '1');
    expect(q['client_id'], 'c1');
    expect(q['status'], 'active');
    // Not a page of anything: no cursor is sent.
    expect(q.containsKey('updated_at'), isFalse);
    expect(q.containsKey('since_id'), isFalse);
  });

  test('a real zero is zero', () async {
    expect(
      await _client(
        '{"data":[],"meta":{"pagination":{"total":0}}}',
      ).getListTotal('/api/v1/quotes'),
      0,
    );
  });

  test('a total sent as a string still counts', () async {
    expect(
      await _client(
        '{"data":[],"meta":{"pagination":{"total":"12"}}}',
      ).getListTotal('/api/v1/quotes'),
      12,
    );
  });

  test(
    'no paginator, or nonsense in it, is "not known" — never zero',
    () async {
      for (final body in [
        '{"data":[]}',
        '{"data":[],"meta":{}}',
        '{"data":[],"meta":{"pagination":{}}}',
        '{"data":[],"meta":{"pagination":{"total":null}}}',
        '{"data":[],"meta":{"pagination":{"total":"many"}}}',
        '{"data":[],"meta":{"pagination":{"total":-1}}}',
        '[]',
      ]) {
        expect(
          await _client(body).getListTotal('/api/v1/quotes'),
          isNull,
          reason: body,
        );
      }
    },
  );
}
