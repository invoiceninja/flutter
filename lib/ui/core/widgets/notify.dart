import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

// `NotifyAction` lives on the controller (so `ToastData` can hold one without
// an import cycle) but is re-exported here: every call site `import`s this
// file and constructs `NotifyAction`, so the surface is unchanged.
// `ToastController` is re-exported too so callers of [Notify.capture] can name
// the captured handle without a second import.
export 'package:admin/ui/core/widgets/toast_controller.dart'
    show NotifyAction, ToastController;

/// App-wide toast / notification helper.
///
/// Use [Notify.success], [Notify.error], [Notify.info], [Notify.warning] in
/// place of touching `ScaffoldMessenger` directly. Each variant renders a card
/// on `tokens.surface` with a colored left stripe and matching leading icon,
/// from the v2 status tokens so the toast reads as part of the same family as
/// `StatusPill`.
///
/// Rendering is handled by the global [ToastHost] (mounted in `main.dart`),
/// which reads the [ToastController] off `Services`. On wide windows toasts
/// stack in the top-right corner (closeable, hover-to-pause); on narrow
/// windows a single toast floats at the bottom (swipe to dismiss).
class Notify {
  Notify._();

  /// Quick green confirmation — "Saved", "Archived", etc.
  static void success(
    BuildContext context,
    String message, {
    String? detail,
    NotifyAction? action,
    ScaffoldMessengerState? messenger,
  }) => _show(
    context,
    variant: NotifyVariant.success,
    message: message,
    detail: detail,
    action: action,
  );

  /// Red error notification. Pass either [detail] or [error]; if both are
  /// passed [detail] wins. [error] is run through a minimal formatter that
  /// strips common Dart exception prefixes so users don't see
  /// `Exception: ...` noise.
  ///
  /// Pass [retryOp] for a *transient* failure (network / 5xx) to offer a
  /// "Retry" button that re-runs the failed operation. Never pass it for
  /// validation / conflict / auth errors — see `isTransientError`.
  static void error(
    BuildContext context,
    String message, {
    String? detail,
    Object? error,
    NotifyAction? action,
    Future<void> Function()? retryOp,
    ScaffoldMessengerState? messenger,
  }) {
    final resolved = detail ?? (error == null ? null : _formatError(error));
    _show(
      context,
      variant: NotifyVariant.error,
      message: _orGeneric(context, message, resolved),
      detail: resolved,
      action:
          action ??
          (retryOp == null
              ? null
              : NotifyAction(context.tr('retry'), () => unawaited(retryOp()))),
    );
  }

  /// Amber warning — validation failures, soft limits.
  static void warning(
    BuildContext context,
    String message, {
    String? detail,
    NotifyAction? action,
    ScaffoldMessengerState? messenger,
  }) => _show(
    context,
    variant: NotifyVariant.warning,
    message: _orGeneric(context, message, detail),
    detail: detail,
    action: action,
  );

  /// Blue informational — "Copied", "Coming soon", neutral notices.
  static void info(
    BuildContext context,
    String message, {
    String? detail,
    NotifyAction? action,
    ScaffoldMessengerState? messenger,
  }) => _show(
    context,
    variant: NotifyVariant.info,
    message: message,
    detail: detail,
    action: action,
  );

  /// Dismiss all currently-visible toasts — e.g. clear a "Processing…" notice
  /// right before a blocking OS sheet (print / share) takes over.
  static void clear(BuildContext context) => _toastsOf(context)?.clearAll();

  /// Capture the toast queue *before* an `await` so a toast can be shown after
  /// the gap without a stale `BuildContext` — the global-host replacement for
  /// the old `ScaffoldMessenger.maybeOf(context)` capture pattern:
  /// ```dart
  /// final toasts = Notify.capture(context);   // before the await
  /// await doWork();
  /// toasts?.success(context.tr('done'));       // no context-after-await
  /// ```
  static ToastController? capture(BuildContext context) => _toastsOf(context);

  // The `messenger:` parameter on the public methods is accepted for backward
  // compatibility but no longer used: the toast host is global and outlives
  // any context, so the old "capture a ScaffoldMessenger before the await so
  // the toast survives an unmounted context" dance is unnecessary.
  static void _show(
    BuildContext context, {
    required NotifyVariant variant,
    required String message,
    String? detail,
    NotifyAction? action,
  }) {
    final toasts = _toastsOf(context);
    if (toasts == null) return; // no Services ancestor — silent no-op
    toasts.show(
      variant: variant,
      message: message,
      detail: detail,
      action: action,
    );
  }

  /// Guarantee a *failure* still says something.
  ///
  /// [ToastController.show] drops a toast with nothing renderable (that blank,
  /// stretched card is invoiceninja/flutter#30), which is right for a
  /// confirmation but wrong for an error: several call sites hand us a raw
  /// server string that can legitimately be `""` (`ApiException.message` is
  /// non-nullable, so `{"message":""}` arrives as an empty title, and `??`
  /// fallbacks don't fire on it).
  static String _orGeneric(
    BuildContext context,
    String message,
    String? detail,
  ) {
    if (message.trim().isNotEmpty) return message;
    // Blank title. With a detail present the controller promotes it into the
    // title slot, so leaving the title blank is correct — substituting here
    // would bury the real reason under a generic one. With nothing at all the
    // controller would drop the toast, so say something.
    final hasDetail = detail != null && detail.trim().isNotEmpty;
    return hasDetail ? message : context.tr('an_error_occurred');
  }

  static ToastController? _toastsOf(BuildContext context) {
    // A directly-provided ToastController wins — lets lightweight harnesses
    // (and tests) supply one without a full Services. Otherwise use the
    // controller on Services, which the app and shell tests provide.
    try {
      return Provider.of<ToastController>(context, listen: false);
    } catch (_) {
      // No ToastController provider in scope — fall back to Services.
    }
    try {
      return context.read<Services>().toasts;
    } catch (_) {
      return null;
    }
  }
}

/// Strip common Dart exception type prefixes so detail lines read cleanly.
/// Kept intentionally dumb — exhaustive type matching is out of scope; the
/// goal is just to drop `Exception: `, `_Exception: `, and the type-name
/// prefixes that Flutter's builtin exceptions print, then trim.
///
/// Also the public seam for error surfaces that render a message string
/// directly instead of going through [Notify.error]'s `error:` parameter
/// (list-load errors, the PDF pane) — those must never show a raw
/// `FooException: …` toString to the user.
String formatNotifyError(Object error) => _formatError(error);

String _formatError(Object error) {
  var text = error.toString().trim();
  // Most Dart exceptions print as `FooException: message`. Strip the type
  // name (optionally prefixed with `_`) plus its `: ` separator so users
  // don't see the raw class name in the detail line.
  final match = RegExp(r'^_?[A-Za-z0-9_]*Exception:\s+').firstMatch(text);
  if (match != null) {
    text = text.substring(match.end).trim();
  }
  return text;
}
