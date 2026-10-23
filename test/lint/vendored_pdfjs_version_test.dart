import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build serves pdf.js from `web/pdfjs/` (`window.dartPdfJsBaseUrl`
/// in `web/index.html`) instead of letting `printing` fetch it from unpkg. The
/// `printing` web plugin is written against one pdf.js version — `printing`
/// 5.15 moved from pdf.js 3 to 6, an API break — so a `printing` bump that
/// moves its pin without a re-vendor would mix the two and break the web PDF
/// preview with nothing failing at build time. Re-vendor
/// `build/pdf.min.mjs`, `build/pdf.worker.min.mjs` and `LICENSE` from
/// `pdfjs-dist@<version>` and update `web/pdfjs/VERSION` (docs/setup.md § Web
/// setup notes).
void main() {
  test("web/pdfjs/ is the pdf.js version printing's web plugin pins", () {
    final config =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    final printing = (config['packages'] as List)
        .cast<Map<String, dynamic>>()
        .singleWhere((p) => p['name'] == 'printing');
    // `rootUri` has no trailing slash, and may be relative to `.dart_tool/`.
    final root = Directory(
      '.dart_tool',
    ).absolute.uri.resolve('${printing['rootUri']}/');
    final source = File.fromUri(
      root.resolve('lib/printing_web.dart'),
    ).readAsStringSync();
    final pinned = RegExp(
      r"_pdfJsVersion\s*=\s*'([^']+)'",
    ).firstMatch(source)?.group(1);
    expect(pinned, isNotNull, reason: 'printing_web.dart no longer pins it');

    expect(File('web/pdfjs/VERSION').readAsStringSync().trim(), pinned);
    for (final name in ['pdf.min.mjs', 'pdf.worker.min.mjs', 'LICENSE']) {
      expect(File('web/pdfjs/$name').existsSync(), isTrue, reason: name);
    }
  });

  test('index.html points printing at the vendored copy', () {
    expect(
      File('web/index.html').readAsStringSync(),
      contains("window.dartPdfJsBaseUrl = new URL('pdfjs/', document.baseURI)"),
    );
  });
}
