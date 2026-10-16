import 'dart:convert';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _client(MockClient httpClient) => ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
  httpClient: httpClient,
);

http.Response _ok() => http.Response(
  jsonEncode({'data': <dynamic>[]}),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('DocumentsApi.download', () {
    // The document's `url` is this same route, and it is behind `token_auth`:
    // a browser opening it got `{"message":"Invalid token"}` (the beta report
    // this method exists for). The bytes must come through the client.
    test(
      'GETs /api/v1/documents/{id}/download carrying the API token',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return http.Response.bytes(utf8.encode('%PDF-1.4\n%%EOF'), 200);
        });

        await DocumentsApi(_client(fake)).download('Wpmbk5ezJn');

        expect(captured!.method, 'GET');
        expect(captured!.url.path, '/api/v1/documents/Wpmbk5ezJn/download');
        expect(captured!.headers['X-API-Token'], 't');
      },
    );

    test('returns the bytes whatever the content type — the server streams '
        'the file with none, and it can be any uploadable type', () async {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
      final fake = MockClient(
        (req) async => http.Response.bytes(
          png,
          200,
          // What Laravel's `streamDownload` falls back to.
          headers: {'content-type': 'text/html; charset=UTF-8'},
        ),
      );

      final bytes = await DocumentsApi(_client(fake)).download('d1');

      expect(bytes, png);
    });

    test('encodes the id into the path', () async {
      http.BaseRequest? captured;
      final fake = MockClient((req) async {
        captured = req;
        return http.Response.bytes(const [1], 200);
      });

      await DocumentsApi(_client(fake)).download('a/b');

      expect(captured!.url.path, '/api/v1/documents/a%2Fb/download');
    });

    test('a refusal surfaces as an exception carrying the server message, and '
        'does not end the session', () async {
      var unauthorized = 0;
      final client = ApiClient(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://test', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorized++,
        httpClient: MockClient(
          (req) async => http.Response(
            jsonEncode({'message': 'This action is forbidden.'}),
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        DocumentsApi(client).download('d1'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('forbidden'),
          ),
        ),
      );
      expect(unauthorized, 0);
    });
  });

  group('DocumentsApi.bulkDownload', () {
    test('POSTs /api/v1/documents/bulk with action:download + the ids '
        '(server-side zip+email export)', () async {
      http.BaseRequest? captured;
      final fake = MockClient((req) async {
        captured = req;
        return _ok();
      });

      await DocumentsApi(
        _client(fake),
      ).bulkDownload(ids: const ['d1', 'd2'], idempotencyKey: 'idem-1');

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/documents/bulk');
      final body =
          jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      expect(body['action'], 'download');
      expect(body['ids'], ['d1', 'd2']);
      // Idempotency key rides the standard header (retry-safe).
      expect(captured!.headers['Idempotency-Key'], 'idem-1');
    });
  });
}
