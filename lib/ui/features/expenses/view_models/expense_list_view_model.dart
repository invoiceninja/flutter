import 'package:admin/data/db/dao/expense_dao.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/expense_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Expenses screen. Mirrors `ProjectListViewModel` —
/// pagination/search/sort/multiselect/columns all live on the generic base.
class ExpenseListViewModel extends GenericListViewModel<Expense> {
  ExpenseListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.clientId,
    this.vendorId,
    this.projectId,
  });

  final ExpenseRepository repo;

  /// When non-null, scopes the watch + fetch to one client.
  final String? clientId;

  /// When non-null, scopes the watch + fetch to one vendor.
  final String? vendorId;

  /// When non-null, scopes the watch + fetch to one project. Used by the
  /// embedded list inside `ProjectDetailScreen`'s Expenses tab.
  final String? projectId;

  @override
  Set<String> get lockedFilterKeyIds => {
    if (clientId != null) 'client',
    if (vendorId != null) 'vendor',
    if (projectId != null) 'project',
  };

  @override
  EntityType get entityType => EntityType.expense;

  @override
  List<ColumnDefinition<Expense>> get allColumns => kAllExpenseColumns;

  @override
  List<String> get defaultColumnIds => kDefaultExpenseColumns;

  /// Default sort is by date — newest dates land on top once the user
  /// flips to descending. The generic base starts ascending; in practice
  /// users immediately toggle the sort icon on first visit and the
  /// preference persists via the saved-view system, so we don't carry a
  /// per-entity default-descending override.
  @override
  String get defaultSortField => ExpenseFieldIds.date;

  @override
  bool isValidColumnId(String field) =>
      expenseColumnsById.containsKey(field) ||
      field == ExpenseFieldIds.updatedAt;

  @override
  String idOf(Expense item) => item.id;

  @override
  bool isArchived(Expense item) => item.archivedAt != null;

  @override
  bool isDeleted(Expense item) => item.isDeleted;

  /// `tag_ids` is applied post-decode over the loaded window (repo.watchPage),
  /// so a short filtered result must auto-chain page fetches (see the base).
  @override
  bool get localOnlyFilterActive =>
      (extraFilters['tag_ids'] ?? const <String>{}).isNotEmpty;

  @override
  Stream<List<Expense>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
    vendorId: vendorId,
    projectId: projectId,
    extraFilters: extraFilters,
  );

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    // `tag_ids` is applied locally (post-decode in repo.watchPage) — strip it.
    final filters = <String, Set<String>>{
      ...GenericListViewModel.extraFiltersWithout(extraFilters, 'tag_ids'),
      if (clientId != null) 'client_id': {clientId!},
      if (vendorId != null) 'vendor_id': {vendorId!},
    };
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: filters,
      ignoreCursor: ignoreCursor,
    );
  }

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Expense>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );
}
