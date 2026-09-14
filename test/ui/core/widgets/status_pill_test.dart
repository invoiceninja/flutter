import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';

/// The pill never renders alone in the app — it sits beside the 22 px record
/// number in a detail header's `Row`, and what must not move is **that row's**
/// height. See [_sizes].
Future<void> _pump(
  WidgetTester tester,
  Widget pill, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: Row(
              key: const Key('header-row'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('#0067', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                pill,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

({Size row, Size pill}) _sizes(WidgetTester tester) => (
  row: tester.getSize(find.byKey(const Key('header-row'))),
  pill: tester.getSize(find.byType(StatusPill)),
);

void main() {
  const label = 'Viewed';
  const fg = Color(0xFFB07A1F);

  group('the plain pill is untouched', () {
    // 30-odd call sites, most of them list rows and table cells. The link
    // branch is a second tree beside the original, never a change to it.
    testWidgets('builds no Material and no InkWell without onTap', (
      tester,
    ) async {
      await _pump(tester, const StatusPill(label: label, fgColor: fg));
      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(find.text(label), findsOneWidget);
    });

    testWidgets('keeps its Tooltip a descendant of StatusPill', (tester) async {
      // `billing_doc_sends_tab_test` finds it exactly this way.
      await _pump(
        tester,
        const StatusPill(label: label, fgColor: fg, tooltip: 'Delivered'),
      );
      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.byType(Tooltip),
        ),
        findsOneWidget,
      );
    });
  });

  group('the link branch', () {
    testWidgets('taps', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        StatusPill(label: label, fgColor: fg, onTap: () => taps++),
      );
      await tester.tap(find.byType(StatusPill));
      expect(taps, 1);
    });

    testWidgets('paints its ink inside the tinted box', (tester) async {
      // A `Material` around the decorated container registers its ink on a
      // layer BELOW the opaque tint, so hover / pressed / focus are invisible.
      // The InkWell must therefore be a descendant of the Container that draws
      // the background.
      await _pump(tester, StatusPill(label: label, fgColor: fg, onTap: () {}));
      final decorated = find.descendant(
        of: find.byType(StatusPill),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration,
        ),
      );
      expect(
        find.descendant(of: decorated, matching: find.byType(InkWell)),
        findsWidgets,
      );
    });

    testWidgets('announces as an activatable button', (tester) async {
      // A role a screen reader can announce but not invoke is the bug
      // `semantics_excludes_need_ontap_test` exists for.
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        StatusPill(
          label: label,
          fgColor: fg,
          onTap: () {},
          semanticsLabel: 'Jane Doe · Viewed: 11 Sep 2026',
          semanticsHint: 'Activity',
        ),
      );
      expect(
        tester.getSemantics(find.byType(StatusPill)),
        matchesSemantics(
          label: 'Jane Doe · Viewed: 11 Sep 2026',
          hint: 'Activity',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('underlines the label at rest on touch', (tester) async {
      // `flutter test` reports android, i.e. `Env.isTouchPrimary` — the branch
      // that matters, because a hover cue can never fire on a finger and the
      // pill would otherwise say nothing about being tappable at all.
      await _pump(tester, StatusPill(label: label, fgColor: fg, onTap: () {}));
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.decoration, TextDecoration.underline);
    });

    testWidgets('the plain pill never underlines', (tester) async {
      await _pump(tester, const StatusPill(label: label, fgColor: fg));
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.decoration, isNot(TextDecoration.underline));
    });

    // The touch-target trade, pinned the way `party_call_button_test`'s layout
    // group pins its twin. The link branch is allowed to be taller than the
    // plain pill — it takes the row's content box, which is free — but it must
    // not drive the header row's cross axis, and it must not steal width from
    // the record number beside it.
    for (final scale in [1.0, kTextScaleMax]) {
      testWidgets('costs the header row nothing at ${scale}x', (tester) async {
        await _pump(
          tester,
          const StatusPill(label: label, fgColor: fg),
          textScale: scale,
        );
        final plain = _sizes(tester);

        await _pump(
          tester,
          StatusPill(label: label, fgColor: fg, onTap: () {}),
          textScale: scale,
        );
        final link = _sizes(tester);

        expect(link.row.height, plain.row.height);
        expect(link.pill.width, plain.pill.width);
      });
    }
  });
}
