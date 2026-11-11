import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/data/services/api_uri.dart';
import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_client.dart';

/// Thin wrapper around the calendar-connection endpoints (Google / Microsoft).
/// Stateless like [QuickbooksRepository] — the connection lives server-side on
/// `user.settings.calendar_connection` and is read back via [status].
///
/// The OAuth handshake is **server-mediated** (Socialite): this client only
/// mints the authorize URL the user opens and relays the one-time `handoff` to
/// the security-critical [complete] step (where the server asserts the
/// completing user is the one that started the flow). Events and calendars are
/// live provider reads, never persisted to Drift.
class CalendarConnectionRepository {
  CalendarConnectionRepository({
    required ApiClient apiClient,
    required AuthRepository auth,
  }) : _api = apiClient,
       _auth = auth;

  final ApiClient _api;
  final AuthRepository _auth;
  final _uuid = const Uuid();

  /// Shared, app-lifetime source of truth for the connection. `complete` /
  /// `status` / `disconnect` push to it so any live calendar view reflects the
  /// change immediately — notably the native deep-link `complete` flow updating
  /// an already-mounted (IndexedStack-retained) calendar screen. `null` = not
  /// yet read.
  final ValueNotifier<CalendarConnection?> connectionState =
      ValueNotifier<CalendarConnection?>(null);

  /// Clear the in-memory connection so a new session starts unread. Called from
  /// [AuthRepository.logout] (wired in `Services`): the repo is an app-lifetime
  /// singleton, so without this a second user logging in on the same install
  /// would briefly see the previous user's connected calendar email — and a
  /// failed `status()` read would keep it on screen indefinitely (cross-user
  /// leak). The connection is per-user server-side; the next [status] repopulates.
  void resetSessionState() {
    connectionState.value = null;
  }

  /// Providers the server supports for calendar connect.
  static const supportedProviders = <String>['google', 'microsoft'];

  static bool isSupportedProvider(String provider) =>
      supportedProviders.contains(provider);

  /// Mint a one-time token and build the provider authorize URL the user opens
  /// to start the OAuth flow. Mirrors React `useConnectCalendar`:
  /// `POST /one_time_token {context:'calendar_<provider>'}` → `{hash}` →
  /// `GET /api/v1/calendar_connection/<provider>/authorize/<hash>`.
  ///
  /// [platform] is sent only for native clients (the server maps `flutter_native`
  /// to the custom-scheme callback). Web clients omit it and return via the
  /// server's `react_url` redirect — see BACKEND.md.
  Future<Uri> buildAuthorizeUrl(String provider, {String? platform}) async {
    final raw = await _api.postJson(
      '/api/v1/one_time_token',
      body: <String, dynamic>{
        'context': 'calendar_$provider',
        if (platform != null) 'platform': platform,
      },
    );
    final hash = _hashFrom(raw);
    final baseUrl = _auth.session.value?.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('cannot build calendar authorize URL without baseUrl');
    }
    // The authorize route lives under `/api/v1` — do NOT strip the segment.
    return apiUri(
      baseUrl,
      '/api/v1/calendar_connection/$provider/authorize/$hash',
    );
  }

  /// The security-critical confirmation call. The server verifies the
  /// authenticated user matches the one that started the flow before exchanging
  /// the OAuth code, then persists the tokens. Returns the resulting
  /// connection. Throws (422/404) when the handoff is invalid/expired or the
  /// user doesn't match.
  Future<CalendarConnection> complete({
    required String provider,
    required String handoff,
  }) async {
    final raw = await _api.postJson(
      '/api/v1/calendar_connection/$provider/complete',
      body: <String, dynamic>{'handoff': handoff},
    );
    final conn =
        _connectionFrom(raw) ?? const CalendarConnection(connected: true);
    connectionState.value = conn;
    return conn;
  }

  /// Current connection status. Returns a disconnected sentinel when the server
  /// envelope is `null`.
  Future<CalendarConnection> status() async {
    final raw = await _api.getOne('/api/v1/calendar_connection');
    final conn =
        _connectionFrom(raw) ?? const CalendarConnection(connected: false);
    connectionState.value = conn;
    return conn;
  }

  /// Every calendar the provider exposes, each flagged `selected` if it's in
  /// the user's saved set.
  Future<List<CalendarInfo>> calendars() async {
    final raw = await _api.getOne('/api/v1/calendar_connection/calendars');
    return _listOf(raw, 'calendars', CalendarInfo.fromJson);
  }

  /// Persist the user's calendar selection.
  Future<void> setCalendars(List<String> calendarIds) async {
    await _api.mutate(
      method: 'PUT',
      path: '/api/v1/calendar_connection/calendars',
      idempotencyKey: _uuid.v4(),
      body: <String, dynamic>{'calendar_ids': calendarIds},
    );
  }

  /// Live events across the selected calendars within [from]..[to] (UTC). The
  /// server caps the window at 45 days and excludes events already converted to
  /// a task by this user.
  Future<List<CalendarEvent>> events({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _api.getOneWithQuery(
      '/api/v1/calendar_connection/events',
      query: <String, String>{
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return _listOf(raw, 'events', CalendarEvent.fromJson);
  }

  /// Remove the calendar connection server-side.
  Future<void> disconnect() async {
    await _api.mutate(
      method: 'DELETE',
      path: '/api/v1/calendar_connection',
      idempotencyKey: _uuid.v4(),
    );
    connectionState.value = const CalendarConnection(connected: false);
  }

  // ---- tolerant parsing (mirrors QuickbooksRepository) ----

  String _hashFrom(dynamic raw) {
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map && data['hash'] is String) return data['hash'] as String;
      if (raw['hash'] is String) return raw['hash'] as String;
    }
    throw StateError('one_time_token response missing hash');
  }

  Map<String, dynamic> _dataOf(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    return const <String, dynamic>{};
  }

  /// Parses `data.calendar_connection`. A `null` envelope (no connection) → null.
  CalendarConnection? _connectionFrom(dynamic raw) {
    final conn = _dataOf(raw)['calendar_connection'];
    if (conn is Map) {
      return CalendarConnection.fromJson(conn.cast<String, dynamic>());
    }
    return null;
  }

  List<T> _listOf<T>(
    dynamic raw,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = _dataOf(raw)[key];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) fromJson(e.cast<String, dynamic>()),
    ];
  }
}
