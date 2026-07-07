import 'dart:async';

import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/product_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/products/stock_filter_key.dart';

/// List ViewModel for the Products screen. Plugs the [GenericListViewModel]
/// base into [ProductRepository] + the product column registry.
class ProductListViewModel extends GenericListViewModel<Product> {
  ProductListViewModel({
    required this.repo,
    required Stream<Company?> companyStream,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  }) {
    _companySub = companyStream.listen(_onCompany);
  }

  final ProductRepository repo;

  late final StreamSubscription<Company?> _companySub;
  bool _trackInventory = false;
  int _companyThreshold = 0;

  /// Whether the active company tracks inventory (live, from the company
  /// stream). Drives the per-row low/out highlight via `InventoryScope` and
  /// gates the on-hand-stock cell styling.
  bool get trackInventory => _trackInventory;

  /// Company-level low-stock threshold fallback (live). Used by the low-stock
  /// filter's cascade when a product carries no threshold of its own.
  int get inventoryThreshold => _companyThreshold;

  void _onCompany(Company? company) {
    final track = company?.trackInventory ?? false;
    final threshold = company?.inventoryNotificationThreshold ?? 0;
    if (track == _trackInventory && threshold == _companyThreshold) return;
    _trackInventory = track;
    _companyThreshold = threshold;
    // Re-render so the highlight (InventoryScope reads [trackInventory] /
    // [inventoryThreshold]) updates. The filtered SET re-applies the new
    // threshold on the next Drift emit (e.g. the initial page fetch's upsert,
    // which lands after this stream has resolved).
    notifyListeners();
  }

  @override
  EntityType get entityType => EntityType.product;

  @override
  List<ColumnDefinition<Product>> get allColumns => kAllProductColumns;

  @override
  List<String> get defaultColumnIds => kDefaultProductColumns;

  @override
  String get defaultSortField => ProductFieldIds.productKey;

  @override
  bool isValidColumnId(String field) => productColumnsById.containsKey(field);

  @override
  String idOf(Product item) => item.id;

  @override
  bool isArchived(Product item) => item.archivedAt != null;

  @override
  bool isDeleted(Product item) => item.isDeleted;

  @override
  Stream<List<Product>> watchPage() => repo
      .watchPage(
        companyId: companyId,
        loadedPages: loadedPages,
        search: search.isEmpty ? null : search,
        states: states,
        sortField: sortField,
        sortAscending: sortAscending,
        customFilters: customFilters,
      )
      .map((products) {
        // `in_stock_quantity` lives in the product payload, not a physical
        // column, so low-stock is a post-decode predicate over the loaded page
        // — never a SQL WHERE. Completeness is bounded by the loaded pages; the
        // Product report is the authoritative full-dataset view. Read the
        // filter + threshold per-emit so a Drift re-emit re-filters with the
        // current company threshold.
        final filter = _stockFilter;
        if (filter == StockFilter.none) return products;
        return products
            .where(
              (p) => stockFilterMatches(
                p,
                filter,
                companyThreshold: _companyThreshold,
              ),
            )
            .toList(growable: false);
      });

  /// Stock is filtered post-decode over the loaded window, so a short
  /// filtered result must auto-chain page fetches (see the base class) —
  /// otherwise `stock:low` with no match in the first 50 rows renders a
  /// false "No records found" that can never scroll itself out.
  @override
  bool get localOnlyFilterActive => _stockFilter != StockFilter.none;

  @override
  int get pageSize => repo.pageSize;

  /// Parse the local `stock` extra-filter slot into a [StockFilter]. `out`
  /// wins over `low` if both are somehow present (out is the stricter set).
  StockFilter get _stockFilter {
    final values = extraFilters[StockFilterKey.serverKey] ?? const <String>{};
    if (values.contains(StockFilterKey.out)) return StockFilter.out;
    if (values.contains(StockFilterKey.low)) return StockFilter.low;
    return StockFilter.none;
  }

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    // `stock` is a LOCAL filter — the server has no such dimension. The
    // local watch re-applies it post-decode in [watchPage]; see
    // [GenericListViewModel.extraFiltersWithout] for why it must not reach
    // the server fetch.
    final serverFilters = GenericListViewModel.extraFiltersWithout(
      extraFilters,
      StockFilterKey.serverKey,
    );
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: serverFilters,
      ignoreCursor: ignoreCursor,
    );
  }

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Product>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );

  @override
  void dispose() {
    _companySub.cancel();
    super.dispose();
  }
}
