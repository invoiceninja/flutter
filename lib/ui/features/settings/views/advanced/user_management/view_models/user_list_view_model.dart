import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/user_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

/// Drives the Settings → User Management list screen.
///
/// The list excludes the company owner and the currently-authenticated user
/// (mirrors React's `?hideOwnerUsers=true&without=<authId>` query). Server
/// and Drift filters are kept in sync so cached rows can't bleed past the
/// exclusion when the screen renders offline.
class UserListViewModel extends GenericListViewModel<User> {
  UserListViewModel({
    required this.repo,
    required this.authUserId,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  });

  final UserRepository repo;
  final String authUserId;

  @override
  EntityType get entityType => EntityType.user;

  @override
  List<ColumnDefinition<User>> get allColumns => kAllUserColumns;

  @override
  List<String> get defaultColumnIds => kDefaultUserColumns;

  @override
  String get defaultSortField => UserFieldIds.firstName;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(userColumnsById, field);

  @override
  String idOf(User item) => item.id;

  @override
  bool isArchived(User item) => item.archivedAt > 0 && !item.isDeleted;

  @override
  bool isDeleted(User item) => item.isDeleted;

  @override
  Stream<List<User>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    excludeAuthUserId: authUserId,
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
    authUserId: authUserId,
    ignoreCursor: ignoreCursor,
  );

  @override
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

  @override
  Iterable<BulkAction<User>> get bulkActions => standardCrudBulkActions(
    isArchived: isArchived,
    isDeleted: isDeleted,
    archive: (id) => repo.archive(companyId: companyId, id: id),
    restore: (id) => repo.restore(companyId: companyId, id: id),
    delete: (id) => repo.delete(companyId: companyId, id: id),
  );

  Future<({int ok, int skipped, int failed})> bulkArchive() =>
      applyBulkAction(bulkActionById('archive')!);

  Future<({int ok, int skipped, int failed})> bulkRestore() =>
      applyBulkAction(bulkActionById('restore')!);
}
