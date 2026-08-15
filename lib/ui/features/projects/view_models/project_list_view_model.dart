import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/project_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Projects screen.
class ProjectListViewModel extends GenericListViewModel<Project> {
  ProjectListViewModel({
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

  final ProjectRepository repo;

  /// When non-null, scopes the watch + fetch to one client.
  final String? clientId;

  @override
  Set<String> get lockedFilterKeyIds => {if (clientId != null) 'client'};

  @override
  EntityType get entityType => EntityType.project;

  @override
  List<ColumnDefinition<Project>> get allColumns => kAllProjectColumns;

  @override
  List<String> get defaultColumnIds => kDefaultProjectColumns;

  @override
  String get defaultSortField => ProjectFieldIds.name;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(projectColumnsById, field) ||
      field == ProjectFieldIds.updatedAt;

  @override
  String idOf(Project item) => item.id;

  @override
  bool isArchived(Project item) => item.archivedAt != null;

  @override
  bool isDeleted(Project item) => item.isDeleted;

  @override
  Stream<List<Project>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
    extraFilters: extraFilters,
    customFilters: customFilters,
  );

  @override
  int get pageSize => repo.pageSize;

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) {
    var filters = extraFilters;
    if (clientId != null) {
      filters = {
        ...filters,
        'client_id': {clientId!},
      };
    }
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
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      repo.watchDistinctCustomValues(
        companyId: companyId,
        columnIndex: columnIndex,
      );

  @override
  Iterable<BulkAction<Project>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    // Selection-level actions: the per-id `apply` is a deliberate no-op — the
    // screen's `EntityListBulkAction.onSelection` does the real work (aggregate
    // invoice / open documents). `eligible` still drives the empty-selection
    // guard and the eligible-count passed to the handler.
    BulkAction<Project>(
      id: 'invoice_project',
      labelKey: 'invoice_project',
      eligible: (p) => !p.isDeleted && !p.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
    BulkAction<Project>(
      id: 'add_to_invoice',
      labelKey: 'add_to_invoice',
      // Same set as `invoice_project` plus a client — the invoice picker is
      // client-scoped, so a client-less project has nothing to append to.
      eligible: (p) =>
          !p.isDeleted && !p.id.startsWith('tmp_') && p.clientId.isNotEmpty,
      apply: (_) async {},
    ),
    BulkAction<Project>(
      id: 'download_documents',
      labelKey: 'documents',
      eligible: (p) => p.documents.isNotEmpty,
      apply: (_) async {},
    ),
  ];
}
