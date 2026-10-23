import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/script_fonts.dart';
import 'package:admin/l10n/localization.dart';

/// When each bundled script font is registered (`ScriptFonts`):
///
/// - the UI language's family from the localization delegate's `load`, which
///   gates the first frame — so an Arabic UI paints its first frame in Noto
///   Sans Arabic, and on web CanvasKit never fetches its own;
/// - nothing at all for a language Inter Tight covers;
/// - natively, every other family once launch work has settled
///   ([ScriptFonts.launchSettled]) or at the latest [kDeferredScriptFontsDelay]
///   after the first frame, out of the launch window — each registration
///   re-lays out every paragraph.
///
/// Proved the way `script_fallback_fonts_test` proves coverage: under
/// `flutter test` a glyph no loaded font has is Inter Tight's placeholder box,
/// a fixed width per character. Each `flutter test` file runs in its own
/// engine, so nothing another file loaded is registered here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final file = File(
      'assets/fonts/${kSansFontFamily.replaceAll(' ', '')}.ttf',
    );
    await (FontLoader(kSansFontFamily)
          ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync()))))
        .load();
  });

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

  bool isBoxes(String text) =>
      (widthOf(text) - text.runes.length * widthOf('\u{10FFFD}')).abs() < 0.01;

  const arabic = 'فاتورة';
  const hebrew = 'חשבונית';
  const thai = 'ใบแจ้งหนี้';

  test(
    'the delegate loads the UI language\'s script font, and only that',
    () async {
      expect(isBoxes(arabic), isTrue, reason: 'nothing registered yet');

      await Localization.delegate.load(const Locale('en'));
      expect(isBoxes(arabic), isTrue);
      expect(isBoxes(hebrew), isTrue);

      await Localization.delegate.load(const Locale('ar'));
      expect(isBoxes(arabic), isFalse, reason: 'Arabic UI, Arabic font');
      expect(isBoxes(hebrew), isTrue, reason: 'Hebrew waits for the deferral');
      expect(isBoxes(thai), isTrue);

      // A language change reloads the delegate, which follows it.
      await Localization.delegate.load(const Locale('he'));
      expect(isBoxes(hebrew), isFalse);
      expect(isBoxes(thai), isTrue);
    },
  );

  test('loadForLocale costs nothing for a language Inter Tight covers', () {
    // Already complete: no asset read, no font registered, no timer.
    var done = false;
    ScriptFonts.loadForLocale(const Locale('de')).then((_) => done = true);
    return Future<void>.microtask(() => expect(done, isTrue));
  });

  testWidgets('natively the other families wait for the deferral', (
    tester,
  ) async {
    ScriptFonts.attach();
    // The app attaches before its first frame; here nothing else schedules one.
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump(kDeferredScriptFontsDelay - const Duration(seconds: 1));
    expect(isBoxes(thai), isTrue, reason: 'still inside the launch window');
    expect(ScriptFonts.requested, isNot(contains('Noto Sans Thai')));

    await tester.pump(const Duration(seconds: 1));
    expect(ScriptFonts.requested, containsAll(kScriptFallbackFonts));
    // The deferred load is in flight; ensureLoaded joins it.
    await tester.runAsync(() => ScriptFonts.ensureLoaded(kScriptFallbackFonts));
    await tester.pump();
    expect(isBoxes(thai), isFalse);
    ScriptFonts.detach();
  });

  // The families are registered by the test above, so these watch the trigger.
  testWidgets('launch settling brings the deferred load forward', (
    tester,
  ) async {
    ScriptFonts.detach();
    ScriptFonts.attach();
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(ScriptFonts.lastDeferredTrigger, isNull);

    ScriptFonts.launchSettled();
    await tester.pump(
      kScriptFontsSettleGrace - const Duration(milliseconds: 1),
    );
    expect(ScriptFonts.lastDeferredTrigger, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(ScriptFonts.lastDeferredTrigger, 'settled');
    ScriptFonts.detach();
  });

  testWidgets('a launch that settles before the first frame waits for it', (
    tester,
  ) async {
    ScriptFonts.detach();
    ScriptFonts.attach();
    ScriptFonts.launchSettled();
    expect(ScriptFonts.lastDeferredTrigger, isNull);
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump(kScriptFontsSettleGrace);
    expect(ScriptFonts.lastDeferredTrigger, 'settled');
    ScriptFonts.detach();
  });

  testWidgets('a launch that never settles loads at the ceiling', (
    tester,
  ) async {
    ScriptFonts.detach();
    ScriptFonts.attach();
    tester.binding.scheduleFrame();
    await tester.pump();
    await tester.pump(kDeferredScriptFontsDelay);
    expect(ScriptFonts.lastDeferredTrigger, 'ceiling');
    ScriptFonts.detach();
  });

  testWidgets('detach cancels a deferral that has not run', (tester) async {
    ScriptFonts.detach();
    ScriptFonts.attach();
    tester.binding.scheduleFrame();
    await tester.pump();
    ScriptFonts.detach();
    // A Timer still pending here fails the test.
  });
}
