import 'dart:convert';

import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Tokens implements DocuNinjaTokenSource {
  @override
  String? token = 'dn';

  @override
  Future<String?> refreshToken() async => token;

  @override
  int get epoch => 0;
}

/// The template (blueprint) calls, as React's `Blueprints.tsx`, wizard and
/// actions make them.
void main() {
  late List<http.Request> sent;

  DocuNinjaApi api(Object body) {
    sent = [];
    return DocuNinjaApi(
      DocuNinjaClient(
        tokens: _Tokens(),
        httpClient: MockClient((r) async {
          sent.add(r);
          return http.Response(jsonEncode(body), 200);
        }),
      ),
    );
  }

  test('the list is newest first, active by default, by search', () async {
    final page = await api({
      'data': [
        {
          'id': 'b1',
          'name': 'NDA',
          'design_hash': 'x',
          'document': {
            'metadata': {'entity_type': 'quote'},
          },
          'archived_at': null,
        },
      ],
      'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
    }).blueprints(search: 'nda');
    final q = sent.single.url.queryParameters;
    expect(sent.single.url.path, '/api/blueprints');
    expect(q['sort'], 'id|desc');
    expect(q['status'], 'active');
    expect(q['search'], 'nda');
    final b = page.items.single;
    expect(b.isInvoiceNinjaDesign, isTrue);
    expect(b.entityType, 'quote');
    expect(b.isActive, isTrue);
  });

  test(
    'Use template makes a document; Clone to template the reverse',
    () async {
      final a = api({
        'data': {'id': 'new1'},
      });
      expect(await a.makeDocument('b1'), 'new1');
      expect(sent.last.url.path, '/api/blueprints/b1/action');
      expect(jsonDecode(sent.last.body), {'action': 'make_document'});
      expect(await a.makeBlueprint('d1'), 'new1');
      expect(sent.last.url.path, '/api/documents/d1/action');
      expect(jsonDecode(sent.last.body), {
        'action': 'make_blueprint',
        'id': 'd1',
      });
    },
  );

  test('Options writes the whole template back with the new name', () async {
    final a = api({
      'data': {'id': 'b1', 'name': 'New'},
    });
    final b = DnBlueprint.fromJson({
      'id': 'b1',
      'name': 'Old',
      'description': '',
      'is_template': true,
    });
    await a.updateBlueprint(b, name: 'New', description: 'd');
    expect(sent.single.method, 'PUT');
    expect(jsonDecode(sent.single.body), {
      'id': 'b1',
      'name': 'New',
      'description': 'd',
      'is_template': true,
    });
  });

  test('archive, restore and delete are one bulk call', () async {
    final a = api(<String, dynamic>{});
    await a.blueprintBulk('delete', ['b1']);
    expect(sent.single.url.path, '/api/blueprints/bulk');
    expect(jsonDecode(sent.single.body), {
      'action': 'delete',
      'ids': ['b1'],
    });
  });

  test(
    'a design template is made on Invoice Ninja, never ending its session',
    () async {
      var unauthorized = 0;
      final requests = <http.Request>[];
      final login = DocuNinjaLoginApi(
        ApiClient(
          credentials: ValueNotifier<ApiCredentials?>(
            const ApiCredentials(baseUrl: 'https://invoicing.co', token: 't'),
          ),
          passwordCache: PasswordCache(),
          onUnauthorized: () async => unauthorized++,
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode({
                'data': {'id': 'b9'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      expect(await login.stubBlueprint('invoice'), 'b9');
      expect(requests.single.url.path, '/api/docuninja/stub_blueprint');
      expect(jsonDecode(requests.single.body), {'entity': 'invoice'});
      expect(unauthorized, 0);
    },
  );

  test(
    'a 401 from stub_blueprint or create_user is an error, never a logout',
    () async {
      var unauthorized = 0;
      final login = DocuNinjaLoginApi(
        ApiClient(
          credentials: ValueNotifier<ApiCredentials?>(
            const ApiCredentials(baseUrl: 'https://invoicing.co', token: 't'),
          ),
          passwordCache: PasswordCache(),
          onUnauthorized: () async => unauthorized++,
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({'message': 'Unauthenticated.'}),
              401,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );
      await expectLater(login.stubBlueprint('quote'), throwsA(anything));
      await expectLater(
        login.createUser(
          userId: 'u1',
          firstName: 'A',
          lastName: 'B',
          email: 'a@b.c',
          isAdmin: false,
          permissions: const [],
        ),
        throwsA(anything),
      );
      expect(unauthorized, 0);
    },
  );

  test(
    'the users list is by Invoice Ninja company; a save puts it back',
    () async {
      final a = api({
        'data': [
          {
            'id': 'u1',
            'first_name': 'Ann',
            'email': 'ann@x.co',
            'company_user': {
              'is_admin': false,
              'notifications': ['all_user'],
            },
            'permissions': [
              {
                'model': 'documents',
                'permission_id': 1,
                'permissionable_id': null,
              },
            ],
          },
        ],
        'meta': {'current_page': 1, 'last_page': 1, 'total': 1},
      });
      final page = await a.users(ninjaCompanyKey: 'ck');
      expect(sent.single.url.queryParameters['ninjaCompanyKey'], 'ck');
      final u = page.items.single;
      expect(u.notifications, ['all_user']);
      expect(u.permissions.single.permissionableId, isNull);
      await a.updateUser(
        u,
        isAdmin: true,
        permissions: u.permissions,
        notifications: const ['all'],
      );
      final body = jsonDecode(sent.last.body) as Map<String, dynamic>;
      expect(sent.last.url.path, '/api/users/u1');
      expect(body['first_name'], 'Ann');
      expect(body['is_admin'], isTrue);
      expect(body['permissions'], isEmpty, reason: 'an admin needs no grants');
      expect(body['notifications'], ['all']);
    },
  );
}
