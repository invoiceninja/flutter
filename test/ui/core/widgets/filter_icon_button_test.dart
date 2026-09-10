import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';

import '../../../_localization_helper.dart';

/// The AppBar filter affordance shared by `/activity` and the four custom Tasks
/// views (invoiceninja/flutter#136). No `Services`, no fakes — the whole point
/// of extracting it is that it is a leaf.
void main() {
  final dot = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
    description: 'the active-filter dot',
  );

  Future<void> pump(
    WidgetTester tester, {
    required int activeCount,
    double? size,
    VoidCallback? onPressed,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Center(
          child: FilterIconButton(
            activeCount: activeCount,
            size: size,
            onPressed: onPressed ?? () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('no dot while nothing is filtered', (tester) async {
    await pump(tester, activeCount: 0);
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    // Asserted on the decoration rather than on a screenshot, per CLAUDE.md's
    // rule for the sidebar's own ink invariants.
    expect(dot, findsNothing);
  });

  testWidgets('the dot appears as soon as one dimension narrows', (
    tester,
  ) async {
    await pump(tester, activeCount: 1);
    expect(dot, findsOneWidget);
  });

  testWidgets('the tooltip carries the count, so the dot is not the only cue', (
    tester,
  ) async {
    // The dot is invisible to a screen reader, and on a phone this button is
    // the ONLY filter surface: with a static tooltip a narrowed board and an
    // unfiltered one announce identically.
    await pump(tester, activeCount: 0);
    expect(find.byTooltip('Filters'), findsOneWidget);

    await pump(tester, activeCount: 2);
    expect(find.byTooltip('Filters (2)'), findsOneWidget);
  });

  testWidgets('tapping fires the callback', (tester) async {
    var taps = 0;
    await pump(tester, activeCount: 0, onPressed: () => taps++);
    await tester.tap(find.byType(FilterIconButton));
    expect(taps, 1);
  });

  testWidgets('a pinned size fits the wide header band', (tester) async {
    // `InSizes.headerBand` (69) minus the band's `Padding(vertical: 12)` leaves
    // its `Row` 45 px. Assert the SIZE, not the absence of an overflow: an
    // over-tall `IconButton` inside that padding is clamped by the incoming
    // constraints and renders short with no error at all, so
    // `expectNoOverflow` would stay green on the very regression this guards.
    await pump(tester, activeCount: 0, size: actionButtonSize());
    final side = tester.getSize(find.byType(IconButton));
    expect(side.height, actionButtonSize());
    expect(side.height, lessThanOrEqualTo(InSizes.headerBand - 24));
    expect(side.width, actionButtonSize());
  });

  testWidgets('no size keeps Flutter\'s default target', (tester) async {
    // The narrow AppBar sits beside `DrawerHamburger` and the view toggle, both
    // default `IconButton`s, so the un-pinned branch must stay 48.
    await pump(tester, activeCount: 0);
    expect(
      tester.getSize(find.byType(IconButton)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
