import 'dart:async';

import 'package:admin/data/db/dao/company_gateway_dao.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/company_gateway_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/combine_latest.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/gateways/gateway_order_writer.dart';

/// List ViewModel for the Company Gateways screen. Mirrors the standard
/// `<Entity>ListViewModel` shape — the base class owns pagination, search,
/// filter, sort, multiselect, and column persistence.
class CompanyGatewayListViewModel extends GenericListViewModel<CompanyGateway> {
  CompanyGatewayListViewModel({
    required this.repo,
    required this.companyRepo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  });

  final CompanyGatewayRepository repo;

  /// Read-only company watch — supplies `company_gateway_ids` so the list can
  /// present gateways in the saved order and mark the default one.
  final CompanyRepository companyRepo;

  /// Id of the default gateway (first in `company_gateway_ids`), surfaced for
  /// the per-row "Default" badge. Recomputed on every list emission.
  String? _defaultGatewayId;
  String? get defaultGatewayId => _defaultGatewayId;

  @override
  EntityType get entityType => EntityType.companyGateway;

  @override
  List<ColumnDefinition<CompanyGateway>> get allColumns =>
      kAllCompanyGatewayColumns;

  @override
  List<String> get defaultColumnIds => kDefaultCompanyGatewayColumns;

  @override
  String get defaultSortField => CompanyGatewayFieldIds.updatedAt;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(companyGatewayColumnsById, field) ||
      field == CompanyGatewayFieldIds.updatedAt;

  @override
  String idOf(CompanyGateway item) => item.id;

  @override
  bool isArchived(CompanyGateway item) => item.archivedAt != 0;

  @override
  bool isDeleted(CompanyGateway item) => item.isDeleted;

  @override
  Stream<List<CompanyGateway>> watchPage() {
    final base = repo.watchPage(
      companyId: companyId,
      loadedPages: loadedPages,
      search: search.isEmpty ? null : search,
      states: states,
      sortField: sortField,
      sortAscending: sortAscending,
    );
    // Fold in `company_gateway_ids`: the default sort presents gateways in the
    // saved order (so a reorder via the sheet is reflected here); an explicit
    // sort choice from the menu wins. Either way we stamp the default id for
    // the per-row badge. Combining streams keeps it reactive to a reorder even
    // when the gateway rows themselves don't change.
    return combineLatest2<List<CompanyGateway>, Company?, List<CompanyGateway>>(
      base,
      companyRepo.watchCompany(companyId),
      (gateways, company) {
        final csv = company?.settings.companyGatewayIds ?? '';
        _defaultGatewayId = firstGatewayId(csv);
        if (sortField != defaultSortField) return gateways;
        return orderGatewaysByCsv(gateways, csv);
      },
    );
  }

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
  Iterable<BulkAction<CompanyGateway>> get bulkActions =>
      standardCrudBulkActions(
        isArchived: isArchived,
        isDeleted: isDeleted,
        archive: (id) => repo.archive(companyId: companyId, id: id),
        restore: (id) => repo.restore(companyId: companyId, id: id),
        delete: (id) => repo.delete(companyId: companyId, id: id),
      );
}
