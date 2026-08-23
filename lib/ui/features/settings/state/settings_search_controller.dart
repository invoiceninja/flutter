import 'package:flutter/widgets.dart';

/// Open/closed state + query text for the `/settings` index search.
///
/// Lives outside `SettingsListSidebar` because the *trigger* and the *results*
/// no longer share a parent. On narrow the magnifying glass and the field sit
/// in `SettingsScreen`'s pinned AppBar — they used to be the `trailing:` of the
/// in-list "Basic Settings" header, so they scrolled away (issue #42) — while
/// the results still render in the list body below.
///
/// Ownership rule: **whoever creates the controller renders the trigger.** The
/// wide 280 px pane has no AppBar, so it creates its own and keeps an in-pane
/// affordance; `SettingsScreen` passes one down and owns the chrome itself.
class SettingsSearchController extends ChangeNotifier {
  /// The live query. A `Listenable` in its own right, so the results list binds
  /// to it directly and a keystroke rebuilds the hits and nothing else — the
  /// AppBar must not rebuild per character.
  final TextEditingController query = TextEditingController();
  final FocusNode focus = FocusNode();

  bool get isActive => _isActive;
  bool _isActive = false;
  bool _disposed = false;

  void open() {
    if (_disposed || _isActive) return;
    _isActive = true;
    notifyListeners();
    // Defer until the TextField is mounted. Explicit `requestFocus` rather than
    // `autofocus: true`: a `FocusScope` skips its autofocus request when
    // something in the scope already holds focus, and on desktop/web that is
    // exactly the IconButton the user just clicked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !_isActive) return;
      focus.requestFocus();
    });
  }

  void close() {
    // A search hit's `onTap` awaits the unsaved-changes guard, navigates, and
    // only then closes — by which point a redirect may have disposed the host.
    if (_disposed) return;
    query.clear();
    if (!_isActive) return;
    _isActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    query.dispose();
    focus.dispose();
    super.dispose();
  }
}
