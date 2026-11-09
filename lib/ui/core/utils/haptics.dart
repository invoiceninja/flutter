import 'package:flutter/services.dart';

import 'package:admin/app/env.dart';

/// The app's haptic vocabulary, fired only on a native phone or tablet
/// (iOS / Android): desktop and web have no motor, and a call there is at best
/// a no-op and at worst a platform-channel error in a test.
///
/// Three weights, each with one meaning (docs/first-run-welcome.md):
/// [selection] when the user moves between choices, [light] when something
/// they did lands, [success] when a flow they started is finished.
class InHaptics {
  InHaptics._();

  static bool get _enabled => Env.isMobile;

  static Future<void> selection() async {
    if (_enabled) await HapticFeedback.selectionClick();
  }

  static Future<void> light() async {
    if (_enabled) await HapticFeedback.lightImpact();
  }

  static Future<void> success() async {
    if (_enabled) await HapticFeedback.successNotification();
  }
}
