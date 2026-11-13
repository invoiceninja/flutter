import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Microsoft sign-in on web (docs/web-deploy.md § Web sign-in) runs
/// `@azure/msal-browser` from `web/msal/`, vendored like pdf.js: the web build
/// is on the FOSS graph, so no pub package or npm install brings it in. Three
/// places name the version and have to agree, or the boot page's cache-busting
/// query outlives a re-vendor: `web/msal/VERSION`, the banner at the top of
/// the minified file, and the boot page's `?v=`.
///
/// Stay on the 4.x line until `web_oauth_web.dart` is rewritten for 5.x: from
/// 5.0 the popup no longer reads the redirect from the window it opened, and
/// the redirect page has to run MSAL's own bridge script.
///
/// To re-vendor: `lib/msal-browser.min.js` and `LICENSE` from
/// `@azure/msal-browser@<version>` (jsDelivr or unpkg, compare the two
/// checksums), then update `VERSION` and the boot page's `?v=`.
void main() {
  final version = File('web/msal/VERSION').readAsStringSync().trim();

  test('web/msal/ holds one 4.x MSAL with its licence', () {
    expect(version, matches(RegExp(r'^4\.\d+\.\d+$')));
    expect(File('web/msal/LICENSE').readAsStringSync(), contains('MIT'));
    final banner = File('web/msal/msal-browser.min.js').readAsLinesSync().first;
    expect(banner, contains('@azure/msal-browser v$version '));
  });

  test('the boot page loads the vendored copy at that version', () {
    expect(
      File('tools/web_deploy/index.blade.php').readAsStringSync(),
      contains("'msal/msal-browser.min.js?v=$version'"),
    );
  });
}
