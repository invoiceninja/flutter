import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/sync_state_table.dart';

part 'sync_state_dao.g.dart';

class SyncCursor {
  const SyncCursor({
    this.updatedAt,
    this.id,
    this.lastDeltaAt,
    this.lastFullAt,
  });

  final int? updatedAt;
  final String? id;
  final int? lastDeltaAt;
  final int? lastFullAt;

  bool get isEmpty => updatedAt == null && id == null;
}

@DriftAccessor(tables: [SyncStateRows])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  Future<SyncCursor> read({
    required String companyId,
    required String entityType,
  }) async {
    final row =
        await (select(syncStateRows)
              ..where(
                (s) =>
                    s.companyId.equals(companyId) &
                    s.entityType.equals(entityType),
              )
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return const SyncCursor();
    return SyncCursor(
      updatedAt: row.lastUpdatedAt,
      id: row.lastUpdatedId,
      lastDeltaAt: row.lastDeltaSyncAt,
      lastFullAt: row.lastFullSyncAt,
    );
  }

  Future<void> writeCursor({
    required String companyId,
    required String entityType,
    required int updatedAt,
    required String id,
    required int now,
    bool wasFullSync = false,
  }) => into(syncStateRows).insertOnConflictUpdate(
    SyncStateRowsCompanion.insert(
      companyId: companyId,
      entityType: entityType,
      lastUpdatedAt: Value(updatedAt),
      lastUpdatedId: Value(id),
      lastDeltaSyncAt: Value(now),
      lastFullSyncAt: wasFullSync ? Value(now) : const Value.absent(),
    ),
  );

  /// Stamp `last_full_sync_at` on its own, leaving the keyset cursor alone.
  ///
  /// Called once by `refreshAllTemplate` when a full sweep has actually walked
  /// to the end, which is what the column is supposed to mean. It used to be a
  /// side effect of [writeCursor]`(wasFullSync: ignoreCursor)`, and `ignoreCursor`
  /// says "do not read the cursor" — true for page 1 of a real full sync, but
  /// also true of every page of the two single-page sweeps that now pass it (the
  /// dashboard's Billing Pipeline `All` tab and a saved-view apply). So the
  /// column recorded a full sync that had fetched fifty rows.
  ///
  /// Harmless today only because nothing reads it back; the point of fixing it is
  /// that the next consumer would inherit the lie.
  Future<void> markFullSync({
    required String companyId,
    required String entityType,
    required int now,
  }) => into(syncStateRows).insertOnConflictUpdate(
    SyncStateRowsCompanion.insert(
      companyId: companyId,
      entityType: entityType,
      lastFullSyncAt: Value(now),
    ),
  );

  /// Clear the cursor — used by "Force full sync".
  Future<void> reset({required String companyId, required String entityType}) =>
      (delete(syncStateRows)..where(
            (s) =>
                s.companyId.equals(companyId) & s.entityType.equals(entityType),
          ))
          .go();
}
