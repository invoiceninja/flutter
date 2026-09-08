import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/group_setting_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/group_setting_api_model.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/group_settings_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

/// Source of truth for group_settings. Mirrors `ProductRepository` — the
/// UI watches Drift; the network only writes. Every mutation goes through
/// the outbox.
class GroupSettingRepository
    extends BaseEntityRepository<GroupSetting, GroupSettingApi>
    implements DocumentBearingRepository {
  GroupSettingRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.group,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.documentDelete,
         },
       );

  final GroupSettingsApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'group';

  /// Watch the first [loadedPages] pages worth of rows. Matches
  /// `ProductRepository.watchPage` for forward-compat with the generic
  /// list ViewModel, though the settings UI uses [watchAll] instead.
  Stream<List<GroupSetting>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = GroupSettingFieldIds.name,
    bool sortAscending = true,
  }) {
    assert(loadedPages >= 1, 'loadedPages is 1-based');
    return db.groupSettingDao
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

  /// Watch every active group for [companyId], sorted by name ascending.
  /// Drives the settings list screen and the Assign Group dialog dropdown.
  Stream<List<GroupSetting>> watchAll({required String companyId}) => db
      .groupSettingDao
      .watchAll(companyId: companyId)
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  /// Watch active + archived groups for [companyId] (excludes deleted).
  /// Backs the list screen's "Show archived" toggle.
  Stream<List<GroupSetting>> watchAllIncludingArchived({
    required String companyId,
  }) => db.groupSettingDao
      .watchAllIncludingArchived(companyId: companyId)
      .map((rows) => rows.map(_fromRow).toList(growable: false));

  Stream<int> watchCount({required String companyId}) =>
      db.groupSettingDao.watchCount(companyId: companyId);

  @override
  Stream<GroupSetting?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.groupSettingDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Drain the `groups` array carried by `/login` and `/refresh?first_load=true`
  /// into the local `group_settings` table. Hooked up via
  /// `services_entity_wiring.dart`'s `bundleAppliers` so the Settings →
  /// Group Settings list reads from Drift on first paint without firing a
  /// redundant `GET /group_settings`.
  ///
  /// Upserts only — never deletes — so rows with pending local edits
  /// (`is_dirty = true`) keep their outbox-bound payload until the next
  /// real sync.
  Future<void> applyBundle({
    required String companyId,
    required List<GroupSettingApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.groupSettingDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

  /// Fetch one page from the server and upsert into Drift. Returns true
  /// if there may be more pages (we got a full page).
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    bool ignoreCursor = false,
  }) => ensurePageLoadedTemplate(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    search: search,
    states: states,
    ignoreCursor: ignoreCursor,
    // `?include=documents` so a paged refresh carries each record's
    // attachments into the local `documents` column.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.groupSettingDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

  /// Pull-to-refresh / foreground-resume.
  Future<void> refreshAll({required String companyId, bool full = false}) =>
      refreshAllTemplate(
        companyId: companyId,
        full: full,
        fetchPage: ensurePageLoaded,
      );

  /// Create a new group offline. Returns the group with its tmp id.
  Future<SaveResult<GroupSetting>> create({
    required String companyId,
    required GroupSetting draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.groupSettingDao.upsert(companion);
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

  /// [designDefaultUpdates] carries the Invoice Design "Update all records"
  /// directives (`[{design_id, entity}, …]`) for group scope. Each is enqueued
  /// as a `setDefaultDesign` row **inside the same transaction** as the settings
  /// `update`, so a process kill can't persist the settings change without the
  /// retro-apply. `settings_level` + `group_settings_id` are stamped here.
  Future<SaveResult<GroupSetting>> save({
    required String companyId,
    required GroupSetting group,
    List<Map<String, dynamic>> designDefaultUpdates = const [],
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(group.id);
    if (resolvedId != group.id) group = group.copyWith(id: resolvedId);

    final companion = _domainToCompanion(group, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.groupSettingDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: group.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: group.id,
        kind: MutationKind.update,
        payload: group.toApiJson(preserveTempId: true),
      );
      for (final u in designDefaultUpdates) {
        await enqueueMutation(
          companyId: companyId,
          entityId: group.id,
          kind: MutationKind.setDefaultDesign,
          payload: {
            'design_id': u['design_id'],
            'entity': u['entity'],
            'settings_level': 'group_settings',
            'group_settings_id': group.id,
          },
        );
      }
    });
    return SaveResult(entity: group, outboxRowId: rowId);
  }

  /// Queue a document upload for this group. Mirrors
  /// `ProductRepository.uploadDocument` — same payload shape, same outbox
  /// kind. The upload returns the refreshed group (with `documents`), applied
  /// via [applyUpdateResponse].
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

  /// Delete one document attached to a group. Password-gated — see
  /// `requiresPasswordFor` above.
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

  /// Flip a document's public/private flag.
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
  }) => db.groupSettingDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.groupSettingDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required GroupSettingApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.groupSettingDao.upsert,
    deleteById: (id) =>
        db.groupSettingDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required GroupSettingApi serverResponse,
  }) async {
    await db.groupSettingDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.groupSettingDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.groupSettingDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  GroupSettingsCompanion _apiToCompanion(GroupSettingApi a, String companyId) {
    return GroupSettingsCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: a.name,
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      // Nullable DTO distinguishes JSON-omitted from JSON-empty;
      // `Value.absent()` preserves the prior column on the UPDATE branch.
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  GroupSettingsCompanion _domainToCompanion(
    GroupSetting g,
    String companyId, {
    required bool isDirty,
  }) {
    return GroupSettingsCompanion.insert(
      id: g.id,
      companyId: companyId,
      name: g.name,
      updatedAt: dateToEpochSeconds(g.updatedAt),
      createdAt: Value(dateToEpochSeconds(g.createdAt)),
      archivedAt: g.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(g.archivedAt!)),
      customValue1: Value(g.customValue1),
      customValue2: Value(g.customValue2),
      customValue3: Value(g.customValue3),
      customValue4: Value(g.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(g.isDeleted),
      // Never write documents on a domain save. Unlike Client/Product (whose
      // edit/detail screens watch a live row), the group edit screen reuses a
      // frozen-snapshot edit VM — `g.documents` here can be stale, so writing
      // it would clobber docs uploaded since the screen opened. Documents are
      // owned solely by `_apiToCompanion` (server/upload responses) and
      // `applyDocumentChanged`/`applyDocumentDeleted`. `Value.absent()`
      // preserves the existing column on the UPDATE path.
      documents: const Value.absent(),
      payload: jsonEncode(g.toApiJson(preserveTempId: true)),
    );
  }

  /// Drop a document from the group's local `documents` JSON column.
  /// Mirror of `ProductRepository.applyDocumentDeleted`.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) => applyDocumentDeletedTemplate(
    documentId: documentId,
    readDocuments: () => _readDocuments(companyId, entityId),
    writeDocuments: (json) => _writeDocuments(companyId, entityId, json),
  );

  /// Replace (or insert) one document in the group's local `documents` JSON
  /// column. Mirror of `ProductRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) => applyDocumentChangedTemplate(
    document: document,
    readDocuments: () => _readDocuments(companyId, entityId),
    writeDocuments: (json) => _writeDocuments(companyId, entityId, json),
  );

  GroupSetting _fromRow(GroupSettingRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = GroupSettingApi.fromJson(json);
    // is_dirty + documents are local-only columns (documents lives in its own
    // column; `toApiJson` omits it) — overlay both from the Drift row.
    return GroupSetting.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }

  /// The row's `documents` column decoded, or null when the row isn't cached
  /// locally, which skips the write. Write-avoidance, not correctness — see
  /// [applyDocumentChangedTemplate].
  Future<List<DocumentApi>?> _readDocuments(
    String companyId,
    String entityId,
  ) async {
    final row = await db.groupSettingDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    return row == null ? null : decodeRawDocumentsColumn(row.documents);
  }

  Future<void> _writeDocuments(
    String companyId,
    String entityId,
    String json,
  ) =>
      (db.update(db.groupSettings)..where(
            (e) => e.companyId.equals(companyId) & e.id.equals(entityId),
          ))
          .write(GroupSettingsCompanion(documents: Value(json)));
}
