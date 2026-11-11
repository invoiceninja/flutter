import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// A list embedded in a record's tab shows the columns the user picked on the
/// standalone list, minus the one naming the record it is scoped to — and
/// never writes that preference itself.
class _Row {
  const _Row();
}

final _kAllColumns = <ColumnDefinition<_Row>>[
  for (final (id, labelKey) in const [
    ('number', 'number'),
    ('client_id', 'client'),
    ('amount', 'amount'),
    ('private_notes', 'private_notes'),
  ])
    ColumnDefinition<_Row>(
      id: id,
      labelKey: labelKey,
      cellBuilder: (_, _) => const Text(''),
    ),
];

class _Vm extends GenericListViewModel<_Row> {
  _Vm({
    required this.locked,
    this.defaults = const ['number', 'client_id', 'amount'],
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
  });

  final Set<String> locked;
  final List<String> defaults;

  @override
  Set<String> get lockedFilterKeyIds => locked;
  @override
  EntityType get entityType => EntityType.payment;
  @override
  List<ColumnDefinition<_Row>> get allColumns => _kAllColumns;
  @override
  List<String> get defaultColumnIds => defaults;
  @override
  String get defaultSortField => 'number';
  @override
  bool isValidColumnId(String field) => _kAllColumns.any((c) => c.id == field);
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
}

void main() {
  late AppDatabase db;
  late UserSettingsRepository settings;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settings = UserSettingsRepository(db: db);
    // `setColumns` skips a company whose settings row has not hydrated.
    await db.userSettingsDao.upsert(
      const UserSettingsCompanion(
        companyId: Value('co'),
        userId: Value('u'),
        tableColumnsJson: Value('{}'),
        extraJson: Value('{}'),
        updatedAt: Value(0),
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  _Vm build({
    Set<String> locked = const {'client'},
    List<String> defaults = const ['number', 'client_id', 'amount'],
  }) {
    final vm = _Vm(
      locked: locked,
      defaults: defaults,
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: settings,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  List<String> shown(_Vm vm) => [for (final c in vm.columns) c.id];

  test('with nothing saved it shows the defaults minus the parent', () async {
    final vm = build();
    await settle();
    expect(shown(vm), ['number', 'amount']);
  });

  test('it follows the layout saved on the standalone list', () async {
    await settings.setColumns(
      companyId: 'co',
      entityType: EntityType.payment,
      columns: const ['number', 'client_id', 'private_notes', 'amount'],
    );
    final vm = build();
    await settle();
    expect(shown(vm), ['number', 'private_notes', 'amount']);

    // A change made on the standalone list while the tab is open lands too.
    await settings.setColumns(
      companyId: 'co',
      entityType: EntityType.payment,
      columns: const ['amount', 'number'],
    );
    await settle();
    expect(shown(vm), ['amount', 'number']);
  });

  test('the standalone list keeps the parent column', () async {
    final vm = build(locked: const {});
    await settle();
    expect(shown(vm), ['number', 'client_id', 'amount']);
  });

  test('it never drops down to no columns', () async {
    final vm = build(defaults: const ['client_id']);
    await settle();
    expect(shown(vm), ['client_id']);
  });

  test('it never writes the preference', () async {
    final vm = build();
    await settle();
    await vm.setColumns(const ['amount']);
    await vm.resetColumns();
    await settle();
    expect(shown(vm), ['number', 'amount']);
    expect(
      await settings
          .watchColumns(companyId: 'co', entityType: EntityType.payment)
          .first,
      anyOf(isNull, isEmpty),
    );
  });
}
