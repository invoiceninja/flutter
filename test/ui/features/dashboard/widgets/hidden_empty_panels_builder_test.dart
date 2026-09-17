import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/hidden_empty_panels_builder.dart';

import '../_fake_dashboard_repo.dart';

/// `HiddenEmptyPanelsBuilder` is the one place the dashboard's three panel
/// surfaces learn which panels "Hide empty panels" is leaving out
/// (invoiceninja/flutter#161). Three of its properties are invisible from the
/// surfaces themselves:
///
/// * it follows [DashboardViewModel.emptyPanels] *and* the preference, with
///   automatic resolved against the window (on for a phone only);
/// * it doesn't rebuild its subtree for a change that can't alter its answer —
///   with hiding off, a panel emptying out must not rebuild the dashboard;
/// * it subscribes once per source, so an ordinary parent rebuild after the
///   view model was disposed (the Customize sheet outlives it across a company
///   switch) doesn't call `addListener` on a disposed notifier.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;
  late DashboardViewModel doomed;
  late HideEmptyPanelsController pref;

  DashboardViewModel newVm() => DashboardViewModel(
    repo: repo,
    companyId: 'co',
    navStateDao: db.navStateDao,
    statics: StaticsRepository(
      db: db,
      service: StaticsService(dummyDashboardClient),
    ),
    persistDebounce: const Duration(milliseconds: 1),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    pref = HideEmptyPanelsController(db: db);
    // Built here, outside the widget test's fake-async zone, and allowed to
    // settle — the constructor starts Drift reads.
    vm = newVm();
    doomed = newVm();
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    if (!doomed.isDisposed) doomed.dispose();
    pref.dispose();
    await db.close();
  });

  const phone = Size(390, 844);
  const tablet = Size(800, 1280);

  /// [tick] rebuilds the parent — a fresh `HiddenEmptyPanelsBuilder` widget
  /// with the same sources, which is what every dashboard notify produces.
  Future<List<Set<String>>> pump(
    WidgetTester tester, {
    required Size window,
    DashboardViewModel? model,
    ValueNotifier<int>? tick,
  }) async {
    final calls = <Set<String>>[];
    final rebuild = tick ?? ValueNotifier<int>(0);
    if (tick == null) addTearDown(rebuild.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: window),
          child: ValueListenableBuilder<int>(
            valueListenable: rebuild,
            builder: (context, _, _) => HiddenEmptyPanelsBuilder(
              vm: model ?? vm,
              pref: pref,
              builder: (context, hidden) {
                calls.add(hidden);
                return Text('hidden: ${(hidden.toList()..sort()).join(',')}');
              },
            ),
          ),
        ),
      ),
    );
    return calls;
  }

  Future<void> settle(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 10));

  testWidgets('on a phone, hidden follows the empty panels and the switch', (
    tester,
  ) async {
    await pump(tester, window: phone);
    expect(find.text('hidden: '), findsOneWidget);

    repo.upcomingQuotes.add(const []);
    await settle(tester);
    expect(
      find.text('hidden: ${DashboardKind.upcomingQuotes}'),
      findsOneWidget,
    );

    pref.value = false;
    await settle(tester);
    expect(find.text('hidden: '), findsOneWidget, reason: 'explicitly off');

    pref.value = null;
    await settle(tester);
    expect(
      find.text('hidden: ${DashboardKind.upcomingQuotes}'),
      findsOneWidget,
      reason: 'automatic is on for a phone',
    );
  });

  testWidgets('automatic hides nothing on a tablet; an explicit on does', (
    tester,
  ) async {
    await pump(tester, window: tablet);
    repo.upcomingQuotes.add(const []);
    await settle(tester);
    expect(find.text('hidden: '), findsOneWidget);

    pref.value = true;
    await settle(tester);
    expect(
      find.text('hidden: ${DashboardKind.upcomingQuotes}'),
      findsOneWidget,
    );
  });

  testWidgets('with hiding off, a panel emptying out rebuilds nothing', (
    tester,
  ) async {
    // Off is the default everywhere but a phone, and the builder wraps the
    // whole dashboard body — rebuilding it here would be pure waste.
    final calls = await pump(tester, window: tablet);
    final before = calls.length;

    repo.upcomingQuotes.add(const []);
    repo.expiredQuotes.add(const []);
    await settle(tester);

    expect(calls.length, before);
  });

  testWidgets('a parent rebuild after the view model is disposed is safe', (
    tester,
  ) async {
    // The Customize sheet is opened with the dashboard's view model and
    // outlives it across a company switch. Re-subscribing on every rebuild
    // would now call `addListener` on a disposed notifier and assert.
    final tick = ValueNotifier<int>(0);
    addTearDown(tick.dispose);
    await pump(tester, window: phone, model: doomed, tick: tick);

    doomed.dispose();
    tick.value++;
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('hidden: '), findsOneWidget);
  });
}
