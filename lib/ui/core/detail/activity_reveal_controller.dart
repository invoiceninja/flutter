import 'package:flutter/foundation.dart';

/// A one-shot "reveal the newest activity of this type" request
/// (invoiceninja/flutter#154), pushed by a detail header's status pill and
/// consumed by that screen's Activity tab.
///
/// Two properties are load-bearing and neither is obvious:
///
///  * **[seq] increments on every call**, so tapping the same pill twice
///    re-fires. A plain `ValueNotifier<int>` would go silent on the second tap
///    because the type id has not changed — the same trap
///    `TabSelectionController.select` exists to fix.
///  * **The request persists** rather than being a pure event. On the first tap
///    the Activity tab is not mounted yet (the strip lands on Overview, and the
///    body is built the frame *after* `select`), so there is no listener to
///    hear a notification. The consumer reads [request] in `initState` as well
///    as listening.
///
/// It is deliberately **not** state on `EntityActivityViewModel`. That class
/// documents at length why it must not notify from a build — `kick()` runs
/// inside the host's `build`, so `_adopt` takes `notify: false` on both paths —
/// and it is shared by three surfaces on eleven hosts, so a reveal notify would
/// repaint the Comments card and the comments-only tab for nothing.
class ActivityRevealRequest {
  const ActivityRevealRequest({
    required this.activityTypeId,
    required this.seq,
  });

  final int activityTypeId;

  /// Monotonic per controller. A consumer records the last one it acted on, so
  /// a repeat request for the same type is a new reveal rather than a no-op.
  final int seq;
}

class ActivityRevealController extends ChangeNotifier {
  ActivityRevealRequest? _request;
  int _seq = 0;

  /// The outstanding request, or null if none has been made.
  ActivityRevealRequest? get request => _request;

  void reveal(int activityTypeId) {
    _request = ActivityRevealRequest(
      activityTypeId: activityTypeId,
      seq: ++_seq,
    );
    notifyListeners();
  }
}
