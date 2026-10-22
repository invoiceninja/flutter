import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/script_fonts.dart';
import 'package:admin/l10n/supported_locales.dart';

/// The scripts Inter Tight lacks render from the bundled Noto fallbacks
/// (`kScriptFallbackFonts`), not from whatever the platform or — on web —
/// fonts.gstatic.com supplies.
///
/// Under `flutter test` a glyph no loaded font has is drawn as Inter Tight's
/// placeholder box, a fixed width per character. The test engine also falls
/// back to any loaded font that has the glyph, so the proof is a before /
/// after: measured with Inter Tight alone, every sample is a row of equal
/// boxes; once the bundled files load, each one is shaped by a real font and
/// its width changes.
void main() {
  Future<void> load(String family) async {
    final file = File('assets/fonts/${family.replaceAll(' ', '')}.ttf');
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    await loader.load();
  }

  setUpAll(() => load(kSansFontFamily));

  double widthOf(String text) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: kSansFontFamily,
          fontFamilyFallback: kScriptFallbackFonts,
          fontSize: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  const samples = {
    'Arabic': 'فاتورة',
    'Persian': 'صورتحساب',
    'Hebrew': 'חשבונית',
    'Thai': 'ใบแจ้งหนี้',
    'Lao': 'ໃບເກັບເງິນ',
    'Khmer': 'វិក្កយបត្រ',
  };

  test('the bundled fonts cover every script Inter Tight lacks', () async {
    // One placeholder box, measured on a code point no bundled font has.
    final box = widthOf('\u{10FFFD}');
    for (final MapEntry(key: script, value: text) in samples.entries) {
      expect(
        widthOf(text),
        closeTo(text.runes.length * box, 0.01),
        reason: '$script should be placeholder boxes with Inter Tight alone',
      );
    }
    for (final family in kScriptFallbackFonts) {
      await load(family);
    }
    for (final MapEntry(key: script, value: text) in samples.entries) {
      expect(
        widthOf(text),
        isNot(closeTo(text.runes.length * box, 0.01)),
        reason: '$script still renders as placeholder boxes',
      );
    }
  });

  test('every fallback family is a bundled asset ScriptFonts can load', () {
    expect(
      kScriptFallbackFontAssets.keys.toSet(),
      kScriptFallbackFonts.toSet(),
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final asset in kScriptFallbackFontAssets.values) {
      expect(pubspec, contains('- $asset'), reason: asset);
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
    // Under `fonts:` the web engine would fetch all of them before the first
    // frame, for every user.
    for (final family in kScriptFallbackFonts) {
      expect(pubspec, isNot(contains('- family: $family')), reason: family);
    }
  });

  test('on web each shipped language loads the script font it needs', () {
    for (final locale in kSupportedLocales) {
      final needs = scriptFontsForLanguage(locale.languageCode);
      for (final family in needs) {
        expect(kScriptFallbackFontAssets, contains(family));
      }
    }
    expect(scriptFontsForLanguage('fa'), ['Noto Sans Arabic']);
    expect(scriptFontsForLanguage('he'), ['Noto Sans Hebrew']);
    expect(scriptFontsForLanguage('en'), isEmpty);
  });
}
