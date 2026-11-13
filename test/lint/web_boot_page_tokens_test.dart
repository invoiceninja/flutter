import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The self-hosted tarball holds no Blade: a Blade view from another
/// repository's release would be compiled into PHP on every server, and no
/// allow-list of Blade syntax held up in review. So the boot page reaches the
/// backend as plain HTML whose `__IN_*__` tokens the backend fills, each with
/// an escaped value (`Ninja::flutterWebPage`), and the landing page as plain
/// HTML it serves as a file (docs/web-deploy.md § Going live).
///
/// The backend fills exactly the tokens in `render_boot_page.py`'s `TOKENS`
/// and blanks any other. A new token therefore needs the backend first, in its
/// own PR and release, or self-hosted servers render it empty.
void main() {
  const backendTokens = {
    'HOSTED',
    'SIGNUP',
    'RC',
    'WHITE_LABEL',
    'API_URL',
    'GOOGLE_CLIENT_ID',
    'MICROSOFT_CLIENT_ID',
    'APPLE_CLIENT_ID',
    'BASE_HREF',
    'TITLE',
  };

  test('the boot page uses only the tokens the backend fills', () {
    final page = File('tools/web_deploy/boot_page.html').readAsStringSync();
    final used = {
      for (final m in RegExp(r'__IN_([A-Z_]+)__').allMatches(page)) m[1]!,
    };
    expect(used.difference(backendTokens), isEmpty);
  });

  test('the renderer and this test name the same tokens', () {
    final script = File(
      'tools/web_deploy/render_boot_page.py',
    ).readAsStringSync();
    final block = RegExp(r'TOKENS = \(([^)]*)\)').firstMatch(script)![1]!;
    final listed = {
      for (final m in RegExp(r'"([A-Z_]+)"').allMatches(block)) m[1]!,
    };
    expect(listed, backendTokens);
  });

  test('every token sits where an escaped value is safe', () {
    // The backend escapes with htmlspecialchars (ENT_QUOTES): enough inside a
    // quoted attribute or <title>, not inside a <script>, where a backslash
    // or a newline would break out.
    final page = File('tools/web_deploy/boot_page.html').readAsStringSync();
    final bad = <String>[];
    for (final line in page.split('\n')) {
      final rest = line.replaceAll(
        RegExp(r'="__IN_[A-Z_]+__"|<title>__IN_[A-Z_]+__</title>'),
        '',
      );
      if (RegExp(r'__IN_[A-Z_]+__').hasMatch(rest)) bad.add(line.trim());
    }
    expect(bad, isEmpty);
  });

  test('nothing on either page is template syntax a server would run', () {
    for (final path in [
      'tools/web_deploy/boot_page.html',
      'tools/web_deploy/landing/landing.html',
    ]) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('<?')), reason: path);
    }
    final boot = File('tools/web_deploy/boot_page.html').readAsStringSync();
    expect(boot, isNot(contains('{{')));
    expect(RegExp(r'@(if|endif|php|verbatim)\b').hasMatch(boot), isFalse);
  });
}
