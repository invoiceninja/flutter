import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/data/db/app_database.dart';

/// Watches the active route and persists it to `nav_state.current_route` so
/// the next launch lands on the same screen.
///
/// Decoupled from [GoRouter] for testability: takes a [Listenable] that
/// fires on each navigation and a `currentPath` callback that reads the
/// current location. The default factory [NavStatePersister.fromRouter]
/// wires it up to a [GoRouter].
///
/// Writes are debounced — rapid navigation (tapping through a list) produces
/// one write at the trailing edge. The `/login` route is filtered out so we
/// Drops query params that must never survive into a restored route — or
/// into the back/forward history ([NavHistoryController], which records the
/// same locations and must not treat a display-mode rewrite as a new place):
///
/// - `module_off`: the router appends it when it bounces a
///   deep-link/restored route off a now-disabled module so the shell can
///   show a one-time notice; persisting it would replay that stale notice
///   (and pollute "resume where you left off") on the next cold start.
/// - `view=full`: the master-detail full-screen pane choice is deliberately
///   *never* remembered across a restart — a cold launch always lands in the
///   sidebar preview. Stripping it covers routes `companySafeLocation`
///   passes through verbatim (arbitrary settings sub-routes — note it does
///   strip `/foo/new` back to `/foo`, query string and all).
///
/// NOTE: only `view=full` is transient. The Tasks screen reuses the same
/// `view=` key for its LAYOUT mode (`calendar`/`daily`/`weekly`/`kanban`),
/// which lives only in the URL and MUST persist — otherwise leaving Tasks on
/// the calendar and restarting silently dumps the user back on the plain
/// list. So a non-`full` `view` value is preserved.
///
/// Every other query param (e.g. `client_id`) is preserved.
String stripTransientQuery(String uri) {
  final hasModuleOff = uri.contains('module_off');
  final hasFullView = uri.contains('view=full');
  if (!hasModuleOff && !hasFullView) return uri;
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return uri;
  final q = Map<String, String>.from(parsed.queryParameters);
  var changed = false;
  if (q.remove('module_off') != null) changed = true;
  if (q['view'] == 'full') {
    q.remove('view'); // only the pane flag, never a task layout mode
    changed = true;
  }
  if (!changed) return uri;
  // Uri.replace(queryParameters: null) keeps the original query, so when
  // nothing else remains fall back to the bare path.
  return q.isEmpty
      ? parsed.path
      : parsed.replace(queryParameters: q).toString();
}

/// don't overwrite a previously-stored deep link during logout transitions.
class NavStatePersister {
  NavStatePersister({
    required Listenable changes,
    required String Function() currentPath,
    required this.db,
    Duration debounce = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _changes = changes,
       _currentPath = currentPath,
       _debounce = debounce,
       _now = now ?? DateTime.now {
    _changes.addListener(_onChange);
  }

  /// Convenience: build the persister bound to a [GoRouter].
  factory NavStatePersister.fromRouter({
    required GoRouter router,
    required AppDatabase db,
    Duration debounce = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) {
    return NavStatePersister(
      changes: router.routerDelegate,
      currentPath: () =>
          router.routerDelegate.currentConfiguration.uri.toString(),
      db: db,
      debounce: debounce,
      now: now,
    );
  }

  final Listenable _changes;
  final String Function() _currentPath;
  final AppDatabase db;
  final Duration _debounce;
  final DateTime Function() _now;

  Timer? _timer;
  String? _lastPersisted;

  void _onChange() {
    final uri = stripTransientQuery(_currentPath());
    if (uri == _lastPersisted) return;
    if (uri == '/login') return; // never overwrite a deep link with /login
    // /lock is transient — a cold launch that hits the biometric gate will
    // route there via redirect, not from a saved nav state. Persisting it
    // would also poison the `?from=` round-trip in the router.
    if (uri == '/lock' || uri.startsWith('/lock?')) return;
    // /setup is a one-shot redirect gate (active until the company has a
    // name). The router decides whether to land here; we never want a
    // cold launch to deep-link directly to the wizard.
    if (uri == '/setup') return;
    // /calendar_connection/complete is a one-shot OAuth landing gate carrying
    // a single-use `handoff` token. Persisting it would (a) write that secret
    // to disk (unencrypted on web) and (b) replay the already-consumed handoff
    // on the next cold start — a spurious "connect failed" toast. Treat it
    // like /lock and /setup.
    if (uri == '/calendar_connection/complete' ||
        uri.startsWith('/calendar_connection/complete?')) {
      return;
    }
    // Never resume into a transient create form (`/x/new`). Persisting it
    // would pre-mount the create screen on next launch; go_router then reuses
    // that mounted screen (without re-running its bootstrap) on the next
    // "New X" navigation, so a staged client seed / `extra` is never consumed
    // and the form opens blank. (Cold-start restore strips `/new` defensively
    // too — see `main.dart` — so this is belt-and-suspenders for older rows.)
    if (uri.endsWith('/new') || uri.contains('/new?')) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_flush(uri)));
  }

  Future<void> _flush(String uri) async {
    _lastPersisted = uri;
    await db.navStateDao.saveRoute(
      route: uri,
      now: _now().millisecondsSinceEpoch,
    );
  }

  void dispose() {
    _timer?.cancel();
    _changes.removeListener(_onChange);
  }
}
