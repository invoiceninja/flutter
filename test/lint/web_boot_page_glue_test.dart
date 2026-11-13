import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: the boot page the server will serve
/// (`tools/web_deploy/boot_page.html`, docs/web-deploy.md) carries the same
/// boot glue as `web/index.html`: the loader and its CSS, `dartPdfJsBaseUrl`,
/// and the first-frame / 30-second Reload script.
///
/// The two pages differ on purpose everywhere else (the server's page picks
/// its base, clears the old app's service worker and injects the bootstrap),
/// so each shared block sits between `<!-- glue:start <name> -->` and
/// `<!-- glue:end -->` in both files and must match byte for byte. A fix to the
/// 30-second card made in one page and not the other would otherwise ship a
/// web app whose two front doors behave differently, and nothing renders the
/// server page outside Deploy to Web.
void main() {
  final start = RegExp(r'<!-- glue:start ([a-z-]+)[^>]*-->\n');

  Map<String, String> blocks(String path) {
    final text = File(path).readAsStringSync();
    final out = <String, String>{};
    for (final m in start.allMatches(text)) {
      final end = text.indexOf('<!-- glue:end -->', m.end);
      expect(end, isNot(-1), reason: '$path: glue "${m[1]}" has no end');
      expect(out.containsKey(m[1]), isFalse, reason: '$path: "${m[1]}" twice');
      out[m[1]!] = text.substring(m.end, end);
    }
    return out;
  }

  test('the server boot page shares web/index.html\'s boot glue', () {
    final web = blocks('web/index.html');
    final server = blocks('tools/web_deploy/boot_page.html');

    expect(web.keys.toSet(), {
      'loader-style',
      'pdfjs',
      'loader',
      'first-frame',
    }, reason: 'web/index.html must mark all four shared blocks');
    expect(server.keys.toSet(), web.keys.toSet());
    for (final name in web.keys) {
      expect(
        server[name],
        web[name],
        reason:
            'glue "$name" differs between web/index.html and '
            'tools/web_deploy/boot_page.html — change both',
      );
    }
  });

  test('the first-frame glue sets the flag the boot smoke reads', () {
    expect(
      blocks('web/index.html')['first-frame'],
      contains('window.__flutterFirstFrame = true'),
      reason: 'tools/web_deploy/smoke_webdriver.sh waits on this flag',
    );
  });
}
