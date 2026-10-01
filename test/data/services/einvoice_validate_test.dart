import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/password_cache.dart';

// Imports only `invoices_api` (→ api_client) — deliberately NOT
// `invoice_actions`, so this runs even while a concurrent session's
// `BulkAction`/`invoice_list_view_model` change breaks that import graph.

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://t', token: 't'),
);

void main() {
  group('parseEInvoiceValidation (probed shape)', () {
    test('passes:true with empty groups → passes, no messages', () {
      final r = parseEInvoiceValidation({
        'passes': true,
        'invoices': <Object>[],
        'recurring_invoices': <Object>[],
        'clients': <Object>[],
        'companies': <Object>[],
      });
      expect(r.passes, isTrue);
      expect(r.messages, isEmpty);
    });

    test('failing groups → flattened readable messages', () {
      final r = parseEInvoiceValidation({
        'passes': false,
        'invoices': [
          {'message': 'Number is required'},
          {'label': 'Bad date'},
        ],
        'clients': [
          {'field': 'vat_number'},
          'raw string issue',
        ],
        'companies': [
          {'code': 'X1'}, // no message/label/field → JSON fallback
        ],
        'recurring_invoices': <Object>[],
      });
      expect(r.passes, isFalse);
      expect(r.messages, contains('Number is required'));
      expect(r.messages, contains('Bad date'));
      expect(r.messages, contains('vat_number'));
      expect(r.messages, contains('raw string issue'));
      expect(r.messages, contains(jsonEncode({'code': 'X1'})));
    });

    test('non-map / garbage → passes:false, empty', () {
      expect(parseEInvoiceValidation(null).passes, isFalse);
      expect(parseEInvoiceValidation('nope').messages, isEmpty);
      expect(parseEInvoiceValidation(<Object>[]).passes, isFalse);
    });
  });

  group('InvoicesApi.validateEInvoice', () {
    test(
      'POSTs validateEntity {entity:invoices,entity_id}; parses result',
      () async {
        Uri? url;
        Map<String, dynamic>? body;
        final fake = MockClient((req) async {
          url = req.url;
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'passes': false,
              'invoices': [
                {'message': 'Client VAT missing'},
              ],
              'recurring_invoices': <Object>[],
              'clients': <Object>[],
              'companies': <Object>[],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
        final api = InvoicesApi(
          ApiClient(
            credentials: _creds(),
            passwordCache: PasswordCache(),
            onUnauthorized: () async {},
            httpClient: fake,
          ),
        );

        final r = await api.validateEInvoice('inv1');
        expect(url!.path, '/api/v1/einvoice/validateEntity');
        expect(body!['entity'], 'invoices');
        expect(body!['entity_id'], 'inv1');
        expect(r.passes, isFalse);
        expect(r.messages, ['Client VAT missing']);
      },
    );

    test('valid invoice → passes, no messages', () async {
      final api = InvoicesApi(
        ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'passes': true,
                'invoices': <Object>[],
                'recurring_invoices': <Object>[],
                'clients': <Object>[],
                'companies': <Object>[],
              }),
              200,
              headers: const {'content-type': 'application/json'},
            ),
          ),
        ),
      );
      final r = await api.validateEInvoice('inv1');
      expect(r.passes, isTrue);
      expect(r.messages, isEmpty);
    });
  });

  // The server answers a FAILED check with 422 and the checker's own map —
  // singular keys, `{field, label}` items (Peppol `EntityLevel`). It used to
  // be thrown away as a generic error, so the user saw "An error occurred"
  // exactly when there was something to fix.
  group('422 failed-check result', () {
    InvoicesApi apiReturning(int status, Map<String, dynamic> json) =>
        InvoicesApi(
          ApiClient(
            credentials: _creds(),
            passwordCache: PasswordCache(),
            onUnauthorized: () async {},
            httpClient: MockClient(
              (_) async => http.Response(
                jsonEncode(json),
                status,
                headers: const {'content-type': 'application/json'},
              ),
            ),
          ),
        );

    test('is parsed as a result, singular keys included', () async {
      final api = apiReturning(422, {
        'passes': false,
        'invoice': ['cvc-complex-type.2.4.b: content is not complete'],
        'client': [
          {'field': 'vat_number', 'label': 'VAT Number'},
        ],
        'company': [
          {'field': 'country_id', 'label': 'Country'},
        ],
      });

      final r = await api.validateEInvoice('inv1');

      expect(r.passes, isFalse);
      expect(r.messages, [
        'cvc-complex-type.2.4.b: content is not complete',
        'VAT Number',
        'Country',
      ]);
    });

    test('a credit check reads its `credit` key', () {
      final r = parseEInvoiceValidation({
        'passes': false,
        'invoice': <Object>[],
        'credit': ['Missing billing reference'],
        'client': <Object>[],
        'company': <Object>[],
      });
      expect(r.messages, ['Missing billing reference']);
    });

    test('a 422 that is not a check result still throws', () async {
      final api = apiReturning(422, {
        'message': 'The given data was invalid.',
        'errors': {
          'entity_id': ['The selected entity id is invalid.'],
        },
      });

      expect(
        () => api.validateEInvoice('nope'),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
