import 'package:admin/data/db/dao/expense_category_dao.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/expense_category_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Expense Categories screen. Mirrors
/// [ProductListViewModel] / [TaskStatusRepository]'s settings-only sibling —
/// plugs the [GenericListViewModel] base into [ExpenseCategoryRepository]
/// and the local column registry.
class ExpenseCategoryListViewModel
    extends GenericListViewModel<ExpenseCategory> {
  ExpenseCategoryListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  });

  final ExpenseCategoryRepository repo;

  @override
  EntityType get entityType => EntityType.expenseCategory;

  @override
  List<ColumnDefinition<ExpenseCategory>> get allColumns =>
      kAllExpenseCategoryColumns;

  @override
  List<String> get defaultColumnIds => kDefaultExpenseCategoryColumns;

  @override
  String get defaultSortField => ExpenseCategoryFieldIds.name;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(expenseCategoryColumnsById, field);

  @override
  String idOf(ExpenseCategory item) => item.id;

  @override
  bool isArchived(ExpenseCategory item) => item.archivedAt != null;

  @override
  bool isDeleted(ExpenseCategory item) => item.isDeleted;

  @override
  Stream<List<ExpenseCategory>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
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
  Iterable<BulkAction<ExpenseCategory>> get bulkActions =>
      standardCrudBulkActions(
        isArchived: isArchived,
        isDeleted: isDeleted,
        archive: (id) => repo.archive(companyId: companyId, id: id),
        restore: (id) => repo.restore(companyId: companyId, id: id),
        delete: (id) => repo.delete(companyId: companyId, id: id),
      );
}
