import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Whether the authenticated shell (`ScaffoldWithNav`) is on screen.
///
/// Written from the shell's `initState` / `dispose`; read by `WindowFrame`,
/// which mounts ABOVE the router (in `MaterialApp.builder`) and so cannot see
/// the shell at all. It needs the bit to decide whether its leading segment
/// should read as the sidebar rail — the frameless Windows / Linux title bar
/// spans the whole window, including the six routes that have no sidebar
/// (`/login`, `/lock`, `/setup`, …).
///
/// **Why the notification is deferred.** The listener is an *ancestor* of the
/// writer, and it has already been built for the frame in which the shell's
/// `initState` runs — so notifying synchronously there is
/// "setState() called during build" *deterministically*, on every login, not
/// as an occasional race. `ShortcutHintController._notify` carries the same
/// guard for the same class of failure (it hit a sibling, which is the milder
/// case). The *value* changes synchronously; only the listener rebuild waits,
/// and only for the one frame in which the route is swapping anyway.
///
/// Putting the guard in the notifier rather than at the call site is
/// deliberate: it makes every writer safe by construction, so there is no
/// "remember to defer" rule for a future caller to break.
class ShellMountedNotifier extends ValueNotifier<bool> {
  ShellMountedNotifier() : super(false);

  bool _notifyScheduled = false;
  bool _disposed = false;

  /// The single interception point: `ValueNotifier`'s own `value` setter
  /// already early-returns on an unchanged value and then calls this, so
  /// overriding the setter as well would just add a second place to get wrong.
  @override
  void notifyListeners() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) super.notifyListeners();
      });
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
