import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

/// One `?reactv2` row: nested `{label, hashed_id}` objects, no flat ids.
Map<String, dynamic> _reactRow({
  required String id,
  required String userId,
  String userLabel = 'Someone',
  int typeId = 4,
  String invoiceLabel = '0001',
}) => {
  'user': {'label': userLabel, 'hashed_id': userId},
  'invoice': {'label': invoiceLabel, 'hashed_id': 'inv_$id'},
  'client': {'label': 'Acme', 'hashed_id': 'cli_$id'},
  'activity_type_id': typeId,
  'id': id,
  'hashed_id': 'act_$id',
  'notes': '',
  'created_at': 1778990481,
  'ip': '192.0.2.1',
};

({ApiClient client, List<Uri> requests}) _clientReturning(Object body) {
  final requests = <Uri>[];
  final fake = MockClient((req) async {
    requests.add(req.url);
    return http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
  return (
    client: ApiClient(
      credentials: _creds(),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: fake,
    ),
    requests: requests,
  );
}

void main() {
  group('ActivitiesApi.fetchUserActivities', () {
    test('GETs the reactv2 feed with the scan-row window', () async {
      String? method;
      Uri? url;
      final fake = MockClient((req) async {
        method = req.method;
        url = req.url;
        return http.Response(
          jsonEncode({'data': const <Object>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final api = ActivitiesApi(
        ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        ),
      );

      await api.fetchUserActivities('VolejRejNm');

      expect(method, 'GET');
      expect(url!.path, '/api/v1/activities');
      // The denormalized branch — its nested `user` object is what makes the
      // client-side actor filter possible.
      expect(url!.queryParameters.containsKey('reactv2'), isTrue);
      expect(url!.queryParameters['rows'], '$kUserActivityScanRows');
      // Inert server-side today, but sent so the request narrows at the
      // source once the backend filter lands.
      expect(url!.queryParameters['user_id'], 'VolejRejNm');
    });

    test('keeps only the requested actor, with real per-row labels', () async {
      // The server ignores `user_id` and returns the whole company feed
      // (invoiceninja/flutter#45) — the filter has to happen here.
      final fake = _clientReturning({
        'data': [
          _reactRow(
            id: '1',
            userId: 'VolejRejNm',
            userLabel: 'Freida Reynolds',
            invoiceLabel: '0025',
          ),
          _reactRow(
            id: '2',
            userId: 'Wpmbk5ezJn',
            userLabel: 'Charity Dickens',
            invoiceLabel: '0026',
          ),
          _reactRow(
            id: '3',
            userId: 'VolejRejNm',
            userLabel: 'Freida Reynolds',
          ),
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('Wpmbk5ezJn');

      expect(rows, hasLength(1));
      expect(rows.single.id, '2');
      expect(rows.single.userId, 'Wpmbk5ezJn');
      // Labels ride along, so `:user` / `:invoice` render real values instead
      // of the localized nouns the flat feed forced.
      expect(rows.single.labels['user'], 'Charity Dickens');
      expect(rows.single.labels['invoice'], '0026');
      expect(rows.single.invoiceId, 'inv_2');
    });

    test('drops rows that name no human actor', () async {
      // `activity_string()` emits a token object only for `:tokens` the
      // `activity_<N>` template contains, so the 34-of-120 templates without
      // `:user` arrive with no `user` key at all. Those are contact- and
      // system-initiated (activity_7 ":contact viewed invoice :invoice",
      // activity_57 "System failed to email invoice :invoice") — nobody's
      // personal activity, so they belong in no user's log.
      final fake = _clientReturning({
        'data': [
          _reactRow(id: '1', userId: 'Wpmbk5ezJn'),
          {
            'contact': {'label': 'A Contact', 'hashed_id': 'con_1'},
            'invoice': {'label': '0027', 'hashed_id': 'inv_9'},
            'activity_type_id': 7,
            'id': '2',
            'created_at': 1778990400,
          },
          // Belt and braces: a `user` object whose relation resolved to null
          // (blank hashed_id) is likewise unattributable.
          {
            'user': {'label': 'System', 'hashed_id': ''},
            'activity_type_id': 4,
            'id': '3',
            'created_at': 1778990400,
          },
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('Wpmbk5ezJn');

      expect(rows.map((r) => r.id), ['1']);
    });

    test('still filters on the flat shape (pre-reactv2 server)', () async {
      // A server without the reactv2 branch answers with the flat
      // ActivityTransformer shape. `user_id` there is the same hashed id, so
      // attribution holds — only the labels degrade.
      final fake = _clientReturning({
        'data': [
          {
            'id': 'O5xe73je7r',
            'activity_type_id': '4',
            'client_id': 'wMvbmOeYAl',
            'user_id': 'VolejRejNm',
            'invoice_id': 'z3YaOpbxql',
            'notes': '',
            'ip': '192.0.2.1',
            'created_at': 1778990481,
          },
          {
            'id': 'A2',
            'activity_type_id': 141,
            'user_id': 'Wpmbk5ezJn',
            'notes': 'a comment',
            'created_at': 1778990400,
          },
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('VolejRejNm');

      expect(rows, hasLength(1));
      expect(rows.single.id, 'O5xe73je7r');
      // String activity_type_id coerces to int (flat feed sends both forms).
      expect(rows.single.activityTypeId, 4);
      expect(rows.single.invoiceId, 'z3YaOpbxql');
      expect(rows.single.labels, isEmpty);
    });

    test('tolerates a bare list body (no data envelope)', () async {
      final fake = _clientReturning([
        {'id': 'X', 'activity_type_id': 5, 'user_id': 'u1', 'created_at': 1},
        {'id': 'Y', 'activity_type_id': 5, 'user_id': 'u2', 'created_at': 1},
      ]);

      final rows = await ActivitiesApi(fake.client).fetchUserActivities('u1');

      expect(rows, hasLength(1));
      expect(rows.single.id, 'X');
    });

    test('truncates to limit', () async {
      final fake = _clientReturning({
        'data': [for (var i = 0; i < 8; i++) _reactRow(id: '$i', userId: 'u1')],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('u1', limit: 3);

      expect(rows.map((r) => r.id), ['0', '1', '2']);
    });

    test(
      'short-circuits without a request when the user id is blank',
      () async {
        final fake = _clientReturning({'data': const <Object>[]});

        final rows = await ActivitiesApi(fake.client).fetchUserActivities('');

        expect(rows, isEmpty);
        expect(fake.requests, isEmpty);
      },
    );
  });
}
