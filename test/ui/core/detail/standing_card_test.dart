import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/standing_card.dart';

import '../../../_responsive_helper.dart';

/// `StandingCard` is the two numbers that answer a record's main question,
/// plus whichever secondary balances the caller passes.

StandingFigure _figure(String label, String value, {VoidCallback? onTap}) =>
    StandingFigure(label: label, value: value, onTap: onTap);

void main() {
  testWidgets('a primary figure prints a zero — it is the answer', (
    tester,
  ) async {
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [_figure('Balance', r'$0.00'), _figure('Paid', r'$0.00')],
      ),
    );
    expect(find.text(r'$0.00'), findsNWidgets(2));
    expect(find.text('—'), findsNothing);
  });

  testWidgets('a figure with no value yet is blank, not a dash', (
    tester,
  ) async {
    // While the formatter loads. A dash on a card of balances would read as
    // "nothing owed"; a blank line of the same height reads as "not yet".
    await pumpAt(
      tester,
      440,
      StandingCard(primary: [_figure('Balance', ''), _figure('Paid', '')]),
    );
    final loading = tester.getSize(find.byType(StandingCard)).height;
    expect(find.text('—'), findsNothing);
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [_figure('Balance', r'$1.00'), _figure('Paid', r'$2.00')],
      ),
    );
    expect(
      tester.getSize(find.byType(StandingCard)).height,
      loading,
      reason: 'the card does not jump when the figures arrive',
    );
  });

  testWidgets('secondary figures are only the ones passed', (tester) async {
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [_figure('Balance', r'$5.00'), _figure('Paid', r'$9.00')],
      ),
    );
    final bare = tester.getSize(find.byType(StandingCard)).height;
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [_figure('Balance', r'$5.00'), _figure('Paid', r'$9.00')],
        secondary: [_figure('Credit', r'$1.00')],
      ),
    );
    expect(find.text('Credit'), findsOneWidget);
    expect(tester.getSize(find.byType(StandingCard)).height, greaterThan(bare));
  });

  testWidgets('a long amount scales down instead of being cut off', (
    tester,
  ) async {
    // A balance with its tail ellipsized is a wrong number, not a short one.
    const long = r'$1,234,567,890.00';
    await pumpAt(
      tester,
      320,
      StandingCard(primary: [_figure('Balance', long), _figure('Paid', long)]),
    );
    expectNoOverflow(tester);
    final text = tester.widget<Text>(find.text(long).first);
    expect(text.overflow, isNot(TextOverflow.ellipsis));
    expect(find.byType(FittedBox), findsWidgets);
  });

  testWidgets('a linked figure opens its target; a plain one has no cue', (
    tester,
  ) async {
    var opened = 0;
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [
          _figure('Balance', r'$5.00', onTap: () => opened++),
          _figure('Paid', r'$9.00'),
        ],
      ),
    );
    // One chevron: the linked figure's. The plain one is not dressed as a
    // link to a tab that is not there.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text(r'$5.00'));
    expect(opened, 1);
  });

  testWidgets('a linked figure is still copyable by long-press', (
    tester,
  ) async {
    // Touch: tap is taken by the link, so the value is reached by long-press —
    // the same split `DetailInfoRow` makes for a row with its own `onTap`.
    var opened = 0;
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [
          _figure('Balance', r'$5.00', onTap: () => opened++),
          _figure('Paid', r'$9.00'),
        ],
      ),
    );
    final detector = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.text(r'$5.00'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(detector.onLongPress, isNotNull);
    expect(detector.onTap, isNull, reason: 'tap belongs to the link');
    expect(opened, 0);
  });

  testWidgets('announces label, value and what the tap does', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAt(
      tester,
      440,
      StandingCard(
        primary: [
          StandingFigure(
            label: 'Balance',
            value: r'$5.00',
            onTap: () {},
            semanticsHint: 'Invoices',
          ),
        ],
      ),
    );
    expect(
      tester.getSemantics(find.text(r'$5.00')),
      isSemantics(
        isButton: true,
        label: r'Balance $5.00',
        hint: 'Invoices',
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('with a pointer a linked figure offers a copy icon', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpAt(
        tester,
        440,
        StandingCard(primary: [_figure('Balance', r'$5.00', onTap: () {})]),
      );
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
