import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/webhooks_table.dart';

part 'webhook_dao.g.dart';

class WebhookFieldIds {
  static const String targetUrl = 'target_url';
  static const String eventId = 'event_id';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}

@DriftAccessor(tables: [Webhooks])
class WebhookDao extends DatabaseAccessor<AppDatabase>
    with _$WebhookDaoMixin, CompanyScopedDao {
  WebhookDao(super.db);

  Stream<List<WebhookRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = WebhookFieldIds.targetUrl,
    bool sortAscending = true,
  }) {
    final q = select(webhooks)..where((w) => w.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (w) => entityStateFilter(
          states: states,
          archivedAt: w.archivedAt,
          isDeleted: w.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (w) =>
            w.targetUrl.lower().like(needle) | w.eventId.lower().like(needle),
      );
    }

    q.orderBy([
      (w) => OrderingTerm(
        expression: _sortExpression(w, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (w) => OrderingTerm(expression: w.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(Webhooks w, String field) {
    switch (field) {
      case WebhookFieldIds.eventId:
        return w.eventId.lower();
      case WebhookFieldIds.createdAt:
        return w.createdAt;
      case WebhookFieldIds.updatedAt:
        return w.updatedAt;
      case WebhookFieldIds.targetUrl:
      default:
        return w.targetUrl.lower();
    }
  }

  Stream<WebhookRow?> watchById({
    required String companyId,
    required String id,
  }) {
    return (select(webhooks)
          ..where((w) => w.companyId.equals(companyId) & w.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(WebhooksCompanion row) =>
      into(webhooks).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<WebhooksCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(webhooks, rows));
  }

  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, WebhooksCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(webhooks)
      ..addColumns([webhooks.id])
      ..where(
        webhooks.companyId.equals(companyId) &
            webhooks.id.isIn(candidateIds) &
            webhooks.isDirty.equals(true),
      );
    final dirty = {for (final r in await dirtyQ.get()) r.read(webhooks.id)!};
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      webhooks,
    )..where((w) => w.companyId.equals(companyId) & w.id.equals(id))).go();
  }

  Stream<int> watchActiveCount({required String companyId}) {
    final q = selectOnly(webhooks)
      ..addColumns([webhooks.id.count()])
      ..where(
        webhooks.companyId.equals(companyId) &
            webhooks.isDeleted.equals(false) &
            webhooks.archivedAt.isNull(),
      );
    return q.map((row) => row.read(webhooks.id.count()) ?? 0).watchSingle();
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
    return (update(webhooks)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const WebhooksCompanion(isDirty: Value(false)));
  }
}
