import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_search_fold.dart';
import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/group_settings_table.dart';

part 'group_setting_dao.g.dart';

/// Stable field-id constants for sort selection. Mirrors `ProductFieldIds`.
class GroupSettingFieldIds {
  static const String name = 'name';
  static const String updatedAt = 'updated_at';
}

@DriftAccessor(tables: [GroupSettings])
class GroupSettingDao
    extends BaseEntityDao<$GroupSettingsTable, GroupSettingRow>
    with _$GroupSettingDaoMixin {
  GroupSettingDao(super.db);

  @override
  $GroupSettingsTable get table => groupSettings;
  @override
  GeneratedColumn<String> get idColumn => groupSettings.id;
  @override
  GeneratedColumn<String> get companyIdColumn => groupSettings.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => groupSettings.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => groupSettings.isDirty;

  /// Watch a windowed slice of group_settings rows. Filters: state (active /
  /// archived / deleted), free-text search across `name`.
  Stream<List<GroupSettingRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = GroupSettingFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(groupSettings)
      ..where((g) => g.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (g) => entityStateFilter(
          states: states,
          archivedAt: g.archivedAt,
          isDeleted: g.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      q.where((g) => searchLike(g.name, search));
    }

    q.orderBy([
      (g) => OrderingTerm(
        expression: _sortExpression(g, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (g) => OrderingTerm(expression: g.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(GroupSettings g, String field) {
    switch (field) {
      case GroupSettingFieldIds.updatedAt:
        return g.updatedAt;
      case GroupSettingFieldIds.name:
      default:
        return g.name.lower();
    }
  }

  /// Watch every active row for [companyId], sorted by name ascending.
  /// Safe — small dataset, watches local Drift only, never expands into a
  /// large network page request. Drives the settings list and the Assign
  /// Group dialog dropdown.
  Stream<List<GroupSettingRow>> watchAll({required String companyId}) {
    final q = select(groupSettings)
      ..where(
        (g) =>
            g.companyId.equals(companyId) &
            g.isDeleted.equals(false) &
            g.archivedAt.isNull(),
      )
      ..orderBy([(g) => OrderingTerm(expression: g.name.lower())]);
    return q.watch().distinctRows();
  }

  /// Watch active **and** archived rows for [companyId] (excludes deleted),
  /// sorted by name ascending. Backs the list screen's "Show archived"
  /// toggle so an archived group stays restorable. The list scaffold splits
  /// the active/archived sections itself via its `isArchivedOf` predicate.
  Stream<List<GroupSettingRow>> watchAllIncludingArchived({
    required String companyId,
  }) {
    final q = select(groupSettings)
      ..where((g) => g.companyId.equals(companyId) & g.isDeleted.equals(false))
      ..orderBy([(g) => OrderingTerm(expression: g.name.lower())]);
    return q.watch().distinctRows();
  }
}
