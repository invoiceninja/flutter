import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/data/services/password_cache.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

Design _design() => Design(
  id: 'abc',
  name: 'My Design',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: true,
  entities: const ['invoice', 'quote'],
  template: const DesignTemplate(body: '<div>\$invoice.number</div>'),
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
);

void main() {
  group('LiveDesignService.renderDesignPreview', () {
    test(
      'POSTs /api/v1/preview?html=false with the probed payload shape',
      () async {
        http.Request? captured;
        final fake = MockClient((req) async {
          captured = req;
          return http.Response.bytes(
            utf8.encode('%PDF-1.4 fake'),
            200,
            headers: const {'content-type': 'application/pdf'},
          );
        });
        final service = LiveDesignService(
          ApiClient(
            credentials: _creds(),
            passwordCache: PasswordCache(),
            onUnauthorized: () async {},
            httpClient: fake,
          ),
        );

        final bytes = await service.renderDesignPreview(
          entityType: 'quote',
          design: _design(),
        );

        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/preview');
        expect(captured!.url.queryParameters['html'], 'false');
        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        expect(body['entity'], 'quote');
        expect(body['entity_id'], '-1');
        expect(body.containsKey('settings_type'), isFalse);
        final design = body['design'] as Map<String, dynamic>;
        expect(design['is_custom'], true);
        expect(design['is_template'], false);
        expect(design['entities'], 'invoice,quote');
        expect(design['id'], 'abc'); // real id preserved
        expect(
          (design['design'] as Map)['body'],
          '<div>\$invoice.number</div>',
        );
        expect(utf8.decode(bytes), startsWith('%PDF'));
      },
    );

    test(
      'a real record id is sent; one the server cannot know is not',
      () async {
        final sent = <Object?>[];
        final service = LiveDesignService(
          ApiClient(
            credentials: _creds(),
            passwordCache: PasswordCache(),
            onUnauthorized: () async {},
            httpClient: MockClient((req) async {
              sent.add((jsonDecode(req.body) as Map)['entity_id']);
              return http.Response.bytes(
                utf8.encode('%PDF-1.4 fake'),
                200,
                headers: const {'content-type': 'application/pdf'},
              );
            }),
          ),
        );
        for (final id in ['Wpmbk5ezJn', null, '', 'tmp_1f0c']) {
          await service.renderDesignPreview(
            entityType: 'invoice',
            design: _design(),
            entityId: id,
          );
        }
        // An unsynced record's id would be a 400 from the server.
        expect(sent, ['Wpmbk5ezJn', '-1', '-1', '-1']);
      },
    );

    test(
      'a brand-new design (empty id) omits the id key from the payload',
      () async {
        http.Request? captured;
        final fake = MockClient((req) async {
          captured = req;
          return http.Response.bytes(
            utf8.encode('%PDF-1.4 fake'),
            200,
            headers: const {'content-type': 'application/pdf'},
          );
        });
        final service = LiveDesignService(
          ApiClient(
            credentials: _creds(),
            passwordCache: PasswordCache(),
            onUnauthorized: () async {},
            httpClient: fake,
          ),
        );

        await service.renderDesignPreview(
          entityType: 'invoice',
          design: _design().copyWith(id: ''),
        );

        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        final design = body['design'] as Map<String, dynamic>;
        expect(design.containsKey('id'), isFalse);
        expect(design['name'], 'My Design');
      },
    );

    test(
      '422 surfaces as ValidationException; designSectionErrors maps it',
      () async {
        final fake = MockClient((req) async {
          return http.Response(
            jsonEncode({
              'message': 'The given data was invalid.',
              'errors': {
                'design.design.body': [
                  'Template syntax error on line 1: Unexpected token.',
                ],
                'design.design.footer': ['Another problem.'],
              },
            }),
            422,
            headers: const {'content-type': 'application/json'},
          );
        });
        final service = LiveDesignService(
          ApiClient(
            credentials: _creds(),
            passwordCache: PasswordCache(),
            onUnauthorized: () async {},
            httpClient: fake,
          ),
        );

        try {
          await service.renderDesignPreview(
            entityType: 'invoice',
            design: _design(),
          );
          fail('expected ValidationException');
        } on ValidationException catch (e) {
          final sections = designSectionErrors(e);
          expect(
            sections['body'],
            'Template syntax error on line 1: Unexpected token.',
          );
          expect(sections['footer'], 'Another problem.');
          expect(sections.containsKey('header'), isFalse);
        }
      },
    );
  });
}
