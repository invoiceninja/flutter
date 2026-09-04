import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_tabs.dart';

import '../../../_responsive_helper.dart';

/// `ClientDetailTabs` builds a VARIABLE-length tab list — eight of its tabs are
/// gated on `me?.moduleEnabled(...)` — and toggling a module in Account
/// Management rebuilds the branch in place. So this widget has to survive its
/// `tabs.length` changing under it.
///
/// Two ways that went wrong, both unguarded until this file existed:
///   * building a second `TabController` under `SingleTickerProviderStateMixin`
///     throws "multiple tickers were created" (the mixin asserts one ticker for
///     the State's whole life and never resets it);
///   * a rebuilt controller that doesn't re-attach the tab-change listener stops
///     growing `_activated`, so every tab body opened afterwards renders
///     nothing — a permanently blank pane.
EntityDetailTab _tab(String label) => EntityDetailTab(
  label: label,
  icon: Icons.circle_outlined,
  bodyBuilder: (_) => Text('$label body'),
);

void main() {
  Future<void> pumpTabs(WidgetTester tester, List<String> labels) => pumpAt(
    tester,
    900,
    EntityDetailTabs(tabs: [for (final l in labels) _tab(l)]),
    scroll: false,
  );

  testWidgets('shrinking the tab list does not throw', (tester) async {
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    expect(find.text('Invoices body'), findsOneWidget);

    await pumpTabs(tester, ['Invoices', 'Quotes']); // Tasks module disabled
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Invoices body'), findsOneWidget);
  });

  testWidgets('growing the tab list does not throw', (tester) async {
    await pumpTabs(tester, ['Invoices']);
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tabs still open after the count changes', (tester) async {
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.pump();

    // The listener has to survive the controller rebuild, or `_activated`
    // never grows and this body never mounts.
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();

    expect(find.text('Quotes body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an already-open tab keeps its body across a count change', (
    tester,
  ) async {
    await pumpTabs(tester, ['Invoices', 'Quotes', 'Tasks']);
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();
    expect(find.text('Quotes body'), findsOneWidget);

    // Disabling a module must not tear down every live tab body — this class
    // promises activated tabs stay alive for the screen's lifetime.
    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.pumpAndSettle();

    expect(find.text('Quotes body'), findsOneWidget);
  });

  testWidgets('an unchanged tab count keeps the same controller', (
    tester,
  ) async {
    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.tap(find.text('Quotes'));
    await tester.pumpAndSettle();

    await pumpTabs(tester, ['Invoices', 'Quotes']);
    await tester.pumpAndSettle();

    // Still on Quotes: a same-length rebuild must not reset the selection.
    expect(find.text('Quotes body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('selectTab', () {
    // Drives the Comments card's `View All` (invoiceninja/flutter#121).
    Future<TabSelectionController> pumpStrip(
      WidgetTester tester, {
      int count = 4,
    }) async {
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        900,
        EntityDetailTabs(
          selectTab: controller,
          tabs: [
            for (var i = 0; i < count; i++)
              EntityDetailTab(
                label: 'Tab $i',
                icon: Icons.circle,
                bodyBuilder: (_) => Text('Body $i'),
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('moves to the requested tab', (tester) async {
      final controller = await pumpStrip(tester);
      expect(find.text('Body 0'), findsOneWidget);
      controller.select(2);
      await tester.pumpAndSettle();
      expect(find.text('Body 2'), findsOneWidget);
    });

    testWidgets('a negative index counts from the end', (tester) async {
      // Lets a host whose tab list is module-gated say "second to last"
      // without recomputing the gates.
      final controller = await pumpStrip(tester);
      controller.select(-2);
      await tester.pumpAndSettle();
      expect(find.text('Body 2'), findsOneWidget);
    });

    testWidgets('an out-of-range request clamps rather than throwing', (
      tester,
    ) async {
      final controller = await pumpStrip(tester);
      controller.select(99);
      await tester.pumpAndSettle();
      expect(find.text('Body 3'), findsOneWidget);
      controller.select(-99);
      await tester.pumpAndSettle();
      expect(find.text('Body 0'), findsOneWidget);
    });

    testWidgets('a repeat request still fires after a manual tab change', (
      tester,
    ) async {
      // A plain `ValueNotifier` would go silent here: the value never changed.
      final controller = await pumpStrip(tester);
      controller.select(2);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab 0'));
      await tester.pumpAndSettle();
      expect(find.text('Body 0'), findsOneWidget);
      controller.select(2);
      await tester.pumpAndSettle();
      expect(find.text('Body 2'), findsOneWidget);
    });
  });

  group('the strip scrolls the active tab into view', () {
    // ~15 tabs on a client and about three visible in a 440-560 px pane, so a
    // tab is routinely *selected without being on screen* — by a restored
    // `lastTab`, or by the Comments card's `View All`. Until
    // invoiceninja/flutter#122 the strip had no `ScrollController` at all and
    // so never moved: the body changed under an unchanged, un-underlined strip.
    List<EntityDetailTab> manyTabs(int count) => [
      for (var i = 0; i < count; i++)
        EntityDetailTab(
          label: 'Tab $i',
          icon: Icons.circle_outlined,
          bodyBuilder: (_) => SizedBox(height: 600, child: Text('Body $i')),
        ),
    ];

    ScrollPosition axisPosition(WidgetTester tester, Axis axis) => tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .map((s) => s.position)
        .firstWhere((p) => p.axis == axis);

    /// The tab button's own box, not its label — the label sits a padding
    /// inside it, which would quietly soften the fade-clearance assertion.
    Rect buttonRect(WidgetTester tester, String label) => tester.getRect(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );

    int fadeCount(WidgetTester tester) => tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => (c.decoration as BoxDecoration?)?.gradient != null)
        .length;

    const width = 400.0;
    // Must track `_kStripEdgeFade`.
    const fade = 32.0;

    testWidgets('the landing tab leaves the head of the strip visible', (
      tester,
    ) async {
      // The regression test for reaching by centring: `ScrollPosition`
      // `ensureVisible(alignment: 0.5)` — what Material's own `TabBar` does —
      // would centre the LANDING tab, scrolling ~53 px on a phone and clipping
      // the Comments tab off the left edge on arrival, which is the whole
      // thing `initialIndex: 2` exists to show.
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(initialIndex: 2, tabs: manyTabs(15)),
        scroll: false,
      );
      await tester.pumpAndSettle();

      expect(axisPosition(tester, Axis.horizontal).pixels, 0);
      expect(tester.getRect(find.text('Tab 0')).left, greaterThanOrEqualTo(0));
    });

    testWidgets('a far-right tab is brought on screen', (tester) async {
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(selectTab: controller, tabs: manyTabs(15)),
        scroll: false,
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Tab 12')).right, greaterThan(width));

      controller.select(12);
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.text('Tab 12'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
    });

    testWidgets('and back to the head when the card links to Comments', (
      tester,
    ) async {
      // The #121 dead link: `View All` activated tab 0 while the strip stayed
      // scrolled right, so nothing appeared to happen.
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(selectTab: controller, tabs: manyTabs(15)),
        scroll: false,
      );
      controller.select(14);
      await tester.pumpAndSettle();
      expect(axisPosition(tester, Axis.horizontal).pixels, greaterThan(0));

      controller.select(0);
      await tester.pumpAndSettle();

      expect(axisPosition(tester, Axis.horizontal).pixels, 0);
      expect(tester.getRect(find.text('Tab 0')).left, greaterThanOrEqualTo(0));
    });

    testWidgets(
      'a restored far-right tab is revealed, and the page stays put',
      (tester) async {
        // Two assertions in one because they are the same mistake: the static
        // `Scrollable.ensureVisible` walks EVERY enclosing scrollable, so it
        // reveals the button by dragging the detail page down to it. Only the
        // strip may move. The spacer puts the strip below the fold so a page
        // scroll is measurable.
        await pumpAt(
          tester,
          width,
          Column(
            children: [
              const SizedBox(height: 900),
              EntityDetailTabs(initialIndex: 12, tabs: manyTabs(15)),
            ],
          ),
          height: 600,
        );
        await tester.pumpAndSettle();

        expect(axisPosition(tester, Axis.horizontal).pixels, greaterThan(0));
        expect(axisPosition(tester, Axis.vertical).pixels, 0);
        expect(
          tester.getRect(find.text('Tab 12')).right,
          lessThanOrEqualTo(width),
        );
      },
    );

    testWidgets('the edge fades follow the scroll position', (tester) async {
      // Each fade is gated on there being something to reveal that way: an
      // unconditional one veils the first or last tab's own label once the
      // strip is scrolled to that end, and neither belongs on a strip that
      // fits. Counted structurally — the fades are the only gradient-filled
      // containers in the strip; a tab button's decoration is a border.
      int fades() => fadeCount(tester);

      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(selectTab: controller, tabs: manyTabs(15)),
        scroll: false,
      );
      await tester.pumpAndSettle();
      expect(fades(), 1, reason: 'at the start: trailing only');

      controller.select(14);
      await tester.pumpAndSettle();
      expect(fades(), 1, reason: 'at the end: leading only');

      await pumpAt(
        tester,
        900,
        EntityDetailTabs(tabs: manyTabs(2)),
        scroll: false,
      );
      await tester.pumpAndSettle();
      expect(fades(), 0, reason: 'a strip that fits needs no fade at all');
    });

    testWidgets('a revealed tab lands clear of the edge fades', (tester) async {
      // The reveal leaves a full fade-width of slack, not the strip's 8 px
      // padding: landed flush against the viewport edge, a mid-strip tab sits
      // UNDER the 32 px gradient drawn there and its label's tail renders at up
      // to 75% opacity. On screen, but veiled — which is why "is it on screen"
      // is not the assertion.
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(selectTab: controller, tabs: manyTabs(15)),
        scroll: false,
      );
      await tester.pumpAndSettle();

      controller.select(7); // mid-strip: neither end clamps the target
      await tester.pumpAndSettle();

      final rect = buttonRect(tester, 'Tab 7');
      expect(rect.right, lessThanOrEqualTo(width - fade));
      expect(rect.left, greaterThanOrEqualTo(fade));
    });

    testWidgets('a repeat request re-reveals a tab that is already active', (
      tester,
    ) async {
      // `_onSelectRequested` skips `animateTo` when the index is unchanged, so
      // a reveal hung off the controller tick alone never runs — and this is
      // precisely the repeat request `TabSelectionController.select` exists to
      // deliver. Tap `View All`, scroll the strip away by hand, tap it again.
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(selectTab: controller, tabs: manyTabs(15)),
        scroll: false,
      );
      controller.select(0);
      await tester.pumpAndSettle();
      expect(axisPosition(tester, Axis.horizontal).pixels, 0);

      axisPosition(tester, Axis.horizontal).jumpTo(600);
      await tester.pumpAndSettle();
      expect(find.text('Body 0'), findsOneWidget, reason: 'still on tab 0');

      controller.select(0);
      await tester.pumpAndSettle();

      expect(axisPosition(tester, Axis.horizontal).pixels, 0);
    });

    testWidgets('the fades re-resolve when only the width changes', (
      tester,
    ) async {
      // A resize changes `maxScrollExtent` without moving `pixels`, and that
      // reaches no `ScrollController` listener — `applyContentDimensions` only
      // schedules a `ScrollMetricsNotification`. Same tab count, so the
      // controller is NOT replaced and the corrective post-frame `setState`
      // does not run; the notification is the only thing that can fix this.
      await pumpAt(
        tester,
        width,
        EntityDetailTabs(tabs: manyTabs(15)),
        scroll: false,
      );
      await tester.pumpAndSettle();
      expect(fadeCount(tester), 1, reason: 'overflowing: trailing fade');

      await pumpAt(
        tester,
        4000,
        EntityDetailTabs(tabs: manyTabs(15)),
        scroll: false,
      );
      await tester.pumpAndSettle();

      expect(
        fadeCount(tester),
        0,
        reason:
            'the strip now fits, and no scroll is left that could ever clear a '
            'stale fade',
      );
    });

    testWidgets('it survives the controller being replaced', (tester) async {
      // A module toggle changes the tab COUNT, which makes the parent build a
      // new `TabController`; a strip that does not re-subscribe stops
      // auto-scrolling from then on, silently.
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      Future<void> pump(int count) => pumpAt(
        tester,
        width,
        EntityDetailTabs(selectTab: controller, tabs: manyTabs(count)),
        scroll: false,
      );

      await pump(15);
      await tester.pumpAndSettle();
      await pump(14);
      await tester.pumpAndSettle();

      controller.select(11);
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.text('Tab 11'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
    });
  });
}
