import 'package:admin/data/db/dao/payment_link_dao.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/data/repositories/payment_link_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/payment_link_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Payment Links screen. Mirrors
/// [ExpenseCategoryListViewModel] — plugs the [GenericListViewModel] base
/// into [PaymentLinkRepository] and the local column registry.
class PaymentLinkListViewModel extends GenericListViewModel<PaymentLink> {
  PaymentLinkListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  });

  final PaymentLinkRepository repo;

  @override
  EntityType get entityType => EntityType.paymentLink;

  @override
  List<ColumnDefinition<PaymentLink>> get allColumns => kAllPaymentLinkColumns;

  @override
  List<String> get defaultColumnIds => kDefaultPaymentLinkColumns;

  @override
  String get defaultSortField => PaymentLinkFieldIds.name;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(paymentLinkColumnsById, field);

  @override
  String idOf(PaymentLink item) => item.id;

  @override
  bool isArchived(PaymentLink item) => item.archivedAt != null;

  @override
  bool isDeleted(PaymentLink item) => item.isDeleted;

  @override
  Stream<List<PaymentLink>> watchPage() => repo.watchPage(
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
  Iterable<BulkAction<PaymentLink>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );
}
