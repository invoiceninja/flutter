// invoiceninja/flutter#163: pull-to-refresh "works everywhere else" but did
// nothing on Quotes (Android beta). Nothing about Quotes was special — the
// reporter simply had fewer quotes than fill a phone screen, and every
// standalone entity list refused the pull at that length.
//
// `EntityListScreenScaffold` hands its `ListView` a `ScrollController` (the
// load-more trigger), and `ScrollView` only defaults a vertical list to
// `AlwaysScrollableScrollPhysics` when it has NO controller. The platform
// physics it fell back to refuse a drag on content that fits the viewport,
// and `RefreshIndicator` only ever starts on a drag. See
// `docs/pull-to-refresh.md`.
//
// This mounts the real scaffold against a real `Services` graph — the list
// view, its controller and its `RefreshIndicator` are exactly what ships; only
// the rows come from a fake view model.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

import '../../features/shell/_shell_test_helpers.dart';

class _Row {
  const _Row(this.id);
  final String id;
}

final _cols = <ColumnDefinition<_Row>>[
  ColumnDefinition(id: 'id', labelKey: 'id', cellBuilder: (r, _) => Text(r.id)),
];

class _Vm extends GenericListViewModel<_Row> {
  _Vm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    required super.searchDebounce,
    required super.persistDebounce,
    required this.rows,
  });

  final List<_Row> rows;

  /// How many times pull-to-refresh reached the view model.
  int refreshCalls = 0;

  /// Quotes, because that is the list #163 was reported on — it also puts the
  /// real status-tab strip above the rows, as on the device.
  @override
  EntityType get entityType => EntityType.quote;
  @override
  List<ColumnDefinition<_Row>> get allColumns => _cols;
  @override
  List<String> get defaultColumnIds => const ['id'];
  @override
  String get defaultSortField => 'id';
  @override
  bool isValidColumnId(String field) => field == 'id';
  @override
  String idOf(_Row item) => item.id;
  @override
  bool isArchived(_Row item) => false;
  @override
  bool isDeleted(_Row item) => false;
  @override
  Stream<List<_Row>> watchPage() => Stream.value(rows);
  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async => false;
  @override
  Future<void> refreshAll() async {
    refreshCalls++;
  }

  @override
  Iterable<BulkAction<_Row>> get bulkActions => const [];
}

void main() {
  /// Mounts the standalone list on a phone-sized window and returns its VM.
  Future<_Vm> pumpList(WidgetTester tester, {required int rowCount}) async {
    // `tester.view`, not `setSurfaceSize`: the latter leaves `MediaQuery` at
    // 800x600, which would put the scaffold on its wide (tablet) branch.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // `addTearDown` from inside the test body: the fixture's `Services` keep
    // timers running, and the binding's pending-Timer assertion fires before
    // a top-level `tearDown` would get the chance to stop them.
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);

    _Vm? vm;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        EntityListScreenScaffold<_Row, _Vm>(
          titleKey: 'quotes',
          newRoute: '/quotes/new',
          newLabelKey: 'new_quote',
          emptyIcon: Icons.request_quote_outlined,
          emptyTitleKey: 'no_quotes_yet',
          wantsFormatter: false,
          buildVm: (services, companyId) => vm = _Vm(
            companyId: companyId,
            navStateDao: services.db.navStateDao,
            userSettings: services.userSettings,
            searchDebounce: const Duration(milliseconds: 1),
            persistDebounce: const Duration(milliseconds: 1),
            rows: [for (var i = 0; i < rowCount; i++) _Row('q$i')],
          ),
          sortOptions: (_) => const [],
          searchFieldBuilder: (_, _, _) => const SizedBox.shrink(),
          tileBuilder: (context, vm, row, index, options) =>
              ListTile(title: Text(row.id)),
          bulkActions: const [],
        ),
      ),
    );
    await _pumpFrames(tester);
    return vm!;
  }

  /// A downward fling from [from], then enough time for the indicator to
  /// snap, call `onRefresh`, and hide again.
  Future<void> pullDown(WidgetTester tester, Finder from) async {
    await tester.fling(from, const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // the scroll settles
    await tester.pump(const Duration(seconds: 1)); // the indicator snaps
    await tester.pump(const Duration(seconds: 1)); // the indicator hides
  }

  testWidgets(
    'a list shorter than the screen still pulls to refresh (#163)',
    (tester) async {
      final vm = await pumpList(tester, rowCount: 2);
      expect(find.text('q1'), findsOneWidget);

      await pullDown(tester, find.text('q0'));

      expect(
        vm.refreshCalls,
        1,
        reason:
            'two rows fit the viewport, so the list only accepts a drag when '
            'its physics are AlwaysScrollableScrollPhysics — passing a '
            'ScrollController switches that default off',
      );
      await _disposeTree(tester);
    },
    // The two arm differently — clamping reports the pull as an overscroll,
    // bouncing as a scroll past the top — so pin both.
    variant: TargetPlatformVariant(const <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('an empty list pulls to refresh', (tester) async {
    final vm = await pumpList(tester, rowCount: 0);
    expect(find.byType(EmptyState), findsOneWidget);

    await pullDown(tester, find.byType(EmptyState));

    expect(vm.refreshCalls, 1);
    await _disposeTree(tester);
  });

  testWidgets('a list longer than the screen pulls to refresh', (tester) async {
    // The control: proves this harness can drive a refresh at all, so a red
    // short-list case is about the physics rather than the fling.
    final vm = await pumpList(tester, rowCount: 30);

    await pullDown(tester, find.text('q0'));

    expect(vm.refreshCalls, 1);
    await _disposeTree(tester);
  });

  testWidgets('the physics wrap the platform physics rather than replace '
      'them', (tester) async {
    await pumpList(tester, rowCount: 2);

    final list = tester.widget<ListView>(
      find.descendant(
        of: find.byType(RefreshIndicator),
        matching: find.byType(ListView),
      ),
    );
    expect(list.controller, isNotNull, reason: 'the load-more trigger');
    // A bare `AlwaysScrollableScrollPhysics` has no parent, so `Scrollable`
    // applies it on top of the platform's own (clamping / bouncing). A
    // hard-coded `ClampingScrollPhysics(parent: ...)` here would take the
    // bounce away from iOS.
    expect(list.physics, isA<AlwaysScrollableScrollPhysics>());
    expect(list.physics!.parent, isNull);
    await _disposeTree(tester);
  });
}

/// `pumpAndSettle` never returns here: the scaffold holds live Drift watches
/// (the company row, the status tabs' counts), so the tree is never "settled".
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tear the subtree down inside the test body so the Drift watches' close
/// timers (`StreamQueryStore.markAsClosed` schedules a zero-duration Timer on
/// unsubscribe) fire before the binding's end-of-test `!timersPending` check.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
