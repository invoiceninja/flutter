import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/utils/fab_clearance.dart';

/// `Scaffold` never insets its body for the floating action button, so every
/// scrollable under one has to pay the inset itself (invoiceninja/flutter#167).
/// These pin the arithmetic that decides how much — the same shape
/// `running_timer_pill_bottom_test.dart` uses for the sibling 112.
void main() {
  /// Pumps [fabScrollClearance] under a given bottom safe inset and hands back
  /// what it returned.
  Future<double> clearanceUnder(
    WidgetTester tester, {
    double bottomInset = 0,
  }) async {
    late double value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottomInset)),
        child: Builder(
          builder: (context) {
            value = fabScrollClearance(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  test('the clearance is the button plus Material own margin', () {
    expect(kFabClearance, 56 + kFloatingActionButtonMargin);
    expect(kFabClearance, 72);
  });

  testWidgets('a scroll view also gets a gap, so the last row is not flush', (
    tester,
  ) async {
    // Flush at exactly kFabClearance would put the row's 44 px `⋮` hard against
    // the FAB's hit box, and a low mis-tap would open a new record.
    expect(await clearanceUnder(tester), kFabClearance + InSpacing.sm);
    expect(await clearanceUnder(tester), 80);
  });

  testWidgets('it carries the bottom safe inset, which a padding turns off', (
    tester,
  ) async {
    // A `BoxScrollView` applies the inset itself ONLY while its padding is
    // null, so anything passing this value has to get the inset back from here
    // or a gesture-nav phone silently loses its home-indicator gap.
    expect(
      await clearanceUnder(tester, bottomInset: 34),
      kFabClearance + InSpacing.sm + 34,
    );
  });

  testWidgets('the gap does not widen with the window', (tester) async {
    // `InSpacing.md` / `.lg` read `MediaQuery.sizeOf(context).width` — the
    // WINDOW — so on a 700 px window with a sub-600 pane (rail up, which still
    // shows a FAB) they would quietly return their wide value. The gap is the
    // const `InSpacing.sm` precisely so this cannot happen.
    late double narrow;
    late double wide;
    for (final (size, sink) in <(Size, void Function(double))>[
      (const Size(390, 800), (v) => narrow = v),
      (const Size(700, 800), (v) => wide = v),
    ]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Builder(
            builder: (context) {
              sink(fabScrollClearance(context));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    }
    expect(narrow, wide);
  });
}
