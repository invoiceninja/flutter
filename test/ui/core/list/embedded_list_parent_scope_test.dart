// An embedded related-record list knows its parent's id and nothing else.
// `EmbeddedListParentScope` is how it learns the parent is deleted (no New) or
// not yet synced (New goes through the sync guard) — and the New button and
// the `N` shortcut must agree, which they did not: `N` ignored the
// parent-prefilled create handler and opened a blank form.
//
// Mounts the real scaffold against a real `Services` graph; only the rows
// come from a fake view model. Same harness as
// `entity_list_fab_clearance_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/detail_refresh_scope.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/list/embedded_list_parent_scope.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
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

  /// What the list asked the server for, so a test can tell a scoped page
  /// reload from a company-wide sweep.
  final List<int> pagesFetched = [];
  final List<Map<String, Set<String>>> filtersFetched = [];
  int sweeps = 0;

  @override
  Stream<List<_Row>> watchPage() => Stream.value(const [_Row('i1')]);
  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    pagesFetched.add(page);
    filtersFetched.add(extraFilters);
    return false;
  }

  @override
  Future<void> refreshAll() async => sweeps++;
  @override
  Iterable<BulkAction<_Row>> get bulkActions => const [];
}

/// [EmbeddedListIntents] that can say how many lists are subscribed.
class _CountingIntents extends EmbeddedListIntents {
  int listenerCount = 0;

  @override
  void addListener(VoidCallback listener) {
    listenerCount++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    listenerCount--;
    super.removeListener(listener);
  }
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  /// Mounts one embedded list, optionally under a parent scope. Returns a
  /// counter of how many times the parent-prefilled New handler ran.
  /// The view model of the most recently pumped list.
  late _Vm vm;

  Future<List<int>> pumpList(
    WidgetTester tester, {
    String? parentId,
    bool readOnly = false,
    EmbeddedListIntents? intents,
    DetailRefreshSignal? refresh,
  }) async {
    final created = <int>[];
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme', isAdmin: true)],
    );
    addTearDown(fixture.dispose);

    Widget list = SingleChildScrollView(
      child: EntityListScreenScaffold<_Row, _Vm>(
        titleKey: 'invoices',
        newRoute: '/invoices/new',
        newLabelKey: 'new_invoice',
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitleKey: 'no_invoices_yet',
        wantsFormatter: false,
        embedded: true,
        embeddedNewOverride: (_) => created.add(1),
        buildVm: (services, companyId) => vm = _Vm(
          companyId: companyId,
          navStateDao: services.db.navStateDao,
          userSettings: services.userSettings,
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        ),
        sortOptions: (_) => const [],
        // Something focusable *inside* the list, and not a text field: the
        // list's shortcuts only hear a key when focus is somewhere in its own
        // subtree, and they stand down while the user is typing.
        searchFieldBuilder: (_, _, _) => const Focus(
          autofocus: true,
          child: SizedBox(width: 10, height: 10),
        ),
        tileBuilder: (context, vm, row, index, options) =>
            ListTile(title: Text(row.id)),
        bulkActions: const [],
      ),
    );
    if (parentId != null) {
      list = EmbeddedListParentScope(
        parentId: parentId,
        readOnly: readOnly,
        intents: intents,
        child: list,
      );
    }
    if (refresh != null) {
      list = DetailRefreshScope(signal: refresh, child: list);
    }
    await tester.pumpWidget(wrapWithShell(fixture.services, list));
    await _frames(tester);
    return created;
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  final newButton = find.widgetWithText(FilledButton, 'New');

  testWidgets('with no scope the list behaves as it always did', (
    tester,
  ) async {
    final created = await pumpList(tester);
    await tester.tap(newButton);
    expect(created, hasLength(1));
    await dispose(tester);
  });

  testWidgets('a read-only parent withdraws New — button and shortcut', (
    tester,
  ) async {
    final created = await pumpList(tester, parentId: 'c1', readOnly: true);
    expect(newButton, findsNothing, reason: 'left out, not greyed');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await _frames(tester);
    expect(created, isEmpty);
    await dispose(tester);
  });

  testWidgets('an unsynced parent sends New through the sync guard', (
    tester,
  ) async {
    // A document created against a `tmp_` client would point at an id the
    // server has never seen.
    final created = await pumpList(tester, parentId: 'tmp_1');
    await tester.tap(newButton);
    await _frames(tester);
    expect(created, isEmpty);
    expect(find.textContaining("hasn't synced"), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('N does what the New button does', (tester) async {
    // It used to go to the bare create route, so pressing it on a client's
    // Invoices tab started an invoice for nobody.
    final created = await pumpList(tester, parentId: 'c1');
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await _frames(tester);
    expect(created, hasLength(1));
    await dispose(tester);
  });

  testWidgets('a refresh of the record reloads this list, and only this list', (
    tester,
  ) async {
    // It used to call the list's own `refresh`, which is a sweep of the whole
    // entity: a pull on one client's record downloaded every invoice the
    // company has, a page at a time.
    final refresh = DetailRefreshSignal();
    addTearDown(refresh.dispose);
    await pumpList(tester, parentId: 'c1', refresh: refresh);
    final before = vm.pagesFetched.length;

    refresh.fire();
    await _frames(tester);

    expect(vm.sweeps, 0, reason: 'never the company-wide sweep');
    expect(vm.pagesFetched.skip(before), [1], reason: 'one request: page 1');
    await dispose(tester);
  });

  testWidgets('a filter addressed to the list is applied, once', (
    tester,
  ) async {
    final intents = EmbeddedListIntents();
    addTearDown(intents.dispose);
    await pumpList(tester, parentId: 'c1', intents: intents);

    intents.send(
      EntityType.invoice,
      ListFilterIntent(
        extraFilters: const {
          'overdue': {'true'},
        },
      ),
    );
    await _frames(tester);
    expect(vm.filtersFetched.last['overdue'], {'true'});
    expect(intents.take(EntityType.invoice), isNull, reason: 'collected');

    // One addressed to a different list is left for that list.
    intents.send(EntityType.quote, ListFilterIntent());
    await _frames(tester);
    expect(intents.take(EntityType.quote), isNotNull);
    await dispose(tester);
  });

  testWidgets('a list that has gone stops listening', (tester) async {
    // The removal sat in the wrong branch, so a disposed list stayed
    // subscribed for as long as the record screen lived.
    final intents = _CountingIntents();
    addTearDown(intents.dispose);
    await pumpList(tester, parentId: 'c1', intents: intents);
    expect(intents.listenerCount, 1);
    await dispose(tester);
    expect(intents.listenerCount, 0);
  });
}
