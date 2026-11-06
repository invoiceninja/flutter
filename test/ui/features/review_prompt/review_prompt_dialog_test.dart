// The review card (docs/review-prompt.md): every answer can reach the review
// page, nothing answers it by accident, and Esc works at every step.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/review_prompt_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/review_prompt.dart';
import 'package:admin/ui/features/review_prompt/review_prompt_dialog.dart';

import '../../../_localization_helper.dart';

void main() {
  // Read as the dialog closes, never awaited: a card that didn't close would
  // otherwise hang the test under fake time.
  late bool closed;
  ReviewCardResult? popped;
  late int opens;
  late bool opensSucceed;

  setUp(() {
    closed = false;
    popped = null;
    opens = 0;
    opensSucceed = true;
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    double textScale = 1,
    TextDirection direction = TextDirection.ltr,
    bool isLastShow = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showDialog<ReviewCardResult>(
                      context: context,
                      // As `showReviewPromptDialog` opens it — which is what
                      // switches off the route's own Esc.
                      barrierDismissible: false,
                      builder: (_) => ReviewPromptDialog(
                        channel: ReviewChannel.capterra,
                        isLastShow: isLastShow,
                        openListing: (_, _) async {
                          opens++;
                          return opensSucceed;
                        },
                      ),
                    ).then((r) {
                      closed = true;
                      popped = r;
                    }),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Past the half-second guard a step change re-arms.
  Future<void> armed(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 600));

  final primary = find.byKey(const ValueKey('review-card-primary'));
  final secondary = find.byKey(const ValueKey('review-card-secondary'));

  /// Esc once the card is armed — a step change re-arms its guard, and an
  /// unanswered `result` would never complete under fake time.
  Future<void> esc(WidgetTester tester) async {
    await armed(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  testWidgets('asks first, with the close button holding the focus', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Are you enjoying the app?'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('Not really'), findsOneWidget);
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<IconButton>()?.tooltip,
      'Close',
    );
  });

  testWidgets('Esc at the question is "closed"', (tester) async {
    await pump(tester);
    await esc(tester);
    expect(closed, isTrue);
    expect(popped, ReviewCardResult.closed);
  });

  testWidgets('Yes leads to the review page; Esc there is "closed after '
      'yes"', (tester) async {
    await pump(tester);
    await tester.tap(primary);
    await tester.pump();
    expect(
      find.text('Great to hear! Would you mind leaving a quick review?'),
      findsOneWidget,
    );
    expect(find.text('Opens Capterra'), findsOneWidget);
    expect(find.text('Leave a review'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    await esc(tester);
    expect(closed, isTrue);
    expect(popped, ReviewCardResult.closedAfterYes);
  });

  testWidgets('Not really still offers the review page, beside Send '
      'feedback — no review gating', (tester) async {
    await pump(tester);
    await tester.tap(secondary);
    await tester.pump();
    expect(
      find.text('Sorry to hear that. What could we do better?'),
      findsOneWidget,
    );
    expect(find.text('Send feedback'), findsOneWidget);
    expect(find.text('Leave a review'), findsOneWidget);
    await esc(tester);
    expect(closed, isTrue);
    expect(popped, ReviewCardResult.unhappy);
  });

  testWidgets('Send feedback returns it for the host to follow', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(secondary);
    await tester.pump();
    await armed(tester);
    await tester.tap(primary);
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(popped, ReviewCardResult.sendFeedback);
  });

  testWidgets('a step change keeps Esc reachable: focus moves to the close '
      'button', (tester) async {
    await pump(tester);
    await tester.tap(primary);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus?.context;
    expect(
      focused?.findAncestorWidgetOfExactType<IconButton>()?.tooltip,
      'Close',
    );
  });

  testWidgets('a double tap on Yes does not land on Leave a review', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(primary);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(primary);
    await tester.pump();
    expect(opens, 0);
    expect(find.text('Leave a review'), findsOneWidget, reason: 'still open');
  });

  testWidgets('a review page that opens closes the card as rated', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(primary);
    await tester.pump();
    await armed(tester);
    await tester.tap(primary);
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(closed, isTrue);
    expect(popped, ReviewCardResult.rated);
  });

  testWidgets('one that fails keeps the card so they can try again', (
    tester,
  ) async {
    opensSucceed = false;
    await pump(tester);
    await tester.tap(primary);
    await tester.pump();
    await armed(tester);
    await tester.tap(primary);
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(find.text('Leave a review'), findsOneWidget);
    await tester.tap(primary);
    await tester.pumpAndSettle();
    expect(opens, 2);
  });

  testWidgets('the last automatic show declines with "No thanks"', (
    tester,
  ) async {
    await pump(tester, isLastShow: true);
    await tester.tap(primary);
    await tester.pump();
    expect(find.text('No thanks'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
  });

  for (final direction in TextDirection.values) {
    testWidgets('fits a 320-wide phone at 1.4x text, ${direction.name}', (
      tester,
    ) async {
      await pump(
        tester,
        size: const Size(320, 640),
        textScale: 1.4,
        direction: direction,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(primary);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await esc(tester);
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(secondary);
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Side by side, not stacked.
      expect(tester.getTopLeft(primary).dy, tester.getTopLeft(secondary).dy);
    });
  }
}
