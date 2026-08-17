/// Driver for `integration_test/ux_review_test.dart`.
///
/// Same job as `screenshots_driver.dart` — supply an `onScreenshot` handler so
/// `binding.takeScreenshot(name)` reaches disk — but writes into a separate,
/// env-configurable directory so a UX-review sweep never clobbers the curated
/// marketing shots in `samples/screenshots/`.
///
/// Invoked by `tools/capture_ux_review.sh`.
library;

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() {
  final outDir = Platform.environment['UX_OUT_DIR'] ?? 'build/ux-review';
  return integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          final file = File('$outDir/$name.png');
          await file.create(recursive: true);
          await file.writeAsBytes(bytes);
          return true;
        },
  );
}
