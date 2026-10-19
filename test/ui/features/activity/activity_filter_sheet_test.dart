import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/ui/core/widgets/multi_entity_picker.dart';
import 'package:admin/ui/features/activity/view_models/activity_view_model.dart';
import 'package:admin/ui/features/activity/widgets/activity_filter_sheet.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';
import '../dashboard/_fake_dashboard_repo.dart';

/// Layout coverage for the `/activity` filter surface — which had none at all
/// until the lens (invoiceninja/flutter#120) replaced its `SwitchListTile` with
/// a three-segment `SegmentedButton`. A switch cannot overflow; three labelled
/// segments in a 320 px sheet at `kTextScaleMax` can, and
/// `SegmentedButton` does not wrap.
class _FakeUserRepo implements UserRepository {
  // `Stream.multi`, not `Stream.value`: the sheet's `StreamBuilder`
  // re-subscribes on every rebuild and a single-subscription stream throws the
  // second time.
  @override
  Stream<List<User>> watchAllForPicker({required String companyId}) =>
      Stream<List<User>>.multi((c) {
        c.add(const <User>[]);
        c.close();
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  @override
  late final UserRepository user = _FakeUserRepo();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late ActivityViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = ActivityViewModel(repo: repo, companyId: 'co');
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> open(
    WidgetTester tester, {
    required double width,
    double textScale = 1.0,
  }) async {
    // `tester.view`, not `pumpAt`'s `setSurfaceSize`: `InSpacing.*` reads
    // `MediaQuery.sizeOf`, which `setSurfaceSize` does not move.
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openActivityFilters(context, vm: vm, companyId: 'co'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the three-segment lens survives a 320 px sheet at the maximum '
      'text scale', (tester) async {
    await open(tester, width: 320, textScale: kTextScaleMax);
    expectNoOverflow(tester);
    expect(find.text('Calls'), findsOneWidget);
  });

  testWidgets('the lens is reachable on the wide dialog branch too', (
    tester,
  ) async {
    await open(tester, width: 900, textScale: kTextScaleMax);
    expectNoOverflow(tester);
    expect(find.text('Calls'), findsOneWidget);
  });

  testWidgets('the narrow sheet can still reach Calls, by scrolling', (
    tester,
  ) async {
    // The direct regression test for the horizontal-scroll wrapper. Without it
    // the third segment lays out at x≈354 on a 320 px sheet — off-screen and
    // un-hit-testable — which is how `debug_panel_section.dart` learned the
    // same lesson for its own three-segment filter.
    await open(tester, width: 320);
    await tester.dragUntilVisible(
      find.text('Calls'),
      find.byType(SegmentedButton<ActivityLens>),
      const Offset(-60, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();
    expect(vm.filters.lens, ActivityLens.calls);
  });

  testWidgets('picking Calls narrows the lens and dims the type picker', (
    tester,
  ) async {
    await open(tester, width: 900);
    expect(vm.filters.lens, ActivityLens.all);

    await tester.tap(find.text('Calls'));
    await tester.pumpAndSettle();

    expect(vm.filters.lens, ActivityLens.calls);
    // The type picker is dimmed and inert under any narrowed lens — the
    // predicate agrees (`ActivityViewModel.matches` skips `typeIds` unless the
    // lens is `all`), so a live picker here would silently discard the choice.
    final dimmed = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(MultiEntityPicker<ActivityTypeOption>),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(dimmed.opacity, lessThan(1.0));
  });

  group('category chips', () {
    DashboardActivity row(String id, int type) => DashboardActivity.fromJson({
      'id': id,
      'activity_type_id': type,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'notes': '',
    });

    testWidgets('carry their counts and toggle the filter', (tester) async {
      repo.activities.add([row('a', 6), row('b', 6), row('c', 10)]);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await open(tester, width: 900);

      final sent = find.widgetWithText(FilterChip, 'Sent  2');
      expect(sent, findsOneWidget);
      await tester.tap(sent);
      await tester.pumpAndSettle();
      expect(vm.filters.categories, {ActivityCategory.sent});
    });

    testWidgets('a chip that could only empty the feed is disabled', (
      tester,
    ) async {
      repo.activities.add([row('a', 6)]);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await open(tester, width: 900);

      final viewed = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Viewed  0'),
      );
      expect(viewed.onSelected, isNull);
    });
  });

  testWidgets('a held range can be cleared from the panel', (tester) async {
    vm.setRange(DateTime(2026, 6, 7), DateTime(2026, 6, 8));
    await open(tester, width: 900);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(vm.filters.hasRange, isFalse);
  });
}
