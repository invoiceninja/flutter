import 'package:flutter/foundation.dart';

import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/repositories/calendar_connection_repository.dart';
import 'package:admin/data/services/calendar_connect_launcher.dart';

/// Drives the calendar-connection surface on the tasks calendar: connection
/// status, the live event list for the visible month window, and the
/// connect/disconnect actions. Pure [ChangeNotifier] — events and status are
/// direct API reads (never Drift), mirroring the reports view-model shape.
///
/// The connection is **per-user** (server `user.settings`), so this VM is not
/// company-scoped; a converted event still creates its task in the active
/// company (the convert flow uses the task repo).
class CalendarConnectionViewModel extends ChangeNotifier {
  CalendarConnectionViewModel({required this.repo}) {
    _connection = repo.connectionState.value;
    _statusLoaded = _connection != null;
    repo.connectionState.addListener(_onRepoConnection);
  }

  final CalendarConnectionRepository repo;

  CalendarConnection? _connection;
  CalendarConnection? get connection => _connection;
  bool get isConnected => _connection?.connected ?? false;
  String? get connectedEmail => _connection?.email;

  bool _statusLoaded = false;
  bool get statusLoaded => _statusLoaded;

  bool _connecting = false;
  bool get connecting => _connecting;

  bool _hideEvents = false;
  bool get hideEvents => _hideEvents;

  /// Toggle the event overlay on the month grid (React `hide_events`).
  void toggleHideEvents() {
    _hideEvents = !_hideEvents;
    _notify();
  }

  bool _eventsLoading = false;
  bool get eventsLoading => _eventsLoading;

  bool _eventsError = false;
  bool get eventsError => _eventsError;

  List<CalendarEvent> _events = const <CalendarEvent>[];
  List<CalendarEvent> get events => _events;

  Map<String, List<CalendarEvent>> _eventsByDay =
      const <String, List<CalendarEvent>>{};

  /// Events bucketed by local `YYYY-MM-DD` day key, cancelled events dropped,
  /// each day sorted by start. Consumed by the calendar day cells.
  Map<String, List<CalendarEvent>> get eventsByDay => _eventsByDay;

  bool _disposed = false;
  int _eventsEpoch = 0;

  @override
  void dispose() {
    _disposed = true;
    repo.connectionState.removeListener(_onRepoConnection);
    super.dispose();
  }

  /// The repo is the source of truth for connection status (pushed by
  /// `complete` / `status` / `disconnect`). Mirror it; clear events when it
  /// flips to disconnected.
  void _onRepoConnection() {
    _connection = repo.connectionState.value;
    _statusLoaded = true;
    if (!isConnected) _setEvents(const <CalendarEvent>[]);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Load the current connection status. Swallows errors into a disconnected
  /// state — the connect menu is the call-to-action either way.
  Future<void> loadStatus() async {
    try {
      await repo.status(); // pushes to repo.connectionState → _onRepoConnection
    } catch (_) {
      // Surface a disconnected state on failure so the menu stays actionable,
      // but only when nothing is known yet (`??=`): a genuine connected value
      // just pushed by `complete()` (with the user's email) must NOT be stomped
      // by a transient status() failure on a fresh calendar-screen mount — that
      // would flash the connection to "disconnected" until the next reload.
      // The cross-user-leak case (a PREVIOUS user's stale value) is handled at
      // the source: AuthRepository.logout() now nulls connectionState via the
      // onSessionReset hook, so a new session starts here at null → this `??=`
      // correctly writes the disconnected sentinel.
      repo.connectionState.value ??= const CalendarConnection(connected: false);
    } finally {
      _statusLoaded = true;
      _notify();
    }
  }

  /// Start the OAuth flow for [provider] ('google' / 'microsoft'). Opens the
  /// system browser (native) or redirects the tab (web); the `handoff` return
  /// is finalised by the complete route, which routes back to the calendar and
  /// re-runs [loadStatus]. Throws on launch/transport failure so the caller can
  /// toast. The in-flight flag clears after the launch (or on a timeout) so the
  /// menu never sticks if the user abandons the browser.
  Future<void> connect(String provider) async {
    if (_connecting) return;
    _connecting = true;
    _notify();
    try {
      // `flutter_native` makes the server 302 the OAuth callback to
      // `invoiceninja://calendar_connection/complete` — send it only where
      // the scheme is actually registered: iOS/macOS/Android (Info.plist /
      // AndroidManifest) and Windows (MSIX protocol_activation + the
      // app_links second-instance forward in windows/runner/main.cpp).
      // Web and LINUX ride the react_url web redirect instead — an AppImage
      // can't reliably register an x-scheme-handler (only AppImageLauncher
      // installs the embedded .desktop) and the GTK runner is
      // G_APPLICATION_NON_UNIQUE (the command-line signal app_links needs
      // never fires), so a native callback would strand the browser on an
      // unresolvable URL. The web flow completes in the browser; this app
      // picks the connection up on the next loadStatus().
      final linux = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
      final platform = (kIsWeb || linux) ? null : 'flutter_native';
      final url = await repo.buildAuthorizeUrl(provider, platform: platform);
      await openCalendarAuthorize(url);
    } finally {
      _connecting = false;
      _notify();
    }
  }

  /// Disconnect server-side. The repo pushes a disconnected state to
  /// `connectionState`, which clears our connection + events via
  /// [_onRepoConnection].
  Future<void> disconnect() async {
    await repo.disconnect();
  }

  /// Load events for the [from]..[to] window (the visible 6-week grid, ≤ the
  /// server's 45-day cap). No-op when disconnected. Epoch-guarded so a fast
  /// month-flip keeps only the latest result.
  Future<void> loadEvents({
    required DateTime from,
    required DateTime to,
  }) async {
    final epoch = ++_eventsEpoch;
    if (!isConnected) {
      _setEvents(const <CalendarEvent>[]);
      _notify();
      return;
    }
    _eventsLoading = true;
    _eventsError = false;
    _notify();
    try {
      final result = await repo.events(from: from, to: to);
      if (epoch != _eventsEpoch) return;
      _setEvents(result);
    } catch (_) {
      if (epoch != _eventsEpoch) return;
      _eventsError = true;
      _setEvents(const <CalendarEvent>[]);
    } finally {
      if (epoch == _eventsEpoch) {
        _eventsLoading = false;
        _notify();
      }
    }
  }

  /// Remove a converted event from the in-memory list so its chip disappears
  /// immediately, without waiting for the next [loadEvents].
  void removeEvent(String calendarEventId) {
    if (calendarEventId.isEmpty) return;
    _setEvents(
      _events.where((e) => e.calendarEventId != calendarEventId).toList(),
    );
    _notify();
  }

  void _setEvents(List<CalendarEvent> events) {
    _events = events;
    final map = <String, List<CalendarEvent>>{};
    for (final e in events) {
      if (e.isCancelled) continue;
      (map[e.dayKey] ??= <CalendarEvent>[]).add(e);
    }
    final zero = DateTime.fromMillisecondsSinceEpoch(0);
    for (final list in map.values) {
      list.sort(
        (a, b) => (a.startLocal ?? zero).compareTo(b.startLocal ?? zero),
      );
    }
    _eventsByDay = map;
  }
}
