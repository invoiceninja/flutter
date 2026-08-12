import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _log = Logger('ToastController');

/// How many lines of [ToastData.detail] the card actually renders. Shared with
/// `toast_host.dart` so the trim in [ToastController.show] and the widget's
/// `maxLines` can't drift apart.
const int kToastDetailMaxLines = 3;

/// The four toast flavors. Promoted out of `notify.dart` so the rendering
/// host ([ToastHost]) and the public facade ([Notify]) share one enum.
enum NotifyVariant { success, error, warning, info }

extension NotifyVariantTiming on NotifyVariant {
  /// Auto-dismiss window per variant — errors linger longest so they're
  /// readable; quick confirmations clear fast.
  Duration get duration {
    switch (this) {
      case NotifyVariant.success:
      case NotifyVariant.info:
        return const Duration(seconds: 3);
      case NotifyVariant.warning:
        return const Duration(seconds: 5);
      case NotifyVariant.error:
        return const Duration(seconds: 6);
    }
  }
}

/// Action button rendered to the right of the toast text.
///
/// Defined here (not in `notify.dart`) so [ToastData] can hold one without an
/// import cycle; `notify.dart` re-exports it, so existing call sites that
/// `import '…/notify.dart'` and use `NotifyAction` keep working unchanged.
class NotifyAction {
  const NotifyAction(this.label, this.onPressed);
  final String label;
  final VoidCallback onPressed;
}

/// One live toast. Immutable; the controller swaps the instance to mutate
/// (e.g. [bump] for the dedup `×N` badge), keeping a stable [id] so the
/// rendered widget animates in place instead of from scratch.
@immutable
class ToastData {
  const ToastData({
    required this.id,
    required this.variant,
    required this.message,
    required this.duration,
    this.detail,
    this.action,
    this.count = 1,
  });

  final int id;
  final NotifyVariant variant;
  final String message;
  final String? detail;
  final NotifyAction? action;
  final Duration duration;

  /// How many identical toasts have coalesced into this one (see dedup in
  /// [ToastController.show]). Rendered as a `×N` badge when > 1.
  final int count;

  ToastData bump() => ToastData(
    id: id,
    variant: variant,
    message: message,
    duration: duration,
    detail: detail,
    action: action,
    count: count + 1,
  );
}

/// App-wide toast queue. A context-free [ChangeNotifier] held on `Services`
/// and rendered by a single global [ToastHost] mounted near the app root, so
/// it outlives any route/sheet and every `Notify.*` call lands regardless of
/// where it fired (replacing the old `ScaffoldMessenger`/`SnackBar` backend).
///
/// Behavior tuned for the offline-first app:
/// * **Stacking** — multiple distinct toasts are visible at once (desktop
///   stacks them in the corner) instead of the old replace-latest model.
/// * **Dedup** — a toast identical to the newest still-visible one bumps its
///   `×N` count and restarts its timer rather than stacking a duplicate, so a
///   sync-failure flurry doesn't flood the corner.
/// * **Cap** — at most [maxVisible]; the oldest is auto-dropped past the cap.
/// * **Pause/resume** — the host pauses a toast's auto-dismiss timer while the
///   pointer hovers it (desktop), so an error can't vanish mid-read.
class ToastController extends ChangeNotifier {
  ToastController({this.maxVisible = 4});

  /// Hard cap on simultaneously-queued toasts. The host may render fewer when
  /// the window is too short; this bounds the controller's own list.
  final int maxVisible;

  final List<ToastData> _toasts = [];
  final Map<int, Timer> _timers = {};
  int _nextId = 0;

  /// Live toasts, oldest first. The host renders newest-nearest-the-corner.
  List<ToastData> get toasts => List.unmodifiable(_toasts);

  // Convenience variants — used by callers that captured the controller
  // before an `await` (via `Notify.capture`) so they can show a toast after
  // the gap without a stale `BuildContext`.
  void success(String message, {String? detail, NotifyAction? action}) => show(
    variant: NotifyVariant.success,
    message: message,
    detail: detail,
    action: action,
  );

  void error(String message, {String? detail, NotifyAction? action}) => show(
    variant: NotifyVariant.error,
    message: message,
    detail: detail,
    action: action,
  );

  void warning(String message, {String? detail, NotifyAction? action}) => show(
    variant: NotifyVariant.warning,
    message: message,
    detail: detail,
    action: action,
  );

  void info(String message, {String? detail, NotifyAction? action}) => show(
    variant: NotifyVariant.info,
    message: message,
    detail: detail,
    action: action,
  );

