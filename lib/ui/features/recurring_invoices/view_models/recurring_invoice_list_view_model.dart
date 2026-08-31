import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/recurring_invoice_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

class RecurringInvoiceListViewModel
    extends GenericListViewModel<RecurringInvoice> {
  RecurringInvoiceListViewModel({
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

  final RecurringInvoiceRepository repo;

  /// When non-null, scopes the watch + fetch to one client.
  final String? clientId;

  @override
  Set<String> get lockedFilterKeyIds => {if (clientId != null) 'client'};

  @override
  EntityType get entityType => EntityType.recurringInvoice;

  @override
  List<ColumnDefinition<RecurringInvoice>> get allColumns =>
      kAllRecurringInvoiceColumns;

  @override
  List<String> get defaultColumnIds => kDefaultRecurringInvoiceColumns;

  @override
  String get defaultSortField => RecurringInvoiceFieldIds.number;

  /// Newest first: invoice number ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(recurringInvoiceColumnsById, field) ||
      field == RecurringInvoiceFieldIds.updatedAt;

  @override
  String idOf(RecurringInvoice item) => item.id;

  @override
  bool isArchived(RecurringInvoice item) => item.archivedAt != null;

  @override
  bool isDeleted(RecurringInvoice item) => item.isDeleted;

  @override
  Stream<List<RecurringInvoice>> watchPage() => repo.watchPage(
    badgeModeId: activeBadgeModeId,
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
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
    final base = extraFilters;
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

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<RecurringInvoice>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    BulkAction<RecurringInvoice>(
      id: 'send_now',
      labelKey: 'send_now',
      // send_now sends the first occurrence — draft-only, matching React.
      eligible: (r) => !isDeleted(r) && r.isDraft,
      apply: (id) => repo.sendNow(companyId: companyId, id: id),
    ),
    BulkAction<RecurringInvoice>(
      id: 'start',
      labelKey: 'start',
      eligible: (r) => !isDeleted(r),
      apply: (id) => repo.start(companyId: companyId, id: id),
    ),
    BulkAction<RecurringInvoice>(
      id: 'stop',
      labelKey: 'stop',
      eligible: (r) => !isDeleted(r),
      apply: (id) => repo.stop(companyId: companyId, id: id),
    ),
    BulkAction<RecurringInvoice>(
      id: 'run_template',
      labelKey: 'run_template',
      eligible: (r) => !isDeleted(r),
      applyArg: (id, arg) => repo.runTemplate(
        companyId: companyId,
        id: id,
        templateId: arg as String,
      ),
    ),
    BulkAction<RecurringInvoice>(
      id: 'update_prices',
      labelKey: 'update_prices',
      eligible: (r) => !isDeleted(r),
      apply: (id) => repo.updatePrices(companyId: companyId, id: id),
    ),
    BulkAction<RecurringInvoice>(
      id: 'increase_prices',
      labelKey: 'increase_prices',
      eligible: (r) => !isDeleted(r),
      applyArg: (id, arg) => repo.increasePrices(
        companyId: companyId,
        id: id,
        percentageIncrease: arg as String,
      ),
    ),
  ];
}
