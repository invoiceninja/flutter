import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/tokens_table.dart';

part 'token_dao.g.dart';

class TokenFieldIds {
  static const String name = 'name';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}

@DriftAccessor(tables: [Tokens])
class TokenDao extends DatabaseAccessor<AppDatabase>
    with _$TokenDaoMixin, CompanyScopedDao {
  TokenDao(super.db);

  Stream<List<TokenRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TokenFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(tokens)..where((t) => t.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (t) => entityStateFilter(
          states: states,
          archivedAt: t.archivedAt,
          isDeleted: t.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where((t) => t.name.lower().like(needle));
    }

    q.orderBy([
      (t) => OrderingTerm(
        expression: _sortExpression(t, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (t) => OrderingTerm(expression: t.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(Tokens t, String field) {
    switch (field) {
      case TokenFieldIds.createdAt:
        return t.createdAt;
      case TokenFieldIds.updatedAt:
        return t.updatedAt;
      case TokenFieldIds.name:
      default:
        return t.name.lower();
    }
  }

  Stream<TokenRow?> watchById({required String companyId, required String id}) {
    return (select(tokens)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(TokensCompanion row) =>
      into(tokens).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<TokensCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(tokens, rows));
  }

  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, TokensCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(tokens)
      ..addColumns([tokens.id])
      ..where(
        tokens.companyId.equals(companyId) &
            tokens.id.isIn(candidateIds) &
            tokens.isDirty.equals(true),
      );
    final dirty = {for (final r in await dirtyQ.get()) r.read(tokens.id)!};
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      tokens,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).go();
  }

  Stream<int> watchActiveCount({required String companyId}) {
    final q = selectOnly(tokens)
      ..addColumns([tokens.id.count()])
      ..where(
        tokens.companyId.equals(companyId) &
            tokens.isDeleted.equals(false) &
            tokens.archivedAt.isNull(),
      );
    return q.map((row) => row.read(tokens.id.count()) ?? 0).watchSingle();
  }

  /// Clear the local `is_dirty` flag for one row (mirrors
  /// [BaseEntityDao.clearDirtyById]).
  ///
  /// Load-bearing: this DAO doesn't extend `BaseEntityDao`, so
  /// `BaseEntityRepository.localDao` is null and the discard-reconciliation
  /// hook would be a silent no-op. Because every refresh path here goes
  /// through `upsertAllPreservingDirty`, a row left dirty after the user
  /// discards its edit is skipped by EVERY later refresh — the abandoned
  /// value would be shown as authoritative forever.
  Future<void> clearDirtyById({required String companyId, required String id}) {
    return (update(tokens)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const TokensCompanion(isDirty: Value(false)));
  }
}
