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

  @override
  bool isValidColumnId(String field) =>
      taskColumnsById.containsKey(field) || field == TaskFieldIds.updatedAt;

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

  /// `tag:` is filtered post-decode over the loaded window (the tag ids live
  /// only in the row payload), so a short filtered result must auto-chain
  /// page fetches — see the base class.
  @override
  bool get localOnlyFilterActive =>
      (extraFilters['tag_ids'] ?? const <String>{}).isNotEmpty;

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
    // `tag_ids` is applied locally (post-decode in repo.watchPage) — see
    // [GenericListViewModel.extraFiltersWithout] for why it must not reach
    // the server fetch.
    var filters = GenericListViewModel.extraFiltersWithout(
      extraFilters,
      'tag_ids',
    );
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
  ];
}
