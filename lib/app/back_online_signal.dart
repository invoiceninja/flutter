import 'package:flutter/foundation.dart';

/// Fires each time the device comes back online.
///
/// For a screen that asked the server something while offline and would
/// otherwise wait for the user to refresh. One shared notifier rather than a
/// `ConnectivityWatcher.onOnline` subscription per screen: that stream probes
/// the platform on every listen, and a record screen is opened far too often
/// to pay for one each.
class BackOnlineSignal extends ChangeNotifier {
  void fire() => notifyListeners();
}
