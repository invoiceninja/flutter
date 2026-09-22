import 'package:flutter/foundation.dart';

/// Native half of the [boot_log] seam. `debugPrint` works fine off web, and it
/// keeps the throttling that a raw `print` would lose.
void bootLog(String message) => debugPrint(message);
