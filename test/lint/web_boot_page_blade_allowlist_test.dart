import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The server's release (`react_release.yml` in invoiceninja/invoiceninja)
/// takes the self-hosted tarball only if its two Blade views use nothing but
/// a fixed allow-list: Blade compiles `{{ }}` and `@if (...)` into PHP that
/// runs on every server, so it checks the views before unpacking them
/// (docs/web-deploy.md § Going live). A boot page that steps outside that
/// list is not an error anywhere: the release just warns and ships without the
/// new web app. This is the same check, here, so the step never meets one.
///
/// Keep the patterns identical to the workflow's. To widen them, change the
/// server's workflow first, in its own PR, and release it before a boot page
/// that needs it ships.
final _echo = RegExp(
  r"\{\{ \(?\$[a-z_]+ \?\? (false|'[^'{}()$;]*')\)?"
  r"( \? '[^'{}$;]*' : '[^'{}$;]*')? \}\}",
);
final _directive = RegExp(
  r'@(if \(\$[a-z_]+ \?\? false\)|endif|keyframes\b.*)',
);

void main() {
  test('the boot page uses only the Blade the server accepts', () {
    var boot = File('tools/web_deploy/index.blade.php').readAsStringSync();
    boot = boot.replaceAll(RegExp(r'\{\{--.*?--\}\}', dotAll: true), '');
    final bad = <String>[
      for (final m in RegExp(r'\{\{.*?\}\}').allMatches(boot))
        if (_echo.matchAsPrefix(m[0]!)?.end != m[0]!.length) m[0]!,
      for (final m in RegExp(r'(?<![\w-])@[A-Za-z]+[^\n]*').allMatches(boot))
        if (_directive.matchAsPrefix(m[0]!.trim())?.end != m[0]!.trim().length)
          m[0]!.trim(),
      if (RegExp(r'<\?|\{!!|\{\{\{').hasMatch(boot)) 'raw PHP or {!! !!}',
    ];
    expect(bad, isEmpty);
  });

  test('the landing view is one @verbatim block', () {
    final source = File(
      'tools/web_deploy/render_landing.py',
    ).readAsStringSync();
    expect(source, contains('@verbatim'));
    expect(source, contains('@endverbatim'));
  });
}
