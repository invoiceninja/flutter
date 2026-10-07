import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/features/products/widgets/product_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Who is offered what on a product, and which of it earns a tile on the
/// record screen.
///
/// `can()` short-circuits true for an admin or owner, so every permission
/// case here is a non-admin with explicit tokens.
Product _product({
  String id = 'p1',
  bool isDeleted = false,
  int archivedAt = 0,
}) => Product.fromApi(
  ProductApi(
    id: id,
    productKey: 'WIDGET',
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
  Future<T> resolve<T>(
    WidgetTester tester,
    T Function(BuildContext context) read, {
    String? permissions,
    int enabledModules = 32767,
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          enabledModules: enabledModules,
          isOwner: permissions == null,
          isAdmin: permissions == null,
          permissions: permissions ?? '',
        ),
      ],
    );
    addTearDown(fixture.dispose);
    late T result;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            result = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  Future<Set<ProductAction>> kinds(
    WidgetTester tester,
    Product product, {
    String? permissions,
    int enabledModules = 32767,
  }) async {
    final items = await resolve(
      tester,
      (context) => ProductActions.itemsFor(context, product, (_) {}),
      permissions: permissions,
      enabledModules: enabledModules,
    );
    return {for (final i in flattenActionItems(items)) i.kind};
  }

  Future<List<EntityQuickAction<ProductAction>>> tiles(
    WidgetTester tester,
    Product product, {
    String? permissions,
  }) async {
    final priority = await resolve(
      tester,
      (context) => ProductActions.quickItemsFor(context, product, (_) {}),
      permissions: permissions,
    );
    return pickQuickActions(priority, max: 6);
  }

  group('a create action needs its module AND create_<entity>', () {
    // The module alone used to decide, which offered New Invoice to a user
    // the server would then refuse.
    testWidgets('a view-only user is offered no New … at all', (tester) async {
      final got = await kinds(tester, _product(), permissions: 'view_product');
      expect(got, isNot(contains(ProductAction.newGroup)));
      expect(got, isNot(contains(ProductAction.newInvoice)));
      expect(got, isNot(contains(ProductAction.newQuote)));
      expect(got, isNot(contains(ProductAction.newPurchaseOrder)));
      expect(got, isNot(contains(ProductAction.clone)));
    });

    testWidgets('each permission unlocks its own document', (tester) async {
      final got = await kinds(tester, _product(), permissions: 'create_quote');
      expect(got, contains(ProductAction.newQuote));
      expect(got, isNot(contains(ProductAction.newInvoice)));
      expect(got, isNot(contains(ProductAction.newPurchaseOrder)));
    });

    testWidgets('the permission without the module offers nothing', (
      tester,
    ) async {
      final got = await kinds(
        tester,
        _product(),
        permissions: 'create_invoice,create_quote',
        enabledModules: 0,
      );
      expect(got, isNot(contains(ProductAction.newInvoice)));
      expect(got, isNot(contains(ProductAction.newQuote)));
    });

    testWidgets('a clone is a new product', (tester) async {
      expect(
        await kinds(tester, _product(), permissions: 'edit_product'),
        isNot(contains(ProductAction.clone)),
      );
    });

    testWidgets('…which create_product allows', (tester) async {
      expect(
        await kinds(tester, _product(), permissions: 'create_product'),
        contains(ProductAction.clone),
      );
    });
  });

  group('what changes the product needs edit_product', () {
    testWidgets('a view-only user cannot archive, delete or re-categorise', (
      tester,
    ) async {
      final got = await kinds(tester, _product(), permissions: 'view_product');
      expect(got, isNot(contains(ProductAction.archive)));
      expect(got, isNot(contains(ProductAction.delete)));
      expect(got, isNot(contains(ProductAction.setTaxCategory)));
    });

    testWidgets('…nor restore an archived one', (tester) async {
      final got = await kinds(
        tester,
        _product(archivedAt: 1700000000),
        permissions: 'view_product',
      );
      expect(got, isNot(contains(ProductAction.restore)));
    });

    testWidgets('an editor can', (tester) async {
      final got = await kinds(tester, _product(), permissions: 'edit_product');
      expect(got, contains(ProductAction.archive));
      expect(got, contains(ProductAction.delete));
      expect(got, contains(ProductAction.setTaxCategory));
    });
  });

  testWidgets('a deleted product offers its link and Restore — nothing that '
      'changes it, copies it or puts it on a document', (tester) async {
    expect(await kinds(tester, _product(isDeleted: true)), {
      ProductAction.copyLink,
      ProductAction.restore,
    });
  });

  group('the record screen\'s tiles', () {
    List<ProductAction> order(List<EntityQuickAction<ProductAction>> t) => [
      for (final q in t) q.item.kind,
    ];

    testWidgets('lead with putting the product on a document', (tester) async {
      final t = await tiles(tester, _product());
      expect(order(t), [
        ProductAction.newInvoice,
        ProductAction.newQuote,
        ProductAction.newPurchaseOrder,
        ProductAction.clone,
        ProductAction.setTaxCategory,
      ]);
      // The create tiles are found inside the menu's Create New group, and
      // labelled with the noun so they fit.
      expect(t.first.shortLabel, '+ Invoice');
      expect(t.first.item.hasChildren, isFalse);
    });

    testWidgets('a deleted or unsynced product has none', (tester) async {
      expect(await tiles(tester, _product(isDeleted: true)), isEmpty);
      expect(await tiles(tester, _product(id: 'tmp_abc')), isEmpty);
    });

    testWidgets('a tile is never offered for an action the menu does not '
        'have', (tester) async {
      final t = await tiles(
        tester,
        _product(),
        permissions: 'view_product,create_invoice',
      );
      expect(order(t), [ProductAction.newInvoice]);
    });
  });
}
