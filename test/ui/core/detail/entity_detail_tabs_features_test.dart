import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/detail_tab_navigator.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/list/master_detail_nav_scope.dart';

import '../../../_responsive_helper.dart';

/// What the strip gained for the summary-first record page: tabs addressed by
/// id, counts, a list of every tab when they do not fit, keyboard movement,
/// and a layout hook that lets a host pin the strip.

EntityDetailTab _tab(String id, {int? count}) => EntityDetailTab(
  id: id,
  count: count,
  label: 'Tab $id',
  icon: Icons.circle_outlined,
  bodyBuilder: (_) => Text('Body $id'),
);

List<EntityDetailTab> _tabs(List<String> ids) => [for (final i in ids) _tab(i)];

void main() {
  final allTabsButton = find.byIcon(Icons.arrow_drop_down);

  group('selectId', () {
    Future<TabSelectionController> pump(
      WidgetTester tester,
      List<String> ids,
    ) async {
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        900,
        EntityDetailTabs(selectTab: controller, tabs: _tabs(ids)),
        scroll: false,
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('moves to the tab with that id, wherever it sits', (
      tester,
    ) async {
      // The point of an id: 'payments' is the third tab here and would be the
      // second on a company with the quotes module off.
      final controller = await pump(tester, ['invoices', 'quotes', 'payments']);
      controller.selectId('payments');
      await tester.pumpAndSettle();
      expect(find.text('Body payments'), findsOneWidget);
    });

    testWidgets('an id the strip does not have is ignored', (tester) async {
      final controller = await pump(tester, ['invoices', 'payments']);
      controller.selectId('quotes');
      await tester.pumpAndSettle();
      expect(find.text('Body invoices'), findsOneWidget);
      expect(find.text('Body payments'), findsNothing);
    });

    testWidgets('a positional request after an id request is positional', (
      tester,
    ) async {
      // `select` has to clear the remembered id, or the strip would keep
      // resolving the earlier `selectId` on every later request.
      final controller = await pump(tester, ['invoices', 'quotes', 'payments']);
      controller.selectId('payments');
      await tester.pumpAndSettle();
      controller.select(0);
      await tester.pumpAndSettle();
      expect(controller.requestedId, isNull);
      final onStage = find.byWidgetPredicate(
        (w) => w is Offstage && !w.offstage,
      );
      expect(
        find.descendant(of: onStage, matching: find.text('Body invoices')),
        findsOneWidget,
      );
    });
  });

  group('counts', () {
    testWidgets('a count is drawn beside its label — zero included', (
      tester,
    ) async {
      await pumpAt(
        tester,
        900,
        EntityDetailTabs(
          tabs: [_tab('a', count: 12), _tab('b', count: 0), _tab('c')],
        ),
        scroll: false,
      );
      // Null means unknown and draws nothing, so a zero has to be printed for
      // the two to look different.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      final row = tester.getRect(find.text('Tab a'));
      expect(tester.getRect(find.text('12')).left, greaterThan(row.right));
    });
  });

  testWidgets('a count that arrives late does not push the active tab under '
      'the all-tabs button', (tester) async {
    // Counts are fetched, so they land after the strip has already revealed
    // the landing tab. The badge widens that tab; without a second look its
    // tail — the badge itself — sat under the button on a phone.
    List<EntityDetailTab> tabs({int? count}) => [
      for (final id in ['comments', 'activity', 'invoices', 'quotes', 'x', 'y'])
        EntityDetailTab(
          id: id,
          label: 'Tab $id',
          icon: Icons.circle_outlined,
          count: id == 'invoices' ? count : null,
          bodyBuilder: (_) => Text('Body $id'),
        ),
    ];
    await pumpAt(
      tester,
      360,
      EntityDetailTabs(initialIndex: 2, tabs: tabs()),
      scroll: false,
    );
    await tester.pumpAndSettle();
    await pumpAt(
      tester,
      360,
      EntityDetailTabs(initialIndex: 2, tabs: tabs(count: 1234)),
      scroll: false,
    );
    await tester.pumpAndSettle();

    final badge = tester.getRect(find.text('1234'));
    final button = tester.getRect(find.byIcon(Icons.arrow_drop_down));
    expect(
      badge.right,
      lessThanOrEqualTo(button.left),
      reason: 'the whole badge is clear of the button',
    );
  });

  group('the "all tabs" list', () {
    List<EntityDetailTab> many() => _tabs([for (var i = 0; i < 15; i++) 't$i']);

    testWidgets('lists every tab with a pointer, and moves to the one picked', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpAt(
          tester,
          400,
          EntityDetailTabs(tabs: many()),
          scroll: false,
        );
        await tester.pumpAndSettle();
        await tester.tap(allTabsButton);
        await tester.pumpAndSettle();
        // The strip's own button for t14 exists but is scrolled off; the
        // menu's is the second one.
        expect(find.text('Tab t14'), findsNWidgets(2));
        await tester.tap(find.text('Tab t14').last);
        await tester.pumpAndSettle();
        expect(find.text('Body t14'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('is a sheet on touch', (tester) async {
      // Fifteen menu rows run off a phone; the sheet scrolls.
      await pumpAt(tester, 400, EntityDetailTabs(tabs: many()), scroll: false);
      await tester.pumpAndSettle();
      await tester.tap(allTabsButton);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Tab t3').last);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Body t3'), findsOneWidget);
    });

    testWidgets('the button does not take width from the tabs', (tester) async {
      // It overlays the strip's trailing edge. Taking its own slot instead
      // narrowed the viewport and scrolled the leading Comments tab off on
      // arrival — the thing `initialIndex: 2` exists to prevent.
      await pumpAt(
        tester,
        400,
        EntityDetailTabs(initialIndex: 2, tabs: many()),
        scroll: false,
      );
      await tester.pumpAndSettle();
      expect(allTabsButton, findsOneWidget);
      final position = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((s) => s.position)
          .firstWhere((p) => p.axis == Axis.horizontal);
      expect(position.viewportDimension, 400);
    });
  });

  group('touch', () {
    Finder box() => find
        .ancestor(of: find.text('Tab a'), matching: find.byType(Container))
        .first;

    /// A phone-width *window*, not just a narrow surface. The strip's padding
    /// comes from `InSpacing.md`, which reads `MediaQuery` — and
    /// `setSurfaceSize` leaves that at the harness default of 800, where the
    /// row is 45 px tall on its own and a floor test would pass vacuously.
    Future<void> pumpPhoneWidth(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpAt(
        tester,
        390,
        EntityDetailTabs(tabs: _tabs(['a', 'b'])),
        height: 844,
      );
    }

    testWidgets('a tab is at least the touch target tall', (tester) async {
      // `flutter test` reports android, so this is the touch branch.
      await pumpPhoneWidth(tester);
      expect(
        tester.getSize(box()).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
      );
    });

    testWidgets('with a pointer the row is not padded out to it', (
      tester,
    ) async {
      // The floor is for fingers. This is also what proves the test above is
      // measuring the floor and not the strip's natural height.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpPhoneWidth(tester);
        expect(tester.getSize(box()).height, lessThan(InSizes.touchTarget));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('semantics', () {
    testWidgets('the active tab is announced as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(tester, 900, EntityDetailTabs(tabs: _tabs(['a', 'b'])));
      expect(
        tester.getSemantics(find.text('Tab a')),
        isSemantics(isSelected: true, isButton: true, label: 'Tab a'),
      );
      expect(
        tester.getSemantics(find.text('Tab b')),
        isSemantics(isSelected: false, isButton: true, label: 'Tab b'),
      );
      handle.dispose();
    });
  });

  group('keyboard', () {
    final after = FocusNode(debugLabel: 'after the strip');
    tearDownAll(after.dispose);

    Future<void> pumpFocused(WidgetTester tester) async {
      await pumpAt(
        tester,
        900,
        Column(
          children: [
            EntityDetailTabs(tabs: _tabs(['a', 'b', 'c'])),
            // Something to Tab on to, so "leaves the strip" has somewhere to
            // go other than wrapping back round to it.
            TextButton(
              focusNode: after,
              onPressed: () {},
              child: const Text('after'),
            ),
          ],
        ),
      );
      // One tab stop: Tab lands on the active button.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    testWidgets('arrow keys walk the strip and stop at its ends', (
      tester,
    ) async {
      await pumpFocused(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Body b'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Body c'), findsOneWidget, reason: 'clamped at the end');
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      final onStage = find.byWidgetPredicate(
        (w) => w is Offstage && !w.offstage,
      );
      expect(
        find.descendant(of: onStage, matching: find.text('Body a')),
        findsOneWidget,
      );
    });

    testWidgets('focus stays on the strip when the tab changes by something '
        'other than an arrow', (tester) async {
      // A click, `]`, the all-tabs list. Moving to a *later* tab used to drop
      // focus back to whatever held it before the strip — so the next Enter
      // pressed a tile, or typed into a search field.
      await pumpFocused(tester);
      String? focused() => FocusManager.instance.primaryFocus?.debugLabel;
      expect(focused(), 'detail tab');

      await tester.tap(find.text('Tab c'));
      await tester.pumpAndSettle();
      expect(find.text('Body c'), findsOneWidget);
      expect(focused(), 'detail tab', reason: 'forward');

      await tester.tap(find.text('Tab a'));
      await tester.pumpAndSettle();
      expect(focused(), 'detail tab', reason: 'and back');
    });

    testWidgets('a tab change does not pull focus onto the strip from '
        'elsewhere', (tester) async {
      await pumpFocused(tester);
      after.requestFocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab c'));
      await tester.pumpAndSettle();
      expect(after.hasFocus, isTrue);
    });

    testWidgets('an arrow with a modifier is left for whoever owns the chord', (
      tester,
    ) async {
      // ⌘← and Alt+← are history back; taken here they changed the tab and,
      // on web, cancelled the browser's own Back.
      await pumpFocused(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Body b'), findsOneWidget);

      // Alt and ⌘ reach nobody in this harness, so the result says the strip
      // let them go. Ctrl+← is taken further up by the framework's own
      // scroll shortcut — not by the strip, which the unchanged tab shows.
      for (final modifier in [
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        expect(
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft),
          isFalse,
          reason: '$modifier',
        );
        await tester.sendKeyUpEvent(modifier);
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      final onStage = find.byWidgetPredicate(
        (w) => w is Offstage && !w.offstage,
      );
      expect(
        find.descendant(of: onStage, matching: find.text('Body b')),
        findsOneWidget,
        reason: 'still on b',
      );
    });

    testWidgets('the strip is a single tab stop', (tester) async {
      await pumpFocused(tester);
      expect(after.hasFocus, isFalse);
      // A second Tab leaves the strip rather than moving to the next button:
      // three tabs, one stop.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(after.hasFocus, isTrue);
      expect(find.text('Body b'), findsNothing);
    });

    testWidgets('a scaffold above can step it with [ and ]', (tester) async {
      final navigator = DetailTabNavigator();
      expect(navigator.hasTabs, isFalse);
      await pumpAt(
        tester,
        900,
        DetailTabNavigatorScope(
          navigator: navigator,
          child: EntityDetailTabs(tabs: _tabs(['a', 'b', 'c'])),
        ),
        scroll: false,
      );
      expect(navigator.hasTabs, isTrue);
      navigator.step(1);
      await tester.pumpAndSettle();
      expect(find.text('Body b'), findsOneWidget);
      navigator.step(-5);
      await tester.pumpAndSettle();
      final onStage = find.byWidgetPredicate(
        (w) => w is Offstage && !w.offstage,
      );
      expect(
        find.descendant(of: onStage, matching: find.text('Body a')),
        findsOneWidget,
        reason: 'clamped at the start',
      );

      await tester.pumpWidget(const SizedBox());
      expect(navigator.hasTabs, isFalse, reason: 'unbound on dispose');
    });
  });

  testWidgets('a field in a tab the user has left does not keep the keyboard', (
    tester,
  ) async {
    // `Offstage` hides a body without taking focus from it, and on native
    // touch a text field does not unfocus on an outside tap — so typing went
    // on into a box the user could no longer see.
    final field = FocusNode(debugLabel: 'field in tab a');
    addTearDown(field.dispose);
    final select = TabSelectionController();
    addTearDown(select.dispose);
    await pumpAt(
      tester,
      900,
      EntityDetailTabs(
        selectTab: select,
        tabs: [
          EntityDetailTab(
            id: 'a',
            label: 'Tab a',
            icon: Icons.circle_outlined,
            bodyBuilder: (_) => TextField(focusNode: field),
          ),
          _tab('b'),
        ],
      ),
      scroll: false,
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(field.hasFocus, isTrue);

    // By the controller, the way a tab changes with no tap anywhere: a tap on
    // another tab would not take focus from the field either.
    select.selectId('b');
    await tester.pumpAndSettle();
    expect(find.text('Body b'), findsOneWidget);
    expect(field.hasFocus, isFalse);

    // And it is not left in the Tab order behind the scenes.
    expect(field.canRequestFocus, isFalse);
    select.selectId('a');
    await tester.pumpAndSettle();
    expect(field.canRequestFocus, isTrue, reason: 'back on stage');
  });

  group('layoutBuilder', () {
    testWidgets('hands the strip and the body to the host to place', (
      tester,
    ) async {
      await pumpAt(
        tester,
        900,
        EntityDetailTabs(
          tabs: _tabs(['a', 'b']),
          layoutBuilder: (context, strip, body) =>
              Column(children: [body, const Text('between'), strip]),
        ),
      );
      // Upside down on purpose: only a host that really places them can
      // produce this order.
      expect(
        tester.getTopLeft(find.text('Body a')).dy,
        lessThan(tester.getTopLeft(find.text('between')).dy),
      );
      expect(
        tester.getTopLeft(find.text('between')).dy,
        lessThan(tester.getTopLeft(find.text('Tab a')).dy),
      );
    });

    testWidgets('onReveal replaces the default page scroll', (tester) async {
      final controller = TabSelectionController();
      addTearDown(controller.dispose);
      var reveals = 0;
      await pumpAt(
        tester,
        900,
        EntityDetailTabs(
          selectTab: controller,
          onReveal: () => reveals++,
          tabs: _tabs(['a', 'b']),
        ),
      );
      controller.selectId('b');
      await tester.pumpAndSettle();
      expect(reveals, 1);
      // A repeat request for the tab already showing still reveals.
      controller.selectId('b');
      await tester.pumpAndSettle();
      expect(reveals, 2);
    });
  });

  group('memory by id', () {
    Widget host(MasterDetailNavController memory, List<String> ids) =>
        MasterDetailNavScope(
          controller: memory,
          child: EntityDetailTabs(tabs: _tabs(ids)),
        );

    testWidgets('the remembered tab survives the count changing', (
      tester,
    ) async {
      // By index this has to decline: 5 tabs and 4 tabs do not mean the same
      // thing at position 3. By id it does not have to.
      final memory = MasterDetailNavController();
      await pumpAt(tester, 900, host(memory, ['a', 'b', 'c', 'd', 'e']));
      await tester.tap(find.text('Tab d'));
      await tester.pumpAndSettle();
      expect(memory.lastTabId, 'd');

      // A different record of the same entity, with one module off.
      await tester.pumpWidget(const SizedBox());
      await pumpAt(tester, 900, host(memory, ['a', 'c', 'd', 'e']));
      await tester.pumpAndSettle();
      expect(find.text('Body d'), findsOneWidget);
    });

    testWidgets('a strip without ids clears an id another strip left', (
      tester,
    ) async {
      final memory = MasterDetailNavController()..lastTabId = 'stale';
      await pumpAt(
        tester,
        900,
        MasterDetailNavScope(
          controller: memory,
          child: EntityDetailTabs(
            tabs: [
              for (final l in ['x', 'y'])
                EntityDetailTab(
                  label: l,
                  icon: Icons.circle,
                  bodyBuilder: (_) => Text('Body $l'),
                ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('y'));
      await tester.pumpAndSettle();
      expect(memory.lastTabId, isNull);
    });
  });
}