  /// Enqueue a toast. Returns its id (stable across a dedup bump), or `null`
  /// when there was nothing to say and no toast was queued — see the
  /// normalization note above [_normalizeMessage].
  int? show({
    required NotifyVariant variant,
    required String message,
    String? detail,
    NotifyAction? action,
  }) {
    var text = _normalizeMessage(message);
    var sub = _normalizeDetail(detail);
    // A toast with no title still carries information when it has a detail —
    // promote it into the title rather than dropping the whole notice.
    if (text.isEmpty && sub != null) {
      text = _normalizeMessage(sub);
      sub = null;
    }
    if (text.isEmpty) {
      // Nothing renderable. Painting anyway gives the blank, vertically
      // stretched card of invoiceninja/flutter#30. Name the caller in debug so
      // the producer is identifiable from the diagnostics log.
      if (kDebugMode) {
        _log.warning(
          'Suppressed a $variant toast with no message or detail',
          null,
          StackTrace.current,
        );
      }
      return null;
    }
    // An empty label renders as a zero-width button that still eats padding.
    final act = action != null && action.label.trim().isEmpty ? null : action;

    // Dedup against the newest still-visible toast: an identical message
    // bumps its count + restarts its timer instead of stacking a duplicate.
    if (_toasts.isNotEmpty) {
      final last = _toasts.last;
      if (last.variant == variant &&
          last.message == text &&
          last.detail == sub) {
        final bumped = last.bump();
        _toasts[_toasts.length - 1] = bumped;
        _armTimer(bumped.id, bumped.duration);
        notifyListeners();
        return bumped.id;
      }
    }

    final id = _nextId++;
    final data = ToastData(
      id: id,
      variant: variant,
      message: text,
      duration: _durationFor(variant, act),
      detail: sub,
      action: act,
    );
    _toasts.add(data);
    _armTimer(id, data.duration);

    // Cap: drop the oldest beyond the limit.
    while (_toasts.length > maxVisible) {
      _removeAt(0);
    }
    notifyListeners();
    return id;
  }

  /// Remove a toast now (timer fired, close button, or swipe). Id-tolerant —
  /// a double-dismiss or a fired timer for an already-gone id is a no-op.
  void dismiss(int id) {
    final idx = _toasts.indexWhere((e) => e.id == id);
    if (idx == -1) {
      _timers.remove(id)?.cancel();
      return;
    }
    _removeAt(idx);
    notifyListeners();
  }

  /// Hover-in: freeze a toast's auto-dismiss timer so it can be read/copied.
  void pause(int id) => _timers.remove(id)?.cancel();

  /// Hover-out: re-arm the auto-dismiss timer for the toast's full duration.
  void resume(int id) {
    for (final t in _toasts) {
      if (t.id == id) {
        _armTimer(id, t.duration);
        return;
      }
    }
  }

  /// Drop everything (e.g. on logout / company switch) and cancel all timers.
  void clearAll() {
    if (_toasts.isEmpty && _timers.isEmpty) return;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _toasts.clear();
    notifyListeners();
  }

  // An actionable toast (Undo / Retry / View …) gets at least this long so the
  // user can read it and act before it auto-dismisses.
  static const Duration _kActionableMin = Duration(seconds: 6);

  Duration _durationFor(NotifyVariant variant, NotifyAction? action) {
    final base = variant.duration;
    if (action != null && base < _kActionableMin) return _kActionableMin;
    return base;
  }

  void _armTimer(int id, Duration d) {
    _timers.remove(id)?.cancel();
    _timers[id] = Timer(d, () => dismiss(id));
  }

  void _removeAt(int idx) {
    final t = _toasts.removeAt(idx);
    _timers.remove(t.id)?.cancel();
  }

  @override
  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}

final _whitespaceRun = RegExp(r'\s+');
final _lineBreak = RegExp(r'\r\n|\r|\n');

/// Collapse a toast title to a single trimmed line.
///
/// The card wraps the title across two lines by *width*, which is the intended
/// behavior; hard line breaks only ever arrive from a string that leaked in
/// from elsewhere — a raw server body (`ApiClient._raiseFromResponse` splices
/// 240 bytes of a 5xx page into the message), a joined error list, a
/// whitespace-only field error. Those paint as empty rows and stretch the card
/// (invoiceninja/flutter#30), so flatten them here rather than at each caller.
String _normalizeMessage(String value) =>
    value.replaceAll(_whitespaceRun, ' ').trim();

/// Trim a toast detail to the non-blank lines the card can actually show.
///
/// The widget renders at most [kToastDetailMaxLines]; anything past that is
/// invisible either way, and a blank line paints as an empty row that makes
/// the card taller with nothing in it. Keep the real content, drop the filler,
/// and return `null` when nothing survives so the card's own guard hides the
/// detail slot entirely.
String? _normalizeDetail(String? value) {
  if (value == null) return null;
  final lines = <String>[];
  for (final raw in value.split(_lineBreak)) {
    // `\s+` can't match a newline here — we already split on them.
    final line = raw.replaceAll(_whitespaceRun, ' ').trim();
    if (line.isEmpty) continue;
    lines.add(line);
    if (lines.length == kToastDetailMaxLines) break;
  }
  return lines.isEmpty ? null : lines.join('\n');
}
