import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/system_logs_api.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

void main() {
  group('SystemLogsApi', () {
    test('GET /system_logs parses every documented field', () async {
      Uri? captured;
      final fake = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'VolejRejNm',
                'company_id': 'VolejRejNm',
                'user_id': 'u1',
                'client_id': 'c1',
                'event_id': 30,
                'category_id': 2,
                'type_id': 303,
                'log': '{"error":"missing from header"}',
                'updated_at': 1778835421,
                'created_at': 1778835421,
              },
              {
                'id': 'VolejRejZx',
                'company_id': 'VolejRejNm',
                'user_id': 'u1',
                'client_id': '',
                'event_id': 60,
                'category_id': 5,
                'type_id': 801,
                'log': '"192.0.2.1"',
                'updated_at': 1778835000,
                'created_at': 1778835000,
              },
            ],
            'meta': {
              'pagination': {'total': 2},
            },
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      final api = SystemLogsApi(client);

      final list = await api.fetchPage();

      // Wire shape
      expect(list.data, hasLength(2));
      final first = list.data.first;
      expect(first.id, 'VolejRejNm');
      expect(first.companyId, 'VolejRejNm');
      expect(first.userId, 'u1');
      expect(first.clientId, 'c1');
      expect(first.eventId, 30);
      expect(first.categoryId, 2);
      expect(first.typeId, 303);
      expect(first.log, '{"error":"missing from header"}');
      expect(first.createdAt, 1778835421);
      expect(first.updatedAt, 1778835421);

      // Query string mirrors React: per_page=200&sort=created_at|DESC.
      expect(captured!.path, '/api/v1/system_logs');
      expect(captured!.queryParameters['per_page'], '200');
      expect(captured!.queryParameters['sort'], 'created_at|DESC');
    });

    test('overrides per_page + sort', () async {
      Uri? captured;
      final fake = MockClient((req) async {
        captured = req.url;
        return http.Response(
          jsonEncode({'data': <Object>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      final api = SystemLogsApi(client);
      await api.fetchPage(perPage: 50, sort: 'updated_at|ASC');
      expect(captured!.queryParameters['per_page'], '50');
      expect(captured!.queryParameters['sort'], 'updated_at|ASC');
    });

    test(
      'adds type_id when scoped to a gateway type; omits it otherwise',
      () async {
        final captured = <Uri>[];
        final fake = MockClient((req) async {
          captured.add(req.url);
          return http.Response(
            jsonEncode({'data': <Object>[]}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        final api = SystemLogsApi(client);
        await api.fetchPage(typeId: 301);
        await api.fetchPage();
        expect(captured[0].queryParameters['type_id'], '301');
        expect(captured[1].queryParameters.containsKey('type_id'), isFalse);
      },
    );

    test(
      'adds client_id when scoped to a client; omits it otherwise',
      () async {
        Uri? captured;
        final fake = MockClient((req) async {
          captured = req.url;
          return http.Response(
            jsonEncode({'data': <Object>[]}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        final api = SystemLogsApi(client);

        await api.fetchPage(clientId: 'cli_42');
        expect(captured!.queryParameters['client_id'], 'cli_42');

        await api.fetchPage();
        expect(captured!.queryParameters.containsKey('client_id'), isFalse);
      },
    );
  });
}
