import 'dart:convert';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/invoices_api.dart';
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

http.Response _pdf() => http.Response.bytes(
  const [0x25, 0x50, 0x44, 0x46], // "%PDF"
  200,
  headers: {'content-type': 'application/pdf'},
);

void main() {
  group('InvoicesApi.downloadPdf', () {
    test('saved invoice, no delivery note → POST /api/v1/live_preview with the '
        'entity body, no delivery_note key on the wire', () async {
      http.BaseRequest? captured;
      final fake = MockClient((req) async {
        captured = req;
        return _pdf();
      });
      final bytes = await InvoicesApi(
        _client(fake),
      ).downloadPdf(entityJson: {'id': 'inv_1', 'number': 'INV-001'});
      expect(bytes, isNotEmpty);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/live_preview');
      expect(captured!.url.queryParameters['entity'], 'invoice');
      expect(captured!.url.queryParameters['entity_id'], 'inv_1');
      final body =
          jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      expect(body['id'], 'inv_1');
      expect(body['number'], 'INV-001');
      expect(body.containsKey('delivery_note'), isFalse);
    });

    test(
      'saved invoice + deliveryNote: true → GET dedicated delivery_note route, '
      'no request body',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await InvoicesApi(_client(fake)).downloadPdf(
          entityJson: {'id': 'inv_1', 'number': 'INV-001'},
          deliveryNote: true,
        );
        expect(captured!.method, 'GET');
        expect(captured!.url.path, '/api/v1/invoices/inv_1/delivery_note');
        expect(captured!.url.queryParameters, isEmpty);
        // No JSON body on a GET.
        expect((captured! as http.Request).body, isEmpty);
      },
    );

    test(
      'delivery note + designId override → ?design_id is carried on the URL',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await InvoicesApi(_client(fake)).downloadPdf(
          entityJson: {'id': 'inv_1'},
          designId: 'design_42',
          deliveryNote: true,
        );
        expect(captured!.method, 'GET');
        expect(captured!.url.path, '/api/v1/invoices/inv_1/delivery_note');
        expect(captured!.url.queryParameters['design_id'], 'design_42');
      },
    );

    test(
      'unsaved (tmp_…) invoice + deliveryNote: true → falls through to '
      'live_preview, no entity_id query, no delivery_note body field',
      () async {
        // The UI hides the toggle until the invoice is saved, but if a caller
        // ever asks for delivery_note on a tmp_ id we must not 404 — we return
        // the normal-layout PDF instead of hitting the dedicated route.
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await InvoicesApi(_client(fake)).downloadPdf(
          entityJson: {'id': 'tmp_abc', 'number': 'draft'},
          deliveryNote: true,
        );
        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/live_preview');
        expect(captured!.url.queryParameters.containsKey('entity_id'), isFalse);
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body.containsKey('delivery_note'), isFalse);
      },
    );

    test(
      'saved + designId, no delivery note → POST live_preview carries design_id '
      'in the body, not on the URL',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await InvoicesApi(
          _client(fake),
        ).downloadPdf(entityJson: {'id': 'inv_1'}, designId: 'design_42');
        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/live_preview');
        expect(captured!.url.queryParameters.containsKey('design_id'), isFalse);
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body['design_id'], 'design_42');
      },
    );

    test('storedPdfKey + the invoice\'s own design → GET the stored render, '
        'not live_preview', () async {
      http.BaseRequest? captured;
      final fake = MockClient((req) async {
        captured = req;
        return _pdf();
      });
      await InvoicesApi(_client(fake)).downloadPdf(
        entityJson: {'id': 'inv_1', 'design_id': 'design_1'},
        designId: 'design_1',
        storedPdfKey: 'key_abc',
      );
      expect(captured!.method, 'GET');
      expect(captured!.url.path, '/api/v1/invoice/key_abc/download');
    });

    test('storedPdfKey + a different design picked → live_preview, since the '
        'download route cannot override the design', () async {
      http.BaseRequest? captured;
      final fake = MockClient((req) async {
        captured = req;
        return _pdf();
      });
      await InvoicesApi(_client(fake)).downloadPdf(
        entityJson: {'id': 'inv_1', 'design_id': 'design_1'},
        designId: 'design_42',
        storedPdfKey: 'key_abc',
      );
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/live_preview');
    });

    test(
      'storedPdfKey + deliveryNote → still the delivery_note route',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await InvoicesApi(_client(fake)).downloadPdf(
          entityJson: {'id': 'inv_1'},
          deliveryNote: true,
          storedPdfKey: 'key_abc',
        );
        expect(captured!.method, 'GET');
        expect(captured!.url.path, '/api/v1/invoices/inv_1/delivery_note');
      },
    );
  });

  // Regression guards for the launch-blocker where status/lifecycle/email
  // actions hit the GET-only per-id `/{id}/{action}` route (→ 404) or the
  // non-existent `/{id}/email` route. They must ride `POST /invoices/bulk`
  // (and `POST /api/v1/emails` for email).
  group('InvoicesApi custom actions → correct server endpoints', () {
    http.Response bulkOk() => http.Response(
      '{"data": []}',
      200,
      headers: {'content-type': 'application/json'},
    );

    test(
      'markSent → POST /invoices/bulk {action: mark_sent, ids:[id]}',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return bulkOk();
        });
        await InvoicesApi(
          _client(fake),
        ).markSent(id: 'inv_1', idempotencyKey: 'k');
        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/invoices/bulk');
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body['action'], 'mark_sent');
        expect(body['ids'], ['inv_1']);
      },
    );

    test(
      'markPaid → POST /invoices/bulk {action: mark_paid, ids:[id]}',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return bulkOk();
        });
        await InvoicesApi(
          _client(fake),
        ).markPaid(id: 'inv_1', idempotencyKey: 'k');
        expect(captured!.url.path, '/api/v1/invoices/bulk');
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body['action'], 'mark_paid');
        expect(body['ids'], ['inv_1']);
      },
    );

    test(
      'cloneTo(quote) → POST /invoices/bulk {action: clone_to_quote}',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return bulkOk();
        });
        await InvoicesApi(
          _client(fake),
        ).cloneTo(id: 'inv_1', targetType: 'quote', idempotencyKey: 'k');
        expect(captured!.url.path, '/api/v1/invoices/bulk');
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body['action'], 'clone_to_quote');
        expect(body['ids'], ['inv_1']);
      },
    );

    test(
      'email → POST /api/v1/emails with entity + email_template_ prefix',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return http.Response('', 200); // empty → mutate returns null
        });
        await InvoicesApi(
          _client(fake),
        ).email(id: 'inv_1', template: 'reminder1', idempotencyKey: 'k');
        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/emails');
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body['entity'], 'invoice');
        expect(body['entity_id'], 'inv_1');
        expect(body['template'], 'email_template_reminder1');
      },
    );

    test(
      'scheduleEmail → POST /api/v1/task_schedulers (email_record)',
      () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return http.Response('', 200); // scheduler response is ignored
        });
        await InvoicesApi(_client(fake)).scheduleEmail(
          id: 'inv_1',
          template: 'reminder1',
          sendAt: '2030-01-15T10:00:00.000',
          idempotencyKey: 'k',
        );
        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/task_schedulers');
        final body =
            jsonDecode((captured! as http.Request).body)
                as Map<String, dynamic>;
        expect(body['template'], 'email_record');
        expect(body['frequency_id'], 0);
        expect(body['next_run'], '2030-01-15'); // date-only, from sendAt
        final params = body['parameters'] as Map<String, dynamic>;
        expect(params['entity'], 'invoice');
        expect(params['entity_id'], 'inv_1');
        expect(params['template'], 'reminder1');
        // No edits, no keys: a scheduled send without them is unchanged.
        expect(params.containsKey('subject'), isFalse);
        expect(params.containsKey('body'), isFalse);
        expect(params.containsKey('cc_email'), isFalse);
      },
    );

    test('scheduleEmail carries the edited subject, body and cc', () async {
      http.BaseRequest? captured;
      final fake = MockClient((req) async {
        captured = req;
        return http.Response('', 200);
      });
      await InvoicesApi(_client(fake)).scheduleEmail(
        id: 'inv_1',
        template: 'invoice',
        sendAt: '2030-01-15',
        subject: 'Your invoice \$number',
        body: '<p>Hi \$client</p>',
        ccEmail: 'a@example.com, b@example.com',
        idempotencyKey: 'k',
      );
      final body =
          jsonDecode((captured! as http.Request).body) as Map<String, dynamic>;
      final params = body['parameters'] as Map<String, dynamic>;
      expect(params['subject'], r'Your invoice $number');
      expect(params['body'], r'<p>Hi $client</p>');
      // The scheduler doesn't split a comma string the way /emails does.
      expect(params['cc_email'], ['a@example.com', 'b@example.com']);
    });
  });
}
