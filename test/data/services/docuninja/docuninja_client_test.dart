import 'dart:convert';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Tokens implements DocuNinjaTokenSource {
  _Tokens(this.token, {this.next});

  @override
  String? token;
  final String? next;
  int refreshes = 0;

  @override
  Future<String?> refreshToken() async {
    refreshes++;
    token = next;
    return next;
  }
}

/// DocuNinja has its own host and token. A 401 re-runs the handshake once,
/// then surfaces; it never touches the Invoice Ninja session
/// (docs/docuninja.md).
void main() {
  test('sends the bearer token to api.docuninja.co', () async {
    late http.Request seen;
    final client = DocuNinjaClient(
      tokens: _Tokens('tok'),
      httpClient: MockClient((r) async {
        seen = r;
        return http.Response('{"data":[]}', 200);
      }),
    );
    await client.getJson('/api/documents', query: {'page': '1'});
    expect(
      seen.url.toString(),
      'https://api.docuninja.co/api/documents?page=1',
    );
    expect(seen.headers['Authorization'], 'Bearer tok');
  });

  test('a 401 refreshes the token once and retries', () async {
    final tokens = _Tokens('stale', next: 'fresh');
    final sent = <String?>[];
    final client = DocuNinjaClient(
      tokens: tokens,
      httpClient: MockClient((r) async {
        sent.add(r.headers['Authorization']);
        return r.headers['Authorization'] == 'Bearer fresh'
            ? http.Response('{"ok":true}', 200)
            : http.Response('{"message":"Unauthenticated."}', 401);
      }),
    );
    expect(await client.getJson('/api/documents'), {'ok': true});
    expect(sent, ['Bearer stale', 'Bearer fresh']);
    expect(tokens.refreshes, 1);
  });

  test('a second 401 surfaces as a DocuNinja error, once', () async {
    final tokens = _Tokens('stale', next: 'still-bad');
    final client = DocuNinjaClient(
      tokens: tokens,
      httpClient: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
      client.getJson('/api/documents'),
      throwsA(
        isA<DocuNinjaException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          isTrue,
        ),
      ),
    );
    expect(tokens.refreshes, 1);
  });

  test(
    'a 422 carries its field errors; no token is a 401 without a call',
    () async {
      var calls = 0;
      final client = DocuNinjaClient(
        tokens: _Tokens('tok'),
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'message': 'Invalid',
              'errors': {
                'description': ['Required'],
              },
            }),
            422,
          );
        }),
      );
      await expectLater(
        client.putJson('/api/documents/1', body: {}),
        throwsA(
          isA<DocuNinjaException>().having(
            (e) => e.fieldErrors['description'],
            'field errors',
            ['Required'],
          ),
        ),
      );
      final none = DocuNinjaClient(
        tokens: _Tokens(null),
        httpClient: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(none.getJson('/x'), throwsA(isA<DocuNinjaException>()));
      expect(calls, 1);
    },
  );

  test('a dropped connection is a NetworkException', () async {
    final client = DocuNinjaClient(
      tokens: _Tokens('tok'),
      httpClient: MockClient((_) async => throw http.ClientException('reset')),
    );
    await expectLater(client.getJson('/x'), throwsA(isA<NetworkException>()));
  });

  test('a file response keeps its Content-Disposition name', () async {
    final client = DocuNinjaClient(
      tokens: _Tokens('tok'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          [37, 80, 68, 70],
          200,
          headers: {
            'content-disposition': 'attachment; filename="Signed contract.pdf"',
          },
        ),
      ),
    );
    final file = await client.postForFile('/api/documents/1/download');
    expect(file.filename, 'Signed contract.pdf');
    expect(file.bytes, [37, 80, 68, 70]);
  });
}
