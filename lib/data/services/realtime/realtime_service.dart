import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/env.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/realtime/pusher_connection.dart';
import 'package:admin/data/services/refresh_scheduler.dart';
import 'package:admin/data/services/request_scope.dart';

final _log = Logger('RealtimeService');

/// A delta refresh that a pushed server event caused has landed for
/// [companyId]. Listeners that hold server-aggregated data the delta can't
/// reach (the dashboard's KPIs and charts) refetch on it.
@immutable
class RealtimeRefresh {
  const RealtimeRefresh({required this.companyId, required this.at});

  final String companyId;
  final DateTime at;
}

/// A file the server finished preparing for this user — a bulk PDF / ZIP
/// download or a company export (`App\Events\Socket\DownloadAvailable`).
/// [message] arrives already translated and names the content; [url] is the
/// signed download link.
@immutable
class DownloadReady {
  const DownloadReady({required this.message, required this.url});

  final String message;
  final String url;
}

/// The server's download-ready event — Laravel broadcasts the event class's
/// full name when it has no `broadcastAs`.
const String kDownloadAvailableEvent = r'App\Events\Socket\DownloadAvailable';

/// The slot the per-user channel rides in on the connection.
const String kUserChannelSlot = 'user';

/// Hosted real-time updates: listens on the server's broadcast channel for the
/// active company and, when anything is announced, schedules the ordinary
/// `/refresh` delta ([RefreshScheduler.requestSoon]).
///
/// It also listens on the signed-in user's own channel
/// (`private-user-{account_key}-{user_id}`), which is where the server says a
/// requested download is ready (React #3340). That event is the one exception
/// to the doorbell rule below: it changes no entity, so it triggers no
/// refresh — it is surfaced on [downloads] for the shell to show.
///
/// **A push never writes an entity.** The events carry full records, but
/// applying them would be a second write path around every guard the delta
/// already has — upsert-only, drop-the-older-row, company binding, session
/// generation (`docs/realtime-updates.md`). The payload is a doorbell.
///
/// Hosted only, like React: self-hosted servers have no socket host the app
/// could know, and the demo build writes nothing anyway. Foreground only —
/// `SyncLifecycleObserver` calls [pause] / [resume], and the resume path runs
/// its own delta, so nothing is missed while away. The 5-minute poll stays as
/// the fallback for everything the channel doesn't announce.
///
/// Driven by `auth.credentials`, which changes on login, company switch, a
/// switch's 401 rollback and logout — one listener instead of three chained
/// callbacks, and the rollback is the case the callbacks don't see.
class RealtimeService {
  RealtimeService({
    required AuthRepository auth,
    required ApiClient api,
    required RefreshScheduler scheduler,
    required Stream<String> Function(String companyId) companyKeys,
    bool enabled = true,
    PusherConnection? connection,
    DateTime Function()? now,
  }) : _auth = auth,
       _api = api,
       _scheduler = scheduler,
       _companyKeys = companyKeys,
       _enabled = enabled && Env.pusherAppKey.isNotEmpty,
       _now = now ?? DateTime.now,
       _connection =
           connection ??
           PusherConnection(
             endpoint: Uri(
               scheme: 'wss',
               host: Env.pusherHost,
               path: '/app/${Env.pusherAppKey}',
               queryParameters: {
                 'protocol': '7',
                 'client': 'dart',
                 'version': AppVersion.kClientVersion,
                 'flash': 'false',
               },
             ),
           ) {
    _eventSub = _connection.events.listen(_onEvent);
    _auth.credentials.addListener(_reconcile);
    _auth.session.addListener(_reconcile);
    _reconcile();
  }

  final AuthRepository _auth;
  final ApiClient _api;
  final RefreshScheduler _scheduler;
  final Stream<String> Function(String companyId) _companyKeys;
  final bool _enabled;
  final DateTime Function() _now;
  final PusherConnection _connection;

  late final StreamSubscription<PusherEvent> _eventSub;
  StreamSubscription<String>? _keySub;

  /// The company whose channel we're on (or waiting for the key of).
  String? _companyId;
  bool _foreground = true;
  Future<bool>? _awaiting;

  final ValueNotifier<RealtimeRefresh?> _lastRefresh = ValueNotifier(null);

  /// The user channel currently carried, or null.
  String? _userChannel;

  final StreamController<DownloadReady> _downloads =
      StreamController<DownloadReady>.broadcast();

  /// Downloads the server finished preparing for this user. `lib/data` can't
  /// show a toast; the shell listens.
  Stream<DownloadReady> get downloads => _downloads.stream;

  /// Bumped after each push-driven delta refresh lands cleanly.
  ValueListenable<RealtimeRefresh?> get lastRefresh => _lastRefresh;

  /// The company currently listened for, or null when the feature is idle.
  @visibleForTesting
  String? get activeCompanyId => _companyId;

  /// App backgrounded: close the socket (the channel is remembered).
  void pause() {
    _foreground = false;
    _connection.disconnect();
  }

