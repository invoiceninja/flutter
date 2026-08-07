import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('TaskRepository');

/// Source of truth for Task data. Mirrors `ProductRepository`'s shape with
/// two task-specific additions:
///   * `watchAllForKanban` — un-paginated stream for the kanban board.
///   * `watchRunning` — the single most-recently-updated running task,
///     for the global running-timer pill.
///   * `reorder` — enqueues a `MutationKind.reorder` row carrying the
///     bulk kanban-sort payload.
class TaskRepository extends BaseEntityRepository<Task, TaskApi>
    with TagNameResolver
    implements DocumentBearingRepository {
  TaskRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.task,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
         },
       );

  final TasksApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'task';

  /// Paginated list view. The list screen calls this; the kanban board
  /// uses [watchAllForKanban] instead.
  ///
  /// [extraFilters] mirrors the server-bound filter dimensions locally
  /// (the UI renders from this watch, so a server-only filter would look
  /// like it did nothing — the billing_extra_filters gap): `task_status`
  /// and `project_tasks` become SQL predicates; `tag_ids` is a post-decode
  /// predicate (tag ids live only in the payload JSON — the denormalized
  /// `tag_names` column holds names, for sort). Completeness of the tag
  /// filter is bounded by the loaded pages; the list VM strips `tag_ids`
  /// from the server fetch and auto-chains page loads to converge.
  Stream<List<Task>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TaskFieldIds.updatedAt,
    bool sortAscending = false,
    String? clientId,
    String? projectId,
    Map<String, Set<String>> extraFilters = const {},
    Map<int, Set<String>> customFilters = const {},
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    final tagIds = parseCsvFilter(extraFilters, 'tag_ids');
    return db.taskDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          clientId: clientId,
          projectId: projectId,
          statusIds: parseCsvFilter(extraFilters, 'task_status'),
          projectIds: parseCsvFilter(extraFilters, 'project_tasks'),
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((t) => matchesTagIdFilter(t.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  /// Stream of tasks grouped by `status_id` for the kanban board. Empty
  /// keys are included so newly-created statuses with no tasks still get
  /// a column (the kanban VM joins this with the watch-all status stream).
  Stream<Map<String, List<Task>>> watchAllByStatus({
    required String companyId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    return db.taskDao
        .watchAllForKanban(companyId: companyId, states: states)
        .map((rows) {
          final result = <String, List<Task>>{};
          for (final row in rows) {
            final task = _fromRow(row);
            // Invoiced tasks are server-immutable; React excludes them from
            // the board so they can't be dragged / re-ordered. They remain
            // visible in the flat list views.
            if (task.isInvoiced) continue;
            result.putIfAbsent(task.statusId, () => <Task>[]).add(task);
          }
          return result;
        });
  }

  /// Flat, unpaginated stream of every task for a company in the given
  /// [states]. Backs the calendar / daily / weekly views, which group by each
  /// task's day in Dart. Unlike [watchAllByStatus] this does NOT drop invoiced
  /// tasks — invoiced work still occupies calendar days and timesheet cells
  /// (rendered read-only). Reuses the kanban DAO query; the `status_order`
  /// sort is irrelevant here since the views re-sort by time-entry start.
  Stream<List<Task>> watchAllActive({
    required String companyId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    return db.taskDao
        .watchAllForKanban(companyId: companyId, states: states)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// The single most-recently-updated running task, or null. Backs the
  /// global running-timer pill (mounted in `AppShell`).
  Stream<Task?> watchRunning({required String companyId}) {
    return db.taskDao
        .watchRunning(companyId: companyId)
        .map((row) => row == null ? null : _fromRow(row));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.taskDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.taskDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  /// Active, non-deleted tasks for a single project. Backs the "Tasks"
  /// card on the Project detail screen.
  Stream<List<Task>> watchForProject({
    required String companyId,
    required String projectId,
  }) {
    if (projectId.isEmpty) {
      return Stream<List<Task>>.value(const <Task>[]);
    }
    return db.taskDao
        .watchForProject(companyId: companyId, projectId: projectId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Task?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.taskDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

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
    excludeDeletedClients: true,
    // `?include=documents` — same rationale as Project/Client/Expense.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) =>
        db.taskDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
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
    const maxPages = 1000;
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
          'refreshAll hit the $maxPages page safety cap for company '
          '$companyId — cursor will resume on the next sync trigger.',
        );
        break;
      }
    }
  }

  Future<SaveResult<Task>> create({
    required String companyId,
    required Task draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    // Resolved OUTSIDE the transaction — see TagNameResolver.
    final tagNames = await resolveTagNames(companyId, stored.tagIds);

    var rowId = 0;
    await db.transaction(() async {
      final companion = _domainToCompanion(
        stored,
        companyId,
        isDirty: true,
        tagNames: tagNames,
      );
      await db.taskDao.upsert(companion);
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

  Future<SaveResult<Task>> save({
    required String companyId,
    required Task task,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(task.id);
    if (resolvedId != task.id) task = task.copyWith(id: resolvedId);

    // Resolved OUTSIDE the transaction — see TagNameResolver.
    final tagNames = await resolveTagNames(companyId, task.tagIds);
    var rowId = 0;
    await db.transaction(() async {
      final companion = _domainToCompanion(
        task,
        companyId,
        isDirty: true,
        tagNames: tagNames,
      );
      await db.taskDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: task.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: task.id,
        kind: MutationKind.update,
        payload: task.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: task, outboxRowId: rowId);
  }

  /// Surgical "stop the running entry, save through the outbox" — used by
  /// the global running-timer pill, where building the modified `Task`
  /// inline in the widget would duplicate the read-modify-write the repo
  /// already understands. The outbox payload is still the full task (via
  /// the standard `save` path); a future v2 optimization can swap to a
  /// targeted `MutationKind.stopTimer` that ships only `time_log`, but
  /// today this centralizes the logic in one place.
  Future<void> stopRunningTimer({
    required String companyId,
    required String taskId,
  }) async {
    final row = await db.taskDao
        .watchById(companyId: companyId, id: taskId)
        .first;
    if (row == null) return;
    final task = _fromRow(row);
    if (task.timeLog.isEmpty || !task.timeLog.last.isRunning) return;
    final entries = <TimeEntry>[...task.timeLog];
    entries[entries.length - 1] = entries.last.copyWith(stop: DateTime.now());
    await save(
      companyId: companyId,
      task: task.copyWith(timeLog: entries),
    );
  }

  /// Surgical "start the timer" — appends a running entry through the outbox.
  /// Used by the bulk-action toolbar and every inline 1-tap toggle. No-op on
  /// an invoiced task (server-immutable) or one that's already running.
  /// Atomically stops any prior running entry first so we never have two
  /// running at once. Carries the last entry's description onto the new entry
  /// (convenience), but NOT its billable flag — a new timer keeps the default
  /// `billable: true` so a "Start" can't silently create a non-billable entry
  /// from a prior non-billable one. A brand-new task with no history starts
  /// blank.
  Future<void> startTimer({
    required String companyId,
    required String taskId,
  }) async {
    final row = await db.taskDao
        .watchById(companyId: companyId, id: taskId)
        .first;
    if (row == null) return;
    final task = _fromRow(row);
    // Refuse invoiced (server-immutable), already-running, and soft-deleted
    // tasks — no path should re-arm a timer on a deleted row.
    if (task.isInvoiced || task.isRunning || task.isDeleted) return;
    final entries = <TimeEntry>[...task.timeLog];
    if (entries.isNotEmpty && entries.last.isRunning) {
      entries[entries.length - 1] = entries.last.copyWith(stop: DateTime.now());
    }
    final last = entries.isNotEmpty ? entries.last : null;
    entries.add(
      TimeEntry(
        start: DateTime.now(),
        stop: null,
        // Carry only the description; billable keeps its default (true) so a
        // "Start" never silently inherits a prior non-billable flag.
        description: last?.description ?? '',
      ),
    );
    await save(
      companyId: companyId,
      task: task.copyWith(timeLog: entries),
    );
  }

  /// Live count of running timers for the company (backs the global pill's
  /// concurrent-timer badge — `watchRunning` only surfaces one).
  Stream<int> watchRunningCount({required String companyId}) =>
      db.taskDao.watchRunningCount(companyId: companyId);

  /// Stop every running timer for the company (the pill's "Stop all").
  /// Sequential so each stop lands as its own outbox row.
  Future<void> stopAllRunning({required String companyId}) async {
    final ids = await db.taskDao.runningTaskIds(companyId: companyId);
    for (final id in ids) {
      await stopRunningTimer(companyId: companyId, taskId: id);
    }
  }

  /// Apply a kanban reorder optimistically + queue the server batch.
  ///
  /// [orderedByStatus] is the new layout: `{ statusId: [taskId, ...], ... }`
  /// with each list in the order the user just dropped them. Local rows
  /// get the new `status_id` + `status_order` written transactionally;
  /// one `MutationKind.reorder` row hits the outbox carrying the same
  /// payload the server expects on `/tasks/sort`.
  Future<void> reorder({
    required String companyId,
    required List<String> statusIds,
    required Map<String, List<String>> orderedByStatus,
  }) async {
    final flatUpdates = <({String taskId, String statusId, int order})>[];
    for (final statusId in statusIds) {
      final ids = orderedByStatus[statusId] ?? const <String>[];
      for (var i = 0; i < ids.length; i++) {
        flatUpdates.add((taskId: ids[i], statusId: statusId, order: i));
      }
    }

    await db.transaction(() async {
      // Preload every affected row in a single SELECT so we don't pay
      // for one watch-subscription per task. The companions we write
      // back also batch into a single `upsertAll` — Drift collapses the
      // statements internally, which matters when the user just dropped
      // a card that triggered a 50-task re-shuffle.
      final touchedIds = flatUpdates.map((u) => u.taskId);
      final rows = await db.taskDao.getByIds(
        companyId: companyId,
        ids: touchedIds,
      );
      final byId = {for (final r in rows) r.id: r};
      final companions = <TasksCompanion>[];
      for (final u in flatUpdates) {
        final existing = byId[u.taskId];
        if (existing == null) continue;
        // Rewrite the task row's denormalized status_id + status_order +
        // mark is_dirty so an inbound delta sync that brings down old
        // server ordering can't clobber the optimistic state.
        final domain = _fromRow(
          existing,
        ).copyWith(statusId: u.statusId, statusOrder: u.order);
        companions.add(_domainToCompanion(domain, companyId, isDirty: true));
      }
      await db.taskDao.upsertAll(companions);
      await enqueueMutation(
        companyId: companyId,
        entityId: kReorderEntityId,
        kind: MutationKind.reorder,
        payload: {'status_ids': statusIds, 'task_ids': orderedByStatus},
      );
    });
  }

  /// Clear the `is_dirty` flag on every task touched by a successful
  /// reorder POST. Called from the `MutationKind.reorder` custom-action
  /// handler in `services.dart`. Without this, the optimistic
  /// `is_dirty = true` set by [reorder] would survive forever — blocking
  /// inbound deltas from refreshing the rows.
  Future<void> clearDirtyForReorder({
    required String companyId,
    required Iterable<String> taskIds,
  }) async {
    await db.transaction(() async {
      final rows = await db.taskDao.getByIds(
        companyId: companyId,
        ids: taskIds,
      );
      if (rows.isEmpty) return;
      final companions = [
        for (final r in rows)
          r.toCompanion(true).copyWith(isDirty: const Value(false)),
      ];
      await db.taskDao.upsertAll(companions);
    });
  }

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.taskDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.taskDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TaskApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.taskDao.upsert,
    deleteById: (id) => db.taskDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required TaskApi serverResponse,
  }) async {
    await db.taskDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  /// Force-refetch tasks by id (e.g. after an invoice billed/un-billed them —
  /// the server sets/clears their `invoice_id`). See [refreshByIdsTemplate].
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<TaskApi, TasksCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) =>
          db.taskDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.taskDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.taskDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  /// Queue a document upload. Mirrors `ExpenseRepository.uploadDocument` —
  /// the dispatcher's `MutationKind.documentUpload` handler streams the
  /// local file via multipart upload.
  @override
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentUpload,
      payload: {'entity_id': entityId, ...source.toPayload()},
    );
  }

  @override
  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentDelete,
      payload: {'entity_id': entityId, 'document_id': documentId},
    );
  }

  @override
  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentVisibility,
      payload: {
        'entity_id': entityId,
        'document_id': documentId,
        'is_public': isPublic,
      },
    );
  }

  /// Drop a document from the task's local `documents` JSON column. Mirror
  /// of `ExpenseRepository.applyDocumentDeleted`.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.taskDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.tasks)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(entityId)))
        .write(
          TasksCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the task's local `documents` JSON
  /// column. Mirror of `ExpenseRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.taskDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = [
      for (final d in current)
        if (d.id == document.id) document else d,
    ];
    if (!current.any((d) => d.id == document.id)) {
      next.add(document);
    }
    await (db.update(db.tasks)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(entityId)))
        .write(
          TasksCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // -------------------- conversions --------------------

  TasksCompanion _apiToCompanion(TaskApi a, String companyId) {
    final entries = TimeEntry.parseLog(a.timeLog);
    final isRunning = entries.isNotEmpty && entries.last.isRunning;
    return TasksCompanion.insert(
      id: a.id,
      companyId: companyId,
      taskNumber: Value(a.number),
      description: Value(a.description),
      rate: Value(_moneyString(a.rate)),
      clientId: Value(a.clientId),
      projectId: Value(a.projectId),
      invoiceId: Value(a.invoiceId),
      taskStatusId: Value(a.statusId),
      statusOrder: Value(a.statusOrder ?? 0),
      isRunning: Value(isRunning),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      // Network response carries tag names — denormalize for local sort.
      tagNames: Value(joinTagNames(a.tags.map((t) => t.name))),
      payload: jsonEncode(a.toJson()),
    );
  }

  /// [tagNames] — pre-resolved denormalized sort key (see [_resolveTagNames]).
  /// Absent keeps the row's previous value on conflict-update; save/create
  /// pass it so a local tag edit doesn't leave the sort-by-tags column stale
  /// until the server echo (offline rows are dirty, so refreshes skip them).
  TasksCompanion _domainToCompanion(
    Task t,
    String companyId, {
    required bool isDirty,
    String? tagNames,
  }) {
    return TasksCompanion.insert(
      id: t.id,
      companyId: companyId,
      taskNumber: Value(t.number),
      description: Value(t.description),
      rate: Value(t.rate.toString()),
      clientId: Value(t.clientId),
      projectId: Value(t.projectId),
      invoiceId: Value(t.invoiceId),
      taskStatusId: Value(t.statusId),
      statusOrder: Value(t.statusOrder),
      isRunning: Value(t.isRunning),
      updatedAt: dateToEpochSeconds(t.updatedAt),
      createdAt: Value(dateToEpochSeconds(t.createdAt)),
      archivedAt: t.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(t.archivedAt!)),
      customValue1: Value(t.customValue1),
      customValue2: Value(t.customValue2),
      customValue3: Value(t.customValue3),
      customValue4: Value(t.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(t.isDeleted),
      documents: Value(
        jsonEncode(t.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      tagNames: tagNames == null ? const Value.absent() : Value(tagNames),
      payload: jsonEncode(t.toApiJson(preserveTempId: true)),
    );
  }

  Task _fromRow(TaskRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = TaskApi.fromJson(json);
    // is_dirty / is_deleted are local-authoritative columns; documents live
    // in their own column. Overlay all onto the API-derived domain so the UI
    // sees current state. `is_deleted` matters because an optimistic delete
    // (`markDeletedDirty`) flips only the column, not the payload JSON — so
    // without this overlay `task.isDeleted` would stay false until a server
    // refresh, silently defeating every `isDeleted` gate (timer toggles,
    // restore/delete menu items).
    return Task.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
