import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// `GenericListViewModel`'s half of invoiceninja/flutter#106: the active
/// company decides what the custom-field columns are called and whether they
/// exist at all, and that answer has to reach the table AND the Columns picker
/// without either re-deriving it per frame or destroying a user's saved layout.
/// The rows themselves are irrelevant here — this test is about which columns
/// the VM offers, not what they render.
class _Row {
  const _Row();
}

final _kAllColumns = <ColumnDefinition<_Row>>[
  ColumnDefinition<_Row>(
    id: 'name',
    labelKey: 'name',
    cellBuilder: (_, _) => const Text('name'),
  ),
  ...customFieldColumns<_Row>(
    prefix: 'widget',
    ids: const ['custom1', 'custom2', 'custom3', 'custom4'],
    values: [(_) => '', (_) => '', (_) => '', (_) => ''],
  ),
];

class _Vm extends GenericListViewModel<_Row> {
  _Vm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
  });

  int notifications = 0;

  @override
  EntityType get entityType => EntityType.invoice;
  @override
  List<ColumnDefinition<_Row>> get allColumns => _kAllColumns;
  @override
  List<String> get defaultColumnIds => const ['name'];
  @override
  String get defaultSortField => 'name';
  @override
  bool isValidColumnId(String field) =>
      _kAllColumns.any((c) => c.id == field && c.sortable);
  @override
  String idOf(_Row item) => 'r';
  @override
  bool isArchived(_Row item) => false;
  @override
  bool isDeleted(_Row item) => false;
  @override
  Stream<List<_Row>> watchPage() => Stream.value(const [_Row()]);
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

  @override
  void notifyListeners() {
    notifications++;
    super.notifyListeners();
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  _Vm build() {
    final vm = _Vm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Company company(Map<String, String> fields) => Company(customFields: fields);

  test('an unbound VM offers no custom-field columns', () async {
    final vm = build();
    await settle();
    expect(
      [for (final c in vm.availableColumns) c.id],
      ['name'],
      reason: 'no company means no honest header for any slot',
    );
    // The raw registry is untouched — it is still the sort allowlist.
    expect(vm.allColumns, hasLength(5));
  });

  test(
    'binding a company reveals the configured slots under their labels',
    () async {
      final vm = build();
      await settle();
      vm.bindCompany(Stream.value(company(const {'widget1': 'Region'})));
      await settle();

      final ids = [for (final c in vm.availableColumns) c.id];
      expect(ids, ['name', 'custom1']);
      expect(
        vm.availableColumns.firstWhere((c) => c.id == 'custom1').label,
        'Region',
      );
    },
  );

  test('an identical re-emission does not notify', () async {
    final vm = build();
    await settle();
    final controller = StreamController<Company?>();
    addTearDown(controller.close);
    vm.bindCompany(controller.stream);

    controller.add(company(const {'widget1': 'Region'}));
    await settle();
    final after = vm.notifications;

    controller.add(company(const {'widget1': 'Region'}));
    await settle();
    expect(
      vm.notifications,
      after,
      reason: 'the signature is unchanged, so nothing repaints',
    );

    controller.add(company(const {'widget1': 'Region|switch'}));
    await settle();
    expect(
      vm.notifications,
      greaterThan(after),
      reason: 'a type-only change still changes every cell',
    );
  });

  test(
    'un-configuring a slot hides the column but keeps the saved id',
    () async {
      final vm = build();
      await settle();
      final controller = StreamController<Company?>();
      addTearDown(controller.close);
      vm.bindCompany(controller.stream);
      controller.add(company(const {'widget1': 'Region'}));
      await settle();

      await vm.setColumns(const ['name', 'custom1']);
      await settle();
      expect([for (final c in vm.columns) c.id], ['name', 'custom1']);

      // An admin blanks the label in Settings → Custom Fields.
      controller.add(company(const {}));
      await settle();
      expect(
        [for (final c in vm.columns) c.id],
        ['name'],
        reason: 'nothing honest to render',
      );
      expect(
        vm.columnIds,
        ['name', 'custom1'],
        reason: 'the preference survives — this must not be destructive',
      );

      // …and restoring it brings the column back.
      controller.add(company(const {'widget1': 'Region'}));
      await settle();
      expect([for (final c in vm.columns) c.id], ['name', 'custom1']);
    },
  );

  test(
    'a sort on an un-configured slot falls back without being cleared',
    () async {
      // The header strip only renders columns the company can show, so a sort on
      // a slot whose label was blanked leaves the list ordered by an invisible
      // column with nothing to click. `sortField` falls back for the query and
      // the arrow; `_sortField` keeps the user's choice, so restoring the label
      // restores the sort.
      final vm = build();
      await settle();
      final controller = StreamController<Company?>();
      addTearDown(controller.close);
      vm.bindCompany(controller.stream);
      controller.add(company(const {'widget1': 'Region'}));
      await settle();

      await vm.setSort(field: 'custom1', ascending: true);
      await settle();
      expect(vm.sortField, 'custom1');

      controller.add(company(const {}));
      await settle();
      expect(
        vm.sortField,
        'name',
        reason: 'unreachable column — fall back to the default',
      );

      controller.add(company(const {'widget1': 'Region'}));
      await settle();
      expect(
        vm.sortField,
        'custom1',
        reason: 'the preference was never cleared, only overridden',
      );
    },
  );

  test('a sort on a column the user merely hid is left alone', () async {
    // Distinct from the case above and deliberately unchanged: sorting by a
    // column you have un-ticked in the picker is legitimate, and the picker can
    // always put it back.
    final vm = build();
    await settle();
    vm.bindCompany(Stream.value(company(const {'widget1': 'Region'})));
    await settle();

    await vm.setSort(field: 'custom1', ascending: true);
    await vm.setColumns(const ['name']);
    await settle();

    expect([for (final c in vm.columns) c.id], ['name']);
    expect(vm.sortField, 'custom1', reason: 'hidden is not unreachable');
  });

  test(
    'columns are memoized between reads and invalidated on a change',
    () async {
      final vm = build();
      await settle();
      // `columns` is read once per header build, once for the table width, and
      // once per visible row — it must not rebuild the list each time.
      expect(identical(vm.columns, vm.columns), isTrue);

      await vm.setColumns(const ['name']);
      await settle();
      final resolved = vm.columns;
      vm.bindCompany(Stream.value(company(const {'widget1': 'Region'})));
      await settle();
      expect(identical(vm.columns, resolved), isFalse);
    },
  );
}
