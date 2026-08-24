import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: nothing in `lib/` gates a launch on `canLaunchUrl`.
///
/// It answers "can I *see* an app that handles this?",
/// which on Android 11+ and recent iOS is a package-visibility question — the
/// plugin's own docs say it "will always return false unless the application
/// has been configured to allow querying". `launchUrl` is not restricted the
/// same way: on Android it goes straight to `startActivity` and reports false
/// only on `ActivityNotFoundException`. Gating on the query therefore refused
/// launches that would have worked, which is exactly how Payment Links' View
/// button came to report "Couldn't open the link" for a URL that pasted into
/// a browser fine (invoiceninja/flutter#80). Every external link in the app
/// carried the same copy-pasted gate; flutter#12 was an earlier symptom of it.
///
/// Prefer the shared helpers in `lib/ui/core/utils/external_url.dart`, which
/// own the launch-mode fallback, the `isSafeWebUrl` check, and the failure
/// toast. A bare `launchUrl` is not flagged — it is merely unguarded, not
/// broken — but there is no reason to write a new one.
void main() {
  test('lib/ never gates a launch on canLaunchUrl', () {
    const helper = 'lib/ui/core/utils/external_url.dart';

    final canLaunch = <String>[];
    var scanned = 0;

    for (final file in _dartFiles()) {
      // The helper is the one place allowed to touch the plugin, and it
      // documents the `canLaunchUrl` trap in prose.
      if (file.path.endsWith('external_url.dart')) continue;
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = line.trimLeft();
        // Prose about the trap is the point of documenting it.
        if (code.startsWith('//') || code.startsWith('*')) continue;
        scanned++;
        if (line.contains('canLaunchUrl(')) {
          canLaunch.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(
      scanned,
      greaterThan(10000),
      reason:
          'Only $scanned lines scanned — the walk is probably broken, so '
          'an empty offender list means nothing.',
    );

    expect(
      canLaunch,
      isEmpty,
      reason:
          'canLaunchUrl refuses launches that would have worked. Call '
          'launchExternalUri / openExternalUrl ($helper) instead. Found at:\n'
          '  ${canLaunch.join('\n  ')}',
    );
  });
}

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));
