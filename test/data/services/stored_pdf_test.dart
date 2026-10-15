import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// A saved, synced billing document's PDF is the server's stored render
// (`GET /api/v1/<entity>/<key>/download`), never a `live_preview` re-render:
// only the stored path carries a DocuNinja signature. The report was a quote
// a client approved and signed, whose signature showed in the web app but not
// here.

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
  group('storedPdfInvitationKey', () {
    final saved = emptyQuote().copyWith(
      id: 'q_1',
      invitations: const [
        Invitation(id: 'i_1', key: 'key_first'),
        Invitation(id: 'i_2', key: 'key_second'),
      ],
    );

    test('a saved, synced document → its first invitation key', () {
      expect(saved.storedPdfInvitationKey, 'key_first');
    });

    test('skips an invitation with no key yet', () {
      final doc = saved.copyWith(
        invitations: const [
          Invitation(clientContactId: 'c_1'),
          Invitation(id: 'i_2', key: 'key_second'),
        ],
      );
      expect(doc.storedPdfInvitationKey, 'key_second');
    });

    test('an unsynced local edit → null, the stored render predates it', () {
      expect(saved.copyWith(isDirty: true).storedPdfInvitationKey, isNull);
    });

    test('an unsaved tmp_ record → null', () {
      expect(saved.copyWith(id: 'tmp_x').storedPdfInvitationKey, isNull);
    });

    test('no invitations → null', () {
      expect(
        saved.copyWith(invitations: const []).storedPdfInvitationKey,
        isNull,
      );
    });
  });

  group('downloadPdf with a storedPdfKey', () {
    final cases =
        <
          String,
          Future<Uint8List> Function(
            ApiClient client, {
            required Map<String, dynamic> entityJson,
            String? designId,
            String? storedPdfKey,
          })
        >{
          'invoice': (c, {required entityJson, designId, storedPdfKey}) =>
              InvoicesApi(c).downloadPdf(
                entityJson: entityJson,
                designId: designId,
                storedPdfKey: storedPdfKey,
              ),
          'quote': (c, {required entityJson, designId, storedPdfKey}) =>
              QuotesApi(c).downloadPdf(
                entityJson: entityJson,
                designId: designId,
                storedPdfKey: storedPdfKey,
              ),
          'credit': (c, {required entityJson, designId, storedPdfKey}) =>
              CreditsApi(c).downloadPdf(
                entityJson: entityJson,
                designId: designId,
                storedPdfKey: storedPdfKey,
              ),
          'purchase_order':
              (c, {required entityJson, designId, storedPdfKey}) =>
                  PurchaseOrdersApi(c).downloadPdf(
                    entityJson: entityJson,
                    designId: designId,
                    storedPdfKey: storedPdfKey,
                  ),
        };

    for (final MapEntry(key: entity, value: download) in cases.entries) {
      test(
        '$entity: own design → GET /api/v1/$entity/<key>/download',
        () async {
          http.BaseRequest? captured;
          final fake = MockClient((req) async {
            captured = req;
            return _pdf();
          });
          await download(
            _client(fake),
            entityJson: {'id': 'e_1', 'design_id': 'd_1'},
            designId: 'd_1',
            storedPdfKey: 'key_abc',
          );
          expect(captured!.method, 'GET');
          expect(captured!.url.path, '/api/v1/$entity/key_abc/download');
        },
      );

      test('$entity: a picked design override → live_preview', () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await download(
          _client(fake),
          entityJson: {'id': 'e_1', 'design_id': 'd_1'},
          designId: 'd_2',
          storedPdfKey: 'key_abc',
        );
        expect(captured!.method, 'POST');
        expect(captured!.url.path, startsWith('/api/v1/live_preview'));
      });

      test('$entity: no storedPdfKey → live_preview', () async {
        http.BaseRequest? captured;
        final fake = MockClient((req) async {
          captured = req;
          return _pdf();
        });
        await download(_client(fake), entityJson: {'id': 'e_1'});
        expect(captured!.method, 'POST');
        expect(captured!.url.path, startsWith('/api/v1/live_preview'));
      });
    }
  });
}
