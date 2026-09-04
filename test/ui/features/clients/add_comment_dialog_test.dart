import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/clients/widgets/detail/add_comment_dialog.dart';

import '../../../_localization_helper.dart';

/// The app's only add-comment dialog.
void main() {
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(800, 900),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showAddCommentDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('says a saved comment is permanent', (tester) async {
    // invoiceninja/flutter#123. The API exposes no update or delete route for
    // an activity note and `activities` has no soft-delete column, so a saved
    // comment cannot be edited or removed by any client — React and the legacy
    // Flutter app included. Saying so here is the only honest place: it stops
    // the hunt for an Edit button before it starts, and the row's `⋯` menu then
    // offers Copy so a typo can be re-posted corrected.
    //
    // Delete this test the day BACKEND.md § F3d ships.
    await open(tester);
    expect(
      find.text(pendingStrings()['comment_permanent_hint']!),
      findsOneWidget,
    );
  });

  testWidgets('the hint does not disturb Save gating', (tester) async {
    await open(tester);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'an empty comment cannot be saved',
    );

    await tester.enterText(find.byType(TextField), 'Will pay Friday');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

  testWidgets('the hint is not truncated on a narrow phone', (tester) async {
    // `InputDecoration.helperMaxLines` defaults to **1**, which ellipsizes the
    // whole sentence away at the width and text scale where it matters most.
    //
    // Pessimistic on purpose: `flutter test` substitutes a font whose every
    // glyph is a square of the font size, so the line count here is roughly
    // double what a real device renders. Passing under the test font means the
    // copy has real headroom — and it is what keeps the sentence short.
    await open(tester, size: const Size(360, 780), textScale: 1.4);
    final hint = pendingStrings()['comment_permanent_hint']!;
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(hint), matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });
}
