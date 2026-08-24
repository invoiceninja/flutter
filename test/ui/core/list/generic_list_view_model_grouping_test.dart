// Grouping state on `GenericListViewModel` (issue #56).
//
// The persistence half matters more than it looks: `groupField` /
// `collapsedGroups` live in the same `nav_state.filters_json` blob as every
// other filter dimension, and `SavedViewsRepository.matchingView` /
// `_lastSeenSlot` both DEEP-COMPARE that blob. So an ungrouped snapshot has
// to stay byte-identical to the pre-grouping shape, or every saved view a
// user already has silently stops matching.

import 'dart:async';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  const _Row(this.id, this.group);
  final String id;
  final String group;
}

final _columns = <ColumnDefinition<_Row>>[
  ColumnDefinition(
    id: 'name',
    labelKey: 'name',
    cellBuilder: (r, _) => Text(r.id),
  ),
];

class _GroupedVm extends GenericListViewModel<_Row> {
  _GroupedVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.persistDebounce,
  });

  List<_Row> rows = const [
    _Row('a', 'Hardware'),
    _Row('b', 'Hardware'),
    _Row('c', 'Software'),
  ];

  @override
  EntityType get entityType => EntityType.product;
  @override
  List<ColumnDefinition<_Row>> get allColumns => _columns;
  @override
  List<String> get defaultColumnIds => const ['name'];
  @override
  String get defaultSortField => 'name';
  @override
  bool isValidColumnId(String field) => field == 'name';
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

  // Mirrors what ProductListViewModel does: hide rows whose group is folded.
  @override
  bool isRowHidden(int index) =>
      groupField != null && isGroupCollapsed(rows[index].group);
  @override
  bool get hasHiddenRows => groupField != null && collapsedGroups.isNotEmpty;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  _GroupedVm build() => _GroupedVm(
    companyId: 'co',
    navStateDao: db.navStateDao,
    userSettings: UserSettingsRepository(db: db),
    persistDebounce: const Duration(milliseconds: 1),
  );

  test('an ungrouped snapshot is byte-identical to the pre-grouping shape', () {
    final vm = build();
    // The exact six keys `currentSnapshot()` carried before #56. A seventh
    // key at its default would break saved-view deep equality for every view
    // a user saved before upgrading.
    expect(vm.currentSnapshot().keys.toSet(), {
      'search',
      'states',
      'sortField',
      'sortAscending',
      'customFilters',
      'extraFilters',
    });
    vm.dispose();
  });

  test('grouping keys appear only once set', () async {
    final vm = build();
    await settle();

    await vm.setGroupField('custom1');
    expect(vm.currentSnapshot()['groupField'], 'custom1');
    expect(vm.currentSnapshot().containsKey('collapsedGroups'), isFalse);

    vm.toggleGroupCollapsed('Hardware');
    expect(vm.currentSnapshot()['collapsedGroups'], ['Hardware']);
    vm.dispose();
  });

  test('a blob written before grouping existed hydrates to defaults', () {
    final vm = build();
    vm.applySnapshot(<String, dynamic>{
      'search': 'widget',
      'states': ['active'],
      'sortField': 'name',
      'sortAscending': true,
      'customFilters': <String, dynamic>{},
      'extraFilters': <String, dynamic>{},
    });
    expect(vm.groupField, isNull);
    expect(vm.collapsedGroups, isEmpty);
    expect(vm.search, 'widget');
    vm.dispose();
  });

  test('a snapshot round-trips grouping + collapse', () async {
    final vm = build();
    await settle();
    await vm.setGroupField('custom2');
    vm.toggleGroupCollapsed('Hardware');
    final snap = vm.currentSnapshot();

    final other = build();
    await other.applySnapshot(snap);
    expect(other.groupField, 'custom2');
    expect(other.collapsedGroups, {'Hardware'});
    vm.dispose();
    other.dispose();
  });

  test(
    'applying a snapshot resets grouping when the snapshot omits it',
    () async {
      final vm = build();
      await settle();
      await vm.setGroupField('custom1');
      vm.toggleGroupCollapsed('Hardware');

      // A "clean" saved view must not inherit yesterday's grouping — the same
      // reset-first invariant every other dimension follows.
      await vm.applySnapshot(<String, dynamic>{'search': ''});
      expect(vm.groupField, isNull);
      expect(vm.collapsedGroups, isEmpty);
      vm.dispose();
    },
  );

  test('changing the group clears the folded set', () async {
    final vm = build();
    await settle();
    await vm.setGroupField('custom1');
    vm.toggleGroupCollapsed('Hardware');
    expect(vm.collapsedGroups, isNotEmpty);

    // "Hardware" means nothing under a different dimension.
    await vm.setGroupField('tags');
    expect(vm.collapsedGroups, isEmpty);
    vm.dispose();
  });

  test('selectAllVisible skips rows inside a collapsed group', () async {
    final vm = build();
    await settle();
    await vm.setGroupField('custom1');
    vm.toggleGroupCollapsed('Hardware');

    vm.enterSelectionMode();
    vm.selectAllVisible();
    // Folding a group away then tapping select-all must not sweep the hidden
    // records into a bulk delete.
    expect(vm.selectedItems.map((r) => r.id), ['c']);
    vm.dispose();
  });

  test('hasHiddenRows tracks the folded set', () async {
    final vm = build();
    await settle();
    expect(vm.hasHiddenRows, isFalse);
    await vm.setGroupField('custom1');
    expect(vm.hasHiddenRows, isFalse);
    vm.toggleGroupCollapsed('Hardware');
    expect(vm.hasHiddenRows, isTrue);
    vm.toggleGroupCollapsed('Hardware');
    expect(vm.hasHiddenRows, isFalse);
    vm.dispose();
  });
}
