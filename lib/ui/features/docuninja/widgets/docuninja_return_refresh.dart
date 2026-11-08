import 'package:flutter/widgets.dart';

/// Re-reads DocuNinja when the user comes back to the app after being away
/// for [minimumAway] or more: fields placed and documents sent in the
/// browser (the builder opens there) then show up.
///
/// "Away" starts the first time the app stops being active and ends on
/// resume, so the way back (hidden, then inactive) doesn't restart it; a
/// desktop window that only lost focus for a moment does not re-read.
AppLifecycleListener dnRefreshOnReturn(
  VoidCallback refresh, {
  Duration minimumAway = const Duration(seconds: 5),
  DateTime Function() now = DateTime.now,
}) {
  DateTime? awaySince;
  void leave() => awaySince ??= now();
  return AppLifecycleListener(
    onInactive: leave,
    onHide: leave,
    onResume: () {
      final since = awaySince;
      awaySince = null;
      if (since != null && now().difference(since) >= minimumAway) refresh();
    },
  );
}
