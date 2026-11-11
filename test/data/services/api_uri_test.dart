import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_uri.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';

/// `apiUri` keeps a self-hosted install's sub-path. `resolve('/api/v1/x')`
/// replaced it, so an install at `https://host/ninja` sent every request to
/// `https://host/api/v1/x` and could not sign in on any platform.
void main() {
  group('apiUri', () {
    test('a root install is unchanged', () {
      expect(
        '${apiUri('https://host', '/api/v1/login')}',
        'https://host/api/v1/login',
      );
      expect(
        '${apiUri('https://host/', '/api/v1/login')}',
        'https://host/api/v1/login',
      );
      expect(
        '${apiUri('http://host:8000', '/api/v1/ping')}',
        'http://host:8000/api/v1/ping',
      );
    });

    test('a sub-path install keeps its path', () {
      expect(
        '${apiUri('https://host/ninja', '/api/v1/login')}',
        'https://host/ninja/api/v1/login',
      );
      expect(
        '${apiUri('https://host/ninja/', 'api/v1/login')}',
        'https://host/ninja/api/v1/login',
      );
    });

    test('the route\'s own query is kept as written', () {
      expect(
        '${apiUri('https://host/ninja', '/api/v1/refresh?first_load=true&include_static=true')}',
        'https://host/ninja/api/v1/refresh?first_load=true&include_static=true',
      );
      expect(
        '${apiUri('https://host', '/api/v1/clients?filter=a%20b&x=%26')}',
        'https://host/api/v1/clients?filter=a%20b&x=%26',
      );
      expect(
        '${apiUri('https://host', '/api/v1/documents/a%2Fb')}',
        'https://host/api/v1/documents/a%2Fb',
      );
    });

    test('an absolute URL the server handed back is used as is', () {
      expect(
        '${apiUri('https://host/ninja', 'https://cdn.example.com/x.pdf')}',
        'https://cdn.example.com/x.pdf',
      );
    });
  });

  test('ApiClient requests keep a sub-path install\'s path', () async {
    final requests = <Uri>[];
    final client = ApiClient(
      credentials: ValueNotifier<ApiCredentials?>(
        const ApiCredentials(baseUrl: 'https://host/ninja', token: 't'),
      ),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: MockClient((req) async {
        requests.add(req.url);
        return http.Response(
          jsonEncode({'data': <String, Object>{}}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.getOne('/api/v1/clients/abc');
    expect(requests.single.toString(), 'https://host/ninja/api/v1/clients/abc');
  });

  test(
    'sign-in and signup keep it too, and the referral code is encoded',
    () async {
      final requests = <Uri>[];
      final svc = AuthService(
        httpClient: MockClient((req) async {
          requests.add(req.url);
          return http.Response(
            jsonEncode({'data': <Object>[]}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      await svc.signup(
        baseUrl: 'https://host/ninja',
        isHosted: false,
        email: 'a@b.test',
        password: 'pw123456',
        referralCode: 'a&b c',
      );
      expect(requests.single.path, '/ninja/api/v1/signup');
      expect(requests.single.queryParameters['rc'], 'a&b c');
    },
  );
}
