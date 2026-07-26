import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// Drives the read-only Vendors list screen.
///
/// All list-screen machinery (pagination, search, filter, sort, multi-select,
/// filter persistence, column selection) lives on [GenericListViewModel];
/// this subclass plugs in the vendor-specific bits: column registry, repo
/// hooks, and bulk-action predicates. Same shape as `ClientListViewModel`.
class VendorListViewModel extends GenericListViewModel<Vendor> {
  VendorListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  });

  final VendorRepository repo;

  // ── Configuration ──────────────────────────────────────────────────

  @override
  EntityType get entityType => EntityType.vendor;

  @override
  List<ColumnDefinition<Vendor>> get allColumns => kAllVendorColumns;

  @override
  List<String> get defaultColumnIds => kDefaultVendorColumns;

  @override
  String get defaultSortField => VendorFieldIds.name;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(vendorColumnsById, field);

  @override
  String idOf(Vendor item) => item.id;

  @override
  bool isArchived(Vendor item) => item.archivedAt != null;

  @override
  bool isDeleted(Vendor item) => item.isDeleted;

  // ── Data-source hooks ──────────────────────────────────────────────

  @override
  Stream<List<Vendor>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    customFilters: customFilters,
    extraFilters: extraFilters,
  );

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) => repo.ensurePageLoaded(
    companyId: companyId,
    page: page,
    search: search,
    states: states,
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
  );

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      repo.watchDistinctCustomValues(
        companyId: companyId,
        columnIndex: columnIndex,
      );

  // ── Bulk actions ───────────────────────────────────────────────────

  @override
  Iterable<BulkAction<Vendor>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );
}
