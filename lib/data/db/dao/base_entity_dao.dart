import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show protected, visibleForTesting;

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

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
  ///
  /// Note this counts archived rows too. That's wrong for the sidebar badge
  /// (whose list shows active rows only) — see [watchBadgeCount] — but it's
  /// the long-standing behaviour for the other ~10 callers, so it stays.
  Stream<int> watchCount({required String companyId}) {
    final count = idColumn.count();
    final q = selectOnly(table)
      ..addColumns([count])
      ..where(
        companyIdColumn.equals(companyId) & isDeletedColumn.equals(false),
      );
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  // -- Sidebar counter badge ------------------------------------------------

  /// `archived_at` — bound by the DAOs whose entity shows a sidebar badge, so
  /// [watchBadgeCount] can exclude archived rows and match the list the user
  /// sees when they click the row. Every entity table has the column (via
  /// `EntityTimestampColumns`); leaving it null on a DAO simply opts that DAO
  /// out of the active-only filter.
  GeneratedColumn<int>? get archivedAtColumn => null;

  /// Extra predicate for a non-`total` [SidebarBadgeMode]. Return null for a
  /// mode this entity doesn't understand — the count then falls back to
  /// counting everything, which is friendlier than showing a hard zero. The
  /// coherence check in `sidebar_badge_count_test` is what stops a *declared*
  /// mode from quietly landing in that fallback; hence `@visibleForTesting`
  /// alongside `@protected`.
  @protected
  @visibleForTesting
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => null;

  /// Live count behind the sidebar badge: active rows for [companyId] that
  /// match [modeId]. `total` counts them all; every other id delegates to
  /// [badgeModePredicate]. [currentUserId] is only read by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) {
    if (modeId == kBadgeModeNone) return Stream.value(0);
    final count = idColumn.count();
    final q = selectOnly(table)
      ..addColumns([count])
      ..where(badgeBaseFilter(companyId));
    final extra = modeId == kBadgeModeTotal
        ? null
        : badgeModePredicate(
            modeId,
            companyId: companyId,
            currentUserId: currentUserId,
          );
    if (extra != null) q.where(extra);
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// The company + active-state predicate every badge count starts from. Also
  /// used to scope the cross-entity subqueries (a vendor's unpaid expenses
  /// shouldn't count an expense the user archived).
  @protected
  Expression<bool> badgeBaseFilter(String companyId) {
    final base =
        companyIdColumn.equals(companyId) & isDeletedColumn.equals(false);
    final archived = archivedAtColumn;
    return archived == null ? base : base & archived.isNull();
  }

  /// `assigned_to_me` predicate. An empty [userId] matches **nothing** — a
  /// logged-out or mid-switch session must show no rows rather than every row.
  ///
  /// Pass [column] when the entity has a real `assigned_user_id` column; omit
  /// it for tasks / expenses, whose tables don't, and the value is read out of
  /// the `payload` JSON instead (the same `json_extract` idiom `ProductDao`
  /// uses for the inventory fields).
  @protected
  Expression<bool> assignedToUserFilter(
    String userId, {
    GeneratedColumn<String>? column,
  }) {
    if (userId.isEmpty) return const Constant(false);
    if (column != null) return column.equals(userId);
    return const CustomExpression<String>(
      "COALESCE(json_extract(payload, '\$.assigned_user_id'), '')",
    ).equals(userId);
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

  /// Project-name counterpart of [clientNameMatchesFilter]. Mirrors the
  /// server `orWhereHas('project', name LIKE)` in `TaskFilters::filter` for
  /// project-bearing DAOs — without this the local task search hides the
  /// project-name matches the API returns. The `projects` subquery keeps the
  /// watch reactive to project renames.
  Expression<bool> projectNameMatchesFilter({
    required GeneratedColumn<String> projectId,
    required String companyId,
    required String needle,
  }) {
    final projects = attachedDatabase.projects;
    final matchingProjectIds = selectOnly(projects)
      ..addColumns([projects.id])
      ..where(
        projects.companyId.equals(companyId) &
            projects.name.lower().like(needle),
      );
    return projectId.isInQuery(matchingProjectIds);
  }

  /// Expense-category-name counterpart of [clientNameMatchesFilter]. Mirrors
  /// the server `orWhereHas('category', name LIKE)` in `ExpenseFilters` /
  /// `RecurringExpenseFilters` for category-bearing DAOs (expense,
  /// recurring_expense) — without this the local search hides the
  /// category-name matches the API returns. The `expenseCategories` subquery
  /// keeps the watch reactive to category renames.
  Expression<bool> categoryNameMatchesFilter({
    required GeneratedColumn<String> categoryId,
    required String companyId,
    required String needle,
  }) {
    final categories = attachedDatabase.expenseCategories;
    final matchingCategoryIds = selectOnly(categories)
      ..addColumns([categories.id])
      ..where(
        categories.companyId.equals(companyId) &
            categories.name.lower().like(needle),
      );
    return categoryId.isInQuery(matchingCategoryIds);
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
