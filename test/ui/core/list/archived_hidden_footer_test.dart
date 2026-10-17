// The line under a searched or filtered list that says archived records were
// left out. Beta report: "There is no Active / Archived / Deleted choices in
// the new version" — a client search found four drafts and nothing said the
// archived invoices it was looking for had been hidden, because the no-match
// empty state (the only place Show archived lived) needs zero rows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/archived_hidden_footer.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

import '../../../_localization_helper.dart';
import '../../features/shell/_shell_test_helpers.dart';

/// Just the members [ArchivedHiddenFooter] reads; anything else is a bug in
/// the widget and throws.
class _FakeVm implements GenericListViewModel<dynamic> {
  _FakeVm({
    this.items = const ['a'],
    this.isLoadingPage = false,
    this.canLoadMore = false,
    this.states = const {EntityState.active},
    this.search = 'acme',
    this.extraFilters = const {},
    this.hasEntityStates = true,
  });

  @override
  final List<dynamic> items;
  @override
  bool isLoadingPage;
  @override
  final bool canLoadMore;
  @override
  final Set<EntityState> states;
  @override
  final String search;
  @override
  final Map<String, Set<String>> extraFilters;
  @override
  final bool hasEntityStates;

  Set<EntityState>? statesSet;

  @override
  Future<void> setStates(Set<EntityState> next) async => statesSet = next;

  /// The base's rule: `{active}` is no state filter.
  @override
  bool get hasActiveFilters =>
      states.length != 1 ||
      !states.contains(EntityState.active) ||
      extraFilters.values.any((v) => v.isNotEmpty) ||
      search.isNotEmpty;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected VM call: ${invocation.memberName}');
}

void main() {
  group('shows', () {
    test('at the end of a searched, active-only list', () {
      expect(ArchivedHiddenFooter.shows(_FakeVm()), isTrue);
    });

    test('on a status tab with no search — Paid is where archived '
        'invoices go', () {
      final vm = _FakeVm(
        search: '',
        extraFilters: const {
          'badge_mode': {'paid'},
        },
      );
      expect(ArchivedHiddenFooter.shows(vm), isTrue);
    });

    test('when deleted is shown but archived is not', () {
      final vm = _FakeVm(
        search: '',
        states: const {EntityState.active, EntityState.deleted},
      );
      expect(ArchivedHiddenFooter.shows(vm), isTrue);
    });
  });

  group('hidden', () {
    test('once archived is shown', () {
      final vm = _FakeVm(
        states: const {EntityState.active, EntityState.archived},
      );
      expect(ArchivedHiddenFooter.shows(vm), isFalse);
    });

    test('while more rows can load — their absence says nothing yet', () {
      expect(ArchivedHiddenFooter.shows(_FakeVm(canLoadMore: true)), isFalse);
    });

    test('while a page is loading', () {
      expect(ArchivedHiddenFooter.shows(_FakeVm(isLoadingPage: true)), isFalse);
    });

    test('on an empty list — that is the no-match empty state', () {
      expect(ArchivedHiddenFooter.shows(_FakeVm(items: const [])), isFalse);
    });

    test('on a list nobody narrowed — a short list would carry it forever', () {
      expect(ArchivedHiddenFooter.shows(_FakeVm(search: '')), isFalse);
    });

    test('on a list with no lifecycle (Documents)', () {
      expect(
        ArchivedHiddenFooter.shows(_FakeVm(hasEntityStates: false)),
        isFalse,
      );
    });
  });

  Future<void> pumpFooter(WidgetTester tester, _FakeVm vm) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: ArchivedHiddenFooter(vm: vm)),
    ),
  );

  testWidgets('Show archived adds archived and keeps what else was shown', (
    tester,
  ) async {
    final vm = _FakeVm(states: const {EntityState.active, EntityState.deleted});
    await pumpFooter(tester, vm);
    expect(find.text('Archived records are hidden'), findsOneWidget);
    await tester.tap(find.text('Show archived'));
    expect(vm.statesSet, {
      EntityState.active,
      EntityState.deleted,
      EntityState.archived,
    });
  });

  testWidgets('wraps at phone width instead of overflowing', (tester) async {
    // 320 px less the 16 px gutters can't hold the sentence and the button on
    // one line, so this exercises the second run.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpFooter(tester, _FakeVm());
    final text = tester.getRect(find.text('Archived records are hidden'));
    final button = tester.getRect(find.byType(OutlinedButton));
    expect(button.top, greaterThanOrEqualTo(text.bottom));
    expect(tester.takeException(), isNull);
  });

  group('the list scaffold puts it under the last row', () {
    testWidgets('a searched list that reached its end shows it; Show archived '
        'takes it away', (tester) async {
      final vm = await _pumpList(tester, hasMore: false);
      expect(
        find.byType(ArchivedHiddenFooter),
        findsNothing,
        reason: 'nobody narrowed the list yet',
      );

      vm.setSearch('q', immediate: true);
      await _pumpFrames(tester);
      expect(find.byType(ArchivedHiddenFooter), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(ArchivedHiddenFooter)).dy,
        greaterThan(tester.getBottomLeft(find.text('q1')).dy - 1),
        reason: 'the footer slot follows the last row',
      );

      await tester.tap(find.text('Show archived'));
      await _pumpFrames(tester);
      expect(vm.states, contains(EntityState.archived));
      expect(find.byType(ArchivedHiddenFooter), findsNothing);
      await _disposeTree(tester);
    });

    testWidgets('not while the server has another page', (tester) async {
      final vm = await _pumpList(tester, hasMore: true);
      vm.setSearch('q', immediate: true);
      await _pumpFrames(tester);
      expect(find.text('q1'), findsOneWidget);
      expect(find.byType(ArchivedHiddenFooter), findsNothing);
      await _disposeTree(tester);
    });
  });
}

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
    required this.hasMoreOnServer,
  });

  final bool hasMoreOnServer;

  static const _rows = [_Row('q0'), _Row('q1')];

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
  Stream<List<_Row>> watchPage() => Stream.value(_rows);
  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async => hasMoreOnServer;
  @override
  Future<void> refreshAll() async {}
  @override
  Iterable<BulkAction<_Row>> get bulkActions => const [];
}

/// Mounts the real standalone list scaffold on a phone-sized window, the same
/// way `entity_list_pull_to_refresh_test.dart` does.
Future<_Vm> _pumpList(WidgetTester tester, {required bool hasMore}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fixture = await buildFixture(
    companies: const [FakeCompany(id: 'co1', name: 'Acme')],
  );
  addTearDown(fixture.dispose);

  _Vm? vm;
  await tester.pumpWidget(
    wrapWithShell(
      fixture.services,
      EntityListScreenScaffold<_Row, _Vm>(
        titleKey: 'invoices',
        newRoute: '/invoices/new',
        newLabelKey: 'new_invoice',
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitleKey: 'no_invoices_yet',
        wantsFormatter: false,
        buildVm: (services, companyId) => vm = _Vm(
          companyId: companyId,
          navStateDao: services.db.navStateDao,
          userSettings: services.userSettings,
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
          hasMoreOnServer: hasMore,
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

/// `pumpAndSettle` never returns: the scaffold holds live Drift watches.
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lets the Drift watches' close timers fire inside the test body.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
