import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';

/// Universal CRUD-list scaffolding for per-entity DAOs. Owns the five
/// methods every entity DAO needs to expose identically — `watchById`,
/// `watchCount`, `upsert`, `upsertAll`, `deleteById` — leaving the
/// concrete subclass to wire its table reference + the three column
/// expressions the base needs at runtime.
///
/// The mixins in `tables/_entity_table_mixin.dart` guarantee every entity
/// table has these three columns by the right name; the override hooks
/// here just bind them so the base can build queries without resorting
/// to dynamic column lookups.
///
/// Concrete DAOs still own `watchPage` (entity-specific filters + sort
/// expressions vary too much to share) and any entity-specific queries
/// — see [ClientDao.watchDistinctCustomValues], [TaskDao.watchRunning],
/// etc. The Drift-generated `_$XxxDaoMixin` still wires `@DriftAccessor`
/// like before.
abstract class BaseEntityDao<TableT extends Table, RowT>
    extends DatabaseAccessor<AppDatabase>
    with CompanyScopedDao {
  BaseEntityDao(super.db);

  /// The entity's Drift table accessor (e.g. `products`). [TableT] is the
  /// Drift-generated `$XxxTable` (a subclass of the hand-written `Xxx`
  /// table-source), so the runtime select/delete/insert flows here carry
  /// the same typing the per-DAO code would.
  TableInfo<TableT, RowT> get table;

  /// `id` column. Always non-null; `tmp_<uuid>` until the server assigns
  /// a real one.
  GeneratedColumn<String> get idColumn;

  /// `company_id` column. Every list query scopes by it — direct table
  /// access bypassing this check is caught by the `CompanyScopedDao` lint.
  GeneratedColumn<String> get companyIdColumn;

  /// `is_deleted` column. Soft-delete marker; the default `watchCount`
  /// excludes deleted rows.
  GeneratedColumn<bool> get isDeletedColumn;

  /// `is_dirty` column. Local-only flag — true means an unsynced edit is
  /// pending in the outbox. Used by [upsertAllPreservingDirty] to skip
  /// server-payload upserts that would otherwise clobber the user's
  /// in-flight edit.
  GeneratedColumn<bool> get isDirtyColumn;

  /// Count of non-deleted rows for [companyId]. Drives the empty-state UI
  /// and total-count badges on list screens.
  Stream<int> watchCount({required String companyId}) {
    final count = idColumn.count();
    final q = selectOnly(table)
      ..addColumns([count])
      ..where(
        companyIdColumn.equals(companyId) & isDeletedColumn.equals(false),
      );
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Single-row watch. Used by detail screens and edit screens that survive
  /// the tmp→real id swap (`id_remap` resolves the watched id under the
  /// hood, so callers don't have to track the swap themselves).
  Stream<RowT?> watchById({required String companyId, required String id}) {
    final q = select(table)
      ..where((_) => companyIdColumn.equals(companyId) & idColumn.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  /// Predicate that excludes rows whose client is soft-deleted in [companyId],
  /// while preserving rows that have no client (`client_id == ''`). Mirrors the
  /// server `without_deleted_clients=true` filter for the offline cache: a
  /// client delete doesn't cascade to its rows in Drift, so client-bearing DAOs
  /// AND this into `watchPage` to drop them from workspace lists. The `clients`
  /// subquery makes the watch reactive to client deletes.
  ///
  /// Apply it ONLY when the list is NOT scoped to a single client — viewing a
  /// (soft-deleted) client's own detail tabs must still show that client's rows.
  Expression<bool> clientNotDeletedFilter({
    required GeneratedColumn<String> clientId,
    required String companyId,
  }) {
    final clients = attachedDatabase.clients;
    final deletedClientIds = selectOnly(clients)
      ..addColumns([clients.id])
      ..where(
        clients.companyId.equals(companyId) & clients.isDeleted.equals(true),
      );
    return clientId.equals('') | clientId.isNotInQuery(deletedClientIds);
  }

  /// Predicate matching rows whose client's name matches the free-text search
  /// [needle] (already lowercased and `%`-wrapped). Mirrors the server's
  /// `orWhereHas('client', name LIKE)` so the local search view surfaces the
  /// same client-name hits the API returns — without this the UI (which reads
  /// from Drift, not the API response) filters the server's client-name
  /// matches back out, so e.g. searching invoices by client name shows nothing.
  ///
  /// OR this into `watchPage`'s search predicate on client-bearing DAOs. The
  /// `clients` subquery keeps the watch reactive to client renames.
  Expression<bool> clientNameMatchesFilter({
    required GeneratedColumn<String> clientId,
    required String companyId,
    required String needle,
  }) {
    final clients = attachedDatabase.clients;
    final matchingClientIds = selectOnly(clients)
      ..addColumns([clients.id])
      ..where(
        clients.companyId.equals(companyId) & clients.name.lower().like(needle),
      );
    return clientId.isInQuery(matchingClientIds);
  }

  /// Vendor-name counterpart of [clientNameMatchesFilter]. Mirrors the server
  /// `orWhereHas('vendor', name LIKE)` for vendor-bearing DAOs (expense,
  /// purchase_order, recurring_expense).
  Expression<bool> vendorNameMatchesFilter({
    required GeneratedColumn<String> vendorId,
    required String companyId,
    required String needle,
  }) {
    final vendors = attachedDatabase.vendors;
    final matchingVendorIds = selectOnly(vendors)
      ..addColumns([vendors.id])
      ..where(
        vendors.companyId.equals(companyId) & vendors.name.lower().like(needle),
      );
    return vendorId.isInQuery(matchingVendorIds);
  }

  /// Insert-or-update one row. The repository uses this on every applyXxx
  /// response handler.
  Future<void> upsert(Insertable<RowT> row) =>
      into(table).insertOnConflictUpdate(row);

  /// Batched insert-or-update; short-circuits when the list is empty so
  /// callers don't have to guard themselves.
  Future<void> upsertAll(List<Insertable<RowT>> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(table, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  ///
  /// For ids whose existing local row has `is_dirty = true`, the incoming
  /// companion is dropped — the user's pending edit (and the queued
  /// outbox row carrying it) survives the refresh. Everything else is
  /// upserted normally.
  ///
  /// Use this on every server-payload write path: `ensurePageLoaded`
  /// (paged refresh) and `applyBundle` (login/refresh fan-out). Single-
  /// row `applyXxxResponse` handlers (post-drain success) intentionally
  /// keep using [upsert] — the dirty bit on that row was set by the very
  /// mutation that just succeeded, and clearing it is correct.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, Insertable<RowT>> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirty = await _dirtyIdsAmong(companyId, candidateIds);
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<Set<String>> _dirtyIdsAmong(String companyId, List<String> ids) async {
    if (ids.isEmpty) return const {};
    final q = selectOnly(table)
      ..addColumns([idColumn])
      ..where(
        companyIdColumn.equals(companyId) &
            idColumn.isIn(ids) &
            isDirtyColumn.equals(true),
      );
    final rows = await q.get();
    return {for (final r in rows) r.read(idColumn)!};
  }

  /// Hard-delete a single row. Repositories use this when the outbox drain
  /// confirms a delete (the row has been removed server-side too).
  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(table)..where(
          (_) => companyIdColumn.equals(companyId) & idColumn.equals(id),
        ))
        .go();
  }

  /// Clear the `is_dirty` flag on one row without otherwise touching it.
  /// Used when a pending offline edit is DISCARDED (the outbox row dropped):
  /// the now-abandoned optimistic values must no longer be protected from
  /// the next server refresh (`upsertAllPreservingDirty` skips dirty rows),
  /// or the discarded edit would linger on screen forever. A partial update
  /// via [RawValuesInsertable] so the generic base doesn't need the concrete
  /// row companion.
  Future<void> clearDirtyById({required String companyId, required String id}) {
    return (update(table)..where(
          (_) => companyIdColumn.equals(companyId) & idColumn.equals(id),
        ))
        .write(
          RawValuesInsertable<RowT>({
            isDirtyColumn.name: const Constant(false),
          }),
        );
  }

  /// Optimistically flag a row archived (`archived_at = atEpochSeconds`,
  /// `is_dirty = true`) without the concrete row companion — the offline
  /// `archive` action calls this so the row visibly leaves the active list
  /// immediately, before the server round-trip. `is_dirty=true` protects the
  /// optimistic flip from a `/refresh` (`upsertAllPreservingDirty` skips dirty
  /// rows) until the sync response reconciles it. Mirrors [clearDirtyById];
  /// `archived_at` is the shared `_entity_table_mixin` column name.
  Future<void> setArchived({
    required String companyId,
    required String id,
    required int atEpochSeconds,
  }) {
    return (update(table)..where(
          (_) => companyIdColumn.equals(companyId) & idColumn.equals(id),
        ))
        .write(
          RawValuesInsertable<RowT>({
            'archived_at': Constant(atEpochSeconds),
            isDirtyColumn.name: const Constant(true),
          }),
        );
  }

  /// Optimistically restore a row to the active state (`archived_at = NULL`,
  /// `is_deleted = false`, `is_dirty = true`) — the offline `restore` action,
  /// which is the inverse of *both* archive and delete (it surfaces on
  /// archived and deleted rows), so it clears both flags. See [setArchived].
  Future<void> markRestored({required String companyId, required String id}) {
    return (update(table)..where(
          (_) => companyIdColumn.equals(companyId) & idColumn.equals(id),
        ))
        .write(
          RawValuesInsertable<RowT>({
            'archived_at': const Constant<int>(null),
            isDeletedColumn.name: const Constant(false),
            isDirtyColumn.name: const Constant(true),
          }),
        );
  }

  /// Optimistically flag a row deleted (`is_deleted = true`, `is_dirty = true`)
  /// — the offline `delete` action. Invoice Ninja delete is a soft-delete, so
  /// the row stays and just drops out of the active list via the [EntityState]
  /// filter. See [setArchived]; `purge` (hard delete) is not covered here.
  Future<void> markDeletedDirty({
    required String companyId,
    required String id,
  }) {
    return (update(table)..where(
          (_) => companyIdColumn.equals(companyId) & idColumn.equals(id),
        ))
        .write(
          RawValuesInsertable<RowT>({
            isDeletedColumn.name: const Constant(true),
            isDirtyColumn.name: const Constant(true),
          }),
        );
  }
}
