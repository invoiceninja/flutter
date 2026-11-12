// The support endpoint's wire shape (docs/feedback-screenshots.md).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/support_api.dart';

void main() {
  late List<http.Request> requests;
  late SupportApi api;

  setUp(() {
    requests = [];
    api = SupportApi(
      ApiClient(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://test', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient((req) async {
          requests.add(req);
          return http.Response('{"success":true}', 200);
        }),
      ),
    );
  });

  // `''` became null server-side, and `null !== false` made a server before
  // 5.13.53 attach its debug info and laravel.log to every message.
  test('a message without images sends send_logs as JSON false', () async {
    await api.sendMessage(message: 'Hello', appVersion: '5.13.53+27');
    final req = requests.single;
    expect(req.url.path, '/api/v1/support/messages/send');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['message'], 'Hello');
    expect(body['send_logs'], isFalse);
    expect(body['version'], '5.13.53+27');
    expect(body['platform'], isNotEmpty);
  });

  test('images go as multipart attachments[], each with a filename, and '
      'no send_logs field', () async {
    await api.sendMessageWithAttachments(
      message: 'See attached',
      appVersion: '5.13.53+27',
      attachments: [
        SupportAttachment(
          bytes: Uint8List.fromList([1, 2, 3]),
          fileName: 'screenshot.png',
        ),
        SupportAttachment(
          bytes: Uint8List.fromList([4, 5]),
          fileName: 'image-1.jpg',
        ),
      ],
    );
    final req = requests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/api/v1/support/messages/send');
    expect(req.headers['content-type'], startsWith('multipart/form-data'));
    final text = utf8.decode(req.bodyBytes, allowMalformed: true);
    expect(
      'name="attachments[]"; filename="screenshot.png"'.allMatches(text),
      hasLength(1),
    );
    expect(
      'name="attachments[]"; filename="image-1.jpg"'.allMatches(text),
      hasLength(1),
    );
    expect(text, contains('name="message"'));
    expect(text, contains('See attached'));
    expect(text, isNot(contains('send_logs')));
  });
}
