import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/products_table.dart';

part 'product_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `ProductRepository.watchPage`.
class ProductFieldIds {
  static const String productKey = 'product_key';
  static const String price = 'price';
  static const String cost = 'cost';
  static const String quantity = 'quantity';
  static const String updatedAt = 'updated_at';
  // Display-only columns (selectable via the column picker). Not yet handled
  // by [_sortExpression] — sorting on these falls back to the default order.
  static const String description = 'description';
  static const String custom1 = 'custom1';
  static const String custom2 = 'custom2';
  static const String custom3 = 'custom3';
  static const String custom4 = 'custom4';
  static const String taxName1 = 'tax_name1';
  static const String taxRate1 = 'tax_rate1';
  static const String taxName2 = 'tax_name2';
  static const String taxRate2 = 'tax_rate2';
  static const String taxName3 = 'tax_name3';
  static const String taxRate3 = 'tax_rate3';
  static const String inStockQuantity = 'in_stock_quantity';
  static const String stockNotificationThreshold =
      'stock_notification_threshold';
  static const String maxQuantity = 'max_quantity';
  // Computed (not persisted): in_stock_quantity × price. Opt-in column only;
  // never a sort/DAO field.
  static const String stockValue = 'stock_value';
  static const String taxCategory = 'tax_category';
  static const String createdAt = 'created_at';
  static const String archivedAt = 'archived_at';
  // Display-only column id (tags live in the payload, not a Drift column) —
  // never add to the list screen's sortOptions.
  static const String tagIds = 'product_tag_ids';
}

@DriftAccessor(tables: [Products])
class ProductDao extends BaseEntityDao<$ProductsTable, ProductRow>
    with _$ProductDaoMixin {
  ProductDao(super.db);

  @override
  $ProductsTable get table => products;
  @override
  GeneratedColumn<String> get idColumn => products.id;
  @override
  GeneratedColumn<String> get companyIdColumn => products.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => products.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => products.isDirty;

  /// Watch a windowed slice of products. Filters: state (active/archived/
  /// deleted), free-text search across product_key + notes.
  Stream<List<ProductRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ProductFieldIds.productKey,
    bool sortAscending = true,
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
  }) {
    final q = select(products)..where((p) => p.companyId.equals(companyId));

    // Custom-field filters mirror server `custom_value1..4` (exact-set local
    // predicate is source of truth — same idiom as ClientDao/InvoiceDao).
    if (customValues1.isNotEmpty) {
      q.where((p) => p.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((p) => p.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((p) => p.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((p) => p.customValue4.isIn(customValues4.toList()));
    }

    if (states.isNotEmpty) {
      q.where(
        (p) => entityStateFilter(
          states: states,
          archivedAt: p.archivedAt,
          isDeleted: p.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (p) =>
            p.productKey.lower().like(needle) |
            p.notes.lower().like(needle) |
            p.customValue1.lower().like(needle) |
            p.customValue2.lower().like(needle) |
            p.customValue3.lower().like(needle) |
            p.customValue4.lower().like(needle),
      );
    }

    q.orderBy([
      (p) => OrderingTerm(
        expression: _sortExpression(p, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      // Stable secondary key.
      (p) => OrderingTerm(expression: p.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  /// Stream distinct active `product_key` values for this company as
  /// `(id, name)` pairs — both the key, because the reports product filter
  /// keys on `product_key`, not the row id. Cheap single-column projection
  /// for the reports product multi-select; mirrors
  /// [ClientDao.watchActiveNames].
  Stream<List<({String id, String name})>> watchActiveProductKeys({
    required String companyId,
  }) {
    final q = selectOnly(products, distinct: true)
      ..addColumns([products.productKey])
      ..where(
        products.companyId.equals(companyId) &
            products.isDeleted.equals(false) &
            products.archivedAt.isNull() &
            products.productKey.equals('').not(),
      )
      ..orderBy([OrderingTerm(expression: products.productKey.lower())]);
    return q
        .map((row) {
          final key = row.read<String>(products.productKey) ?? '';
          return (id: key, name: key);
        })
        .watch()
        .distinctRows();
  }

  Expression _sortExpression(Products p, String field) {
    switch (field) {
      case ProductFieldIds.productKey:
        return p.productKey.lower();
      case ProductFieldIds.price:
        return p.price.cast<double>();
      case ProductFieldIds.cost:
        return p.cost.cast<double>();
      case ProductFieldIds.quantity:
        return p.quantity.cast<double>();
      case ProductFieldIds.updatedAt:
        return p.updatedAt;
      case ProductFieldIds.description:
        return p.notes.lower();
      case ProductFieldIds.custom1:
        return p.customValue1.lower();
      case ProductFieldIds.custom2:
        return p.customValue2.lower();
      case ProductFieldIds.custom3:
        return p.customValue3.lower();
      case ProductFieldIds.custom4:
        return p.customValue4.lower();
      case ProductFieldIds.createdAt:
        return p.createdAt;
      case ProductFieldIds.archivedAt:
        return p.archivedAt;
      // Payload-only columns (tax config + the inventory fields). These are
      // `sortable: true` by default, so without a case here the header tap was
      // accepted and then silently ordered by product_key — the arrow moved,
      // the rows didn't.
      case ProductFieldIds.inStockQuantity:
      case ProductFieldIds.stockNotificationThreshold:
      case ProductFieldIds.maxQuantity:
      case ProductFieldIds.taxRate1:
      case ProductFieldIds.taxRate2:
      case ProductFieldIds.taxRate3:
        return CustomExpression<double>(
          "CAST(COALESCE(json_extract(payload, '\$.$field'), 0) AS REAL)",
        );
      // NOT part of the `$field` group below: the column id is
      // `tax_category` but the payload key is `tax_id`, so interpolating the
      // id would json_extract nothing and silently collapse the sort.
      case ProductFieldIds.taxCategory:
        return CustomExpression<String>(
          "LOWER(COALESCE(json_extract(payload, '\$.tax_id'), ''))",
        );
      case ProductFieldIds.taxName1:
      case ProductFieldIds.taxName2:
      case ProductFieldIds.taxName3:
        return CustomExpression<String>(
          "LOWER(COALESCE(json_extract(payload, '\$.$field'), ''))",
        );
      default:
        // Every registered product column now has a case, so this is
        // unreachable — throw rather than silently ordering by product_key, so
        // `sortable_columns_test` catches any future omission.
        throw ArgumentError.value(
          field,
          'sortField',
          'no sort expression for this product column — add a case, or mark '
              'the column sortable: false',
        );
    }
  }
}
