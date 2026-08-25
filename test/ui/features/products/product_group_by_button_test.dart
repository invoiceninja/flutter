// The wide-screen "Group by" control (issue #56).
//
// Runtime tests, not a source scan: the defect this file exists for was a
// `PopupMenuButton<String?>` whose `value: null` "No grouping" row could never
// fire `onSelected`, because Flutter reads a null menu result as a dismissal
// (`_PopupMenuButtonState._showButtonMenu` → `onCanceled`). Nothing short of
// actually tapping the item catches that.

import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/products_api.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/products/view_models/product_list_view_model.dart';
import 'package:admin/ui/features/products/widgets/product_group_by_button.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_localization_helper.dart';

class _FakeProductsApi implements ProductsApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

void main() {
  late AppDatabase db;
  late ProductRepository repo;
  const co = 'co_1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProductRepository(db: db, api: _FakeProductsApi());
  });
  tearDown(() async => db.close());

  Future<void> product(String id, {String custom1 = ''}) =>
      db.productDao.upsertAll([
        ProductsCompanion.insert(
          id: id,
          companyId: co,
          productKey: id,
          notes: '',
          price: '0',
          cost: '0',
          quantity: '1',
          updatedAt: 1,
          payload: jsonEncode({
            'id': id,
            'product_key': id,
            'custom_value1': custom1,
          }),
          customValue1: Value(custom1),
        ),
      ]);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(Duration.zero);
    }
  }

  Future<ProductListViewModel> pumpButton(WidgetTester tester) async {
    final vm = ProductListViewModel(
      repo: repo,
      companyId: co,
      companyStream: Stream<Company?>.value(
        const Company(customFields: {'product1': 'Category|Hardware,Software'}),
      ),
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      persistDebounce: const Duration(milliseconds: 1),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => ProductGroupByButton(vm: vm),
          ),
        ),
      ),
    );
    await settle(tester);
    return vm;
  }

  testWidgets('picking a dimension groups the list', (tester) async {
    await product('a', custom1: 'Hardware');
    final vm = await pumpButton(tester);

    await tester.tap(find.byType(ProductGroupByButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category').last);
    await tester.pumpAndSettle();

    expect(vm.groupField, ProductFieldIds.custom1);
  });

  testWidgets('"No grouping" actually ungroups — it is not a dead item', (
    tester,
  ) async {
    // The regression. Typed `String?` with a `value: null` row, this tap fired
    // `onCanceled` and `setGroupField(null)` never ran — and because the wide
    // AppBar branch carries no sort sheet, this button is the ONLY path back
    // to an ungrouped list on a desktop viewport.
    await product('a', custom1: 'Hardware');
    final vm = await pumpButton(tester);
    await vm.setGroupField(ProductFieldIds.custom1);
    await settle(tester);
    await tester.pump();
    expect(vm.groupField, ProductFieldIds.custom1, reason: 'precondition');

    await tester.tap(find.byType(ProductGroupByButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No grouping'));
    await tester.pumpAndSettle();

    expect(vm.groupField, isNull);
    expect(vm.effectiveGroupField, isNull);
  });
}
