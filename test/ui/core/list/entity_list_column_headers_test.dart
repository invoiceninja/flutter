import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/entity_list_column_headers.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

import '../../../_localization_helper.dart';

/// The table header is the other half of invoiceninja/flutter#106's custom-field
/// fix (the Columns picker being the first): it has to render the company's
/// configured label, not `CUSTOM1`, while staying a live sort control.
class _Row {
  const _Row();
}

final _kAllColumns = <ColumnDefinition<_Row>>[
  ColumnDefinition<_Row>(
    id: 'name',
    labelKey: 'name',
    width: 120,
    cellBuilder: (_, _) => const Text('name'),
  ),
  ...customFieldColumns<_Row>(
    prefix: 'project',
    ids: const ['custom1', 'custom2', 'custom3', 'custom4'],
    values: [(_) => '', (_) => '', (_) => '', (_) => ''],
  ),
  // Display-only, so its header must not advertise a sort it can't perform.
  ColumnDefinition<_Row>(
    id: 'tags',
    labelKey: 'tags',
    width: 120,
    sortable: false,
    cellBuilder: (_, _) => const Text('tags'),
  ),
];

class _Vm extends GenericListViewModel<_Row> {
  _Vm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
  });

  @override
  EntityType get entityType => EntityType.project;
  @override
  List<ColumnDefinition<_Row>> get allColumns => _kAllColumns;
  @override
  List<String> get defaultColumnIds => const ['name', 'custom1', 'tags'];
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
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<_Vm> pump(WidgetTester tester, {Company? company}) async {
    final vm = _Vm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
    );
    addTearDown(vm.dispose);
    if (company != null) vm.bindCompany(Stream.value(company));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => EntityListColumnHeaders<_Row>(vm: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets("a custom-field header reads the company's label", (
    tester,
  ) async {
    await pump(
      tester,
      company: const Company(customFields: {'project1': 'Region'}),
    );
    expect(find.text('REGION'), findsOneWidget);
    expect(find.text('CUSTOM1'), findsNothing);
    expect(find.text('FIRST CUSTOM'), findsNothing);
  });

  testWidgets('an unconfigured slot renders no header at all', (tester) async {
    await pump(tester, company: const Company());
    expect(find.text('REGION'), findsNothing);
    expect(find.text('FIRST CUSTOM'), findsNothing);
    // The rest of the row is untouched.
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('TAGS'), findsOneWidget);
  });

  testWidgets('a custom-field header is still a live sort control', (
    tester,
  ) async {
    final vm = await pump(
      tester,
      company: const Company(customFields: {'project1': 'Region'}),
    );
    await tester.tap(find.text('REGION'));
    await tester.pumpAndSettle();
    expect(vm.sortField, 'custom1');

    // …while a display-only header stays inert.
    await tester.tap(find.text('TAGS'));
    await tester.pumpAndSettle();
    expect(vm.sortField, 'custom1');
  });
}
