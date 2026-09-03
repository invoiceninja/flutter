import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://test', token: 't'),
);

/// One `?reactv2` row: nested `{label, hashed_id}` objects, no flat ids.
Map<String, dynamic> _reactRow({
  required String id,
  required String userId,
  String userLabel = 'Someone',
  int typeId = 4,
  String invoiceLabel = '0001',
}) => {
  'user': {'label': userLabel, 'hashed_id': userId},
  'invoice': {'label': invoiceLabel, 'hashed_id': 'inv_$id'},
  'client': {'label': 'Acme', 'hashed_id': 'cli_$id'},
  'activity_type_id': typeId,
  'id': id,
  'hashed_id': 'act_$id',
  'notes': '',
  'created_at': 1778990481,
  'ip': '192.0.2.1',
};

/// Like [_clientReturning] but keeps each request's decoded JSON body — the
/// `/entity` endpoint is a POST, so nothing about it shows up in the URL.
({ApiClient client, List<Map<String, dynamic>> bodies}) _clientRecordingBodies(
  Object body,
) {
  final bodies = <Map<String, dynamic>>[];
  final fake = MockClient((req) async {
    bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
    return http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
  return (
    client: ApiClient(
      credentials: _creds(),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: fake,
    ),
    bodies: bodies,
  );
}

({ApiClient client, List<Uri> requests}) _clientReturning(Object body) {
  final requests = <Uri>[];
  final fake = MockClient((req) async {
    requests.add(req.url);
    return http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
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
  group('ActivitiesApi.fetchUserActivities', () {
    test('GETs the reactv2 feed with the scan-row window', () async {
      String? method;
      Uri? url;
      final fake = MockClient((req) async {
        method = req.method;
        url = req.url;
        return http.Response(
          jsonEncode({'data': const <Object>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      final api = ActivitiesApi(
        ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        ),
      );

      await api.fetchUserActivities('VolejRejNm');

      expect(method, 'GET');
      expect(url!.path, '/api/v1/activities');
      // The denormalized branch — its nested `user` object is what makes the
      // client-side actor filter possible.
      expect(url!.queryParameters.containsKey('reactv2'), isTrue);
      expect(url!.queryParameters['rows'], '$kUserActivityScanRows');
      // Inert server-side today, but sent so the request narrows at the
      // source once the backend filter lands.
      expect(url!.queryParameters['user_id'], 'VolejRejNm');
    });

    test('keeps only the requested actor, with real per-row labels', () async {
      // The server ignores `user_id` and returns the whole company feed
      // (invoiceninja/flutter#45) — the filter has to happen here.
      final fake = _clientReturning({
        'data': [
          _reactRow(
            id: '1',
            userId: 'VolejRejNm',
            userLabel: 'Freida Reynolds',
            invoiceLabel: '0025',
          ),
          _reactRow(
            id: '2',
            userId: 'Wpmbk5ezJn',
            userLabel: 'Charity Dickens',
            invoiceLabel: '0026',
          ),
          _reactRow(
            id: '3',
            userId: 'VolejRejNm',
            userLabel: 'Freida Reynolds',
          ),
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('Wpmbk5ezJn');

      expect(rows, hasLength(1));
      expect(rows.single.id, '2');
      expect(rows.single.userId, 'Wpmbk5ezJn');
      // Labels ride along, so `:user` / `:invoice` render real values instead
      // of the localized nouns the flat feed forced.
      expect(rows.single.labels['user'], 'Charity Dickens');
      expect(rows.single.labels['invoice'], '0026');
      expect(rows.single.invoiceId, 'inv_2');
    });

    test('drops rows that name no human actor', () async {
      // `activity_string()` emits a token object only for `:tokens` the
      // `activity_<N>` template contains, so the 34-of-120 templates without
      // `:user` arrive with no `user` key at all. Those are contact- and
      // system-initiated (activity_7 ":contact viewed invoice :invoice",
      // activity_57 "System failed to email invoice :invoice") — nobody's
      // personal activity, so they belong in no user's log.
      final fake = _clientReturning({
        'data': [
          _reactRow(id: '1', userId: 'Wpmbk5ezJn'),
          {
            'contact': {'label': 'A Contact', 'hashed_id': 'con_1'},
            'invoice': {'label': '0027', 'hashed_id': 'inv_9'},
            'activity_type_id': 7,
            'id': '2',
            'created_at': 1778990400,
          },
          // Belt and braces: a `user` object whose relation resolved to null
          // (blank hashed_id) is likewise unattributable.
          {
            'user': {'label': 'System', 'hashed_id': ''},
            'activity_type_id': 4,
            'id': '3',
            'created_at': 1778990400,
          },
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('Wpmbk5ezJn');

      expect(rows.map((r) => r.id), ['1']);
    });

    test('still filters on the flat shape (pre-reactv2 server)', () async {
      // A server without the reactv2 branch answers with the flat
      // ActivityTransformer shape. `user_id` there is the same hashed id, so
      // attribution holds — only the labels degrade.
      final fake = _clientReturning({
        'data': [
          {
            'id': 'O5xe73je7r',
            'activity_type_id': '4',
            'client_id': 'wMvbmOeYAl',
            'user_id': 'VolejRejNm',
            'invoice_id': 'z3YaOpbxql',
            'notes': '',
            'ip': '192.0.2.1',
            'created_at': 1778990481,
          },
          {
            'id': 'A2',
            'activity_type_id': 141,
            'user_id': 'Wpmbk5ezJn',
            'notes': 'a comment',
            'created_at': 1778990400,
          },
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('VolejRejNm');

      expect(rows, hasLength(1));
      expect(rows.single.id, 'O5xe73je7r');
      // String activity_type_id coerces to int (flat feed sends both forms).
      expect(rows.single.activityTypeId, 4);
      expect(rows.single.invoiceId, 'z3YaOpbxql');
      expect(rows.single.labels, isEmpty);
    });

    test('tolerates a bare list body (no data envelope)', () async {
      final fake = _clientReturning([
        {'id': 'X', 'activity_type_id': 5, 'user_id': 'u1', 'created_at': 1},
        {'id': 'Y', 'activity_type_id': 5, 'user_id': 'u2', 'created_at': 1},
      ]);

      final rows = await ActivitiesApi(fake.client).fetchUserActivities('u1');

      expect(rows, hasLength(1));
      expect(rows.single.id, 'X');
    });

    test('truncates to limit', () async {
      final fake = _clientReturning({
        'data': [for (var i = 0; i < 8; i++) _reactRow(id: '$i', userId: 'u1')],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('u1', limit: 3);

      expect(rows.map((r) => r.id), ['0', '1', '2']);
    });

    // invoiceninja/flutter#47 — "a user who is `Pending invite` should not
    // have any `Activity` displayed". Someone who has never acted owns no rows
    // in the company feed, so the actor filter alone empties their log; there
    // is deliberately no `isEmailUnconfirmed` short-circuit above it: that flag
    // also covers hosted owners who never clicked the verify email and anyone
    // who has changed their address — people with real history to show.
    test('an actor with no rows in a busy feed gets an empty log', () async {
      final fake = _clientReturning({
        'data': [
          for (var i = 0; i < 40; i++)
            _reactRow(id: '$i', userId: i.isEven ? 'admin' : 'colleague'),
        ],
      });

      final rows = await ActivitiesApi(
        fake.client,
      ).fetchUserActivities('never_signed_in');

      expect(rows, isEmpty);
      // The request still goes out — "no rows" is a finding, not an assumption.
      expect(fake.requests, hasLength(1));
    });

    test(
      'short-circuits without a request when the user id is blank',
      () async {
        final fake = _clientReturning({'data': const <Object>[]});

        final rows = await ActivitiesApi(fake.client).fetchUserActivities('');

        expect(rows, isEmpty);
        expect(fake.requests, isEmpty);
      },
    );
  });

  group('ActivitiesApi.fetchForEntity', () {
    Map<String, dynamic> feed() => {
      'data': [
        {
          'id': 'a1',
          'activity_type_id': 141,
          'notes': 'Will pay Friday',
          'created_at': 1778990481,
          'ip': '1.2.3.4',
        },
      ],
    };

    test('asks for the widened row window', () async {
      final fake = _clientRecordingBodies(feed());
      await ActivitiesApi(
        fake.client,
      ).fetchForEntity(entity: 'client', entityId: 'c1');
      expect(fake.bodies.single, {
        'entity': 'client',
        'entity_id': 'c1',
        'rows': kEntityActivityRows,
      });
    });

    test('concurrent observers of one record share a single request', () async {
      // The router re-keys the detail subtree per `:id` and J/K steps a list,
      // so a held key would otherwise issue one uncancelled POST per repeat.
      final fake = _clientRecordingBodies(feed());
      final api = ActivitiesApi(fake.client);
      await Future.wait([
        api.fetchForEntity(entity: 'client', entityId: 'c1'),
        api.fetchForEntity(entity: 'client', entityId: 'c1'),
        api.fetchForEntity(entity: 'client', entityId: 'c1'),
      ]);
      expect(fake.bodies, hasLength(1));
    });

    test(
      'a landed feed is peekable, and a later one still refetches',
      () async {
        // Stale-while-revalidate: the cache buys an instant repaint, never a
        // skipped request — a colleague's comment must not arrive late.
        final fake = _clientRecordingBodies(feed());
        final api = ActivitiesApi(fake.client);
        expect(api.peekForEntity(entity: 'client', entityId: 'c1'), isNull);
        await api.fetchForEntity(entity: 'client', entityId: 'c1');
        expect(
          api.peekForEntity(entity: 'client', entityId: 'c1'),
          hasLength(1),
        );
        await api.fetchForEntity(entity: 'client', entityId: 'c1');
        expect(fake.bodies, hasLength(2));
      },
    );

    test('a peek expires with the TTL', () async {
      var now = DateTime.utc(2026, 9, 3, 12);
      final fake = _clientRecordingBodies(feed());
      final api = ActivitiesApi(fake.client, now: () => now);
      await api.fetchForEntity(entity: 'client', entityId: 'c1');
      now = now.add(kEntityActivityCacheTtl + const Duration(seconds: 1));
      expect(api.peekForEntity(entity: 'client', entityId: 'c1'), isNull);
    });

    test('clearCache drops every feed — the logout fan-out calls it', () async {
      final fake = _clientRecordingBodies(feed());
      final api = ActivitiesApi(fake.client);
      await api.fetchForEntity(entity: 'client', entityId: 'c1');
      api.clearCache();
      expect(api.peekForEntity(entity: 'client', entityId: 'c1'), isNull);
    });

    test(
      'a clear mid-flight discards the result that was already on the wire',
      () async {
        // A request that 401s ends the session; its response lands *after* the
        // wipe and must not resurrect the outgoing user's rows.
        final fake = _clientRecordingBodies(feed());
        final api = ActivitiesApi(fake.client);
        final inFlight = api.fetchForEntity(entity: 'client', entityId: 'c1');
        api.clearCache();
        await inFlight;
        expect(api.peekForEntity(entity: 'client', entityId: 'c1'), isNull);
      },
    );

    test('a stale in-flight future does not evict a newer one', () async {
      // `addNote` calls `clearCache()` on every comment, so a newer request for
      // the same record is routinely registered while an older one is still on
      // the wire. An unconditional `remove(key)` on the older future's
      // completion turned the dedupe off for the rest of the newer one's
      // flight — and let the slower of two overlapping responses win the cache.
      // One completer per request, so releasing the older one leaves the newer
      // genuinely in flight.
      final gates = <Completer<void>>[];
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient((req) async {
          final gate = Completer<void>();
          gates.add(gate);
          await gate.future;
          return http.Response(
            jsonEncode(feed()),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      final api = ActivitiesApi(client);

      final first = api.fetchForEntity(entity: 'client', entityId: 'c1');
      await Future<void>.delayed(Duration.zero);
      api.clearCache(); // what `addNote` does on every comment
      final second = api.fetchForEntity(entity: 'client', entityId: 'c1');
      await Future<void>.delayed(Duration.zero);
      expect(gates, hasLength(2));

      gates[0].complete(); // the OLDER request settles first
      await first;
      await Future<void>.delayed(Duration.zero);

      // `second` is still on the wire; a third observer must join it rather
      // than open a third request — which is what an unconditional
      // `_feedInFlight.remove(key)` on `first`'s completion would have caused.
      final third = api.fetchForEntity(entity: 'client', entityId: 'c1');
      await Future<void>.delayed(Duration.zero);
      expect(gates, hasLength(2), reason: 'the third call must be deduped');
      gates[1].complete();
      await Future.wait([second, third]);
    });

    test('the cache is bounded', () async {
      final fake = _clientRecordingBodies(feed());
      final api = ActivitiesApi(fake.client);
      for (var i = 0; i <= kEntityActivityCacheLimit; i++) {
        await api.fetchForEntity(entity: 'client', entityId: 'c$i');
      }
      // The oldest key is evicted, the newest survives.
      expect(api.peekForEntity(entity: 'client', entityId: 'c0'), isNull);
      expect(
        api.peekForEntity(
          entity: 'client',
          entityId: 'c$kEntityActivityCacheLimit',
        ),
        isNotNull,
      );
    });
  });
}
