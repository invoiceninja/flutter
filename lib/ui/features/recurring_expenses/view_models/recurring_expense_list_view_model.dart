import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/recurring_expense_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Recurring Expenses screen. Mirrors
/// `ExpenseListViewModel`.
///
/// Status filtering is the shared status-tab strip (`badge_mode`, see
/// `lib/domain/list_status_tabs.dart`), which supersedes the in-memory
/// `recurringStatus` dimension this VM used to carry: that one never called
/// `_resetAndReload`, so it notified listeners without re-subscribing the Drift
/// watch and could not actually filter anything.
class RecurringExpenseListViewModel
    extends GenericListViewModel<RecurringExpense> {
  RecurringExpenseListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.vendorId,
  });

  final RecurringExpenseRepository repo;

  /// When non-null, scopes the watch + fetch to one vendor.
  final String? vendorId;

  @override
  Set<String> get lockedFilterKeyIds => {if (vendorId != null) 'vendor'};

  @override
  EntityType get entityType => EntityType.recurringExpense;

  @override
  List<ColumnDefinition<RecurringExpense>> get allColumns =>
      kAllRecurringExpenseColumns;

  @override
  List<String> get defaultColumnIds => kDefaultRecurringExpenseColumns;

  /// Default sort is by next-send-date — descending lands the most
  /// imminent runs at the top once the user flips ascending.
  @override
  String get defaultSortField => RecurringExpenseFieldIds.nextSendDate;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(recurringExpenseColumnsById, field) ||
      field == RecurringExpenseFieldIds.updatedAt;

  @override
  String idOf(RecurringExpense item) => item.id;

  @override
  bool isArchived(RecurringExpense item) => item.archivedAt != null;

  @override
  bool isDeleted(RecurringExpense item) => item.isDeleted;

  @override
  Stream<List<RecurringExpense>> watchPage() => repo
      .watchPage(
        badgeModeId: activeBadgeModeId,
        companyId: companyId,
        loadedPages: loadedPages,
        search: search.isEmpty ? null : search,
        states: states,
        sortField: sortField,
        sortAscending: sortAscending,
        vendorId: vendorId,
        customFilters: customFilters,
      )
      .map((items) {
        // `tag_ids` lives only in the payload — post-decode predicate.
        final tagIds = extraFilters['tag_ids'] ?? const <String>{};
        if (tagIds.isEmpty) return items;
        return items
            .where((e) => matchesTagIdFilter(e.tagIds, tagIds))
            .toList(growable: false);
      });

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    final base = extraFilters;
    final filters = vendorId == null
        ? base
        : {
            ...base,
            'vendor_id': {vendorId!},
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
  Iterable<BulkAction<RecurringExpense>> get bulkActions => [
    ...standardCrudBulkActions<RecurringExpense>(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    // Start / Stop bulk actions. Eligibility mirrors the per-row item
    // affordances on `RecurringExpenseAction` so the bar only shows rows
    // we can actually transition.
    BulkAction<RecurringExpense>(
      id: 'start',
      labelKey: 'start',
      eligible: (e) => e.canBeStarted && !isDeleted(e) && !isArchived(e),
      apply: (id) => repo.start(companyId: companyId, id: id),
    ),
    BulkAction<RecurringExpense>(
      id: 'stop',
      labelKey: 'stop',
      eligible: (e) => e.canBeStopped && !isDeleted(e) && !isArchived(e),
      apply: (id) => repo.stop(companyId: companyId, id: id),
    ),
  ];
}
