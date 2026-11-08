import 'dart:convert';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/upload_source.dart';
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

  @override
  int epoch = 0;
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

  test('an upload is multipart, rebuilt for the retry after a 401', () async {
    final tokens = _Tokens('stale', next: 'fresh');
    final bodies = <String>[];
    final client = DocuNinjaClient(
      tokens: tokens,
      httpClient: MockClient((r) async {
        bodies.add(utf8.decode(r.bodyBytes, allowMalformed: true));
        expect(r.headers['content-type'], startsWith('multipart/form-data'));
        return r.headers['Authorization'] == 'Bearer fresh'
            ? http.Response('{"data":{"id":"d1"}}', 200)
            : http.Response('{"message":"Unauthenticated."}', 401);
      }),
    );
    final json = await client.postMultipart(
      '/api/documents',
      fields: {'description': 'Contract'},
      files: [
        (
          field: 'files[]',
          source: BytesUploadSource(utf8.encode('%PDF-1.7'), 'a.pdf'),
          filename: 'a.pdf|secret',
        ),
      ],
    );
    expect(json, {
      'data': {'id': 'd1'},
    });
    // The retry sent the whole body again, not an empty, spent stream.
    expect(bodies, hasLength(2));
    for (final body in bodies) {
      expect(body, contains('name="description"'));
      expect(body, contains('Contract'));
      expect(body, contains('filename="a.pdf|secret"'));
      expect(body, contains('%PDF-1.7'));
    }
  });

  test('a 401 is not retried once the company has changed', () async {
    final tokens = _Tokens('a-token', next: 'b-token');
    final sent = <String?>[];
    final client = DocuNinjaClient(
      tokens: tokens,
      httpClient: MockClient((r) async {
        sent.add(r.headers['Authorization']);
        // The company switches while the first attempt is out.
        tokens.epoch++;
        return http.Response('{"message":"Unauthenticated."}', 401);
      }),
    );
    await expectLater(
      client.postJson('/api/blueprints', body: {'name': 'x'}),
      throwsA(isA<DocuNinjaException>()),
    );
    expect(sent, ['Bearer a-token'], reason: 'never resent with B\'s token');
  });

  test('a write that times out is an error; a read is offline', () async {
    final client = DocuNinjaClient(
      tokens: _Tokens('t'),
      timeout: const Duration(milliseconds: 10),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.postJson('/api/documents/d/send'),
      throwsA(
        isA<DocuNinjaException>().having((e) => e.statusCode, 'status', 408),
      ),
    );
    await expectLater(
      client.getJson('/api/documents'),
      throwsA(isA<NetworkException>()),
    );
  });
}