  /// App foregrounded: reopen now, skipping any backoff wait.
  void resume() {
    _foreground = true;
    if (_companyId != null) _connection.connect();
  }

  /// The network came back: reopen now if the app is in front — a backoff
  /// timer sized for a flapping server would otherwise sit out up to a minute.
  void onOnline() {
    if (_foreground && _companyId != null) _connection.connect();
  }

  void dispose() {
    _auth.credentials.removeListener(_reconcile);
    _auth.session.removeListener(_reconcile);
    unawaited(_keySub?.cancel());
    unawaited(_eventSub.cancel());
    _connection.dispose();
    _lastRefresh.dispose();
    unawaited(_downloads.close());
  }

  bool _eligible(ApiCredentials? creds) =>
      _enabled &&
      creds != null &&
      creds.isAuthenticated &&
      creds.isHosted &&
      creds.companyId.isNotEmpty &&
      !Env.demoMode &&
      !(_auth.session.value?.isDemo ?? false);

  void _reconcile() {
    final creds = _auth.credentials.value;
    final target = _eligible(creds) ? creds!.companyId : null;
    // Credentials are reassigned on every refresh with identity equality, so
    // most notifications change nothing.
    if (target == _companyId) {
      // The account key can land after the company did (a session refresh),
      // so the user channel is reconciled on every notification.
      _reconcileUserChannel();
      return;
    }
    _companyId = target;
    unawaited(_keySub?.cancel());
    _keySub = null;
    if (target == null) {
      _connection.unsubscribe();
      _userChannel = null;
      _connection.disconnect();
      return;
    }
    // A company switch moves the company channel only. The user channel's
    // name doesn't involve the company and the server authorizes it on the
    // account key and user id alone (`routes/channels.php`), so it stays —
    // dropping and re-joining it would lose a download notice landing in
    // between. It is re-pointed at the new company's signing for the next
    // reconnect.
    _connection.unsubscribe(slot: kDefaultChannelSlot);
    _reconcileUserChannel(reauthorize: true);
    if (_foreground) _connection.connect();
    // On a first login the credentials can land before the company row does,
    // and `companyKey` defaults to '' — wait for the real one.
    _keySub = _companyKeys(target).where((k) => k.isNotEmpty).take(1).listen((
      key,
    ) {
      if (_companyId != target) return;
      _connection.subscribe(
        'private-company-$key',
        (socketId, channel) => _authorize(target, socketId, channel),
      );
    });
  }

  /// Carry the signed-in user's channel while a company is active — signed
  /// in that company's scope like the company channel. [reauthorize] re-hands
  /// an unchanged channel the active company's authorizer (a company switch);
  /// [PusherConnection.subscribe] then swaps only the signer, no re-join.
  void _reconcileUserChannel({bool reauthorize = false}) {
    final companyId = _companyId;
    final session = _auth.session.value;
    final accountKey = session?.accountKey ?? '';
    final userId = session?.userId ?? '';
    final wanted = companyId == null || accountKey.isEmpty || userId.isEmpty
        ? null
        : 'private-user-$accountKey-$userId';
    if (wanted == _userChannel && !(reauthorize && wanted != null)) return;
    _userChannel = wanted;
    if (wanted == null) {
      _connection.unsubscribe(slot: kUserChannelSlot);
      return;
    }
    _connection.subscribe(
      wanted,
      (socketId, channel) => _authorize(companyId!, socketId, channel),
      slot: kUserChannelSlot,
    );
  }

  /// `POST /broadcasting/auth` — at the server root, not under `/api/v1` — in
  /// the scope of [companyId], so a company switch mid-request throws instead
  /// of signing one workspace's channel with another's token.
  Future<String> _authorize(
    String companyId,
    String socketId,
    String channel,
  ) async {
    final raw = await RequestScope(companyId).run(
      () => _api.postJson(
        '/broadcasting/auth',
        body: {'socket_id': socketId, 'channel_name': channel},
        readOnly: true,
      ),
    );
    final auth = raw is Map ? raw['auth'] : null;
    if (auth is! String || auth.isEmpty) {
      throw StateError('/broadcasting/auth returned no auth signature');
    }
    return auth;
  }

  void _onEvent(PusherEvent event) {
    final companyId = _companyId;
    if (companyId == null) return;
    _log.fine('realtime ${event.event}');
    if (event.event == kDownloadAvailableEvent) {
      final data = event.data;
      final url = data is Map ? data['url'] : null;
      final message = data is Map ? data['message'] : null;
      if (url is String && url.isNotEmpty && !_downloads.isClosed) {
        _downloads.add(
          DownloadReady(message: message is String ? message : '', url: url),
        );
      }
      return;
    }
    final pending = _scheduler.requestSoon();
    // A burst of events shares one pending refresh — follow it once.
    if (identical(pending, _awaiting)) return;
    _awaiting = pending;
    unawaited(
      pending.then((refreshed) {
        if (identical(_awaiting, pending)) _awaiting = null;
        if (!refreshed || _companyId != companyId) return;
        _lastRefresh.value = RealtimeRefresh(companyId: companyId, at: _now());
      }),
    );
  }
}
