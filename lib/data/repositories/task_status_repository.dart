import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/task_status_dao.dart';
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/task_statuses_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('TaskStatusRepository');

class TaskStatusRepository
    extends BaseEntityRepository<TaskStatus, TaskStatusApi> {
  TaskStatusRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.taskStatus,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final TaskStatusesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'task_status';

  Stream<List<TaskStatus>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TaskStatusFieldIds.statusOrder,
    bool sortAscending = true,
  }) {
    return db.taskStatusDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Watch every active task status for a company. Used by the kanban
  /// board (one column per row) and by the status picker on Task edit.
  Stream<List<TaskStatus>> watchAll({required String companyId}) {
    return db.taskStatusDao
        .watchAll(companyId: companyId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Watch active **and** archived statuses, in canonical order. Used by
  /// the Settings → Task Statuses list when the user toggles "Show
  /// archived" so they can restore a previously-archived status.
  /// Limit is a defensive ceiling — typical workspaces have <20 statuses.
  Stream<List<TaskStatus>> watchAllIncludingArchived({
    required String companyId,
  }) {
    return db.taskStatusDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: 200,
          states: const {EntityState.active, EntityState.archived},
          sortField: TaskStatusFieldIds.statusOrder,
          sortAscending: true,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<TaskStatus?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.taskStatusDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Seed the local task_statuses table from the `/refresh` envelope's
  /// bundled `data[N].company.task_statuses` array. Called from
  /// `AuthRepository._persistAndActivate` so the first paint of the Task
  /// Statuses screen reads from Drift instead of firing a redundant
  /// `GET /task_statuses` (the data is already in hand).
  ///
  /// Upserts only — never deletes — so rows with pending local edits
  /// (`is_dirty = true`) keep their outbox-bound payload until the next
  /// real sync. Sets the keyset cursor to the bundle's max `updated_at`
  /// so a subsequent `ensurePageLoaded` treats the bundle as the freshest
  /// snapshot we've seen.
  Future<void> applyBundle({
    required String companyId,
    required List<TaskStatusApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    // Bundled refresh: skip ids whose existing local row has is_dirty=true,
    // so the user's pending offline edit isn't clobbered by login/refresh.
    upsert: (byId) => db.taskStatusDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) => ensurePageLoadedTemplate(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    search: search,
    states: states,
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.taskStatusDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

  Future<void> refreshAll({
    required String companyId,
    bool full = false,
  }) async {
    if (full) {
      await db.syncStateDao.reset(
        companyId: companyId,
        entityType: entityTypeName,
      );
    }
    var page = 1;
    var hasMore = true;
    const maxPages = 100; // ~5k statuses is more than anyone needs
    final allStates = EntityState.values.toSet();
    while (hasMore) {
      hasMore = await ensurePageLoaded(
        companyId: companyId,
        page: page,
        states: allStates,
        ignoreCursor: full && page == 1,
      );
      page++;
      if (page > maxPages) {
        _log.warning(
          'refreshAll hit the $maxPages page safety cap for $companyId',
        );
        break;
      }
    }
  }

  Future<SaveResult<TaskStatus>> create({
    required String companyId,
    required TaskStatus draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.taskStatusDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: stored.toApiJson(),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<TaskStatus>> save({
    required String companyId,
    required TaskStatus status,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(status.id);
    if (resolvedId != status.id) status = status.copyWith(id: resolvedId);

    final companion = _domainToCompanion(status, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.taskStatusDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: status.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: status.id,
        kind: MutationKind.update,
        payload: status.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: status, outboxRowId: rowId);
  }

  /// Reorder statuses by passing the new full id sequence (the Settings
  /// `ReorderableListView` and the kanban column drag both produce one).
  ///
  /// The server has **no** bulk sort endpoint for statuses, so we mirror
  /// `TaskStatusController::update`: a single `PUT /task_statuses/{id}`
  /// carrying the moved status's new `status_order` makes the server shift
  /// + renumber every sibling (1..N). We therefore:
  ///   1. detect the single moved status (the one whose removal makes the
  ///      old and new sequences identical),
  ///   2. compute its insertion `status_order` = the *current* order of the
  ///      status it should now precede (or `maxOrder + 1` to append) — the
  ///      slot the server's reorder pass opens, and
  ///   3. optimistically renumber every row **1-based** (the same space the
  ///      server renumbers into, so consecutive reorders stay consistent)
  ///      with `is_dirty = true` so an inbound delta can't clobber the new
  ///      order before the PUT drains.
  /// The `MutationKind.reorder` handler PUTs the moved status, then clears
  /// the optimistic dirty flags via [clearDirtyForReorder].
  Future<void> reorder({
    required String companyId,
    required List<String> orderedStatusIds,
  }) async {
    if (orderedStatusIds.isEmpty) return;
    await db.transaction(() async {
      final rows = await db.taskStatusDao.getByIds(
        companyId: companyId,
        ids: orderedStatusIds,
      );
      final byId = {for (final r in rows) r.id: r};

      // Pre-move order: current status_order asc, id as a stable tiebreak.
      final oldOrder = [...orderedStatusIds]
        ..sort((a, b) {
          final oa = byId[a]?.statusOrder ?? 0;
          final ob = byId[b]?.statusOrder ?? 0;
          return oa != ob ? oa.compareTo(ob) : a.compareTo(b);
        });

      // Nothing actually moved — bail before the detection loop, which
      // would otherwise match the first element (removing any single id
      // from two identical sequences leaves them equal).
      var changed = false;
      for (var i = 0; i < orderedStatusIds.length; i++) {
        if (oldOrder[i] != orderedStatusIds[i]) {
          changed = true;
          break;
        }
      }
      if (!changed) return;

      // The moved status is the one whose removal makes the old and new
      // sequences identical. (An adjacent swap has two valid candidates
      // that yield the same final order — the first match is correct.)
      String? movedId;
      for (final candidate in orderedStatusIds) {
        if (_sequencesEqualExcept(oldOrder, orderedStatusIds, candidate)) {
          movedId = candidate;
          break;
        }
      }
      if (movedId == null) return; // nothing actually moved
      // The moved id comes from the passed sequence, not the local cache; if a
      // concurrent sync removed its row between render and reorder, bail before
      // the optimistic write rather than dereferencing a missing row below.
      final movedRow = byId[movedId];
      if (movedRow == null) return;

      // Insertion slot = current order of the moved status's new successor
      // (or past the max to append), matching the server's reorder pass.
      final newIdx = orderedStatusIds.indexOf(movedId);
      final successorId = newIdx + 1 < orderedStatusIds.length
          ? orderedStatusIds[newIdx + 1]
          : null;
      final maxOrder = rows.fold<int>(
        0,
        (m, r) => r.statusOrder > m ? r.statusOrder : m,
      );
      final insertionOrder = successorId != null
          ? (byId[successorId]?.statusOrder ?? 0)
          : maxOrder + 1;

      // Optimistic renumber, 1-based to match the server's renumber space.
      final companions = <TaskStatusesCompanion>[];
      for (var i = 0; i < orderedStatusIds.length; i++) {
        final row = byId[orderedStatusIds[i]];
        if (row == null) continue;
        final domain = _fromRow(row).copyWith(statusOrder: i + 1);
        companions.add(_domainToCompanion(domain, companyId, isDirty: true));
      }
      await db.taskStatusDao.upsertAll(companions);

      // One standard PUT for the moved status; the server renumbers the
      // rest. `all_ids` lets the handler clear every optimistic dirty flag.
      final movedPayload = _fromRow(
        movedRow,
      ).copyWith(statusOrder: insertionOrder).toApiJson(preserveTempId: true);
      await enqueueMutation(
        companyId: companyId,
        entityId: movedId,
        kind: MutationKind.reorder,
        payload: {'status': movedPayload, 'all_ids': orderedStatusIds},
      );
    });
  }

  /// Clear `is_dirty` on the statuses touched by a successful reorder
  /// POST. Mirrors `TaskRepository.clearDirtyForReorder` so the
  /// `services.dart` reorder handler can reset the flag uniformly.
  Future<void> clearDirtyForReorder({
    required String companyId,
    required Iterable<String> statusIds,
  }) async {
    await db.transaction(() async {
      final rows = await db.taskStatusDao.getByIds(
        companyId: companyId,
        ids: statusIds,
      );
      if (rows.isEmpty) return;
      final companions = [
        for (final r in rows)
          r.toCompanion(true).copyWith(isDirty: const Value(false)),
      ];
      await db.taskStatusDao.upsertAll(companions);
    });
  }

  /// This DAO doesn't extend `BaseEntityDao`, so the base's `localDao` hook is
  /// null and the discard-reconciliation clear would be a no-op. Combined with
  /// `upsertAllPreservingDirty` on every refresh path, that pinned a discarded
  /// edit permanently — see [taskStatusDao.clearDirtyById].
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.taskStatusDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.taskStatusDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TaskStatusApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.taskStatusDao.upsert,
    deleteById: (id) =>
        db.taskStatusDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required TaskStatusApi serverResponse,
  }) async {
    await db.taskStatusDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.taskStatusDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.taskStatusDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  TaskStatusesCompanion _apiToCompanion(TaskStatusApi a, String companyId) {
    return TaskStatusesCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      color: Value(a.color),
      statusOrder: Value(a.statusOrder ?? 0),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  TaskStatusesCompanion _domainToCompanion(
    TaskStatus s,
    String companyId, {
    required bool isDirty,
  }) {
    return TaskStatusesCompanion.insert(
      id: s.id,
      companyId: companyId,
      name: Value(s.name),
      color: Value(s.color),
      statusOrder: Value(s.statusOrder),
      updatedAt: _secs(s.updatedAt),
      createdAt: Value(_secs(s.createdAt)),
      archivedAt: s.archivedAt == null
          ? const Value.absent()
          : Value(_secs(s.archivedAt!)),
      isDirty: Value(isDirty),
      isDeleted: Value(s.isDeleted),
      payload: jsonEncode(s.toApiJson(preserveTempId: true)),
    );
  }

  TaskStatus _fromRow(TaskStatusRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = TaskStatusApi.fromJson(json);
    return TaskStatus.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }
}

int _secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// True when removing every occurrence of [skip] from [a] and [b] yields
/// identical sequences — i.e. [a] and [b] differ only by the position of
/// [skip]. Used to detect the single moved status in a reorder.
bool _sequencesEqualExcept(List<String> a, List<String> b, String skip) {
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == skip) {
      i++;
      continue;
    }
    if (b[j] == skip) {
      j++;
      continue;
    }
    if (a[i] != b[j]) return false;
    i++;
    j++;
  }
  while (i < a.length && a[i] == skip) {
    i++;
  }
  while (j < b.length && b[j] == skip) {
    j++;
  }
  return i == a.length && j == b.length;
}
