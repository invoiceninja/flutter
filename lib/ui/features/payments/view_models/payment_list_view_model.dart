import 'package:admin/data/db/dao/payment_dao.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/payment_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Payments screen. Mirrors `ExpenseListViewModel`.
/// Adds a "has unapplied funds" filter chip on top of the generic base.
class PaymentListViewModel extends GenericListViewModel<Payment> {
  PaymentListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.clientId,
  });

  final PaymentRepository repo;

  /// When non-null, scopes the watch + fetch to one client. Used by the
  /// embedded list inside `ClientDetailScreen`'s Payments tab.
  final String? clientId;

  bool _hasUnappliedFundsOnly = false;

  bool get hasUnappliedFundsOnly => _hasUnappliedFundsOnly;

  set hasUnappliedFundsOnly(bool value) {
    if (_hasUnappliedFundsOnly == value) return;
    _hasUnappliedFundsOnly = value;
    notifyListeners();
  }

  @override
  Set<String> get lockedFilterKeyIds => {if (clientId != null) 'client'};

  @override
  EntityType get entityType => EntityType.payment;

  @override
  List<ColumnDefinition<Payment>> get allColumns => kAllPaymentColumns;

  @override
  List<String> get defaultColumnIds => kDefaultPaymentColumns;

  @override
  String get defaultSortField => PaymentFieldIds.date;

  /// Newest first: date ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(paymentColumnsById, field) ||
      field == PaymentFieldIds.updatedAt;

  @override
  String idOf(Payment item) => item.id;

  @override
  bool isArchived(Payment item) => item.archivedAt != null;

  @override
  bool isDeleted(Payment item) => item.isDeleted;

  @override
  Stream<List<Payment>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    hasUnappliedFundsOnly: _hasUnappliedFundsOnly,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
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
  }) {
    // `date` is a LOCAL-ONLY filter here: `PaymentFilters` has no `date()`
    // method (unlike Invoice/Quote/Credit), so the server silently ignores it
    // and returns an unnarrowed page. Strip it from the request and let the
    // DAO predicate + the auto-chain (`localOnlyFilterActive` below) converge,
    // instead of shipping a page the local filter guts down to a handful of
    // rows with no way to scroll for more.
    final base = GenericListViewModel.extraFiltersWithout(extraFilters, 'date');
    final filters = clientId == null
        ? base
        : {
            ...base,
            'client_id': {clientId!},
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

  /// `date` is filtered locally (see [fetchPage]), so a page the predicate
  /// guts down must auto-chain the next one — otherwise the list dead-ends on a
  /// false "No records found".
  @override
  bool get localOnlyFilterActive =>
      super.localOnlyFilterActive ||
      (extraFilters['date']?.isNotEmpty ?? false);

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<Payment>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );
}
