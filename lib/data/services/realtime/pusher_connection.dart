import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final _log = Logger('PusherConnection');

/// The one socket seam: a live [WebSocketChannel] in the app, a fake in tests.
abstract interface class RealtimeSocket {
  Stream<dynamic> get stream;
  void send(String frame);
  int? get closeCode;
  void close();
}

typedef RealtimeSocketConnector = RealtimeSocket Function(Uri uri);

/// Opens a real websocket. Web and native alike — `WebSocketChannel.connect`
/// picks the platform implementation.
RealtimeSocket connectWebSocket(Uri uri) =>
    _ChannelSocket(WebSocketChannel.connect(uri));

class _ChannelSocket implements RealtimeSocket {
  _ChannelSocket(this._channel) {
    // A failed connect completes `ready` with an error *and* surfaces it on
    // the stream, which [PusherConnection] already handles. Nothing else
    // awaits `ready`, and an unobserved failed future is an uncaught error.
    _channel.ready.ignore();
  }

  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;

  @override
  void send(String frame) => _channel.sink.add(frame);

  @override
  int? get closeCode => _channel.closeCode;

  @override
  void close() => unawaited(_channel.sink.close());
}

/// An event the server broadcast on the subscribed channel — never one of the
/// protocol's own `pusher:*` / `pusher_internal:*` frames.
class PusherEvent {
  const PusherEvent({
    required this.channel,
    required this.event,
    required this.data,
  });

  final String channel;

  /// Laravel's broadcast name — the event class, e.g.
  /// `App\Events\Invoice\InvoiceWasPaid`.
  final String event;

  /// The payload, JSON-decoded when it arrived as a JSON string.
  final Object? data;
}

/// Signs a private-channel subscription: returns the `auth` string the server
/// hands back for this socket and channel.
typedef ChannelAuthorizer =
    Future<String> Function(String socketId, String channel);

/// The slot [PusherConnection.subscribe] uses unless told otherwise — the
/// company channel.
const String kDefaultChannelSlot = 'default';

/// One channel the connection should carry, and where its subscribe stands.
class _Slot {
  _Slot(this.channel, this.authorize);

  final String channel;
  ChannelAuthorizer? authorize;

  /// The server confirmed it on the current socket.
  bool subscribed = false;

  /// Its auth is in flight, or its frame is sent and not yet confirmed.
  bool subscribing = false;
  Timer? retryTimer;
  int retries = 0;

  void reset() {
    subscribing = false;
    retryTimer?.cancel();
    retryTimer = null;
    retries = 0;
  }
}

/// A client for the Pusher protocol (v7) over one websocket, carrying one
/// channel per named slot — the company channel, and the signed-in user's
/// (download-ready notices). Hand-rolled rather than a package: the
/// protocol surface used here is a handshake, subscribe, ping/pong and close
/// codes, and owning it keeps web, native and the F-Droid build identical.
///
/// State is *desired* state: [connect] / [disconnect] say whether a socket
/// should exist and [subscribe] which channel each slot should carry. A dropped socket
/// reconnects on its own with backoff and resubscribes; a close code in
/// 4000–4099 (the server refusing us for good — bad key, app disabled) stops
/// until the next [connect].
class PusherConnection {
  PusherConnection({
    required this.endpoint,
    RealtimeSocketConnector? connect,
    Random? random,
    this.connectTimeout = const Duration(seconds: 20),
    this.pongTimeout = const Duration(seconds: 30),
    this.maxAuthRetries = 5,
  }) : _connect = connect ?? connectWebSocket,
       _random = random ?? Random();

  /// `wss://<host>/app/<key>?protocol=7&…`.
  final Uri endpoint;

  /// How long an opened socket may stay silent before it's treated as dead —
  /// `WebSocketChannel.connect` has no timeout of its own.
  final Duration connectTimeout;

  /// How long to wait for any frame after sending a `pusher:ping`.
  final Duration pongTimeout;

  /// Retries of a failed subscribe (auth refused or errored, or the server's
  /// `pusher:subscription_error`) on one socket, on the reconnect backoff —
  /// five come to about half a minute. Then it waits for the next socket or
  /// the next [connect].
  final int maxAuthRetries;

  final RealtimeSocketConnector _connect;
  final Random _random;

  final StreamController<PusherEvent> _events =
      StreamController<PusherEvent>.broadcast();

  /// Events on any subscribed channel — [PusherEvent.channel] says which.
  Stream<PusherEvent> get events => _events.stream;

  bool _wanted = false;
  final Map<String, _Slot> _slots = {};

  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  String? _socketId;

