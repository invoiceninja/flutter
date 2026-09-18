import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/api/document_version_api_model.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/document_versions_api.dart';
import 'package:admin/data/services/password_cache.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

/// One activity row in `ActivityTransformer`'s shape. `activity_type_id`
/// defaults to a **string**, which is what the live server emits here.
Map<String, dynamic> _row({
  String id = 'act1',
  Object typeId = '5',
  Object? amount = 100.5,
  String historyId = 'bk1',
  String? activityId,
  int createdAt = 1789733761,
  String userId = 'usr1',
  String contactId = '',
  bool isSystem = false,
  bool withHistory = true,
}) => {
  'id': id,
  'activity_type_id': typeId,
  'user_id': userId,
  'contact_id': contactId,
  'is_system': isSystem,
  if (withHistory)
    'history': {
      'id': historyId,
      'activity_id': activityId ?? id,
      'json_backup': '',
      'html_backup': '',
      'amount': amount,
      'created_at': createdAt,
      'updated_at': createdAt,
    },
};

List<DocumentVersionActivityApi> _parse(List<Map<String, dynamic>> rows) =>
    DocumentVersionItemApi.fromJson({
      'data': {'activities': rows},
    }).data.activities;

({ApiClient client, List<http.Request> requests}) _clientReturning(
  Object body, {
  int status = 200,
  String contentType = 'application/json',
  bool raw = false,
}) {
  final requests = <http.Request>[];
  final fake = MockClient((req) async {
    requests.add(req);
    return http.Response(
      raw ? body as String : jsonEncode(body),
      status,
      headers: {'content-type': contentType},
    );
  });
  return (
    client: ApiClient(
      credentials: _creds(),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: fake,
    ),
    requests: requests,
  );
}

