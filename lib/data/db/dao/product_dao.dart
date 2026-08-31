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

  @override
  GeneratedColumn<int>? get archivedAtColumn => products.archivedAt;

  /// The stock counters are the only badge modes that need values from outside
  /// the row: the company's `track_inventory` switch, and its
  /// `inventory_notification_threshold` as the fallback when a product carries
  /// no threshold of its own.
  ///
  /// Both are pulled in as **subqueries over `companies`** rather than being
  /// passed down from the repository. That keeps this a single query, and —
  /// because drift registers a subquery's table as one this stream reads from —
  /// the badge recomputes on its own when Product Settings changes, with no
  /// stream-switching plumbing in the repo.
  ///
  /// The inventory fields themselves are payload-only, read with the same
  /// `json_extract` shape `_sortExpression` already uses for them.
  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) {
    if (modeId != 'out_of_stock' && modeId != 'low_stock') return null;
    const qty = CustomExpression<double>(
      r"CAST(COALESCE(json_extract(payload, '$.in_stock_quantity'), 0) AS REAL)",
    );
    const ownThreshold = CustomExpression<double>(
      r"CAST(COALESCE(json_extract(payload, '$.stock_notification_threshold')"
      r', 0) AS REAL)',
    );
    // Inventory off ⇒ on-hand stock is meaningless. Without this gate every
    // product would read as out of stock, since the payload key is absent and
    // `COALESCE(…, 0) <= 0` holds.
    final trackingOn = existsQuery(
      selectOnly(attachedDatabase.companies)
        ..addColumns([attachedDatabase.companies.id])
        ..where(
          attachedDatabase.companies.id.equals(companyId) &
              attachedDatabase.companies.trackInventory.equals(true),
        ),
    );
    if (modeId == 'out_of_stock') {
      return trackingOn & qty.isSmallerOrEqualValue(0);
    }
    final companyThreshold = subqueryExpression<double>(
      selectOnly(attachedDatabase.companies)
        ..addColumns([
          attachedDatabase.companies.inventoryNotificationThreshold
              .cast<double>(),
        ])
        ..where(attachedDatabase.companies.id.equals(companyId)),
    );
    // Mirrors `InventoryScope.statusFor`, which mirrors the backend
    // `AdjustProductInventory` two-tier check: the product's own threshold, or
    // the company fallback when the product's is 0. `out` wins over `low`, so
    // low-stock excludes rows already at or below zero.
    final effective = CaseWhenExpression<double>(
      cases: [CaseWhen(ownThreshold.isBiggerThanValue(0), then: ownThreshold)],
      orElse: companyThreshold,
    );
    return trackingOn &
        qty.isBiggerThanValue(0) &
        effective.isBiggerThanValue(0) &
        qty.isSmallerOrEqual(effective);
  }

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
    String? groupField,
    String? badgeModeId,
  }) {
    final q = select(products)..where((p) => p.companyId.equals(companyId));
    // Status-tab strip (#98): the SAME predicate the tab's count uses, so
    // the number above the list and the rows in it can't disagree. Applied
    // here (pre-LIMIT) rather than post-decode, so the Drift window stays
    // aligned with the page count.
    final badgeFilter = badgeModeListFilter(badgeModeId, companyId: companyId);
    if (badgeFilter != null) q.where((_) => badgeFilter);

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
      // Grouping leads the ORDER BY so each group's rows are contiguous and
      // the screen can print a header on every value change; the user's sort
      // then applies *within* a group. Two terms, not one:
      //   1. empty-last, so `Uncategorized` sorts to the bottom (SQLite ranks
      //      false(0) before true(1), so ascending on `col = ''` does it);
      //   2. `.lower()`, because SQLite's default TEXT collation is BINARY —
      //      without it `Zebra` would sort ahead of `apple`;
      //   3. the raw column, because the SCREEN groups on the raw value. With
      //      only the lowercased term, `Retail` and `retail` tie and the
      //      user's sort interleaves them — rendering a header per run and
      //      making one collapse hide non-adjacent rows.
      if (_groupColumn(products, groupField) != null) ...[
        (p) =>
            OrderingTerm(expression: _groupColumn(p, groupField)!.equals('')),
        (p) => OrderingTerm(expression: _groupColumn(p, groupField)!.lower()),
        (p) => OrderingTerm(expression: _groupColumn(p, groupField)!),
      ],
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

  /// The custom-value column a grouping id names, or null for "no grouping"
  /// and for any id this DAO can't group by in SQL (`tags` lives in the
  /// payload and is grouped in Dart by the ViewModel).
  ///
  /// Returns null rather than throwing, unlike [_sortExpression]: a grouping
  /// id can go stale in persisted list state when a company un-configures a
  /// custom field, and that must degrade to an ungrouped list, not a crash.
  Expression<String>? _groupColumn(Products p, String? groupField) =>
      switch (groupField) {
        ProductFieldIds.custom1 => p.customValue1,
        ProductFieldIds.custom2 => p.customValue2,
        ProductFieldIds.custom3 => p.customValue3,
        ProductFieldIds.custom4 => p.customValue4,
        _ => null,
      };

  /// Distinct non-empty values of `custom_value{columnIndex}` for the given
  /// company, ordered ascending. Feeds the `custom1:`…`custom4:` filter
  /// tokens' value suggestions and the products list's "group by" menu (a
  /// slot with no values isn't worth offering as a grouping dimension).
  /// Mirrors [ClientDao.watchDistinctCustomValues].
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) {
    final column = switch (columnIndex) {
      1 => products.customValue1,
      2 => products.customValue2,
      3 => products.customValue3,
      4 => products.customValue4,
      _ => throw ArgumentError('columnIndex must be 1..4 (got $columnIndex)'),
    };
    final q = selectOnly(products, distinct: true)
      ..addColumns([column])
      ..where(products.companyId.equals(companyId) & column.equals('').not())
      // `.lower()` to match the grouped list's own ordering — BINARY
      // collation would otherwise list `Zebra` ahead of `apple`.
      ..orderBy([OrderingTerm(expression: column.lower())]);
    return q.map((row) => row.read(column)!).watch().distinctRows();
  }
}