  Timer? _reconnectTimer;
  Timer? _watchdog;
  int _attempt = 0;

  /// The server's `activity_timeout` — how long a quiet connection waits
  /// before pinging. 120 s is the protocol default; the handshake overrides it.
  Duration _activityTimeout = const Duration(seconds: 120);

  /// Whether the server has confirmed the default slot's channel on this
  /// socket.
  bool get isSubscribed => isSubscribedTo(kDefaultChannelSlot);

  /// Whether the server has confirmed [slot]'s channel on this socket.
  bool isSubscribedTo(String slot) => _slots[slot]?.subscribed ?? false;

  _Slot? _slotFor(Object? channel) {
    for (final slot in _slots.values) {
      if (slot.channel == channel) return slot;
    }
    return null;
  }

  /// Want a socket. Opens one now if there isn't one, cutting short any
  /// backoff wait — callers use this on resume and on regaining the network,
  /// where waiting out a minute of backoff would be the wrong answer. A live
  /// socket whose subscribe gave up gets a fresh round of attempts instead.
  void connect() {
    _wanted = true;
    if (_socket != null) {
      if (_socketId == null) return;
      for (final slot in _slots.values) {
        if (!slot.subscribed && !slot.subscribing && slot.retryTimer == null) {
          slot.retries = 0;
          _subscribeSlot(slot);
        }
      }
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
    _open();
  }

  /// Close the socket and stay closed. The channel is remembered, so the next
  /// [connect] subscribes to it again.
  void disconnect() {
    _wanted = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _drop();
  }

  /// Carry [channel] in [slot] — a `private-` one is signed by [authorize].
  /// Replaces the slot's previous channel, unsubscribing it on a live socket;
  /// other slots are untouched.
  void subscribe(
    String channel,
    ChannelAuthorizer authorize, {
    String slot = kDefaultChannelSlot,
  }) {
    final existing = _slots[slot];
    if (existing != null && existing.channel == channel) {
      existing.authorize = authorize;
      return;
    }
    unsubscribe(slot: slot);
    final next = _Slot(channel, authorize);
    _slots[slot] = next;
    _subscribeSlot(next);
  }

  /// Stop carrying [slot]'s channel — every slot's when [slot] is null.
  void unsubscribe({String? slot}) {
    final names = slot == null ? _slots.keys.toList() : [slot];
    for (final name in names) {
      final previous = _slots.remove(name);
      if (previous == null) continue;
      previous.subscribed = false;
      previous.reset();
      if (_socketId != null) {
        _send('pusher:unsubscribe', {'channel': previous.channel});
      }
    }
  }

  void dispose() {
    disconnect();
    _slots.clear();
    unawaited(_events.close());
  }

  void _open() {
    if (!_wanted || _socket != null) return;
    final RealtimeSocket socket;
    try {
      socket = _connect(endpoint);
    } catch (e, st) {
      _log.fine('socket connect threw', e, st);
      _scheduleReconnect();
      return;
    }
    _socket = socket;
    _sub = socket.stream.listen(
      (raw) => _onFrame(socket, raw),
      onError: (Object e, StackTrace st) {
        // Followed by onDone, which does the reconnecting.
        _log.fine('socket error', e, st);
      },
      onDone: () => _onClosed(socket),
    );
    _arm(connectTimeout, _stalled);
  }

  void _onFrame(RealtimeSocket socket, dynamic raw) {
    if (!identical(socket, _socket)) return;
    // Any traffic proves the link is alive — only a quiet one is pinged.
    _arm(_activityTimeout, _ping);
    if (raw is! String) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    final event = decoded['event'];
    final channel = decoded['channel'];
    final data = _decodeData(decoded['data']);
    if (event is! String) return;

    switch (event) {
      case 'pusher:connection_established':
        final socketId = data is Map ? data['socket_id'] : null;
        if (socketId is! String || socketId.isEmpty) return;
        _socketId = socketId;
        final timeout = data is Map ? data['activity_timeout'] : null;
        if (timeout is num && timeout > 0) {
          _activityTimeout = Duration(seconds: timeout.toInt());
        }
        _attempt = 0;
        _arm(_activityTimeout, _ping);
        for (final slot in _slots.values) {
          slot.subscribed = false;
          slot.reset();
          _subscribeSlot(slot);
        }
      case 'pusher:ping':
        _send('pusher:pong', const {});
      case 'pusher_internal:subscription_succeeded':
        final slot = _slotFor(channel);
        if (slot != null) {
          slot.subscribed = true;
          slot.reset();
        }
      case 'pusher:subscription_error':
        final slot = _slotFor(channel);
        if (slot == null) return;
        slot.subscribing = false;
        _subscribeFailed(slot, 'realtime subscription refused: $data');
      case 'pusher:error':
        // The close that follows carries the same code and decides what
        // happens next; this frame only explains it.
        _log.warning('realtime server error: $data');
      default:
        if (event.startsWith('pusher:') ||
            event.startsWith('pusher_internal:')) {
          return;
        }
        if (channel is! String || _slotFor(channel) == null) return;
        _events.add(PusherEvent(channel: channel, event: event, data: data));
    }
  }

  bool _isLive(_Slot slot) => _slots.values.any((s) => identical(s, slot));

  void _subscribeSlot(_Slot slot) {
    slot.retryTimer?.cancel();
    slot.retryTimer = null;
    final channel = slot.channel;
    final authorize = slot.authorize;
    final socketId = _socketId;
    final socket = _socket;
    if (socketId == null || socket == null) return;
    if (!channel.startsWith('private-')) {
      slot.subscribing = true;
      _send('pusher:subscribe', {'channel': channel});
      return;
    }
    if (authorize == null) return;
    slot.subscribing = true;
    authorize(socketId, channel).then(
      (auth) {
        // The socket or the slot moved on while the auth was in flight;
        // whatever replaced it keeps its own state.
        if (!identical(socket, _socket) || !_isLive(slot)) return;
        _send('pusher:subscribe', {'channel': channel, 'auth': auth});
      },
      onError: (Object e, StackTrace st) {
        if (!identical(socket, _socket) || !_isLive(slot)) return;
        slot.subscribing = false;
        _subscribeFailed(slot, 'realtime channel auth failed', e, st);
      },
    );
  }

  /// A subscribe didn't take. Retry on the backoff — a 5xx or a network blip
  /// during the auth POST is transient, and a socket left connected but
  /// unsubscribed would otherwise be dead for as long as the server keeps it
  /// open, which on desktop and web is the rest of the session. Bounded,
  /// because a refusal (403) would only be refused again.
  void _subscribeFailed(
    _Slot slot,
    String what, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (slot.retries >= maxAuthRetries) {
      _log.warning('$what; giving up until the next connection', error, stack);
      return;
    }
    _log.fine(what, error, stack);
    slot.retryTimer = Timer(_backoff(slot.retries++), () {
      if (_isLive(slot)) _subscribeSlot(slot);
    });
  }

  void _onClosed(RealtimeSocket socket) {
    if (!identical(socket, _socket)) return;
    final code = socket.closeCode;
    _drop();
    if (!_wanted) return;
    if (code != null && code >= 4000 && code < 4100) {
      _log.warning('realtime socket refused for good (close code $code)');
      _wanted = false;
      return;
    }
    _scheduleReconnect(immediate: code != null && code >= 4200 && code < 4300);
  }

  void _ping() {
    _send('pusher:ping', const {});
    _arm(pongTimeout, _stalled);
  }

  /// No handshake, or no answer to a ping: the socket is dead even if nothing
  /// closed it. Replace it — the old one's late `onDone` is ignored.
  void _stalled() {
    _log.fine('realtime socket stalled; reconnecting');
    _drop();
    if (_wanted) _scheduleReconnect();
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (_reconnectTimer != null) return;
    final delay = immediate ? Duration.zero : _backoff(_attempt++);
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      _open();
    });
  }

  /// 1 s, 2 s, 4 s … capped at 60 s, each drawn from its upper half so a fleet
  /// of clients dropped by one server restart doesn't return in lockstep.
  Duration _backoff(int attempt) {
    final capMs = min(60000, 1000 * (1 << min(attempt, 6)));
    return Duration(milliseconds: capMs ~/ 2 + _random.nextInt(capMs ~/ 2 + 1));
  }

  void _drop() {
    _watchdog?.cancel();
    _watchdog = null;
    unawaited(_sub?.cancel());
    _sub = null;
    _socket?.close();
    _socket = null;
    _socketId = null;
    for (final slot in _slots.values) {
      slot.subscribed = false;
      slot.reset();
    }
  }

  void _arm(Duration after, void Function() then) {
    _watchdog?.cancel();
    _watchdog = Timer(after, then);
  }

  void _send(String event, Map<String, dynamic> data) =>
      _socket?.send(jsonEncode({'event': event, 'data': data}));

  static Object? _decodeData(Object? data) {
    if (data is! String) return data;
    try {
      return jsonDecode(data);
    } catch (_) {
      return data;
    }
  }
}
