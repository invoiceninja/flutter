import 'dart:convert';
import 'dart:io';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_login_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The DocuNinja handshake answers every user without a DocuNinja account
/// with a 400 or 401. That is an answer, not a signed-out session: it must
/// never reach `ApiClient`'s logout path, and never even cost the `/ping`
/// that path runs first (docs/docuninja.md).
void main() {
  late List<Uri> requests;
  late int unauthorizedCalls;

  DocuNinjaLoginApi api(http.Response Function(http.Request) reply) {
    requests = [];
    unauthorizedCalls = 0;
    return DocuNinjaLoginApi(
      ApiClient(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://invoicing.co', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorizedCalls++,
        httpClient: MockClient((r) async {
          requests.add(r.url);
          return reply(r);
        }),
      ),
    );
  }

  test(
    'posts to the host root, not /api/v1, and parses the companies',
    () async {
      final body = File(
        'test/fixtures/docuninja/login.json',
      ).readAsStringSync();
      final login = await api(
        (_) => http.Response(
          body,
          200,
          headers: {'content-type': 'application/json'},
        ),
      ).login();

      expect(
        requests.single.toString(),
        'https://invoicing.co/api/docuninja/login',
      );
      expect(login.companies, hasLength(2));
      expect(login.companyUser.isOwner, isTrue);
      expect(login.account.plan, 'pro');
    },
  );

  for (final status in [400, 401]) {
    test('a $status is "no DocuNinja account", never a logout', () async {
      final login = api(
        (_) => http.Response(
          jsonEncode({'message': 'Unauthenticated.'}),
          status,
          headers: {'content-type': 'application/json'},
        ),
      );
      await expectLater(login.login(), throwsA(isA<DocuNinjaRefused>()));
      expect(unauthorizedCalls, 0);
      // No /ping: the 401 path never ran.
      expect(requests, hasLength(1));
    });
  }

  test('a server error still surfaces as one', () async {
    final login = api((_) => http.Response('boom', 500));
    await expectLater(login.login(), throwsA(isA<ServerException>()));
    expect(unauthorizedCalls, 0);
  });

  test('creating the account: a 401 is an error, never a logout', () async {
    final create = api(
      (_) => http.Response(
        jsonEncode({'message': 'Unauthenticated.'}),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );
    await expectLater(create.createAccount(), throwsA(isA<ServerException>()));
    expect(unauthorizedCalls, 0);
    expect(requests.single.path, '/api/docuninja/create');
  });
}
