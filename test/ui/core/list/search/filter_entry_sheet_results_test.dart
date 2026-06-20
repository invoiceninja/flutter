// Widget coverage for the live-results section of the mobile filter sheet:
// typing a free-text query renders the real per-entity list tiles (via the
// injected resultTile), and tapping a row pops the sheet and opens that
// record (via onOpenRecord). The search itself is applied as-you-type, so
// the AppBar back arrow returns to the filtered list (no commit row).

import 'dart:async';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_entry_sheet.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';

class _Row {
  const _Row(this.id, this.label);
  final String id;
  final String label;
}

const _kStub = [_Row('r1', 'Acme Corp'), _Row('r2', 'Zenith LLC')];

final _kCols = <ColumnDefinition<_Row>>[
  ColumnDefinition(
    id: 'label',
    labelKey: 'name',
    cellBuilder: (r, _) => Text(r.label),
  ),
];

class _FakeVm extends GenericListViewModel<_Row> {
  _FakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  EntityType get entityType => EntityType.client;
  @override
  List<ColumnDefinition<_Row>> get allColumns => _kCols;
  @override
  List<String> get defaultColumnIds => const ['label'];
  @override
  String get defaultSortField => 'label';
  @override
  bool isValidColumnId(String field) => field == 'label';
  @override
  String idOf(_Row item) => item.id;
  @override
  bool isArchived(_Row item) => false;
  @override
  bool isDeleted(_Row item) => false;
  @override
  Stream<List<_Row>> watchPage() => Stream.value(_kStub);
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
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      const Stream.empty();
  @override
  Iterable<BulkAction<_Row>> get bulkActions => const [];
}

/// Minimal non-checkbox FilterKey for exercising the sheet's key→value-mode
/// flow. [directApplyValue], when set, makes selection a one-tap apply.
class _StubKey extends FilterKey {
  _StubKey({required this.id, required this.label, this.directApplyValue});

  @override
  final String id;
  final String label;
  @override
  final String? directApplyValue;

  String? addedValue;

  @override
  String displayLabel(BuildContext context) => label;
  @override
  FilterValueType get valueType => FilterValueType.string;
  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) => const [];
  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => const Stream.empty();
  @override
  Future<void> addValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    addedValue = rawValue;
  }

  @override
  Future<void> removeValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {}
  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) => true;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('typing shows result tiles and tapping opens the record', (
    tester,
  ) async {
    final vm = _FakeVm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: Duration.zero,
      persistDebounce: Duration.zero,
    );
    addTearDown(vm.dispose);

    String? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FilterEntrySheet(
                      vm: vm,
                      filterKeys: const <FilterKey>[],
                      hintKey: 'search',
                      resultTile: (c, item, i) => Text((item! as _Row).label),
                      onOpenRecord: (id) => opened = id,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Free-text query → results view (real tiles from vm.items).
    await tester.enterText(find.byType(EditableText).first, 'acme');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();

    expect(find.text('Acme Corp'), findsOneWidget);
    expect(find.text('Zenith LLC'), findsOneWidget);

    // Tapping a result opens that record and pops the sheet. The tile text is
    // inside IgnorePointer (its own taps are suppressed); the tap lands on the
    // outer GestureDetector, so warnIfMissed is expected here.
    await tester.tap(find.text('Acme Corp'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(opened, 'r1');
    expect(find.text('Acme Corp'), findsNothing); // sheet popped
    expect(find.text('open'), findsOneWidget);
  });

  // Opens the sheet (via a push from a button) with the given filter keys.
  Future<void> openSheetWithKeys(
    WidgetTester tester,
    List<FilterKey> keys,
  ) async {
    final vm = _FakeVm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: Duration.zero,
      persistDebounce: Duration.zero,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FilterEntrySheet(
                      vm: vm,
                      filterKeys: keys,
                      hintKey: 'search',
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a non-checkbox key keeps its key: prefix (value mode)', (
    tester,
  ) async {
    // Regression: tapping a key row drops focus (TextField.onTapOutside) before
    // selectKey writes "color:"; the reseed branch must NOT wipe that prefix.
    await openSheetWithKeys(tester, [_StubKey(id: 'color', label: 'Color')]);
    await tester.tap(find.text('Color'));
    await tester.pump();
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.controller.text, 'color:');
  });

  testWidgets('tapping a directApplyValue key applies in one tap, no prefix', (
    tester,
  ) async {
    final flag = _StubKey(id: 'flag', label: 'Flag', directApplyValue: 'true');
    await openSheetWithKeys(tester, [flag]);
    await tester.tap(find.text('Flag'));
    await tester.pump();
    expect(flag.addedValue, 'true'); // applied directly
    final field = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(field.controller.text, isEmpty); // no "flag:" prefix written
  });
}
