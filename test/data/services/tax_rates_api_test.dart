import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/tax_rates_api.dart';

/// First coverage for `TaxRatesApi` — the last untested layer of the tax-rate
/// vertical (see `tax_rate_repository_test.dart`).
///
/// Beyond the plain wire shape, this pins the `tolerantList` behaviour the
/// model opts into: one malformed row from the server must be skipped rather
/// than throwing away the whole page. Tax rates feed the default-tax pickers,
/// so a page-wide parse throw would silently empty them.
ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

({TaxRatesApi api, List<Uri> requests}) _apiReturning(
  Object body, {
  int status = 200,
}) {
  // `status` is exercised by the error-mapping test at the bottom — a
  // non-2xx response must surface as a typed exception, not a parse failure
  // on an error envelope.
  final requests = <Uri>[];
  final fake = MockClient((req) async {
    requests.add(req.url);
    return http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );
  });
  return (
    api: TaxRatesApi(
      ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      ),
    ),
    requests: requests,
  );
}

void main() {
  group('list', () {
    test('parses every documented field and hits /api/v1/tax_rates', () async {
      final t = _apiReturning({
        'data': [
          {
            'id': 'VolejRejNm',
            'name': 'GST',
            'rate': 10.0,
            'created_at': 1778835000,
            'updated_at': 1778835421,
            'archived_at': 0,
            'is_deleted': false,
          },
          {
            'id': 'Opnel5aKBz',
            'name': 'PST',
            'rate': 7.5,
            'created_at': 1778830000,
            'updated_at': 1778830000,
            'archived_at': 1778840000,
            'is_deleted': true,
          },
        ],
      });

      final result = await t.api.list(page: 1);

      expect(result.data.data, hasLength(2));
      final first = result.data.data.first;
      expect(first.id, 'VolejRejNm');
      expect(first.name, 'GST');
      expect(first.rate, 10.0);
      expect(first.createdAt, 1778835000);
      expect(first.updatedAt, 1778835421);
      expect(first.archivedAt, 0);
      expect(first.isDeleted, isFalse);

      final second = result.data.data[1];
      expect(second.rate, 7.5);
      expect(second.archivedAt, 1778840000);
      expect(second.isDeleted, isTrue);

      expect(t.requests.single.path, '/api/v1/tax_rates');
    });

    test(
      'sends the page + per_page it was given (never a huge per_page)',
      () async {
        final t = _apiReturning({'data': <Object>[]});

        await t.api.list(page: 3, perPage: 50);

        expect(t.requests.single.queryParameters['page'], '3');
        expect(t.requests.single.queryParameters['per_page'], '50');
      },
    );

    test('missing optional fields fall back to their defaults', () async {
      final t = _apiReturning({
        'data': [
          {'id': 't1'},
        ],
      });

      final result = await t.api.list(page: 1);

      final row = result.data.data.single;
      expect(row.name, '');
      expect(row.rate, 0.0);
      expect(row.updatedAt, 0);
      expect(row.isDeleted, isFalse);
    });

    test('an empty page parses to an empty list', () async {
      final t = _apiReturning({'data': <Object>[]});

      expect((await t.api.list(page: 1)).data.data, isEmpty);
    });

    test(
      'tolerantList skips one malformed row instead of dropping the page',
      () async {
        final t = _apiReturning({
          'data': [
            {'id': 't1', 'name': 'GST', 'rate': 10.0},
            // `rate` as an object is unparseable — must not take the page down.
            {'id': 't2', 'name': 'Broken', 'rate': <String, dynamic>{}},
            {'id': 't3', 'name': 'PST', 'rate': 7.0},
          ],
        });

        final result = await t.api.list(page: 1);

        expect(
          result.data.data.map((r) => r.id),
          ['t1', 't3'],
          reason: 'the good rows must survive a single bad row',
        );
      },
    );
  });

  group('item responses', () {
    test('update parses the wrapped item envelope', () async {
      final t = _apiReturning({
        'data': {'id': 't1', 'name': 'GST', 'rate': 12.5, 'updated_at': 999},
      });

      final item = await t.api.update(
        id: 't1',
        payload: const {'name': 'GST', 'rate': 12.5},
        idempotencyKey: 'idk',
      );

      expect(item.data.id, 't1');
      expect(item.data.rate, 12.5);
      expect(item.data.updatedAt, 999);
      expect(t.requests.single.path, '/api/v1/tax_rates/t1');
    });

    test('create POSTs to the collection path', () async {
      final t = _apiReturning({
        'data': {'id': 'new1', 'name': 'VAT', 'rate': 20.0},
      });

      final item = await t.api.create(
        payload: const {'name': 'VAT', 'rate': 20.0},
        idempotencyKey: 'idk',
      );

      expect(item.data.id, 'new1');
      expect(t.requests.single.path, '/api/v1/tax_rates');
    });
  });

  group('error responses', () {
    test('a 422 surfaces as ValidationException with the field errors, '
        'not a parse failure on the error envelope', () async {
      final t = _apiReturning({
        'message': 'The given data was invalid.',
        'errors': {
          'name': ['The name field is required.'],
        },
      }, status: 422);

      await expectLater(
        t.api.create(payload: const {}, idempotencyKey: 'idk'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['name'],
            'fieldErrors[name]',
            ['The name field is required.'],
          ),
        ),
      );
    });

    test('a 500 surfaces as ServerException', () async {
      final t = _apiReturning({'message': 'Server error'}, status: 500);

      await expectLater(t.api.list(page: 1), throwsA(isA<ServerException>()));
    });
  });
}
