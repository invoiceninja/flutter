import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';

/// What this launch has already put in front of the user unasked.
///
/// A launch that opened with the local-data recovery notice, the
/// missing-name prompt or the What's New dialog has asked enough of the
/// user; the mobile-app promo waits for a launch that hasn't
/// (docs/mobile-app-promo.md). Process-wide, not per shell: the shell
/// unmounts on a sign-out, and a second sign-in in the same launch is still
/// the same launch.
abstract final class AutomaticDialogs {
  static bool _shownThisLaunch = false;

  /// True once anything has called [noteShown] in this process.
  static bool get shownThisLaunch => _shownThisLaunch;

  /// Called by each automatic dialog as it opens.
  static void noteShown() => _shownThisLaunch = true;

  /// For tests — a process-wide flag otherwise leaks between them.
  static void resetForTest() => _shownThisLaunch = false;
}

/// One automatic dialog's "may I open now?" — shared by the What's New and
/// mobile-app promo hosts, which each hold their own, so one host's check
/// never spends the other's view of recent input.
class QuietMomentCheck {
  QuietMomentCheck() {
    _InputActivity.ensureTracking();
    _mark = _InputActivity.count;
  }

  late int _mark;

  /// The last path segments of the screens that are forms: a record's
  /// editor, a create screen, and the email / refund / statement screens a
  /// record's actions open.
  static const _formLeaves = {'edit', 'new', 'email', 'refund', 'statement'};

  /// Nothing the user is in the middle of: no click, tap, scroll or key
  /// since the previous check (or since this check was made), no dialog or
  /// sheet up, nothing being typed, no unsaved form, not on a form or
  /// settings screen, the window in front.
  ///
  /// `isCurrent` sees only the root navigator, so a sheet pushed onto a
  /// branch navigator is caught through the route that holds focus instead;
  /// a `MenuAnchor` menu is not a route at all and stays an accepted gap —
  /// the dialog opens over it and closes back to it.
  bool isQuiet(BuildContext context) {
    final inputs = _InputActivity.count;
    final idle = inputs == _mark;
    _mark = inputs;
    if (!idle) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null && ModalRoute.of(focused) is PopupRoute) return false;
    if (isTextInputFocused()) return false;
    if (context.read<Services>().unsavedChangesGuard.hasUnsaved) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    final path = GoRouter.maybeOf(
      context,
    )?.routerDelegate.currentConfiguration.uri.path;
    if (path != null &&
        (path.startsWith('/settings') ||
            _formLeaves.contains(path.split('/').last))) {
      return false;
    }
    return true;
  }
}

/// A count of the user's presses — pointer downs, scroll-wheel ticks and
/// key downs — so a check can tell whether they are mid-gesture. Counted,
/// not timed: a test's fake clock can't move a wall-clock idle timer.
abstract final class _InputActivity {
  static bool _tracking = false;
  static int count = 0;

  static void ensureTracking() {
    if (_tracking) return;
    _tracking = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerSignalEvent) count++;
  }

  /// Listens only — never handles, so every key still reaches the keyboard
  /// layer (docs/keyboard.md).
  static bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) count++;
    return false;
  }
}
