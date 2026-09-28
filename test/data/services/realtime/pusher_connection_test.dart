// The Pusher protocol client behind hosted real-time updates, driven against a
// fake socket. `testWidgets` is used only for its fake timers (backoff, the
// idle ping, the watchdog) — there is no widget here.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/realtime/pusher_connection.dart';

class _FakeSocket implements RealtimeSocket {
  final StreamController<dynamic> _in = StreamController<dynamic>();
  final List<Map<String, dynamic>> sent = [];
  int? code;
  bool closed = false;

  @override
  Stream<dynamic> get stream => _in.stream;

  @override
  void send(String frame) =>
      sent.add(jsonDecode(frame) as Map<String, dynamic>);

  @override
  int? get closeCode => code;

  @override
  void close() => closed = true;

  /// A frame from the server. Pusher double-encodes `data` as a JSON string.
  void serverSends(String event, {Object? data, String? channel}) => _in.add(
    jsonEncode({
      'event': event,
      if (channel != null) 'channel': channel,
      'data': data is String ? data : jsonEncode(data ?? const {}),
    }),
  );

  void handshake({String socketId = '1.2', int activityTimeout = 30}) =>
      serverSends(
        'pusher:connection_established',
        data: {'socket_id': socketId, 'activity_timeout': activityTimeout},
      );

  void serverCloses(int? closeCode) {
    code = closeCode;
    unawaited(_in.close());
  }

  List<String> get sentEvents => [for (final f in sent) f['event'] as String];
}

