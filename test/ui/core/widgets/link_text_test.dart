import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// A cross-entity link must carry its affordance **at rest** on touch, because
/// the hover underline that carries it on a pointer platform can never fire
/// there (invoiceninja/flutter#128).
///
/// Assertions are deliberately about *relationships*, not literal token values.
/// `accent` is user-overridable per (company, user) and `buildInTheme`
/// re-derives `accentInk` from whatever the user picked, so a hardcoded
/// `== InTheme.light.accentInk` would pin a value that legitimately moves —
/// the same brittleness `sidebar_search_box_test.dart` records getting burned
/// by. What must hold is: on touch the link is underlined at rest and its
/// colour is not the caller's; on a pointer platform neither is true.
const _base = TextStyle(color: Color(0xFF857F73), fontSize: 13);

/// Pumps the link under [platform] and returns the style it rendered with,
/// resetting the platform override **before returning**. `flutter_test` checks
/// `debugAssertAllFoundationVarsUnset` at the end of the test *body*, before
/// any `tearDown` runs, so a reset in `tearDown` fails every test that sets it.
Future<TextStyle> _pumpLink(
  WidgetTester tester, {
  required InTheme tokens,
  required TargetPlatform platform,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(tokens),
      home: Scaffold(
        body: Builder(
          builder: (context) => linkOrText(
            context: context,
            link: true,
            label: 'Acme Corp',
            onTap: () {},
            style: _base,
          ),
        ),
      ),
    ),
  );
  // `MaterialApp` wraps the body in an `AnimatedTheme`, so a second pump into
  // the same element tree reads a theme still lerping from the previous one —
  // which silently returned the DARK `accentInk` for a light-theme pump.
  await tester.pumpAndSettle();
  final style = tester.widget<Text>(find.text('Acme Corp')).style!;
  debugDefaultTargetPlatformOverride = null;
  return style;
}

void main() {
  group('linkNeedsAtRestCue', () {
    test('true on touch platforms, false on pointer platforms', () {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = p;
        expect(linkNeedsAtRestCue, isTrue, reason: '$p');
      }
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = p;
        expect(linkNeedsAtRestCue, isFalse, reason: '$p');
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('touch: underlined at rest, recoloured off the caller style', (
    tester,
  ) async {
    final style = await _pumpLink(
      tester,
      tokens: InTheme.light,
      platform: TargetPlatform.android,
    );

    expect(
      style.decoration,
      TextDecoration.underline,
      reason:
          'the hover underline can never fire on touch, so it must be on '
          'at rest — and it is the one cue immune to the accent override',
    );
    expect(
      style.color,
      isNot(_base.color),
      reason: 'the at-rest colour must not be the muted caller style',
    );
  });

  testWidgets('pointer: no underline at rest, caller colour untouched', (
    tester,
  ) async {
    final style = await _pumpLink(
      tester,
      tokens: InTheme.light,
      platform: TargetPlatform.macOS,
    );

    expect(style.decoration, TextDecoration.none);
    expect(
      style.color,
      _base.color,
      reason: 'desktop rendering must be byte-identical to before the fix',
    );
  });

  testWidgets('dark theme gets the same at-rest cue on touch', (tester) async {
    // Dark is where the `accent`/`accentInk` distinction bites: `accent` is the
    // same mid blue in both brightnesses and lands ~3.2:1 on the dark
    // `accentSoft` a selected row is filled with. A light-only test passes
    // either way, so it would prove nothing about that choice.
    final dark = await _pumpLink(
      tester,
      tokens: InTheme.dark,
      platform: TargetPlatform.android,
    );
    expect(dark.decoration, TextDecoration.underline);

    final light = await _pumpLink(
      tester,
      tokens: InTheme.light,
      platform: TargetPlatform.android,
    );
    expect(
      dark.color,
      isNot(light.color),
      reason:
          'accentInk shifts per brightness; accent would not, which is why '
          'it is the wrong token here',
    );
  });

  testWidgets('a link announces itself as a link, and can be activated', (
    tester,
  ) async {
    // `excludeSemantics: true` drops the child GestureDetector's node along
    // with its `SemanticsAction.tap`, so the wrapper has to re-declare `onTap`
    // or the node is a link nothing can invoke.
    final handle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => linkOrText(
              context: context,
              link: true,
              label: 'Acme Corp',
              onTap: () => tapped = true,
              style: _base,
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Acme Corp')),
      matchesSemantics(label: 'Acme Corp', isLink: true, hasTapAction: true),
    );

    // And the declared action actually runs the callback.
    await tester.tap(find.text('Acme Corp'));
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('plain text when link is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => linkOrText(
              context: context,
              link: false,
              label: 'Acme Corp',
              onTap: () {},
              style: _base,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(LinkText), findsNothing);
    expect(tester.widget<Text>(find.text('Acme Corp')).style, _base);
  });
}
