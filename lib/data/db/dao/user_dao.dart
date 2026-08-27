import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/columns/ids/user_column_ids.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/tables/user_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'user_dao.g.dart';

/// Reads/writes the per-(company, user) row. Powers two flows:
///  * Auth user — single-row reads via [watchByCompanyAndId] / [getByCompanyAndId].
///  * Settings → User Management — paged + filtered reads via [watchPage].
@DriftAccessor(tables: [Users])
class UserDao extends BaseEntityDao<$UsersTable, UserRow> with _$UserDaoMixin {
  UserDao(super.db);

  @override
  $UsersTable get table => users;
  @override
  GeneratedColumn<String> get idColumn => users.id;
  @override
  GeneratedColumn<String> get companyIdColumn => users.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => users.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => users.isDirty;

  /// Single-row lookup by `(company_id, id)`. Same shape as
  /// [BaseEntityDao.watchById]; kept under the legacy name so the auth-user
  /// repo (`UserRepository.watch`) and Email Settings's OAuth picker don't
  /// have to change.
  Stream<UserRow?> watchByCompanyAndId({
    required String companyId,
    required String id,
  }) {
    return watchById(companyId: companyId, id: id);
  }

  Future<UserRow?> getByCompanyAndId({
    required String companyId,
    required String id,
  }) {
    final q = select(users)
      ..where((u) => u.companyId.equals(companyId) & u.id.equals(id))
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// All user rows cached for the given company. Used by Email Settings's
  /// OAuth picker (filters by `oauth_provider_id`).
  Stream<List<UserRow>> watchAllForCompany({required String companyId}) {
    final q = select(users)..where((u) => u.companyId.equals(companyId));
    return q.watch().distinctRows();
  }

  /// Paged + filtered fetch for the User Management list screen and every
  /// assigned-user picker.
  ///
  /// Returns the **whole** company roster — the account owner and the
  /// logged-in user included. This used to strip both (`excludeOwner` /
  /// `excludeIds`, mirroring the `hideOwnerUsers` + `without=<authId>` server
  /// filters the fetch sent), which was invoiceninja/flutter#46: the owner was
  /// absent from User Management *and* unselectable in every assignee picker,
  /// since all of them read this one query. Restricting what may be *done* to
  /// the owner is the screen's job (see `user_management_screen.dart`), not
  /// this query's.
  ///
  /// `search` is a name-or-email LIKE filter applied in addition to whatever
  /// the server returned, so the local watch stream narrows in lockstep
  /// with the server response.
  Stream<List<UserRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = 'first_name',
    bool sortAscending = true,
  }) {
    final q = select(users)..where((u) => u.companyId.equals(companyId));

    if (states.isNotEmpty) {
      // Build OR predicate per requested state. archived = archived_at > 0,
      // deleted = is_deleted=true, active = archived_at IS NULL AND NOT deleted.
      Expression<bool>? predicate;
      for (final state in states) {
        final term = switch (state) {
          EntityState.active =>
            users.archivedAt.isNull() & users.isDeleted.equals(false),
          EntityState.archived =>
            users.archivedAt.isNotNull() & users.isDeleted.equals(false),
          EntityState.deleted => users.isDeleted.equals(true),
        };
        predicate = predicate == null ? term : predicate | term;
      }
      if (predicate != null) q.where((_) => predicate!);
    }

    if (search != null && search.isNotEmpty) {
      final pattern = '%$search%';
      q.where(
        (u) =>
            u.firstName.like(pattern) |
            u.lastName.like(pattern) |
            u.email.like(pattern),
      );
    }

    final mode = sortAscending ? OrderingMode.asc : OrderingMode.desc;
    q.orderBy([
      (u) => OrderingTerm(expression: _sortExpr(u, sortField), mode: mode),
      (u) => OrderingTerm(expression: u.id, mode: mode),
    ]);
    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpr(Users u, String field) {
    switch (field) {
      case 'first_name':
        return u.firstName;
      case 'last_name':
        return u.lastName;
      case 'email':
        return u.email;
      case 'created_at':
        return u.createdAt;
      case 'updated_at':
        return u.updatedAt;
      case UserFieldIds.phone:
        return u.phone;
      default:
        // Throw rather than silently ordering by first name — see the note in
        // `bank_transaction_dao`. `phone` reached this fallback.
        throw ArgumentError.value(
          field,
          'sortField',
          'no sort expression for this user column — add a case, or mark the '
              'column sortable: false',
        );
    }
  }

  Future<int> deleteForCompany(String companyId) =>
      (delete(users)..where((u) => u.companyId.equals(companyId))).go();
}
