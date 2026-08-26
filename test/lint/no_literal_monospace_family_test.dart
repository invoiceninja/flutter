import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `fontFamily: 'monospace'` is NOT a bundled family.
///
/// `pubspec.yaml` declares `Inter Tight`, **`JetBrains Mono`**, `Roboto` and
/// `Material Design Icons`, and `theme.dart` sets `fontFamily: kSansFontFamily`
/// with no `fontFamilyFallback`. `'monospace'` is a real family alias only in
/// Android's `/system/etc/fonts.xml` (and a CSS generic on web) — on Apple and
/// Windows the engine can't match it and silently falls back to the default
/// face. So every "code" surface written that way (keycaps, System Logs, the
/// design-JSON viewers, the WYSIWYG property editors, generated-number
/// patterns) lost its monospacing on exactly the platforms this app ships to
/// as a desktop / iOS build, while looking correct on Android.
///
/// `design_tokens.dart` already warns about the same class of drift for
/// `moneyTextStyle`: "never re-inline the family, or it silently drifts back to
/// the sans face". Use [kMonoFontFamily].
void main() {
  test('no lib/ source hardcodes the unbundled "monospace" family', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart') ||
          entity.path.endsWith('.freezed.dart')) {
        continue;
      }
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'''fontFamily:\s*['"]monospace['"]''').hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use kMonoFontFamily (lib/app/design_tokens.dart) — the bundled '
          'JetBrains Mono. A literal "monospace" resolves only on Android and '
          'the web, and falls back to the proportional UI face everywhere '
          'else.\nOffenders:\n${offenders.join('\n')}',
    );
  });
}
