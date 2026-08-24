// Locks down the non-breaking `BulkAction.applyArg` + `applyBulkAction(arg:)`
// extension added for prep-dialog bulk actions (bulk email / run-template /
// assign-group). Guarantees:
//   * `applyArg` takes precedence over `apply` and receives the threaded arg
//   * `apply`-only actions still work (legacy callers unchanged)
//   * eligibility / skipped accounting is unaffected by the new path

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
  const _Row(this.id, {this.deleted = false});
  final String id;
  final bool deleted;
}

final _cols = <ColumnDefinition<_Row>>[
  ColumnDefinition(id: 'id', labelKey: 'id', cellBuilder: (r, _) => Text(r.id)),
];

class _Vm extends GenericListViewModel<_Row> {
  _Vm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  final List<_Row> _stub = const [
    _Row('a'),
    _Row('b'),
    _Row('c', deleted: true),
  ];

  final List<String> applyIds = [];
  final List<(String, Object?)> applyArgCalls = [];

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
  bool isDeleted(_Row item) => item.deleted;
  @override
  Stream<List<_Row>> watchPage() => Stream.value(_stub);
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
      id: 'plain',
      labelKey: 'plain',
      eligible: (r) => !r.deleted,
      apply: (id) async => applyIds.add(id),
    ),
    BulkAction<_Row>(
      id: 'prep',
      labelKey: 'prep',
      eligible: (r) => !r.deleted,
      // Both supplied — applyArg must win.
      apply: (id) async => applyIds.add('SHOULD_NOT_RUN'),
      applyArg: (id, arg) async => applyArgCalls.add((id, arg)),
    ),
  ];
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  _Vm build() => _Vm(
    companyId: 'co',
    navStateDao: db.navStateDao,
    userSettings: UserSettingsRepository(db: db),
    searchDebounce: const Duration(milliseconds: 1),
    persistDebounce: const Duration(milliseconds: 1),
  );

  test('apply-only action runs the legacy path unchanged', () async {
    final vm = build();
    await settle();
    vm.toggleSelected('a');
    vm.toggleSelected('b');
    vm.toggleSelected('c'); // ineligible (deleted)
    final r = await vm.applyBulkAction(vm.bulkActionById('plain')!);
    expect(r.ok, 2);
    expect(r.skipped, 1);
    expect(vm.applyIds.toSet(), {'a', 'b'});
    vm.dispose();
  });

  test('applyArg wins over apply and receives the threaded arg', () async {
    final vm = build();
    await settle();
    vm.toggleSelected('a');
    vm.toggleSelected('b');
    const payload = 'template-42';
    final r = await vm.applyBulkAction(
      vm.bulkActionById('prep')!,
      arg: payload,
    );
    expect(r.ok, 2);
    expect(
      vm.applyIds,
      isEmpty,
      reason: 'apply must not run when applyArg set',
    );
    expect(vm.applyArgCalls.map((e) => e.$1).toSet(), {'a', 'b'});
    expect(
      vm.applyArgCalls.every((e) => e.$2 == payload),
      isTrue,
      reason: 'each per-id call gets the prepared value',
    );
    expect(vm.isInMultiselect, isFalse, reason: 'selection cleared on exit');
    vm.dispose();
  });

  // A bulk delete answered "Nothing to delete" and left the row in place: the
  // password sheet the destructive verbs stop for is awaited *between* the
  // eligibility check and the apply, and the selection does not survive that
  // gap (priming the cache drains the outbox, whose sync edge re-arms the
  // list). Re-reading `_selectedIds` afterwards therefore found nothing
  // (invoiceninja/flutter#89).
  group('a selection cleared mid-dialog', () {
    test('still applies when the caller captured the ids first', () async {
      final vm = build();
      await settle();
      vm.toggleSelected('a');
      vm.toggleSelected('b');

      final captured = vm.eligibleSelectedIds(vm.bulkActionById('plain')!);
      expect(captured, {'a', 'b'});

      // Whatever the dialog did, the user's selection is gone by now.
      vm.clearSelection();

      final r = await vm.applyBulkAction(
        vm.bulkActionById('plain')!,
        ids: captured,
      );
      expect(r.ok, 2);
      expect(vm.applyIds.toSet(), {'a', 'b'});
      vm.dispose();
    });

    test('is what the un-captured path gets wrong', () async {
      // Pins the mechanism rather than the symptom: the same sequence without
      // `ids` is the bug, and it must stay visible if anyone reverts the fix.
      final vm = build();
      await settle();
      vm.toggleSelected('a');
      vm.clearSelection();

      final r = await vm.applyBulkAction(vm.bulkActionById('plain')!);
      expect(r.ok, 0);
      expect(vm.applyIds, isEmpty);
      vm.dispose();
    });

    test('eligibleSelectedIds filters the same way the counter did', () async {
      final vm = build();
      await settle();
      vm.toggleSelected('a');
      vm.toggleSelected('c'); // deleted → ineligible
      vm.toggleSelected('zz'); // outside the loaded window

      final action = vm.bulkActionById('plain')!;
      expect(vm.eligibleSelectedIds(action), {'a'});
      expect(vm.countEligibleSelected(action), 1);
      vm.dispose();
    });

    test(
      'an empty captured set is a no-op, not a full-selection apply',
      () async {
        final vm = build();
        await settle();
        vm.toggleSelected('a');

        final r = await vm.applyBulkAction(
          vm.bulkActionById('plain')!,
          ids: const <String>{},
        );
        expect(r.ok, 0);
        expect(vm.applyIds, isEmpty);
        vm.dispose();
      },
    );
  });
}
