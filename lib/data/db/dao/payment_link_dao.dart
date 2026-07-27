import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/payment_links_table.dart';

part 'payment_link_dao.g.dart';

/// Stable identifiers for sortable / filterable PaymentLink fields.
/// Mirrors `ExpenseCategoryFieldIds`.
class PaymentLinkFieldIds {
  static const String name = 'name';
  static const String price = 'price';
  static const String updatedAt = 'updated_at';

  /// Payload-only column surfaced by the column picker.
  static const String purchasePage = 'purchase_page';
}

@DriftAccessor(tables: [PaymentLinks])
class PaymentLinkDao extends DatabaseAccessor<AppDatabase>
    with _$PaymentLinkDaoMixin, CompanyScopedDao {
  PaymentLinkDao(super.db);

  Stream<List<PaymentLinkRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = PaymentLinkFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(paymentLinks)..where((s) => s.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (s) => entityStateFilter(
          states: states,
          archivedAt: s.archivedAt,
          isDeleted: s.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (s) =>
            s.name.lower().like(needle) | s.purchasePage.lower().like(needle),
      );
    }

    q.orderBy([
      (s) => OrderingTerm(
        expression: _sortExpression(s, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (s) => OrderingTerm(expression: s.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(PaymentLinks s, String field) {
    switch (field) {
      case PaymentLinkFieldIds.name:
        return s.name.lower();
      case PaymentLinkFieldIds.price:
        return s.priceCents;
      case PaymentLinkFieldIds.updatedAt:
        return s.updatedAt;
      // Payload-only column — see the note in ExpenseCategoryDao.
      case PaymentLinkFieldIds.purchasePage:
        return CustomExpression<String>(
          "LOWER(COALESCE(json_extract(payload, '\$.purchase_page'), ''))",
        );
      default:
        return s.name.lower();
    }
  }

  /// Count of rows matching the active state filter — drives the
  /// scaffold's pagination-exhausted check.
  Stream<int> watchCount({
    required String companyId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final countExp = paymentLinks.id.count();
    final q = selectOnly(paymentLinks)
      ..addColumns([countExp])
      ..where(paymentLinks.companyId.equals(companyId));
    if (states.isNotEmpty) {
      q.where(
        entityStateFilter(
          states: states,
          archivedAt: paymentLinks.archivedAt,
          isDeleted: paymentLinks.isDeleted,
        ),
      );
    }
    return q.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  Stream<PaymentLinkRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(paymentLinks)
      ..where((s) => s.companyId.equals(companyId) & s.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<void> upsert(PaymentLinksCompanion row) =>
      into(paymentLinks).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<PaymentLinksCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(paymentLinks, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by
  /// `applyBundle` and `ensurePageLoaded` so a stale server payload from a
  /// `/refresh` bundle or a paged refresh doesn't clobber a queued offline
  /// edit (which would also drop the row's "Unsynced" pill).
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, PaymentLinksCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(paymentLinks)
      ..addColumns([paymentLinks.id])
      ..where(
        paymentLinks.companyId.equals(companyId) &
            paymentLinks.id.isIn(candidateIds) &
            paymentLinks.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(paymentLinks.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      paymentLinks,
    )..where((s) => s.companyId.equals(companyId) & s.id.equals(id))).go();
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
    return (update(paymentLinks)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const PaymentLinksCompanion(isDirty: Value(false)));
  }
}
