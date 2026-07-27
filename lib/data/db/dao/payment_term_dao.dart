import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/payment_terms_table.dart';

part 'payment_term_dao.g.dart';

class PaymentTermFieldIds {
  static const String name = 'name';
  static const String numDays = 'num_days';
  static const String updatedAt = 'updated_at';
}

@DriftAccessor(tables: [PaymentTerms])
class PaymentTermDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentTermDaoMixin, CompanyScopedDao {
  PaymentTermDao(super.db);

  Stream<List<PaymentTermRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = PaymentTermFieldIds.numDays,
    bool sortAscending = true,
  }) {
    final q = select(paymentTerms)..where((t) => t.companyId.equals(companyId));

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

  Expression _sortExpression(PaymentTerms t, String field) {
    switch (field) {
      case PaymentTermFieldIds.name:
        return t.name.lower();
      case PaymentTermFieldIds.numDays:
        return t.numDays;
      case PaymentTermFieldIds.updatedAt:
        return t.updatedAt;
      default:
        return t.numDays;
    }
  }

  /// Watch every active payment term for a company, ordered by num_days
  /// ascending (Net 7 before Net 30 before Net 60). Used by the dropdown
  /// on Online Payments → Defaults.
  Stream<List<PaymentTermRow>> watchAll({required String companyId}) {
    final q = select(paymentTerms)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            t.isDeleted.equals(false) &
            t.archivedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.numDays),
        (t) => OrderingTerm(expression: t.name.lower()),
      ]);
    return q.watch().distinctRows();
  }

  Stream<PaymentTermRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(paymentTerms)
      ..where((t) => t.companyId.equals(companyId) & t.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<List<PaymentTermRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <PaymentTermRow>[]);
    final q = select(paymentTerms)
      ..where((t) => t.companyId.equals(companyId) & t.id.isIn(list));
    return q.get();
  }

  Future<void> upsert(PaymentTermsCompanion row) =>
      into(paymentTerms).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<PaymentTermsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(paymentTerms, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by
  /// `applyBundle` and `ensurePageLoaded` so the user's queued offline
  /// edit isn't clobbered by a stale server payload.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, PaymentTermsCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(paymentTerms)
      ..addColumns([paymentTerms.id])
      ..where(
        paymentTerms.companyId.equals(companyId) &
            paymentTerms.id.isIn(candidateIds) &
            paymentTerms.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(paymentTerms.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      paymentTerms,
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
    return (update(paymentTerms)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const PaymentTermsCompanion(isDirty: Value(false)));
  }
}
