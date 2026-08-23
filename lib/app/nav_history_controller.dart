import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/nav_state_persister.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';

/// Whether navigating from [from] to [to] is a structural **"up"** — i.e.
/// [to] is a proper URL-parent of [from] (`/quotes` is up from
/// `/quotes/q_1?view=full`; `/quotes/q_1` is up from `/quotes/q_1/edit`).
///
/// Paths only: an in-cell link appends `?view=full` (`goEntityFullDetail`) and
/// the pane's close target may or may not carry it, so comparing whole URIs
/// would miss the match. A *lateral* jump is deliberately not "up" —
/// `/clients` is not up from `/invoices`, so walking the sidebar
/// Clients → Invoices → Clients still records three entries and back returns
/// to Invoices instead of exiting the app.
bool isUpNavigation({required String from, required String to}) {
  final fromPath = Uri.parse(from).path;
  final toPath = Uri.parse(to).path;
  if (toPath.isEmpty || fromPath == toPath) return false;
  return fromPath.startsWith(toPath.endsWith('/') ? toPath : '$toPath/');
}

/// Whether [uri] is a **create form** (`/x/new`) — a place the user can never
/// meaningfully go *back* to.
///
/// Leaving one always replaces its history entry: the record it created
/// (`goAfterEntitySave`) is not an up-navigation from `/x/new`, so without this
/// every "save a new invoice, swipe back" landed the user on a blank New
/// Invoice form. [NavStatePersister] refuses to persist these locations for the
/// same reason — a create form is transient by construction, and re-entering a
/// stale one opens it blank anyway.
bool isTransientCreateRoute(String uri) => Uri.parse(uri).path.endsWith('/new');

/// In-memory browser-style navigation history.
///
/// The app navigates almost entirely via `context.go()`, which *replaces* the
/// current location rather than pushing it — so go_router keeps no usable
/// back/forward stack. This controller records every distinct location the
/// router lands on and lets the user walk backward/forward through it.
/// Surfaced four ways: `Cmd/Alt + Left/Right` shortcuts, the mouse
/// back/forward thumb buttons (both in `ScaffoldWithNav`), the sidebar arrow
/// pair (`NavHistoryButtons`), and the **Android system back gesture**
/// (`SystemBackGate`, issue #39). The last two are what make history reachable
/// on touch, where there is no keyboard and no multi-button mouse.
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

    // Normalized exactly as the persisted route is (`stripTransientQuery`):
    // `view=full` is a display mode, not a place. The master-detail layout
    // auto-promotes an editor to full-screen with a second `go()` one frame
    // after it opens, so without this every wide-viewport editor lands in
    // history twice and the close-replaces-the-entry rule below can only
    // collapse the second copy — leaving back to re-open the editor the user
    // just closed. Also drops the one-shot `module_off` notice token.
    final uri = stripTransientQuery(_currentPath());
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

    _pushFresh(uri, isFreshNavigation: !wasNavigating);
  }

  /// Fresh user navigation: drop any forward entries and append. Going back a
  /// few steps then navigating somewhere new prunes the abandoned branch —
  /// exactly how a browser's history behaves. `go()` to an unsaved edit
  /// screen skips the `PopScope` discard prompt, same as the existing J/K
  /// row navigation in `master_detail_layout.dart`; behavior stays consistent.
  ///
  /// Two exceptions *replace* the current entry instead of appending:
  ///
  ///  * a structural **"up"** navigation ([isUpNavigation]). The app's back
  ///    affordances all navigate with `go()` rather than popping — the pane's
  ///    leading arrow (`entityCloseTargetPath`), `_closePaneAnimated`, and the
  ///    inner-navigator pop from `/x/:id/edit` back to `/x/:id`. Appending
  ///    there would leave the screen the user just closed sitting one step
  ///    *forward* of the cursor, so the next back (now also the Android system
  ///    back gesture) would walk straight into it.
  ///  * leaving a **create form** ([isTransientCreateRoute]) — `/x/new` is
  ///    never a place to return to.
  void _pushFresh(String uri, {required bool isFreshNavigation}) {
    // The replace rules below describe *user* intent, so they're gated on a
    // fresh navigation. The other caller is `_onChange`'s post-back re-sync
    // (a `back()` whose landing was redirected somewhere not in the stack):
    // its cursor has already been moved, and replacing there would overwrite
    // an entry the user really did visit.
    final canReplace =
        isFreshNavigation && _index >= 0 && _index < _stack.length;
    if (canReplace &&
        (isUpNavigation(from: _stack[_index], to: uri) ||
            isTransientCreateRoute(_stack[_index]))) {
      _stack[_index] = uri;
      // Collapse behind the cursor while the previous entry is this location
      // or something *below* it: coming up out of a subtree, everything in
      // that subtree is behind you, and leaving it in place would let the
      // next back descend into a child of where you now are.
      while (_index > 0 &&
          (_stack[_index - 1] == uri ||
              isUpNavigation(from: _stack[_index - 1], to: uri))) {
        _stack.removeAt(_index);
        _index--;
        _stack[_index] = uri;
      }
      if (_index < _stack.length - 1) {
        _stack.removeRange(_index + 1, _stack.length);
      }
      notifyListeners();
      return;
    }
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