void main() {
  late List<_FakeSocket> sockets;
  late PusherConnection conn;
  late List<(String, String)> authCalls;

  Future<String> authorize(String socketId, String channel) async {
    authCalls.add((socketId, channel));
    return 'key:sig';
  }

  setUp(() {
    sockets = [];
    authCalls = [];
    conn = PusherConnection(
      endpoint: Uri.parse('wss://socket.test/app/k?protocol=7'),
      connect: (_) {
        final s = _FakeSocket();
        sockets.add(s);
        return s;
      },
      random: Random(1),
    );
  });

  // Every test ends by disposing: `testWidgets` fails a test that leaves a
  // timer pending, and a live connection always has its watchdog armed.
  void connTest(String description, Future<void> Function(WidgetTester) body) =>
      testWidgets(description, (tester) async {
        await body(tester);
        conn.dispose();
      });

  connTest('handshake, then a signed subscribe for a private channel', (
    tester,
  ) async {
    conn.subscribe('private-company-abc', authorize);
    conn.connect();
    expect(sockets, hasLength(1));

    sockets.single.handshake(socketId: '9.9');
    await tester.pump();

    expect(authCalls.single, ('9.9', 'private-company-abc'));
    expect(sockets.single.sent.last, {
      'event': 'pusher:subscribe',
      'data': {'channel': 'private-company-abc', 'auth': 'key:sig'},
    });

    sockets.single.serverSends(
      'pusher_internal:subscription_succeeded',
      channel: 'private-company-abc',
    );
    await tester.pump();
    expect(conn.isSubscribed, isTrue);
  });

  connTest('channel events come out decoded; everything else is dropped', (
    tester,
  ) async {
    final events = <PusherEvent>[];
    final sub = conn.events.listen(events.add);
    conn.subscribe('private-company-abc', authorize);
    conn.connect();
    sockets.single.handshake();
    await tester.pump();

    final s = sockets.single;
    s.serverSends(
      r'App\Events\Invoice\InvoiceWasPaid',
      channel: 'private-company-abc',
      data: {'id': 'inv1'},
    );
    s.serverSends(r'App\Events\Other', channel: 'private-company-zzz');
    s.serverSends(
      'pusher_internal:subscription_succeeded',
      channel: 'private-company-abc',
    );
    s._in.add('not json');
    s._in.add(jsonEncode([1, 2, 3]));
    await tester.pump();

    expect(events, hasLength(1));
    expect(events.single.event, r'App\Events\Invoice\InvoiceWasPaid');
    expect(events.single.data, {'id': 'inv1'});
    unawaited(sub.cancel());
  });

  connTest('answers a server ping with a pong', (tester) async {
    conn.connect();
    sockets.single.handshake();
    sockets.single.serverSends('pusher:ping');
    await tester.pump();
    expect(sockets.single.sentEvents, contains('pusher:pong'));
  });

  connTest('a quiet link is pinged, and an unanswered ping replaces it', (
    tester,
  ) async {
    conn.connect();
    sockets.single.handshake(activityTimeout: 30);
    await tester.pump();

    await tester.pump(const Duration(seconds: 30));
    expect(sockets.single.sentEvents, contains('pusher:ping'));

    await tester.pump(conn.pongTimeout);
    expect(sockets.first.closed, isTrue);

    await tester.pump(const Duration(seconds: 2)); // first backoff ≤ 1 s
    expect(sockets, hasLength(2));
  });

  connTest('a socket that never says hello is dropped', (tester) async {
    conn.connect();
    await tester.pump(conn.connectTimeout);
    expect(sockets.single.closed, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(sockets, hasLength(2));
  });

  connTest('close 4000–4099 is final until the next connect()', (tester) async {
    conn.connect();
    sockets.single.handshake();
    sockets.single.serverCloses(4001);
    await tester.pump(const Duration(minutes: 2));
    expect(sockets, hasLength(1));

    conn.connect();
    expect(sockets, hasLength(2));
  });

  connTest('close 4200–4299 reconnects at once', (tester) async {
    conn.connect();
    sockets.single.handshake();
    sockets.single.serverCloses(4200);
    // A bare `pump()` only flushes microtasks; the zero-delay timer needs time
    // to elapse, even none.
    await tester.pump(Duration.zero);
    expect(sockets, hasLength(2));
  });

  connTest('any other drop reconnects with backoff and resubscribes', (
    tester,
  ) async {
    conn.subscribe('private-company-abc', authorize);
    conn.connect();
    sockets.single.handshake(socketId: 'a');
    await tester.pump();
    sockets.single.serverCloses(1006);
    await tester.pump();
    expect(sockets, hasLength(1), reason: 'backoff, not a tight loop');

    await tester.pump(const Duration(seconds: 1));
    expect(sockets, hasLength(2));
    sockets.last.handshake(socketId: 'b');
    await tester.pump();
    expect(authCalls.last, ('b', 'private-company-abc'));
  });

  connTest('disconnect() stays down; connect() comes back subscribed', (
    tester,
  ) async {
    conn.subscribe('private-company-abc', authorize);
    conn.connect();
    sockets.single.handshake(socketId: 'a');
    await tester.pump();

    conn.disconnect();
    expect(sockets.single.closed, isTrue);
    await tester.pump(const Duration(minutes: 2));
    expect(sockets, hasLength(1));

    conn.connect();
    sockets.last.handshake(socketId: 'b');
    await tester.pump();
    expect(authCalls.last, ('b', 'private-company-abc'));
  });

  connTest('switching channel unsubscribes the old one', (tester) async {
    conn.subscribe('private-company-a', authorize);
    conn.connect();
    sockets.single.handshake();
    await tester.pump();

    conn.subscribe('private-company-b', authorize);
    await tester.pump();

    final s = sockets.single;
    expect(s.sent.any((f) => f['event'] == 'pusher:unsubscribe'), isTrue);
    expect(s.sent.last, {
      'event': 'pusher:subscribe',
      'data': {'channel': 'private-company-b', 'auth': 'key:sig'},
    });
  });

  connTest('a failed auth retries on the backoff, then subscribes', (
    tester,
  ) async {
    var calls = 0;
    conn.subscribe('private-company-abc', (socketId, channel) async {
      if (++calls <= 2) throw Exception('502 during a deploy');
      return 'key:sig';
    });
    conn.connect();
    sockets.single.handshake();
    await tester.pump();
    expect(calls, 1);
    expect(sockets.single.sentEvents, isNot(contains('pusher:subscribe')));

    // Two retries: the first backoff is ≤ 1 s, the second ≤ 2 s.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    expect(calls, 3);
    expect(sockets.single.sent.last, {
      'event': 'pusher:subscribe',
      'data': {'channel': 'private-company-abc', 'auth': 'key:sig'},
    });
    expect(sockets, hasLength(1), reason: 'the socket itself was fine');
  });

  connTest('a refusal that persists gives up after maxAuthRetries', (
    tester,
  ) async {
    var calls = 0;
    conn.subscribe('private-company-abc', (_, _) async {
      calls++;
      throw Exception('403');
    });
    conn.connect();
    sockets.single.handshake();
    // Five retries on the backoff finish inside ~31 s — and before the idle
    // ping (30 s) could stall this fake, which never answers one.
    await tester.pump(const Duration(seconds: 35));

    expect(calls, 1 + conn.maxAuthRetries);
    expect(sockets.single.sentEvents, isNot(contains('pusher:subscribe')));
  });

  connTest('connect() on a live socket whose subscribe gave up tries again', (
    tester,
  ) async {
    var calls = 0;
    conn.subscribe('private-company-abc', (_, _) async {
      calls++;
      throw Exception('offline');
    });
    conn.connect();
    sockets.single.handshake();
    // Five retries on the backoff finish inside ~31 s — and before the idle
    // ping (30 s) could stall this fake, which never answers one.
    await tester.pump(const Duration(seconds: 35));
    final gaveUpAt = calls;

    // The network came back / the app came to the front.
    conn.connect();
    await tester.pump();

    expect(calls, gaveUpAt + 1);
    expect(sockets, hasLength(1));
  });

  connTest('a subscription_error from the server is retried', (tester) async {
    conn.subscribe('private-company-abc', authorize);
    conn.connect();
    sockets.single.handshake();
    await tester.pump();
    expect(authCalls, hasLength(1));

    sockets.single.serverSends(
      'pusher:subscription_error',
      channel: 'private-company-abc',
      data: {'type': 'AuthError', 'status': 401},
    );
    await tester.pump(const Duration(seconds: 1));

    expect(authCalls, hasLength(2));
    expect(
      sockets.single.sentEvents.where((e) => e == 'pusher:subscribe'),
      hasLength(2),
    );
  });

  connTest('a subscribe awaiting confirmation is not sent twice', (
    tester,
  ) async {
    conn.subscribe('private-company-abc', authorize);
    conn.connect();
    sockets.single.handshake();
    await tester.pump();

    conn.connect(); // e.g. the network flapped before the server confirmed
    await tester.pump();

    expect(authCalls, hasLength(1));
  });
}
