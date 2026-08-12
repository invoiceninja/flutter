import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/templates_api.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

/// Captures the request the API issues and replies with a canned
/// `/api/v1/templates` payload.
({TemplatesApi api, Map<String, dynamic> Function() sent, Uri? Function() url})
_harness() {
  Map<String, dynamic> sent = const {};
  Uri? url;
  final fake = MockClient((req) async {
    url = req.url;
    sent = jsonDecode(req.body) as Map<String, dynamic>;
    return http.Response(
      jsonEncode({
        'subject': 'New quote 0021 from Acme',
        'body': '<p>Wren Ltd</p>',
        'wrapper': '<html><body>\$body</body></html>',
        'raw_subject': r'New quote $number from $company.name',
        'raw_body': r'<p>$client</p>',
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
  return (api: TemplatesApi(client), sent: () => sent, url: () => url);
}

void main() {
  group('TemplatesApi.render', () {
    test('binds the render to the document when entity + id are supplied '
        '(invoiceninja/flutter#31)', () async {
      final h = _harness();

      await h.api.render(
        template: 'quote',
        subject: '',
        body: '',
        entity: 'quote',
        entityId: 'z3YaOpbxql',
      );

      expect(h.url()!.path, '/api/v1/templates');
      // Both must be non-empty or the server silently falls back to the
      // company's oldest (possibly soft-deleted) record of that type.
      expect(h.sent()['entity'], 'quote');
      expect(h.sent()['entity_id'], 'z3YaOpbxql');
      expect(h.sent()['template'], 'email_template_quote');
    });

    test('omitting entity keeps the generic sample — the settings preview '
        'has no document in scope', () async {
      final h = _harness();

      await h.api.render(template: 'invoice', subject: 's', body: 'b');

      expect(h.sent()['entity'], '');
      expect(h.sent()['entity_id'], '');
      expect(h.sent()['subject'], 's');
      expect(h.sent()['body'], 'b');
    });

    test('keeps the irregular quote_reminder1 wire name', () async {
      final h = _harness();

      await h.api.render(
        template: 'quote_reminder1',
        subject: '',
        body: '',
        entity: 'quote',
        entityId: 'abc123',
      );

      expect(h.sent()['template'], 'email_quote_template_reminder1');
    });

    test('splices the rendered body into the wrapper placeholder', () async {
      final h = _harness();

      final preview = await h.api.render(
        template: 'quote',
        subject: '',
        body: '',
        entity: 'quote',
        entityId: 'abc123',
      );

      expect(preview.subject, 'New quote 0021 from Acme');
      expect(preview.body, '<p>Wren Ltd</p>');
      expect(preview.wrapper, '<html><body><p>Wren Ltd</p></body></html>');
      // Raw values seed the composer's subject/body fields.
      expect(preview.rawSubject, r'New quote $number from $company.name');
      expect(preview.rawBody, r'<p>$client</p>');
    });
  });
}
