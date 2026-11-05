// invoiceninja/flutter#186: the rows of an embedded list — a record screen's
// Invoices, Quotes, Payments… tab — could be selected, but only the
// standalone list's header showed what to do with them, so nothing did. The
// embedded toolbar now swaps for the same selection row while selecting.
//
// Same harness as `embedded_list_parent_scope_test.dart`: the real scaffold
// against a real `Services` graph, rows from a fake view model.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_list_selection_row.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

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
  });

  final archived = <String>[];

  @override
  EntityType get entityType => EntityType.invoice;
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
  Stream<List<_Row>> watchPage() =>
      Stream.value(const [_Row('i1'), _Row('i2')]);
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
  Iterable<BulkAction<_Row>> get bulkActions => [
    BulkAction<_Row>(
      id: 'archive',
      labelKey: 'archive',
      eligible: (_) => true,
      apply: (id) async => archived.add(id),
    ),
  ];
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _Vm vm;

  Future<void> pumpList(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme', isAdmin: true)],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        SingleChildScrollView(
          child: EntityListScreenScaffold<_Row, _Vm>(
            titleKey: 'invoices',
            newRoute: '/invoices/new',
            newLabelKey: 'new_invoice',
            emptyIcon: Icons.receipt_long_outlined,
            emptyTitleKey: 'no_invoices_yet',
            wantsFormatter: false,
            embedded: true,
            embeddedNewOverride: (_) {},
            buildVm: (services, companyId) => vm = _Vm(
              companyId: companyId,
              navStateDao: services.db.navStateDao,
              userSettings: services.userSettings,
              searchDebounce: const Duration(milliseconds: 1),
              persistDebounce: const Duration(milliseconds: 1),
            ),
            sortOptions: (_) => const [],
            searchFieldBuilder: (_, _, _) => const SizedBox(height: 10),
            tileBuilder: (context, vm, row, index, options) =>
                ListTile(title: Text(row.id)),
            bulkActions: const [
              EntityListBulkAction(
                actionId: 'archive',
                icon: Icons.archive_outlined,
                tooltipKey: 'archive',
                singleSuccessKey: 'archived_invoice',
                pluralSuccessKey: 'archived_invoices',
                nothingKey: 'archive',
              ),
            ],
          ),
        ),
      ),
    );
    await _frames(tester);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  // `skipOffstage: false`: the IndexedStack keeps its hidden child offstage.
  final selectionRow = find.byType(
    EntityListSelectionRow<_Row>,
    skipOffstage: false,
  );

  /// The selection row is stacked under the toolbar at all times (so the
  /// search keeps its state); "shown" means its IndexedStack picks it.
  bool selectionShown(WidgetTester tester) {
    final stack = tester.widget<IndexedStack>(
      find
          .ancestor(of: selectionRow, matching: find.byType(IndexedStack))
          .first,
    );
    return stack.index == 1;
  }

  testWidgets('wide: selecting shows the count and the bulk actions', (
    tester,
  ) async {
    await pumpList(tester, width: 1200);
    expect(selectionShown(tester), isFalse);

    vm.toggleSelected('i1');
    await _frames(tester);
    expect(selectionShown(tester), isTrue);
    expect(find.text('1 selected'), findsOneWidget);
    // Spread inline on a wide row, as labelled buttons.
    expect(find.text('Archive'), findsWidgets);

    // The action runs on the selection, which then clears.
    await tester.tap(find.text('Archive').first);
    await _frames(tester);
    expect(vm.archived, ['i1']);
    expect(vm.isInMultiselect, isFalse);
    expect(selectionShown(tester), isFalse);
    await dispose(tester);
  });

  testWidgets('narrow: a Select button enters selection mode', (tester) async {
    await pumpList(tester, width: 400);
    await tester.tap(find.byTooltip('Select'));
    await _frames(tester);
    expect(vm.isInMultiselect, isTrue);
    expect(selectionShown(tester), isTrue);

    // Select all visible, then the actions are one ⋮ menu.
    await tester.tap(find.byTooltip('Select all visible'));
    await _frames(tester);
    expect(find.text('2 selected'), findsOneWidget);

    // Cancel leaves selection, and the toolbar comes back.
    await tester.tap(find.byTooltip('Cancel'));
    await _frames(tester);
    expect(vm.isInMultiselect, isFalse);
    expect(selectionShown(tester), isFalse);
    await dispose(tester);
  });
}
