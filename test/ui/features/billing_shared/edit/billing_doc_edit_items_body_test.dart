import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_fab.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_doc_edit_items_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';

/// The narrow Items-tab host. Everything asserted here is invisible at the
/// call site and silent when broken — see the widget's own dartdoc.
void main() {
  const childKey = ValueKey('items-child');

  /// `InSpacing.lg` reads the WINDOW width, so it is 16 at every size these
  /// tests use except the sub-600 one.
  double padFor(double width) => width >= 600 ? 16 : 12;

  Future<void> pump(
    WidgetTester tester, {
    required Size surface,
    double childHeight = 20,
    double? childWidth = 100,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: BillingDocEditItemsBody(
            heroTag: 'test_items_fab',
            onPickItems: () {},
            child: SizedBox(
              key: childKey,
              width: childWidth,
              height: childHeight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the scroll view fills the tab, it does not shrink-wrap', (
    tester,
  ) async {
    // `StackFit.loose` — the default, and what shipped — hands a
    // non-positioned child `constraints.loosen()`, so the scroll view
    // collapsed to its content and the Stack parked it at its default
    // top-START. That is invoiceninja/flutter#141: a populated list hid it
    // (its ListView fills the cross axis) while the empty state hugged the
    // corner. A 100 px-wide child is what discriminates the two.
    await pump(tester, surface: const Size(400, 800));

    expect(
      tester.getSize(find.byType(SingleChildScrollView)).width,
      400,
      reason: 'StackFit.expand is load-bearing, not decoration',
    );
  });

  testWidgets('a short child is stretched to the viewport on the narrow '
      'branch, so the empty state can centre in it', (tester) async {
    const surface = Size(400, 800);
    await pump(tester, surface: surface);

    expect(
      tester.getSize(find.byKey(childKey)).height,
      surface.height - padFor(surface.width) * 2,
    );
  });

  testWidgets('a short child is NOT stretched on the wide-table branch', (
    tester,
  ) async {
    // `RenderFlex` ends in `constraints.constrain(...)`, which honours
    // minHeight whatever the mainAxisSize — so a minHeight here stretches
    // `LineItemTableDesktop`'s BORDERED container to the full viewport and
    // leaves a tall empty box below the last row.
    await pump(tester, surface: const Size(900, 800));

    expect(tester.getSize(find.byKey(childKey)).height, 20);
  });

  testWidgets('a tall child scrolls rather than overflowing', (tester) async {
    await pump(tester, surface: const Size(400, 800), childHeight: 5000);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  group('the picker FAB follows the TABLE, not the layout branch', () {
    // The narrow layout runs up to a 1024 px pane while `LineItemEditor`
    // switches to the desktop table at 700 px of CONTENT — and that table has
    // no inline picker at all, so an iPad Pro in portrait would be left with
    // no way to open the picker and no ⌘N to fall back on.
    testWidgets('absent where the mobile card list renders', (tester) async {
      await pump(tester, surface: const Size(400, 800));
      expect(find.byType(BillingDocEditFab), findsNothing);
    });

    testWidgets('present where the desktop table renders', (tester) async {
      await pump(tester, surface: const Size(900, 800));
      expect(find.byType(BillingDocEditFab), findsOneWidget);
    });

    testWidgets('the gate subtracts the host gutters', (tester) async {
      // 700 of content, not 700 of pane: this widget's LayoutBuilder sits
      // OUTSIDE the padding the editor's own one sits inside, and the two must
      // agree to the pixel about which branch is rendering.
      await pump(tester, surface: const Size(700 + 32 - 1, 800));
      expect(find.byType(BillingDocEditFab), findsNothing);

      await pump(tester, surface: const Size(700 + 32, 800));
      expect(find.byType(BillingDocEditFab), findsOneWidget);
    });
  });
}
