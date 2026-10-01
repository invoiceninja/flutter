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

  /// The user channel (download-ready notices), in its own slot.
  String? userChannel;
  ChannelAuthorizer? userAuthorizer;
  int userUnsubscribes = 0;

  @override
  void subscribe(
    String channel,
    ChannelAuthorizer authorize, {
    String slot = kDefaultChannelSlot,
  }) {
    if (slot != kDefaultChannelSlot) {
      userChannel = channel;
      userAuthorizer = authorize;
      return;
    }
    this.channel = channel;
    authorizer = authorize;
  }

  @override
  void unsubscribe({String? slot}) {
    if (slot != null && slot != kDefaultChannelSlot) {
      userChannel = null;
      userUnsubscribes++;
      return;
    }
    unsubscribes++;
    channel = null;
    if (slot == null && userChannel != null) {
      userChannel = null;
      userUnsubscribes++;
    }
  }

  @override
  void dispose() {}

  void push(String event) => _events.add(
    PusherEvent(channel: channel ?? '', event: event, data: null),
  );

  void pushEvent(PusherEvent event) => _events.add(event);

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

  // React #3340 — the per-user channel carries "your download is ready".
  group('the user channel', () {
    AuthSession session({String accountKey = 'ACCT', String userId = 'u1'}) =>
        AuthSession(
          baseUrl: 'https://invoicing.co',
          isHosted: true,
          accountId: 'a1',
          companies: const [],
          currentCompanyId: 'co1',
          userId: userId,
          accountKey: accountKey,
        );

    test('is carried once the account key is known', () {
      build();
      auth.creds.value = _hosted('co1');
      expect(conn.userChannel, isNull);

      auth.sess.value = session();
      expect(conn.userChannel, 'private-user-ACCT-u1');
    });

    test('a download-ready event is surfaced, and refreshes nothing', () async {
      final service = build();
      auth.sess.value = session();
      auth.creds.value = _hosted('co1');
      final got = <DownloadReady>[];
      final sub = service.downloads.listen(got.add);
      addTearDown(sub.cancel);

      conn.pushEvent(
        PusherEvent(
          channel: 'private-user-ACCT-u1',
          event: kDownloadAvailableEvent,
          data: {
            'message': 'Your Download is now ready! [ Invoices ]',
            'url': 'https://invoicing.co/download/x',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(got.single.url, 'https://invoicing.co/download/x');
      expect(got.single.message, contains('Invoices'));
      expect(scheduler.requests, 0);
    });

    test('a company switch keeps it, signed by the new company', () async {
      build();
      auth.sess.value = session();
      auth.creds.value = _hosted('co1');
      expect(conn.userChannel, 'private-user-ACCT-u1');

      auth.creds.value = _hosted('co2');

      expect(conn.userChannel, 'private-user-ACCT-u1');
      expect(conn.userUnsubscribes, 0);
      await conn.userAuthorizer!('1.1', 'private-user-ACCT-u1');
      expect(api.posts.last.$3, 'co2');
    });

    test('signing out drops it with the company channel', () {
      build();
      auth.sess.value = session();
      auth.creds.value = _hosted('co1');
      expect(conn.userChannel, isNotNull);

      auth.creds.value = null;
      expect(conn.userChannel, isNull);
    });
  });
}
