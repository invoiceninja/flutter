import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/sidebar_menu.dart';
import 'package:admin/ui/features/settings/widgets/sidebar_menu_section.dart';

import '../../shell/_shell_test_helpers.dart';

/// Renders the real Menu card against a real `Services` + Drift, so the chain
/// from the segmented control through the controller to `nav_state` is
/// exercised end to end (invoiceninja/flutter#125).
void main() {
  late ShellFixture fixture;

  /// `addTearDown` from inside the test body, not a top-level `tearDown`: the
  /// fixture's `Services` keep timers running, and the binding's
  /// still-pending-Timer assertion fires before a `tearDown` would get the
  /// chance to stop them.
  Future<void> setUpFixture() async {
    fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
  }

  Future<void> pumpCard(WidgetTester tester) => tester.pumpWidget(
    wrapWithShell(
      fixture.services,
      const SingleChildScrollView(child: SidebarMenuSection()),
    ),
  );

  testWidgets('offers both layouts and starts on List', (tester) async {
    await setUpFixture();
    await pumpCard(tester);

    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Layout'), findsOneWidget);
    // "Menu order", never the bundled `order` key — that one is the invoicing
    // noun and renders as the *purchase order* in de / fr / nl / ja.
    expect(find.text('Menu order'), findsOneWidget);
    expect(find.text('Order'), findsNothing);
    // The current layout is echoed as the row's subtitle, so "List" appears
    // twice: once as the segment, once as the subtitle.
    expect(find.text('List'), findsNWidgets(2));
    expect(find.text('Grid'), findsOneWidget);
    expect(fixture.services.sidebarMenu.layout, SidebarMenuLayout.list);
    await _disposeTree(tester);
  });

  testWidgets('picking Grid writes through to the controller and nav_state', (
    tester,
  ) async {
    await setUpFixture();
    await pumpCard(tester);

    await tester.tap(find.text('Grid'));
    await _pumpFrames(tester);

    expect(fixture.services.sidebarMenu.layout, SidebarMenuLayout.grid);
    final row = await fixture.db.navStateDao.current();
    expect(row?.sidebarMenuJson, contains('grid'));
    // The subtitle follows, so the card shows its own effect.
    expect(find.text('Grid'), findsNWidgets(2));
    await _disposeTree(tester);
  });

  testWidgets('Customize opens the menu editor', (tester) async {
    await setUpFixture();
    await pumpCard(tester);

    await tester.tap(find.text('Customize'));
    await _pumpFrames(tester);

    expect(find.text('Customize menu'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('the card reflects a preference restored from the database', (
    tester,
  ) async {
    // The sidebar and this card read one controller, so a value restored at
    // boot has to reach both. Nothing else proves the restore path is wired.
    await setUpFixture();
    await fixture.services.sidebarMenu.setLayout(SidebarMenuLayout.grid);
    await fixture.services.sidebarMenu.restore();
    await pumpCard(tester);

    expect(find.text('Grid'), findsNWidgets(2));
    await _disposeTree(tester);
  });
}

/// `pumpAndSettle` is avoided for the same reason the counters card's test
/// avoids it: the fixture holds live Drift watches, so the tree is never
/// "settled". Pump enough frames to cover the sheet / segment animations.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tear the subtree down inside the test body so the Drift watches' close
/// timers fire before the binding's end-of-test `!timersPending` check.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