void main() {
  group('versionsFrom', () {
    test('drops a row whose history is the empty relation shell', () {
      // The server serializes `history` even when no backup exists — blank
      // activity_id, zero amount. `history.id` is the only real gate.
      final rows = _parse([
        _row(id: 'a', historyId: 'bk1'),
        {
          'id': 'b',
          'activity_type_id': '10',
          'history': {
            'id': '',
            'activity_id': '',
            'amount': 0,
            'created_at': 0,
          },
        },
      ]);
      final out = versionsFrom(rows);
      expect(out.map((v) => v.activityId), ['a']);
    });

    test('drops a row with no history key at all', () {
      final out = versionsFrom(_parse([_row(id: 'a', withHistory: false)]));
      expect(out, isEmpty);
    });

    test('drops the four portal view activity types', () {
      // 7 invoice / 21 quote / 60 credit / 136 purchase order — every view
      // writes a backup identical to the one before it.
      final rows = _parse([
        _row(id: 'keep', typeId: '5'),
        _row(id: 'v-invoice', typeId: '7'),
        _row(id: 'v-quote', typeId: '21'),
        _row(id: 'v-credit', typeId: '60'),
        _row(id: 'v-po', typeId: '136'),
      ]);
      expect(versionsFrom(rows).map((v) => v.activityId), ['keep']);
    });

    test(
      'sorts newest first, breaking ties on the server\'s arrival order',
      () {
        // The ids are deliberately anti-sorted: 'aaa' arrives first but sorts
        // last lexicographically, so a tie-break on `activityId` (a hashid —
        // non-monotonic, and what this used to do) yields ['bbb','aaa'] while
        // arrival order yields ['aaa','bbb']. The list order also drives the
        // History tab's amount delta, so getting this wrong flips a delta sign.
        final rows = _parse([
          _row(id: 'aaa', createdAt: 2000),
          _row(id: 'bbb', createdAt: 2000),
          _row(id: 'old', createdAt: 1000),
        ]);
        expect(versionsFrom(rows).map((v) => v.activityId), [
          'aaa',
          'bbb',
          'old',
        ]);
      },
    );

    test(
      'a tie beyond the stable-sort threshold still keeps arrival order',
      () {
        // `List.sort` is only stable below 32 elements; the window holds 50, so
        // relying on stability rather than an explicit index tie-break breaks
        // exactly where the data is busiest.
        final rows = _parse([
          for (var i = 0; i < 40; i++) _row(id: 'id$i', createdAt: 5000),
        ]);
        expect(versionsFrom(rows).map((v) => v.activityId), [
          for (var i = 0; i < 40; i++) 'id$i',
        ]);
      },
    );

    test('coerces amount from double, int and string', () {
      // Raw-JSON blobs bypass the server's read-time casts, so all three
      // shapes are reachable on the wire.
      final rows = _parse([
        _row(id: 'a', amount: 96564.6, createdAt: 3000),
        _row(id: 'b', amount: 42, createdAt: 2000),
        _row(id: 'c', amount: '17.25', createdAt: 1000),
      ]);
      expect(versionsFrom(rows).map((v) => v.amount), [
        Decimal.parse('96564.6'),
        Decimal.parse('42'),
        Decimal.parse('17.25'),
      ]);
    });

    test('coerces activity_type_id from a string and from an int', () {
      final rows = _parse([
        _row(id: 'a', typeId: '5', createdAt: 2000),
        _row(id: 'b', typeId: 5, createdAt: 1000),
      ]);
      expect(versionsFrom(rows).map((v) => v.activityTypeId), ['5', '5']);
    });

    test('an int view type is filtered too', () {
      expect(versionsFrom(_parse([_row(id: 'a', typeId: 7)])), isEmpty);
    });

    test('createdAt is UTC, from epoch seconds', () {
      // A local DateTime here renders an ISO string with no `Z`, which
      // Formatter.date(showTime: true) then localizes a second time.
      final out = versionsFrom(_parse([_row(createdAt: 1789733761)]));
      expect(out.single.createdAt.isUtc, isTrue);
      expect(out.single.createdAt, DateTime.utc(2026, 9, 18, 12, 16, 1));
    });

    test('carries the actor fields through', () {
      final out = versionsFrom(
        _parse([_row(userId: 'u9', contactId: 'c3', isSystem: true)]),
      );
      expect(out.single.userId, 'u9');
      expect(out.single.contactId, 'c3');
      expect(out.single.isSystem, isTrue);
    });

    test('falls back to the row id when history.activity_id is blank', () {
      final out = versionsFrom(_parse([_row(id: 'row1', activityId: '')]));
      expect(out.single.activityId, 'row1');
    });

    test('skips a malformed row instead of blanking the list', () {
      final parsed = DocumentVersionItemApi.fromJson({
        'data': {
          'activities': [
            _row(id: 'good'),
            {'id': 'bad', 'history': 'not-an-object'},
          ],
        },
      }).data.activities;
      expect(versionsFrom(parsed).map((v) => v.activityId), ['good']);
    });

    test('an absent activities key yields no versions', () {
      final parsed = DocumentVersionItemApi.fromJson({
        'data': <String, dynamic>{},
      });
      expect(versionsFrom(parsed.data.activities), isEmpty);
    });
  });

  group('DocumentVersionsApi.fetchForEntity', () {
    test('GETs the entity path with the nested include', () async {
      final h = _clientReturning({
        'data': {
          'activities': [_row()],
        },
      });
      final api = DocumentVersionsApi(h.client);
      final page = await api.fetchForEntity(
        basePath: '/api/v1/invoices',
        id: 'inv1',
      );

      expect(h.requests.single.method, 'GET');
      expect(h.requests.single.url.path, '/api/v1/invoices/inv1');
      // `include=history` is silently dropped server-side and
      // `include=activities` alone carries none — only the nested form works.
      expect(
        h.requests.single.url.queryParameters['include'],
        'activities.history',
      );
      expect(page.versions.single.activityId, 'act1');
      expect(page.truncated, isFalse);
    });

    test('flags truncation when the server window came back full', () async {
      // Invoice::activities() is ->take(50) with no pagination, so a full
      // window means older versions exist and cannot be reached.
      // A full window whose rows are mostly *filtered out* — view events —
      // still means older versions exist. Counting survivors would report a
      // complete list here.
      final rows = List.generate(
        kDocumentVersionWindow,
        (i) => _row(id: 'a$i', createdAt: 1000 + i, typeId: i < 10 ? '5' : '7'),
      );
      final h = _clientReturning({
        'data': {'activities': rows},
      });
      final page = await DocumentVersionsApi(
        h.client,
      ).fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1');
      expect(page.truncated, isTrue);
      expect(page.versions, hasLength(10));
    });

    test(
      'truncation counts the raw wire rows, not the parsed survivors',
      () async {
        // One malformed row makes `tolerantList` drop it, so counting the
        // *parsed* list reports 49 and claims the history is complete when the
        // server's window was in fact full.
        final rows = <Map<String, dynamic>>[
          for (var i = 0; i < kDocumentVersionWindow - 1; i++)
            _row(id: 'a$i', createdAt: 1000 + i),
          {'id': 'bad', 'history': 'not-an-object'},
        ];
        final h = _clientReturning({
          'data': {'activities': rows},
        });
        final page = await DocumentVersionsApi(
          h.client,
        ).fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1');
        expect(page.versions, hasLength(kDocumentVersionWindow - 1));
        expect(page.truncated, isTrue);
      },
    );

    test('concurrent callers for one record share a single request', () async {
      // The History tab and the PDF route routinely ask at the same moment.
      final h = _clientReturning({
        'data': {
          'activities': [_row()],
        },
      });
      final api = DocumentVersionsApi(h.client);
      await Future.wait([
        api.fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1'),
        api.fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1'),
      ]);
      expect(h.requests, hasLength(1));
    });

    test('peek serves a fetched page, and clearCache drops it', () async {
      final h = _clientReturning({
        'data': {
          'activities': [_row()],
        },
      });
      final api = DocumentVersionsApi(h.client);
      expect(
        api.peekForEntity(basePath: '/api/v1/invoices', id: 'inv1'),
        isNull,
      );
      await api.fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1');
      expect(
        api.peekForEntity(basePath: '/api/v1/invoices', id: 'inv1'),
        isNotNull,
      );
      api.clearCache();
      expect(
        api.peekForEntity(basePath: '/api/v1/invoices', id: 'inv1'),
        isNull,
      );
    });

    test('peek expires after the TTL', () async {
      var now = DateTime.utc(2026);
      final h = _clientReturning({
        'data': {
          'activities': [_row()],
        },
      });
      final api = DocumentVersionsApi(h.client, now: () => now);
      await api.fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1');
      now = now.add(kDocumentVersionCacheTtl + const Duration(seconds: 1));
      expect(
        api.peekForEntity(basePath: '/api/v1/invoices', id: 'inv1'),
        isNull,
      );
    });

    test('a response that is not a JSON object yields an empty page', () async {
      final h = _clientReturning([1, 2, 3]);
      final page = await DocumentVersionsApi(
        h.client,
      ).fetchForEntity(basePath: '/api/v1/invoices', id: 'inv1');
      expect(page.isEmpty, isTrue);
    });
  });

  group('DocumentVersionsApi.downloadVersionPdf', () {
    test('GETs the activity download route and returns the bytes', () async {
      final h = _clientReturning(
        '%PDF-1.4\nbody\n%%EOF',
        contentType: 'application/pdf',
        raw: true,
      );
      final bytes = await DocumentVersionsApi(
        h.client,
      ).downloadVersionPdf('wMvbmwOeYA');

      expect(h.requests.single.method, 'GET');
      expect(
        h.requests.single.url.path,
        '/api/v1/activities/download_entity/wMvbmwOeYA',
      );
      expect(bytes, isA<Uint8List>());
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('a non-PDF content type is rejected rather than rendered', () async {
      // getRaw pins `application/pdf`; Laravel's streamDownload sets no type
      // by default, so a server change would otherwise reach the rasterizer.
      final h = _clientReturning(
        '<html>nope</html>',
        contentType: 'text/html',
        raw: true,
      );
      await expectLater(
        DocumentVersionsApi(h.client).downloadVersionPdf('a1'),
        throwsA(isA<ServerException>()),
      );
    });

    test('surfaces the server message when no backup exists', () async {
      // A real 404 here, unlike everywhere else on this API: a Backup row
      // whose document had no invitation is stored with a null filename and
      // still passes the history.id gate.
      final h = _clientReturning({
        'message': 'No backup exists for this activity',
        'errors': <String, dynamic>{},
      }, status: 404);
      await expectLater(
        DocumentVersionsApi(h.client).downloadVersionPdf('a1'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('No backup exists'),
          ),
        ),
      );
    });
  });
}
