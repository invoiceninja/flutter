import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build's Google, Microsoft and Apple sign-in each run in a window
/// the page opens and then watches (docs/web-deploy.md § Web sign-in). A
/// `Cross-Origin-Opener-Policy: same-origin` on the page severs it from that
/// window: MSAL can no longer read where it landed, and Google's and Apple's
/// scripts never hear back, so every sign-in spins until the user gives up.
/// It is the header skwasm's multi-threaded renderer would ask for (with
/// COEP, for cross-origin isolation), so it is the one a performance change is
/// likely to add. `same-origin-allow-popups` keeps the windows working.
void main() {
  test('no page the web build ships isolates itself from its pop-ups', () {
    final bad = <String>[];
    for (final path in [
      'tools/web_deploy/pages/_headers',
      'tools/web_deploy/boot_page.html',
      'web/index.html',
    ]) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('#')) continue;
        final match = RegExp(
          r'cross-origin-opener-policy\s*[:=]\s*"?\s*([a-z-]+)',
          caseSensitive: false,
        ).firstMatch(line);
        if (match == null) continue;
        final value = match.group(1)!.toLowerCase();
        if (value != 'unsafe-none' && value != 'same-origin-allow-popups') {
          bad.add('$path:${i + 1}: $line');
        }
      }
    }
    expect(bad, isEmpty);
  });
}
