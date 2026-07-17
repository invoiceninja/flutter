import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/projects_table.dart';

part 'project_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `ProjectRepository.watchPage`.
class ProjectFieldIds {
  static const String name = 'name';
  static const String number = 'number';
  static const String clientId = 'client_id';
  static const String assignedUserId = 'assigned_user_id';
  static const String dueDate = 'due_date';
  static const String taskRate = 'task_rate';
  static const String budgetedHours = 'budgeted_hours';
  static const String currentHours = 'current_hours';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String customValue1 = 'custom_value1';
  static const String customValue2 = 'custom_value2';
  static const String customValue3 = 'custom_value3';
  static const String customValue4 = 'custom_value4';

  /// Local approximation of the server's `project_tag_ids|asc` sort — orders
  /// by the denormalized, comma-joined tag names (`projects.tag_names`).
  static const String tagIds = 'project_tag_ids';
}

@DriftAccessor(tables: [Projects])
class ProjectDao extends BaseEntityDao<$ProjectsTable, ProjectRow>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  @override
  $ProjectsTable get table => projects;
  @override
  GeneratedColumn<String> get idColumn => projects.id;
  @override
  GeneratedColumn<String> get companyIdColumn => projects.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => projects.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => projects.isDirty;

  /// Watch a windowed slice of projects. Filters: state (active/archived/
  /// deleted), free-text search across name + number + public/private
  /// notes (via payload JSON extract).
  Stream<List<ProjectRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ProjectFieldIds.name,
    bool sortAscending = true,
    String? clientId,
    Set<String> clientIds = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
  }) {
    final q = select(projects)..where((p) => p.companyId.equals(companyId));

    if (clientId != null && clientId.isNotEmpty) {
      q.where((p) => p.clientId.equals(clientId));
    }
    // `client_id` membership mirror (the standalone list's `client:` chips) —
    // distinct from the single embedded [clientId] lock above. Same idiom as
    // InvoiceDao.
    if (clientIds.isNotEmpty) {
      q.where((p) => p.clientId.isIn(clientIds.toList()));
    }
    // Workspace list: hide projects whose client was soft-deleted (offline
    // parity with the server `without_deleted_clients` fetch filter). Skipped
    // under an explicit client scope (client-detail tab or `client:` chips) so
    // a client's own rows stay visible.
    if ((clientId == null || clientId.isEmpty) && clientIds.isEmpty) {
      q.where(
        (p) =>
            clientNotDeletedFilter(clientId: p.clientId, companyId: companyId),
      );
    }
    // Custom-field filters mirror server `custom_value1..4` (exact-set local
    // predicate is source of truth — same idiom as ClientDao/InvoiceDao).
    if (customValues1.isNotEmpty) {
      q.where((p) => p.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((p) => p.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((p) => p.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((p) => p.customValue4.isIn(customValues4.toList()));
    }

    if (states.isNotEmpty) {
      q.where(
        (p) => entityStateFilter(
          states: states,
          archivedAt: p.archivedAt,
          isDeleted: p.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (p) =>
            p.name.lower().like(needle) |
            p.number.lower().like(needle) |
            p.customValue1.lower().like(needle) |
            p.customValue2.lower().like(needle) |
            p.customValue3.lower().like(needle) |
            p.customValue4.lower().like(needle) |
            clientNameMatchesFilter(
              clientId: p.clientId,
              companyId: companyId,
              needle: needle,
            ),
      );
    }

    q.orderBy([
      (p) => OrderingTerm(
        expression: _sortExpression(p, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (p) => OrderingTerm(expression: p.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(Projects p, String field) {
    switch (field) {
      case ProjectFieldIds.name:
        return p.name.lower();
      case ProjectFieldIds.number:
        return p.number.lower();
      case ProjectFieldIds.clientId:
        return p.clientId;
      case ProjectFieldIds.assignedUserId:
        return p.assignedUserId;
      case ProjectFieldIds.dueDate:
        return p.dueDate;
      case ProjectFieldIds.taskRate:
        return p.taskRate.cast<double>();
      case ProjectFieldIds.budgetedHours:
        return p.budgetedHours;
      case ProjectFieldIds.currentHours:
        return p.currentHours;
      case ProjectFieldIds.tagIds:
        return p.tagNames;
      case ProjectFieldIds.createdAt:
        return p.createdAt;
      case ProjectFieldIds.updatedAt:
        return p.updatedAt;
      case ProjectFieldIds.customValue1:
        return p.customValue1.lower();
      case ProjectFieldIds.customValue2:
        return p.customValue2.lower();
      case ProjectFieldIds.customValue3:
        return p.customValue3.lower();
      case ProjectFieldIds.customValue4:
        return p.customValue4.lower();
      default:
        return p.name.lower();
    }
  }

  /// Stream `(id, name)` pairs for active projects in this company. Cheap
  /// alternative to `watchPage` for filter-key suggestions and chip name
  /// resolution — selects only the two columns needed and orders by name.
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) {
    final q = selectOnly(projects)
      ..addColumns([projects.id, projects.name])
      ..where(
        projects.companyId.equals(companyId) &
            projects.isDeleted.equals(false) &
            projects.archivedAt.isNull(),
      )
      ..orderBy([OrderingTerm(expression: projects.name.lower())]);
    return q
        .map((row) {
          return (
            id: row.read<String>(projects.id) ?? '',
            name: row.read<String>(projects.name) ?? '',
          );
        })
        .watch()
        .distinctRows();
  }

  /// Watch every project for one client. Used by the Task edit Project
  /// picker so changing client narrows the project list immediately.
  Stream<List<ProjectRow>> watchForClient({
    required String companyId,
    required String clientId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(projects)
      ..where(
        (p) => p.companyId.equals(companyId) & p.clientId.equals(clientId),
      );
    if (states.isNotEmpty) {
      q.where(
        (p) => entityStateFilter(
          states: states,
          archivedAt: p.archivedAt,
          isDeleted: p.isDeleted,
        ),
      );
    }
    q.orderBy([(p) => OrderingTerm(expression: p.name.lower())]);
    return q.watch().distinctRows();
  }

  /// Distinct non-empty values of `custom_value{columnIndex}` for the given
  /// company, ordered ascending. Drives the bottom-sheet option list for
  /// custom-field filtering (mirrors `ClientDao`).
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) {
    final column = switch (columnIndex) {
      1 => projects.customValue1,
      2 => projects.customValue2,
      3 => projects.customValue3,
      4 => projects.customValue4,
      _ => throw ArgumentError('columnIndex must be 1..4 (got $columnIndex)'),
    };
    final q = selectOnly(projects, distinct: true)
      ..addColumns([column])
      ..where(projects.companyId.equals(companyId) & column.equals('').not())
      ..orderBy([OrderingTerm(expression: column)]);
    return q.map((row) => row.read(column)!).watch().distinctRows();
  }
}
