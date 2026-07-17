import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// One modifier-shortcut hint shown in the hold-modifier hint bar.
///
/// [keys] are pre-resolved display glyphs (e.g. `[platformModifierLabel(),
/// 'S']` renders as `⌘ S`). [labelKey] is an l10n key resolved at render
/// time via `context.tr` — keeping this model context-free so it can live
/// on a controller and be unit-tested without a widget tree.
@immutable
class ShortcutHint {
  const ShortcutHint({required this.keys, required this.labelKey});

  final List<String> keys;
  final String labelKey;

  @override
  bool operator ==(Object other) =>
      other is ShortcutHint &&
      listEquals(other.keys, keys) &&
      other.labelKey == labelKey;

  @override
  int get hashCode => Object.hash(Object.hashAll(keys), labelKey);
}

/// App-wide registry + visibility state for the Slack-style "hold the
/// platform modifier to reveal shortcuts" hint bar. A context-free
/// [ChangeNotifier] held on `Services` and rendered by a single global
/// `ShortcutHintOverlay` near the app root (mirrors `ToastController` /
/// `ToastHost`).
///
/// Screens contribute the modifier shortcuts available in their context via
/// `ShortcutHintScope`, which [register]s on mount and [unregister]s on
/// dispose. The authenticated shell registers the always-available global
/// set the same way, so the login screen (no shell) shows nothing.
///
/// The registry is **token-keyed** (not a single slot or a LIFO stack):
/// during route/pane transitions a new screen's `initState` can run before
/// the old screen's `dispose`, so per-token removal is the only model that
/// never clears the wrong entry and blanks the bar.
class ShortcutHintController extends ChangeNotifier {
  final Map<Object, List<ShortcutHint>> _scopes = {};
  bool _visible = false;
  bool _disposed = false;
  bool _notifyScheduled = false;

  bool get visible => _visible;

  /// Register (or replace) the hints contributed by [token]. Insertion
  /// order is preserved so the bar reads global-first, context-next.
  void register(Object token, List<ShortcutHint> hints) {
    _scopes[token] = hints;
    _notify();
  }

  void unregister(Object token) {
    if (_scopes.remove(token) != null) _notify();
  }

  /// Union of every registered scope's hints, in registration order,
  /// de-duped by (keys, labelKey) so a shortcut registered by two mounted
  /// scopes (e.g. list + detail-edit in master-detail) shows only once.
  List<ShortcutHint> get activeHints {
    final seen = <ShortcutHint>{};
    final out = <ShortcutHint>[];
    for (final list in _scopes.values) {
      for (final hint in list) {
        if (seen.add(hint)) out.add(hint);
      }
    }
    return out;
  }

  /// Show the bar. No-op when there's nothing to show, so a stray hold on a
  /// scope-less screen never flashes an empty pill.
  void reveal() {
    if (_visible || activeHints.isEmpty) return;
    _visible = true;
    _notify();
  }

  void hide() {
    if (!_visible) return;
    _visible = false;
    _notify();
  }

  /// Defensive reset on logout (mirrors `ToastController.clearAll`): clears
  /// visibility and every scope so nothing survives a session boundary.
  void reset() {
    final had = _visible || _scopes.isNotEmpty;
    _visible = false;
    _scopes.clear();
    if (had) _notify();
  }

  /// Notify listeners — but never *during* a frame's build/layout/paint phase.
  ///
  /// `ShortcutHintScope` registers/unregisters from `didChangeDependencies`,
  /// which on an entity edit screen runs inside the scaffold's `LayoutBuilder`
  /// layout callback. Notifying synchronously there would mark the sibling
  /// `ShortcutHintOverlay` (`ListenableBuilder`, mounted near the app root)
  /// dirty mid-build → "setState() called during build". When called mid-frame
  /// (`persistentCallbacks`), defer the notification to the end of the frame
  /// (coalesced via [_notifyScheduled]); otherwise notify synchronously as
  /// before. State mutations above are always synchronous — only the listener
  /// rebuild is deferred, and only by one frame (imperceptible: the bar only
  /// appears after a ~400 ms modifier hold).
  void _notify() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
