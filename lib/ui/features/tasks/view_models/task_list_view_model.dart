import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/task_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// List ViewModel for the Tasks screen (list view only — the kanban board
/// has its own `KanbanViewModel` + `TaskFiltersMixin` state and does not
/// share this VM's filter chips).
class TaskListViewModel extends GenericListViewModel<Task> {
  TaskListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.clientId,
    this.projectId,
  });

  final TaskRepository repo;

  /// When non-null, scopes the watch + fetch to one client.
  final String? clientId;

  /// When non-null, scopes the watch + fetch to one project. Used by the
  /// embedded list inside `ProjectDetailScreen`'s Tasks tab.
  final String? projectId;

  @override
  Set<String> get lockedFilterKeyIds => {
    if (clientId != null) 'client',
    if (projectId != null) 'project',
  };

  @override
  EntityType get entityType => EntityType.task;

  @override
  List<ColumnDefinition<Task>> get allColumns => kAllTaskColumns;

  @override
  List<String> get defaultColumnIds => kDefaultTaskColumns;

  @override
  String get defaultSortField => TaskFieldIds.updatedAt;

  /// Newest first: last-updated ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(taskColumnsById, field) ||
      field == TaskFieldIds.updatedAt;

  @override
  String idOf(Task item) => item.id;

  @override
  bool isArchived(Task item) => item.archivedAt != null;

  @override
  bool isDeleted(Task item) => item.isDeleted;

  @override
  Stream<List<Task>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
    projectId: projectId,
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
  Iterable<BulkAction<Task>> get bulkActions => [
    BulkAction<Task>(
      id: 'start',
      labelKey: 'start',
      eligible: (t) => !t.isRunning && !t.isInvoiced && !t.isDeleted,
      apply: (id) => repo.startTimer(companyId: companyId, taskId: id),
    ),
    BulkAction<Task>(
      id: 'stop',
      labelKey: 'stop',
      eligible: (t) => t.isRunning && !t.isDeleted,
      apply: (id) => repo.stopRunningTimer(companyId: companyId, taskId: id),
    ),
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    // Selection-level actions: the per-id `apply` is a deliberate no-op — the
    // screen's `EntityListBulkAction.onSelection` builds one invoice from the
    // whole selection. `eligible` still drives the empty-selection guard.
    // A running task would bill a live-timer snapshot; an invoiced one would
    // double-bill; a `tmp_` row has no server id to reference.
    BulkAction<Task>(
      id: 'invoice_task',
      labelKey: 'invoice_task',
      eligible: _billable,
      apply: (_) async {},
    ),
    BulkAction<Task>(
      id: 'add_to_invoice',
      labelKey: 'add_to_invoice',
      // Plus a client — the invoice picker is client-scoped.
      eligible: (t) => _billable(t) && t.clientId.isNotEmpty,
      apply: (_) async {},
    ),
  ];

  static bool _billable(Task t) =>
      !t.isDeleted && !t.id.startsWith('tmp_') && !t.isRunning && !t.isInvoiced;
}
