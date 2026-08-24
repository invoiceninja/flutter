import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the `<queries>` intents that make `url_launcher` work on Android 11+.
///
/// A regression here is silent in every way that matters: the build succeeds,
/// `flutter analyze` is clean, every test still passes, and the app only breaks
/// on a real device running API 30 or newer. Package visibility hides
/// undeclared apps from `PackageManager`, so any `canLaunchUrl` on a web URL
/// answers false — which is how issue #12 broke every external link in the
/// Android build at once: the User Guide and Support Forum links in the
/// sidebar footer, client and vendor portals, payment links, the upgrade
/// flow, gateway and QuickBooks OAuth, and bank reconnect.
///
/// `lib/` no longer *gates* on that query — `canLaunchUrl` refused launches
/// that would have worked, which is invoiceninja/flutter#80, and
/// `no_can_launch_url_test` now forbids it — so these intents are a belt to
/// that fix's braces rather than the load-bearing part. They stay because the
/// declaration is free, plugins and any future `canLaunch` still read it, and
/// removing it is a silent-on-CI regression by construction.
///
/// Only `http` / `https` are required — `isSafeWebUrl` (lib/utils/url_safety.dart)
/// rejects every other scheme before it reaches `launchUrl`, so there is
/// deliberately no `mailto:` / `tel:` intent to assert here. If a future change
/// starts launching one of those, it needs both a new `<intent>` and a new case
/// below.
void main() {
  test('AndroidManifest declares browser intents for url_launcher', () {
    final file = File('android/app/src/main/AndroidManifest.xml');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'android/app/src/main/AndroidManifest.xml should exist',
    );

    // Normalise whitespace so the assertion survives reformatting/reindenting
    // of the XML, and self-closing vs. spaced tags.
    final xml = file.readAsStringSync().replaceAll(RegExp(r'\s+'), ' ');

    expect(
      xml.contains('<queries>'),
      isTrue,
      reason: 'the manifest must declare a <queries> element',
    );

    // Matches `<intent>`, never `<intent-filter>` — so the app's own
    // `invoiceninja://` deep-link filter, which also pairs ACTION_VIEW with a
    // scheme, can't satisfy these assertions.
    final intents = RegExp(
      r'<intent>.*?</intent>',
    ).allMatches(xml).map((m) => m.group(0)!).toList();

    for (final scheme in const ['https', 'http']) {
      // The action and the scheme must live in the *same* <intent>: an
      // ACTION_VIEW intent with no matching <data> scheme does not grant
      // visibility of a browser for that scheme. The closing quote in the
      // scheme match matters — without it `https` would satisfy `http`.
      final declared = intents.any(
        (i) =>
            i.contains('android.intent.action.VIEW') &&
            i.contains('android:scheme="$scheme"'),
      );
      expect(
        declared,
        isTrue,
        reason:
            'AndroidManifest.xml is missing a <queries> <intent> pairing '
            'android.intent.action.VIEW with android:scheme="$scheme". '
            'Without it canLaunchUrl returns false on Android 11+ and every '
            'external link in the app fails with "failed to open URL". '
            'See issue #12.',
      );
    }
  });
}
