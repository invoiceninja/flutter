// invoiceninja/flutter#167: the create `+` sat on top of the last entry of
// every entity list, and no amount of scrolling freed it. On a narrow row the
// trailing edge is where the `⋮` overflow menu lives, so the last record's
// whole action menu was unreachable — the reporter's screenshot is the Quotes
// list, with the button over the row's amount, its status pill and its `⋮`.
//
// `Scaffold` does not inset its body for the FAB, and the scaffold's
// `ListView.builder` passed no `padding:` at all, so the rows ended flush with
// the viewport. The `itemCount: items.length + 1` footer slot does not help:
// it is a spinner while a page is in flight and `SizedBox.shrink()` otherwise.
//
// This mounts the real scaffold against a real `Services` graph — the list
// view, its controller, its FAB and its padding are exactly what ships; only
// the rows come from a fake view model. Same harness as
// `entity_list_pull_to_refresh_test.dart` (#163, on the very same list).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/utils/fab_clearance.dart';

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

  /// Quotes, because that is the list #167 was reported on.
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
  Future<void> refreshAll() async {}

  @override
  Iterable<BulkAction<_Row>> get bulkActions => const [];
}

void main() {
  /// Mounts the list on a phone-sized window, optionally with a bottom safe
  /// inset, and returns nothing — the tests measure the tree.
  Future<void> pumpList(
    WidgetTester tester, {
    required int rowCount,
    bool embedded = false,
    double bottomInset = 0,
  }) async {
    // `tester.view`, not `setSurfaceSize`: the latter leaves `MediaQuery` at
    // 800x600, which would put the scaffold on its wide branch — where there
    // is no FAB and so nothing to clear.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = FakeViewPadding(bottom: bottomInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);

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
          embedded: embedded,
          buildVm: (services, companyId) => _Vm(
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
  }

  /// The list the scaffold builds for its rows.
  ListView listOf(WidgetTester tester) => tester.widget<ListView>(
    find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(ListView),
    ),
  );

  testWidgets('the last row scrolls clear of the FAB', (tester) async {
    await pumpList(tester, rowCount: 30);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // To the very end of the list.
    await tester.fling(find.text('q0'), const Offset(0, -4000), 4000);
    await _pumpFrames(tester);
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 4000);
    await _pumpFrames(tester);

    // Load-bearing, not a sanity check: measuring the last row anywhere short
    // of the bottom would let it clear the FAB for the wrong reason, and this
    // test would keep passing while the bug came back.
    final position = listOf(tester).controller!.position;
    expect(
      position.pixels,
      position.maxScrollExtent,
      reason: 'the assertion below is only meaningful at rest at the bottom',
    );

    // The row, not its label: the tile is a 72 px-min box and the `⋮` this
    // exists to protect is centred in it, so the text's rect would report a
    // gap that is mostly the tile's own padding.
    final last = find.widgetWithText(ListTile, 'q29');
    expect(last, findsOneWidget, reason: 'scrolled to the end of the list');

    // The actual bug: the last row overlapping the button.
    expect(
      tester.getRect(last).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(FloatingActionButton)).top),
      reason:
          'the last row must come to rest above the FAB, or its `⋮` menu is '
          'unreachable at every scroll offset (#167)',
    );
    await _disposeTree(tester);
  });

  testWidgets('the padding is the shared clearance, inset included', (
    tester,
  ) async {
    await pumpList(tester, rowCount: 30, bottomInset: 34);
    expect(
      listOf(tester).padding,
      EdgeInsets.only(bottom: kFabClearance + InSpacing.sm + 34),
      reason:
          'an explicit padding switches off BoxScrollView own MediaQuery '
          'consumption, so the safe inset has to be carried here',
    );
    await _disposeTree(tester);
  });

  testWidgets('an embedded list keeps a null padding', (tester) async {
    // Embedded lists shrink-wrap into a detail page and have no Scaffold and
    // no FAB. `null` (not `EdgeInsets.zero`) is what lets `BoxScrollView` keep
    // applying the safe inset for itself.
    await pumpList(tester, rowCount: 5, embedded: true);
    final list = tester.widget<ListView>(find.byType(ListView).first);
    expect(list.padding, isNull);
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
/// timers fire before the binding's end-of-test `!timersPending` check.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
