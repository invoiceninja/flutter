import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';

/// In-memory browser-style navigation history.
///
/// The app navigates almost entirely via `context.go()`, which *replaces* the
/// current location rather than pushing it — so go_router keeps no usable
/// back/forward stack. This controller records every distinct location the
/// router lands on and lets the user walk backward/forward through it.
/// Surfaced three ways: `Cmd/Alt + Left/Right` shortcuts and the mouse
/// back/forward thumb buttons (both in `ScaffoldWithNav`), plus the visible
/// sidebar arrow pair (`NavHistoryButtons` in `InSidebar`).
///
/// Decoupled from [GoRouter] for testability — same seam as
/// [NavStatePersister] (`lib/app/nav_state_persister.dart`): takes a
/// [Listenable] that fires on each navigation, a `currentPath` callback, a
/// `navigate` callback, and the auth [session] (so history clears when the
/// active company changes or on logout — you must not be able to walk back
/// into another company's records). The default factory
/// [NavHistoryController.fromRouter] wires it to a [GoRouter].
class NavHistoryController extends ChangeNotifier {
  NavHistoryController({
    required Listenable changes,
    required String Function() currentPath,
    required void Function(String) navigate,
    required ValueListenable<AuthSession?> session,
    this.maxEntries = 50,
  }) : _changes = changes,
       _currentPath = currentPath,
       _navigate = navigate,
       _session = session {
    _lastCompanyId = _session.value?.currentCompanyId;
    _changes.addListener(_onChange);
    _session.addListener(_onSession);
  }

  /// Convenience: build the controller bound to a [GoRouter].
  factory NavHistoryController.fromRouter({
    required GoRouter router,
    required ValueListenable<AuthSession?> session,
    int maxEntries = 50,
  }) {
    return NavHistoryController(
      changes: router.routerDelegate,
      currentPath: () =>
          router.routerDelegate.currentConfiguration.uri.toString(),
      navigate: router.go,
      session: session,
      maxEntries: maxEntries,
    );
  }

  final Listenable _changes;
  final String Function() _currentPath;
  final void Function(String) _navigate;
  final ValueListenable<AuthSession?> _session;

  /// Cap on retained entries so a long session doesn't grow unbounded.
  final int maxEntries;

  final List<String> _stack = <String>[];
  int _index = -1;

  /// Set while a [back] / [forward] navigation is in flight so the resulting
  /// router change moves the cursor instead of pushing a new entry.
  bool _navigating = false;
  String? _lastCompanyId;

  bool get canGoBack => _index > 0;
  bool get canGoForward => _index >= 0 && _index < _stack.length - 1;

  @visibleForTesting
  List<String> get stack => List.unmodifiable(_stack);

  @visibleForTesting
  int get index => _index;

  void _onChange() {
    // Consume the navigating flag up-front so it can never get stuck — a
    // back()/forward() that lands on a filtered gate route below would
    // otherwise leave it set and corrupt the next push.
    final wasNavigating = _navigating;
    _navigating = false;

    final uri = _currentPath();
    // Same skip filters as NavStatePersister: these are transient gates the
    // router redirects to, never a place the user meaningfully "was".
    if (uri == '/login') return;
    if (uri == '/lock' || uri.startsWith('/lock?')) return;
    if (uri == '/setup') return;
    // One-shot OAuth landing gate with a single-use handoff token — backing
    // onto it would re-fire the consumed handoff (spurious "connect failed").
    if (uri == '/calendar_connection/complete' ||
        uri.startsWith('/calendar_connection/complete?')) {
      return;
    }

    // Already the cursor's location (e.g. a redirect that resolved back to
    // here, or a no-op rebuild) — nothing to record.
    if (_index >= 0 && _index < _stack.length && _stack[_index] == uri) {
      return;
    }

    if (wasNavigating) {
      // This change *is* the result of our back()/forward() call. A route
      // guard may have redirected elsewhere; re-sync the cursor to wherever
      // we actually landed rather than pushing a duplicate.
      final at = _stack.indexOf(uri);
      if (at != -1) {
        _index = at;
        notifyListeners();
        return;
      }
    }

    _pushFresh(uri);
  }

  /// Fresh user navigation: drop any forward entries and append. Going back a
  /// few steps then navigating somewhere new prunes the abandoned branch —
  /// exactly how a browser's history behaves. `go()` to an unsaved edit
  /// screen skips the `PopScope` discard prompt, same as the existing J/K
  /// row navigation in `master_detail_layout.dart`; behavior stays consistent.
  void _pushFresh(String uri) {
    if (_index < _stack.length - 1) {
      _stack.removeRange(_index + 1, _stack.length);
    }
    _stack.add(uri);
    if (_stack.length > maxEntries) {
      _stack.removeAt(0);
    }
    _index = _stack.length - 1;
    notifyListeners();
  }

  void _onSession() {
    final companyId = _session.value?.currentCompanyId;
    if (companyId != _lastCompanyId) {
      _lastCompanyId = companyId;
      _clear();
    }
  }

  void _clear() {
    // Always reset the flag, even when the stack is already empty, so a
    // company switch / logout can never leave it stuck.
    _navigating = false;
    if (_stack.isEmpty && _index == -1) return;
    _stack.clear();
    _index = -1;
    notifyListeners();
  }

  // back()/forward() notify unconditionally: the resulting router change
  // usually resolves to the "cursor already matches" early-return in
  // [_onChange] (the cursor moves *before* navigating), which deliberately
  // skips notifying — so without these, canGoBack/canGoForward consumers
  // (the sidebar arrow buttons) would render stale enabled state.

  void back() {
    if (!canGoBack) return;
    _navigating = true;
    _index--;
    _navigate(_stack[_index]);
    notifyListeners();
  }

  void forward() {
    if (!canGoForward) return;
    _navigating = true;
    _index++;
    _navigate(_stack[_index]);
    notifyListeners();
  }

  @override
  void dispose() {
    _changes.removeListener(_onChange);
    _session.removeListener(_onSession);
    super.dispose();
  }
}
