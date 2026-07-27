import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/tax_rates_table.dart';

part 'tax_rate_dao.g.dart';

class TaxRateFieldIds {
  static const String name = 'name';
  static const String rate = 'rate';
  static const String updatedAt = 'updated_at';
}

@DriftAccessor(tables: [TaxRates])
class TaxRateDao extends DatabaseAccessor<AppDatabase>
    with _$TaxRateDaoMixin, CompanyScopedDao {
  TaxRateDao(super.db);

  Stream<List<TaxRateRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TaxRateFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(taxRates)..where((t) => t.companyId.equals(companyId));

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

  Expression _sortExpression(TaxRates t, String field) {
    switch (field) {
      case TaxRateFieldIds.name:
        return t.name.lower();
      case TaxRateFieldIds.rate:
        return t.rate;
      case TaxRateFieldIds.updatedAt:
        return t.updatedAt;
      default:
        return t.name.lower();
    }
  }

  /// Watch every active tax rate for a company, ordered by name. Used by the
  /// default-tax pickers on Settings → Tax Settings.
  Stream<List<TaxRateRow>> watchAll({required String companyId}) {
    final q = select(taxRates)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            t.isDeleted.equals(false) &
            t.archivedAt.isNull(),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]);
    return q.watch().distinctRows();
  }

  Stream<TaxRateRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(taxRates)
      ..where((t) => t.companyId.equals(companyId) & t.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<List<TaxRateRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <TaxRateRow>[]);
    final q = select(taxRates)
      ..where((t) => t.companyId.equals(companyId) & t.id.isIn(list));
    return q.get();
  }

  Future<void> upsert(TaxRatesCompanion row) =>
      into(taxRates).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<TaxRatesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(taxRates, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by
  /// `applyBundle` and `ensurePageLoaded` so the user's queued offline
  /// edit isn't clobbered by a stale server payload.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, TaxRatesCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(taxRates)
      ..addColumns([taxRates.id])
      ..where(
        taxRates.companyId.equals(companyId) &
            taxRates.id.isIn(candidateIds) &
            taxRates.isDirty.equals(true),
      );
    final dirty = {for (final r in await dirtyQ.get()) r.read(taxRates.id)!};
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      taxRates,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).go();
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
    return (update(taxRates)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const TaxRatesCompanion(isDirty: Value(false)));
  }
}
