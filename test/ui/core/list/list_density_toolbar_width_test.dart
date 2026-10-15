import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/list_density_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';
import 'package:admin/ui/core/list/entity_list_app_bar.dart';
import 'package:admin/ui/core/list/entity_list_top_row.dart';
import 'package:admin/ui/core/list/list_density_scope.dart';
import 'package:admin/ui/core/list/list_density_toggle.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/tasks/widgets/tasks_view_toggle.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';
import 'search/_token_search_harness.dart';

/// The density toggle beside the wide toolbar's Columns button costs the
/// search field 44 px with a pointer (36 + 8 gap), and the toolbar has none to
/// spare at its narrowest: at a 600 px pane a plain list's field is 100 px, and
/// the Tasks toolbar — five view segments on top — overflows before the toggle
/// exists. So the toggle is gated on the room its slot is actually left
/// (`kDensityToggleMinSearchWidth`), never on a pane breakpoint: one breakpoint
/// would either hide it on a laptop-width Invoices list or starve Tasks.
///
/// Measured (macOS, no sidebar), search-field width per pane width:
///  * plain list: pane − 500 without the toggle, pane − 544 with it;
///  * Tasks: overflows at every pane ≤ 760 with or without the toggle — a
///    separate, pre-existing bug this test deliberately does not pin.
void main() {
  late AppDatabase db;
  late ListDensityController density;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    density = ListDensityController(prefs: prefs);
  });
  tearDown(() async {
    density.dispose();
    await db.close();
  });

  final pointer = TargetPlatformVariant.only(TargetPlatform.macOS);

  Finder toggle() => find.byType(ListDensityToggle);
  double fieldWidth(WidgetTester tester) =>
      tester.getSize(find.byType(TokenSearchField)).width;

  Future<void> pumpToolbar(
    WidgetTester tester, {
    required double width,
    bool scoped = true,
    bool tasks = false,
  }) async {
    final vm = newHarnessVm(db);
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, inner) => scoped
            ? ListDensityScope(controller: density, child: inner!)
            : inner!,
        home: Provider<Services>.value(
          value: FakeSearchServices(),
          child: Scaffold(
            appBar: EntityListAppBar<dynamic>(
              vm: vm,
              wide: true,
              selecting: false,
              maxExtent: EntityListAppBar.maxExtentFor(
                wide: true,
                available: 700,
              ),
              titleKey: 'tasks',
              newRoute: '/tasks/new',
              newLabelKey: 'new_task',
              sortOptions: const [],
              searchField: TokenSearchField(
                vm: vm,
                filterKeys: [FruitKey()],
                wide: true,
                hintKey: 'search',
              ),
              extraActions: tasks
                  ? const [
                      TasksViewToggle(active: TasksViewMode.list, wide: true),
                    ]
                  : const [],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the view model's debounced `nav_state` write fire before teardown.
  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  for (final width in [600.0, 700.0, 760.0, 800.0, 1000.0, 1400.0]) {
    testWidgets('a plain list never overflows, and the toggle only shows with '
        'room to spare (pane $width)', (tester) async {
      await pumpToolbar(tester, width: width);
      expect(tester.takeException(), isNull);
      if (toggle().evaluate().isNotEmpty) {
        expect(fieldWidth(tester), greaterThanOrEqualTo(200));
      } else {
        // Hidden only because showing it would have pushed the field under
        // the floor.
        expect(
          fieldWidth(tester),
          lessThan(
            kDensityToggleMinSearchWidth +
                listDensityToggleSize() +
                InSpacing.sm,
          ),
        );
      }
      await settle(tester);
    }, variant: pointer);
  }

  testWidgets('a plain list shows the toggle on a laptop-width pane', (
    tester,
  ) async {
    await pumpToolbar(tester, width: 800);
    expect(toggle(), findsOneWidget);
    await settle(tester);
  }, variant: pointer);

  testWidgets('Tasks keeps its search field until the toggle can fit too', (
    tester,
  ) async {
    // 1000 px: the five view segments leave the field 208 px — the toggle
    // would take it under the floor, so it stands down and costs nothing.
    await pumpToolbar(tester, width: 1000, tasks: true);
    expect(toggle(), findsNothing);
    final hidden = fieldWidth(tester);
    await settle(tester);

    await pumpToolbar(tester, width: 1000, tasks: true, scoped: false);
    expect(fieldWidth(tester), hidden);
    await settle(tester);

    await pumpToolbar(tester, width: 1200, tasks: true);
    expect(toggle(), findsOneWidget);
    expect(fieldWidth(tester), greaterThanOrEqualTo(200));
    await settle(tester);
  }, variant: pointer);

  testWidgets('with no scope the toolbar is exactly what it was', (
    tester,
  ) async {
    // Every other toolbar test mounts no scope; the slot must not move a pixel
    // for them. A plain list's field was pane − 500 before the toggle existed.
    await pumpToolbar(tester, width: 800, scoped: false);
    expect(toggle(), findsNothing);
    expect(fieldWidth(tester), 300);
    await settle(tester);
  }, variant: pointer);
}
