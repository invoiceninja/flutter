import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/widgets/customize_menu_sheet.dart';

import '../../shell/_shell_test_helpers.dart';

/// All modules on except Tasks (bit 8), so one row in the editor is
/// module-disabled and the "listed but inert" rules can be asserted.
const int _allModulesExceptTasks = 32767 - 8;

/// iPhone home-indicator inset in logical px. Deliberately not Android's 24:
/// the sheet's action row already stops 26 px short of the screen edge on its
/// own, so 24 would pass with or without the SafeArea and prove nothing, while
/// 34 is both the real iOS figure and the one that discriminates.
const double _kHomeIndicator = 34;

/// Drives the real Customize menu editor against a real `Services` + Drift
/// (invoiceninja/flutter#125). Mutations apply instantly, so every assertion is
/// against the controller and the `nav_state` row rather than a Save button.
void main() {
  late ShellFixture fixture;

  /// `addTearDown` from inside the test body, not a top-level `tearDown`: the
  /// fixture's `Services` keep timers running, and the binding's
  /// still-pending-Timer assertion fires before a `tearDown` would get the
  /// chance to stop them.
  Future<void> setUpFixture({int enabledModules = 32767}) async {
    fixture = await buildFixture(
      companies: [
        FakeCompany(id: 'co1', name: 'Acme', enabledModules: enabledModules),
      ],
    );
    addTearDown(fixture.dispose);
  }

  /// Shrinks the window to a phone and gives it a home-indicator inset, so
  /// `openCustomizeMenu` takes its **bottom-sheet** branch.
  ///
  /// `FakeViewPadding` is in PHYSICAL px, hence the dpr multiply; the dpr
  /// itself is deliberately left alone, because `MediaQueryData.fromView`
  /// divides `physicalSize` by it and `openCustomizeMenu`'s own width check
  /// reads the result. Same trap `sidebar_footer_actions_widget_test.dart`
  /// documents for #124.
  void useNarrowPhone(WidgetTester tester) {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = Size(390 * dpr, 844 * dpr);
    tester.view.padding = FakeViewPadding(bottom: _kHomeIndicator * dpr);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
  }

  /// Opens the editor from a host wide enough to take the dialog branch, which
  /// gives the reorderable list a bounded box without a bottom-sheet animation.
  Future<void> pumpEditor(WidgetTester tester) async {
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openCustomizeMenu(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _pumpFrames(tester);
  }

  /// The editor's list is lazy and taller than the dialog, so a row near the
  /// bottom is not built until it is scrolled into range. Drags the list body
  /// (never the leading handle, which would start a reorder instead).
  Future<void> scrollTo(WidgetTester tester, String label) async {
    final scrollable = find
        .descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 20 && find.text(label).evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -200));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Every menu id in default order — the same list the sheet resolves
  /// against. Distinct from [storedIds], which deliberately projects onto a
  /// handful of ids: a projection is fine for "is this one still present?" but
  /// useless for "where did it land", since it silently closes the gaps left by
  /// the ids it drops.
  List<String> allMenuIds() => [
    'dashboard',
    for (final h in fixture.services.entityRegistry.sidebarTop) h.type.name,
    'reports',
    'activity',
  ];

  List<String> storedFullIds() => [
    for (final e in fixture.services.sidebarMenu.entriesFor(allMenuIds())) e.id,
  ];

  List<String> storedIds() => [
    for (final e in fixture.services.sidebarMenu.entriesFor(const [
      'dashboard',
      'client',
      'invoice',
      'task',
    ]))
      e.id,
  ];

  testWidgets('lists every destination with a drag handle', (tester) async {
    await setUpFixture();
    await pumpEditor(tester);

    expect(find.text('Customize menu'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    // Every destination, not just the module-enabled ones — the list is the
    // full id space `setEntries` writes back.
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(
      list.itemCount,
      fixture.services.entityRegistry.sidebarTop.length + 3,
      reason: 'dashboard + every sidebar entity + reports + activity',
    );
    // A handle and a switch on each built row (the list is lazy).
    final handles = find.byIcon(Icons.drag_indicator);
    expect(handles.evaluate().length, greaterThan(4));
    expect(find.byType(Switch).evaluate().length, handles.evaluate().length);
    // The rows trailing the entity block are reachable by scrolling.
    await scrollTo(tester, 'Activity');
    expect(find.text('Activity'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('dragging a row reorders the menu and persists it', (
    tester,
  ) async {
    await setUpFixture();
    await pumpEditor(tester);

    final before = storedIds();
    final firstHandle = find.byIcon(Icons.drag_indicator).first;
    final gesture = await tester.startGesture(tester.getCenter(firstHandle));
    await tester.pump(const Duration(milliseconds: 100));
    // Far enough to clear two rows, so the assertion doesn't hinge on the exact
    // landing index — only on the first entry no longer being first.
    await gesture.moveBy(const Offset(0, 160));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await _pumpFrames(tester);

    final after = storedIds();
    expect(after.first, isNot(before.first));
    expect(after.toSet(), before.toSet());
    expect(fixture.services.sidebarMenu.hasCustomEntries, isTrue);
    final row = await fixture.db.navStateDao.current();
    expect(row?.sidebarMenuJson, isNotNull);
    await _disposeTree(tester);
  });

  testWidgets('the switch hides a row, and the hidden entry keeps its place', (
    tester,
  ) async {
    // Hiding is a render-time filter, never a delete: the stored entry survives
    // so re-showing puts the row back exactly where the user left it.
    await setUpFixture();
    await pumpEditor(tester);

    final clientsSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('Clients'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(clientsSwitch);
    await _pumpFrames(tester);

    final entries = fixture.services.sidebarMenu.entriesFor(const [
      'dashboard',
      'client',
      'invoice',
    ]);
    final client = entries.firstWhere((e) => e.id == 'client');
    expect(client.visible, isFalse);
    expect(entries.indexOf(client), 1, reason: 'kept its position');
    // Still listed in the editor — hiding is not removing.
    expect(find.text('Clients'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('a module-disabled row is listed, inert, and still written back', (
    tester,
  ) async {
    // Dropping it from the list would take its stored position with it, so a
    // user who re-enabled the module would find it at the bottom of the menu.
    await setUpFixture(enabledModules: _allModulesExceptTasks);
    await pumpEditor(tester);

    await scrollTo(tester, 'Tasks');
    final tasksRow = find.ancestor(
      of: find.text('Tasks'),
      matching: find.byType(ListTile),
    );
    expect(tasksRow, findsOneWidget);
    expect(
      find.descendant(of: tasksRow, matching: find.text('Module disabled')),
      findsOneWidget,
    );
    final tasksSwitch = tester.widget<Switch>(
      find.descendant(of: tasksRow, matching: find.byType(Switch)),
    );
    expect(tasksSwitch.onChanged, isNull, reason: 'inert, not a dead control');

    // Reorder anything, which is what triggers the write-back, then confirm the
    // module-disabled entity survived it.
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 2);
    await _pumpFrames(tester);
    expect(storedIds(), contains('task'));
    await _disposeTree(tester);
  });

  testWidgets('Reset to defaults appears only once something is customized', (
    tester,
  ) async {
    await setUpFixture();
    await pumpEditor(tester);
    expect(find.text('Reset to defaults'), findsNothing);

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 3);
    await _pumpFrames(tester);
    expect(find.text('Reset to defaults'), findsOneWidget);

    await tester.tap(find.text('Reset to defaults'));
    await _pumpFrames(tester);
    expect(fixture.services.sidebarMenu.hasCustomEntries, isFalse);
    expect(storedIds(), const ['dashboard', 'client', 'invoice', 'task']);
    // Reset writes null, so "never customised" and "reset" are the same state.
    final row = await fixture.db.navStateDao.current();
    expect(row?.sidebarMenuJson, isNull);
    await _disposeTree(tester);
  });
  testWidgets('on a phone the editor opens as a bottom sheet whose actions '
      'clear the home indicator', (tester) async {
    // The narrow branch had no coverage at all — every other test in this file
    // runs at the harness's 800x600 window and so always took the dialog. That
    // is why the missing SafeArea went unnoticed: `showModalBottomSheet`
    // defaults to `useSafeArea: false`, so nothing else pays the inset.
    await setUpFixture();
    useNarrowPhone(tester);
    await pumpEditor(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Customize menu'), findsOneWidget);

    final done = find.text('Done');
    expect(done, findsOneWidget);
    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getRect(done).bottom,
      lessThanOrEqualTo(screenBottom - _kHomeIndicator),
      reason:
          'the action row must clear the home indicator. Without the SafeArea '
          'it stops 26 px short of the screen edge — enough for a 24-px '
          'Android gesture bar by two pixels, not for this.',
    );
    await _disposeTree(tester);
  });

  testWidgets('a reorder lands the row exactly where it was dropped', (
    tester,
  ) async {
    // The drag test above only proves the first entry changed. An off-by-one in
    // the `onReorderItem` contract — which hands back a post-removal index, so
    // the body must NOT apply the classic `newIndex--` fix-up — would pass that
    // and fail here.
    await setUpFixture();
    await pumpEditor(tester);

    final before = storedFullIds();
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 2);
    await _pumpFrames(tester);

    final moved = before.first;
    final after = storedFullIds();
    expect(after.indexOf(moved), 2);
    expect(after, [before[1], before[2], moved, ...before.skip(3)]);
    await _disposeTree(tester);
  });

  testWidgets('hiding a row and showing it again leaves nothing customized', (
    tester,
  ) async {
    // Otherwise "Reset to defaults" appears with nothing to do, and the install
    // is frozen out of any later change to the *default* order.
    await setUpFixture();
    await pumpEditor(tester);

    final clientsSwitch = find.descendant(
      of: find.ancestor(
        of: find.text('Clients'),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Switch),
    );
    await tester.tap(clientsSwitch);
    await _pumpFrames(tester);
    expect(fixture.services.sidebarMenu.hasCustomEntries, isTrue);

    await tester.tap(clientsSwitch);
    await _pumpFrames(tester);
    expect(fixture.services.sidebarMenu.hasCustomEntries, isFalse);
    expect((await fixture.db.navStateDao.current())?.sidebarMenuJson, isNull);
    await _disposeTree(tester);
  });
}

/// `pumpAndSettle` is avoided for the same reason the counters card's test
/// avoids it: the fixture holds live Drift watches, so the tree is never
/// "settled".
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tear the subtree down inside the test body so the Drift watches' close
/// timers fire before the binding's end-of-test `!timersPending` check.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
