import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Snap interfaces the Linux app relies on. A regression here is
/// silent — the build still succeeds and the bug only surfaces on a confined
/// Linux install:
///   * `password-manager-service` is **load-bearing**: flutter_secure_storage
///     holds the SQLCipher DB key, so without it the app can't open its
///     encrypted database.
///   * `network-manager` enables `connectivity_plus`'s NetworkManager probe.
///     It's optional (ConnectivityWatcher degrades to assume-online without it),
///     but dropping it silently disables real offline detection on Linux.
///
/// See docs/setup.md § Linux desktop / Snap.
void main() {
  test('snap/snapcraft.yaml declares the required plugs', () {
    final file = File('snap/snapcraft.yaml');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'snap/snapcraft.yaml should exist',
    );

    // Exact trimmed-line match: a substring check on `- network` would also
    // match `- network-manager` and give a false pass.
    final lines = file.readAsLinesSync().map((l) => l.trim()).toSet();

    const required = [
      'network',
      'home',
      'password-manager-service',
      'network-manager',
    ];
    final missing = [
      for (final plug in required)
        if (!lines.contains('- $plug')) plug,
    ];

    expect(
      missing,
      isEmpty,
      reason:
          'snap/snapcraft.yaml is missing required plug(s): '
          '${missing.join(', ')}. See docs/setup.md § Linux desktop / Snap.',
    );
  });
}
