import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/projects_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('ProjectRepository');

/// Source of truth for Project data. The UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Page size is fixed at [pageSize]. Subsequent pages are fetched only on
/// demand — list screens call [ensurePageLoaded] near the scroll edge.
///
/// Project archive/delete does **not** cascade to local tasks. The server
/// is the source of truth for cascades; tasks keep their `projectId`
/// referencing the now-archived/deleted project and the Project card on
/// Task detail still renders (with the archived/deleted state indicator).
class ProjectRepository extends BaseEntityRepository<Project, ProjectApi>
    with TagNameResolver
    implements DocumentBearingRepository {
  ProjectRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.project,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
         },
       );

  final ProjectsApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'project';

  /// Watch the first [loadedPages] pages worth of rows. [loadedPages] is
  /// 1-based — 1 means "show page 1," 2 means "show pages 1+2," etc.
  ///
  /// [extraFilters] mirrors the server-bound filter dimensions locally
  /// (the UI renders from this watch, so a server-only filter would look
  /// like it did nothing): the standalone list's `client_id` chips become a
  /// SQL membership predicate; `tag_ids` is a post-decode predicate (tag
  /// ids live only in the payload JSON). Tag-filter completeness is bounded
  /// by the loaded pages; the list VM strips `tag_ids` from the server
  /// fetch and auto-chains page loads to converge.
  Stream<List<Project>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ProjectFieldIds.name,
    bool sortAscending = true,
    String? clientId,
    Map<String, Set<String>> extraFilters = const {},
    Map<int, Set<String>> customFilters = const {},
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    final tagIds = parseCsvFilter(extraFilters, 'tag_ids');
    return db.projectDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          clientId: clientId,
          clientIds: parseClientIdFilter(extraFilters),
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((p) => matchesTagIdFilter(p.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  Stream<int> watchCount({required String companyId}) =>
      db.projectDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.projectDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  /// Distinct non-empty values populated by projects in `companyId` for the
  /// given custom column (1..4). Drives the custom-field filter option list
  /// (mirrors `ClientRepository`).
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) => db.projectDao.watchDistinctCustomValues(
    companyId: companyId,
    columnIndex: columnIndex,
  );

  /// Cheap `(id, name)` stream for active projects — used by the Task
  /// list's project filter key (suggestion menu + chip display name).
  /// Selects only the two columns needed; orders by name.
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) => db.projectDao.watchActiveNames(companyId: companyId);

  /// Active, non-deleted projects for one client. Used by the Task edit
  /// Project picker so changing client narrows the project list.
  Stream<List<Project>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<Project>>.value(const <Project>[]);
    }
    return db.projectDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Project?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.projectDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Fetch one page from the server and upsert into Drift.
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
    // `?include=documents` — same rationale as Client/Product.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.projectDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

  /// Lazily hydrate one project by id when a reference (e.g. a task's
  /// project) isn't in the prefetched page so a `*NameLabel` would show
  /// the raw id. See [ensureLoadedTemplate].
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.projectDao.upsertAllPreservingDirty(
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

  /// Create a new project offline. Returns the project with its tmp id so
  /// the UI can navigate to the detail screen immediately.
  Future<SaveResult<Project>> create({
    required String companyId,
    required Project draft,
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
      await db.projectDao.upsert(companion);
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

  Future<SaveResult<Project>> save({
    required String companyId,
    required Project project,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(project.id);
    if (resolvedId != project.id) project = project.copyWith(id: resolvedId);

    // Resolved OUTSIDE the transaction — see TagNameResolver.
    final tagNames = await resolveTagNames(companyId, project.tagIds);
    var rowId = 0;
    await db.transaction(() async {
      final companion = _domainToCompanion(
        project,
        companyId,
        isDirty: true,
        tagNames: tagNames,
      );
      await db.projectDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: project.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: project.id,
        kind: MutationKind.update,
        payload: project.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: project, outboxRowId: rowId);
  }

  /// Apply a design / email template to this project. Mirrors
  /// `InvoiceRepository.runTemplate`.
  Future<void> runTemplate({
    required String companyId,
    required String id,
    required String templateId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.runTemplate,
    payload: {'id': id, 'template_id': templateId},
  );

  /// Queue a document upload. Mirrors `ProductRepository.uploadDocument` —
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

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.projectDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.projectDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required ProjectApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.projectDao.upsert,
    deleteById: (id) => db.projectDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required ProjectApi serverResponse,
  }) async {
    await db.projectDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  /// Force-refetch projects by id (e.g. after a quote was converted to one).
  /// See [refreshByIdsTemplate].
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<ProjectApi, ProjectsCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.projectDao.upsertAllPreservingDirty(
        companyId: companyId,
        byId: byId,
      ),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.projectDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.projectDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  /// Drop a document from the project's local `documents` JSON column.
  /// Mirror of `ProductRepository.applyDocumentDeleted`.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.projectDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.projects)
          ..where((p) => p.companyId.equals(companyId) & p.id.equals(entityId)))
        .write(
          ProjectsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the project's local `documents`
  /// JSON column. Mirror of `ProductRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.projectDao
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
    await (db.update(db.projects)
          ..where((p) => p.companyId.equals(companyId) & p.id.equals(entityId)))
        .write(
          ProjectsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // -------------------- conversions --------------------

  ProjectsCompanion _apiToCompanion(ProjectApi a, String companyId) {
    return ProjectsCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      number: Value(a.number),
      clientId: Value(a.clientId),
      assignedUserId: Value(a.assignedUserId),
      dueDate: Value(a.dueDate),
      taskRate: Value(_moneyString(a.taskRate)),
      budgetedHours: Value(a.budgetedHours.toDouble()),
      currentHours: Value(a.currentHours.toDouble()),
      color: Value(a.color),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      // Use Value(null) (not Value.absent()) so a restore (server returns
      // archived_at: 0) actually clears the column under the partial
      // insertOnConflictUpdate — otherwise the active-list filter
      // (archived_at IS NULL) keeps excluding the row after restore.
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
  ProjectsCompanion _domainToCompanion(
    Project p,
    String companyId, {
    required bool isDirty,
    String? tagNames,
  }) {
    return ProjectsCompanion.insert(
      id: p.id,
      companyId: companyId,
      name: Value(p.name),
      number: Value(p.number),
      clientId: Value(p.clientId),
      assignedUserId: Value(p.assignedUserId),
      dueDate: Value(p.dueDate?.toIso() ?? ''),
      taskRate: Value(p.taskRate.toString()),
      budgetedHours: Value(p.budgetedHours),
      currentHours: Value(p.currentHours),
      color: Value(p.color),
      updatedAt: dateToEpochSeconds(p.updatedAt),
      createdAt: Value(dateToEpochSeconds(p.createdAt)),
      archivedAt: p.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(p.archivedAt!)),
      customValue1: Value(p.customValue1),
      customValue2: Value(p.customValue2),
      customValue3: Value(p.customValue3),
      customValue4: Value(p.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(p.isDeleted),
      documents: Value(
        jsonEncode(p.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      tagNames: tagNames == null ? const Value.absent() : Value(tagNames),
      payload: jsonEncode(p.toApiJson(preserveTempId: true)),
    );
  }

  Project _fromRow(ProjectRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = ProjectApi.fromJson(json);
    // is_dirty is local-only; documents live in their own column. Overlay
    // both onto the API-derived domain so the UI sees current state.
    return Project.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

/// The server sometimes returns money as a number, sometimes as a string;
/// normalize to a string for stable storage.
String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
