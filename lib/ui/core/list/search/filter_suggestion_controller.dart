import 'package:flutter/foundation.dart';

/// Shared state between [FilterSuggestionMenu] (which renders rows) and
/// [TokenSearchField] (which intercepts keyboard events via its `Focus`
/// wrapper). The menu publishes its rows in display order; the field
/// drives the highlight + commit.
///
/// We can't put the index inside the menu alone because the field needs
/// to know the row count for arrow-key clamping and the row's action for
/// Enter — and we can't put it inside the field alone because the menu's
/// row list is derived from streamed value suggestions the field doesn't
/// have access to. A shared `ChangeNotifier` is the smallest piece of
/// glue that lets each side own what it knows.
class FilterSuggestionController extends ChangeNotifier {
  int _selectedIndex = 0;
  List<VoidCallback> _rowActions = const [];
  List<Object> _rowKeys = const [];
  Object? _stamp;
  bool _movedByKeyboard = false;

  /// Currently highlighted row, in the menu's display order. Always in
  /// `[0, rowCount)` when [rowCount] > 0; `0` when the menu is empty.
  int get selectedIndex => _selectedIndex;

  /// Number of rows the menu just published.
  int get rowCount => _rowActions.length;

  /// True when the highlight last moved by keyboard (arrows, a programmatic
  /// pre-selection) rather than by the pointer. Rows scroll themselves into
  /// view only for a keyboard move — a pointer is already where it points, and
  /// scrolling the list under it would move a different row beneath the cursor.
  ///
  /// **Not** "the user is using the keyboard": a fresh list starts true and
  /// only a mouse that MOVES clears it, so a touch tap — or a click from a
  /// pointer that was already parked on the row — still reads true. To ask
  /// whether the action running right now came from a key, use
  /// [committingByKeyboard].
  bool get movedByKeyboard => _movedByKeyboard;

  bool _committingByKeyboard = false;

  /// True only while [commit] is running a row's action — i.e. the action was
  /// fired by Enter / Tab / the soft keyboard's submit, not by a tap on the
  /// row. A row's own tap handler calls the same action with this false.
  bool get committingByKeyboard => _committingByKeyboard;

  /// Called by the menu after each rebuild — typically from a
  /// post-frame callback so `notifyListeners` doesn't fire while widgets
  /// are still being built. Pass the row actions in display order
  /// alongside a parallel list of stable [keys] that identify each row
  /// by content (e.g. `'key:status'`, `'value:status:active'`).
  ///
  /// The highlight resets to row 0 only when the published [keys]
  /// differ from the previous publish — by length or by per-index
  /// `==`. Same keys → same logical rows → highlight survives the
  /// publish, even though the closures in [actions] are fresh objects
  /// from this rebuild. This is what keeps the highlight glued to the
  /// row the user arrow-keyed to while a VM `notifyListeners` storms
  /// through (network load → list page swap → many no-op rebuilds).
  /// A genuine content change (filter narrows, value list shrinks)
  /// still flips at least one key and resets correctly.
  ///
  /// [stamp] identifies the input these rows were built for (the host passes
  /// the text in the box). Rows publish a frame after the text changes, so
  /// for one frame the published actions belong to the PREVIOUS text — see
  /// [commit].
  ///
  /// [preselect] moves the highlight to that row when the keys changed (a
  /// fresh list), e.g. the operator the user typed. It never overrides a
  /// highlight the user has already moved within the same rows.
  void publishRows(
    List<VoidCallback> actions,
    List<Object> keys, {
    Object? stamp,
    int? preselect,
  }) {
    assert(actions.length == keys.length);
    final unchanged = _keysMatch(keys);
    _rowActions = List<VoidCallback>.unmodifiable(actions);
    _rowKeys = List<Object>.unmodifiable(keys);
    _stamp = stamp;
    if (!unchanged) {
      final wanted = preselect ?? 0;
      _selectedIndex = (wanted >= 0 && wanted < actions.length) ? wanted : 0;
      // A fresh list starts from a programmatic position, which the rows
      // should scroll to — same as a keyboard move.
      _movedByKeyboard = true;
    }
    notifyListeners();
  }

  bool _keysMatch(List<Object> next) {
    if (next.length != _rowKeys.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i] != _rowKeys[i]) return false;
    }
    return true;
  }

  /// Set the highlight to a specific row. Used by mouse hover so a
  /// pointing user sees the same surface-alt background as a keyboard
  /// user — and Enter commits whichever row was last hovered or arrowed
  /// to. No-ops on out-of-range or unchanged input so spurious hover
  /// events don't fire notifications.
  ///
  /// [byKeyboard] is false for the pointer (the default — hover is the main
  /// caller) and true for a programmatic move the rows should scroll to.
  void setSelectedIndex(int index, {bool byKeyboard = false}) {
    if (index < 0 || index >= _rowActions.length) return;
    if (index == _selectedIndex && byKeyboard == _movedByKeyboard) return;
    _selectedIndex = index;
    _movedByKeyboard = byKeyboard;
    notifyListeners();
  }

  void moveUp() {
    if (_rowActions.isEmpty) return;
    final last = _rowActions.length - 1;
    _selectedIndex = _selectedIndex <= 0 ? last : _selectedIndex - 1;
    _movedByKeyboard = true;
    notifyListeners();
  }

  void moveDown() {
    if (_rowActions.isEmpty) return;
    _selectedIndex = (_selectedIndex + 1) % _rowActions.length;
    _movedByKeyboard = true;
    notifyListeners();
  }

  /// Fire the currently-highlighted row's action. Returns true when an
  /// action ran (the caller can stop further handling), false when there
  /// were no rows to commit (the caller may fall back to free-text
  /// search).
  ///
  /// Pass [expecting] — the input the caller is committing — to refuse rows
  /// that were published for a different one. A barcode scanner, or a paste
  /// followed at once by Enter, lands the keystroke in the same frame as the
  /// text change, before the menu has re-published: without the check Enter
  /// ran "Search for acm" under a box reading `acme`. On a mismatch the
  /// caller's typed path commits what is actually in the box.
  bool commit({Object? expecting}) {
    if (_rowActions.isEmpty) return false;
    if (expecting != null && expecting != _stamp) return false;
    if (_selectedIndex < 0 || _selectedIndex >= _rowActions.length) {
      return false;
    }
    _committingByKeyboard = true;
    try {
      _rowActions[_selectedIndex]();
    } finally {
      _committingByKeyboard = false;
    }
    return true;
  }
}
