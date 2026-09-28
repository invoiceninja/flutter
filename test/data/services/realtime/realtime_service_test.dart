// RealtimeService decides when the hosted channel is open, which channel it
// carries, how it is signed, and what a pushed event does — a refresh request,
// never a write.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/realtime/pusher_connection.dart';
import 'package:admin/data/services/realtime/realtime_service.dart';
import 'package:admin/data/services/refresh_scheduler.dart';
import 'package:admin/data/services/request_scope.dart';

class _FakeAuth implements AuthRepository {
  final ValueNotifier<ApiCredentials?> creds = ValueNotifier(null);
  final ValueNotifier<AuthSession?> sess = ValueNotifier(null);

  @override
  ValueListenable<ApiCredentials?> get credentials => creds;

  @override
  ValueListenable<AuthSession?> get session => sess;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeApi implements ApiClient {
  final List<(String, Map<String, dynamic>?, String?)> posts = [];
  Object? reply = {'auth': 'ninja-key:sig'};

  @override
  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool readOnly = false,
    bool requiresPassword = false,
  }) async {
    posts.add((path, body, RequestScope.current?.companyId));
    return reply;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeScheduler implements RefreshScheduler {
  int requests = 0;
  Completer<bool>? pending;

  @override
  Future<bool> requestSoon() {
    requests++;
    return (pending ??= Completer<bool>()).future;
  }

  void land(bool refreshed) {
    final c = pending!;
    pending = null;
    c.complete(refreshed);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeConnection implements PusherConnection {
  final StreamController<PusherEvent> _events =
      StreamController<PusherEvent>.broadcast(sync: true);
  int connects = 0;
  int disconnects = 0;
  int unsubscribes = 0;
  String? channel;
  ChannelAuthorizer? authorizer;

  @override
  Stream<PusherEvent> get events => _events.stream;

  @override
  void connect() => connects++;

  @override
  void disconnect() => disconnects++;

  @override
  void subscribe(String channel, ChannelAuthorizer authorize) {
    this.channel = channel;
    authorizer = authorize;
  }

  @override
  void unsubscribe() {
    unsubscribes++;
    channel = null;
  }

  @override
  void dispose() {}

  void push(String event) => _events.add(
    PusherEvent(channel: channel ?? '', event: event, data: null),
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

ApiCredentials _hosted(String companyId) => ApiCredentials(
  baseUrl: 'https://invoicing.co',
  token: 't-$companyId',
  isHosted: true,
  companyId: companyId,
);

void main() {
  late _FakeAuth auth;
  late _FakeApi api;
  late _FakeScheduler scheduler;
  late _FakeConnection conn;
  late Map<String, StreamController<String>> keys;

  setUp(() {
    auth = _FakeAuth();
    api = _FakeApi();
    scheduler = _FakeScheduler();
    conn = _FakeConnection();
    keys = {};
  });

  RealtimeService build({bool enabled = true}) {
    final service = RealtimeService(
      auth: auth,
      api: api,
      scheduler: scheduler,
      companyKeys: (id) =>
          (keys[id] ??= StreamController<String>.broadcast(sync: true)).stream,
      enabled: enabled,
      connection: conn,
      now: () => DateTime(2026, 9, 28, 12),
    );
    addTearDown(service.dispose);
    return service;
  }

  test('self-hosted never connects', () {
    build();
    auth.creds.value = const ApiCredentials(
      baseUrl: 'https://my.server',
      token: 't',
      companyId: 'co1',
    );
    expect(conn.connects, 0);
  });

  test('disabled (every test / harness build) never connects', () {
    build(enabled: false);
    auth.creds.value = _hosted('co1');
    expect(conn.connects, 0);
  });

  test('hosted connects, then subscribes once the company key is known', () {
    final service = build();
    auth.creds.value = _hosted('co1');
    expect(conn.connects, 1);
    expect(service.activeCompanyId, 'co1');
    expect(conn.channel, isNull);

    keys['co1']!.add(''); // the company row hasn't landed yet
    expect(conn.channel, isNull);
    keys['co1']!.add('KEY1');
    expect(conn.channel, 'private-company-KEY1');
  });

  test(
    'the channel is signed at /broadcasting/auth, scoped to the company',
    () async {
      build();
      auth.creds.value = _hosted('co1');
      keys['co1']!.add('KEY1');

      final signature = await conn.authorizer!(
        '123.456',
        'private-company-KEY1',
      );

      expect(signature, 'ninja-key:sig');
      final (path, body, scope) = api.posts.single;
      expect(path, '/broadcasting/auth');
      expect(body, {
        'socket_id': '123.456',
        'channel_name': 'private-company-KEY1',
      });
      expect(scope, 'co1');
    },
  );

  test('a reply with no signature fails the auth', () async {
    build();
    auth.creds.value = _hosted('co1');
    keys['co1']!.add('KEY1');
    api.reply = {'message': 'nope'};

    expect(
      conn.authorizer!('1.1', 'private-company-KEY1'),
      throwsA(isA<StateError>()),
    );
  });

  test('a company switch moves the channel; a no-op reassign does not', () {
    build();
    auth.creds.value = _hosted('co1');
    keys['co1']!.add('KEY1');
    final unsubscribesBefore = conn.unsubscribes;

    auth.creds.value = _hosted('co1'); // new identity, same company
    expect(conn.unsubscribes, unsubscribesBefore);
    expect(conn.channel, 'private-company-KEY1');

    auth.creds.value = _hosted('co2');
    expect(conn.unsubscribes, unsubscribesBefore + 1);
    keys['co2']!.add('KEY2');
    expect(conn.channel, 'private-company-KEY2');
  });

  test("a late key for the company we've left is ignored", () {
    build();
    auth.creds.value = _hosted('co1');
    auth.creds.value = _hosted('co2');
    keys['co1']!.add('KEY1');
    expect(conn.channel, isNull);
  });

  test('signing out disconnects', () {
    final service = build();
    auth.creds.value = _hosted('co1');
    auth.creds.value = null;
    expect(conn.disconnects, 1);
    expect(service.activeCompanyId, isNull);
  });

  test('an event asks for a refresh and announces it once it lands', () async {
    final service = build();
    auth.creds.value = _hosted('co1');
    keys['co1']!.add('KEY1');
    final announced = <RealtimeRefresh?>[];
    service.lastRefresh.addListener(
      () => announced.add(service.lastRefresh.value),
    );

    conn.push(r'App\Events\Invoice\InvoiceWasPaid');
    conn.push(r'App\Events\Payment\PaymentWasUpdated');
    expect(scheduler.requests, 2);

    scheduler.land(true);
    await pumpEventQueue();

    expect(announced, hasLength(1), reason: 'one refresh, one announcement');
    expect(announced.single!.companyId, 'co1');
  });

  test('a refresh that did not land announces nothing', () async {
    final service = build();
    auth.creds.value = _hosted('co1');
    keys['co1']!.add('KEY1');

    conn.push(r'App\Events\Invoice\InvoiceWasPaid');
    scheduler.land(false);
    await pumpEventQueue();

    expect(service.lastRefresh.value, isNull);
  });

  test('a refresh landing after a company switch announces nothing', () async {
    final service = build();
    auth.creds.value = _hosted('co1');
    keys['co1']!.add('KEY1');

    conn.push(r'App\Events\Invoice\InvoiceWasPaid');
    auth.creds.value = _hosted('co2');
    scheduler.land(true);
    await pumpEventQueue();

    expect(service.lastRefresh.value, isNull);
  });

  test('backgrounded: closed, and a regained network does not reopen it', () {
    final service = build();
    auth.creds.value = _hosted('co1');
    expect(conn.connects, 1);

    service.pause();
    expect(conn.disconnects, 1);
    service.onOnline();
    expect(conn.connects, 1);

    service.resume();
    expect(conn.connects, 2);
    service.onOnline();
    expect(conn.connects, 3);
  });
}
