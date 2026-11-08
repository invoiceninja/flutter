import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/version.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/realtime/pusher_connection.dart';

final _log = Logger('DocuNinjaRealtime');

/// DocuNinja's own Pusher host and key, as React's builder package uses them.
const kDocuNinjaSocketHost = 'socket.docuninja.co';
const kDocuNinjaSocketKey = 'docuninja-key';

/// The events that change what the DocuNinja screens show: a signature
/// landed, or a file's page previews are ready.
const kDocuNinjaRefreshEvents = {
  r'App\Events\Document\DocumentWasSigned',
  r'App\Events\DocumentFile\DocumentFilePreviewGenerated',
};

/// DocuNinja's live updates (docs/docuninja.md § Live updates): a second
/// Pusher socket, to DocuNinja's own host, on the paired DocuNinja company's
/// private channel, signed by DocuNinja's `/broadcasting/auth` with the
/// company token. An event only bumps [DocuNinjaSession.remoteChanged], so
/// the open screens re-read; it never writes anything and never schedules an
/// Invoice Ninja `/refresh`.
///
/// It follows [DocuNinjaSession]: connected while the session is ready,
/// disconnected otherwise (sign-out, company switch, a refusal). Like the
/// Invoice Ninja socket it exists only when `Services.build(realtimeUpdates:)`
/// says so, which only `main.dart` does.
class DocuNinjaRealtime {
  DocuNinjaRealtime({
    required DocuNinjaSession session,
    required DocuNinjaClient client,
    PusherConnection? connection,
  }) : _session = session,
       _client = client,
       _connection =
           connection ??
           PusherConnection(
             endpoint: Uri(
               scheme: 'wss',
               host: kDocuNinjaSocketHost,
               path: '/app/$kDocuNinjaSocketKey',
               queryParameters: {
                 'protocol': '7',
                 'client': 'dart',
                 'version': AppVersion.kClientVersion,
                 'flash': 'false',
               },
             ),
           ) {
    _events = _connection.events.listen(_onEvent);
    _session.addListener(_reconcile);
    // Closed in the background, as the Invoice Ninja socket is.
    _lifecycle = AppLifecycleListener(onHide: pause, onShow: resume);
    _reconcile();
  }

  late final AppLifecycleListener _lifecycle;

  final DocuNinjaSession _session;
  final DocuNinjaClient _client;
  final PusherConnection _connection;
  late final StreamSubscription<PusherEvent> _events;
  String? _channel;

  void _reconcile() {
    final state = _session.value;
    final companyId = state.isReady ? state.company?.id : null;
    final wanted = companyId == null ? null : 'private-company-$companyId';
    if (wanted == _channel) return;
    _channel = wanted;
    if (wanted == null) {
      _connection.unsubscribe();
      _connection.disconnect();
      return;
    }
    _connection.subscribe(wanted, _authorize);
    _connection.connect();
  }

  /// Laravel's broadcasting auth, on DocuNinja, with the company token.
  Future<String> _authorize(String socketId, String channel) async {
    final json = await _client.postJson(
      '/broadcasting/auth',
      body: {'socket_id': socketId, 'channel_name': channel},
    );
    final auth = json is Map ? json['auth'] : null;
    if (auth is! String || auth.isEmpty) {
      throw StateError('DocuNinja broadcasting auth returned no auth');
    }
    return auth;
  }

  void _onEvent(PusherEvent e) {
    if (e.channel != _channel) return;
    if (!kDocuNinjaRefreshEvents.contains(e.event)) return;
    _log.fine('DocuNinja: ${e.event}');
    _session.markRemoteChanged();
  }

  /// The app went to the background, or came back.
  void pause() => _connection.disconnect();
  void resume() {
    if (_channel != null) _connection.connect();
  }

  void dispose() {
    _lifecycle.dispose();
    _session.removeListener(_reconcile);
    unawaited(_events.cancel());
    _connection.dispose();
  }
}
