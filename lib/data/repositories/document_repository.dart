import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/document_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/domain/document_parent.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/embedded_documents_owner.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('DocumentRepository');

/// What a record tab's own document changes tell the Documents table, once
/// the server has confirmed them — `documentMutationHandlers` and the company
/// dispatcher call it. Best-effort by contract: the server write has already
/// committed, so a failure here is logged, never thrown into the drain.
abstract interface class DocumentMirror {
  /// The server's copy of a document changed on a record tab (its visibility).
  Future<void> applyServerCopy({
    required String companyId,
    required DocumentApi document,
    EntityType? parentType,
    String? parentId,
  });

  /// The server confirmed a delete made on a record tab.
  Future<void> removeConfirmed({
    required String companyId,
    required String documentId,
  });
}

/// One parent record's attachments, as a `/refresh` delta carries them.
///
/// [prunable] says the list is the record's COMPLETE set, so a linked row
/// missing from it is gone. True for every browsable record and the groups
/// (the server loads each one's whole `documents` relation); false for the
/// company's own files, whose `company.documents` array is itself filtered to
/// `updated_at >= <watermark>`.
typedef DocumentParentSlice = ({
  EntityType type,
  String id,
  int updatedAt,
  List<DocumentApi>? documents,
  bool prunable,
});

/// Source of truth for the company-wide Documents list. The UI watches Drift
/// through [watchPage] / [watch]; the network only writes.
///
/// Five things set it apart from the other list repositories, all because of
/// what the server does with a document (`docs/documents-list.md`):
///
///  * **No lifecycle.** Archive and restore are no-ops server-side and
///    `documents` has no `is_deleted` column, so `status=archived|deleted`
///    would fail the query — [stateQueryParams] sends nothing, ever.
///  * **A delete is hard and leaves no tombstone**, so no `updated_at` delta
///    reports it. Rows the server no longer has are removed three ways: a
///    confirmed delete, a parent whose complete `documents` list no longer
///    names them ([applyRefreshDelta]), and a full sweep that walked to the
///    end without seeing them ([refreshAll]) — never a dirty row or one an
///    outbox row still speaks for.
///  * **An older server doesn't say what a document is attached to.** One
///    with invoiceninja/invoiceninja#13365 sends `documentable_type` / `_id`,
///    which [_apiToCompanion] takes; without it the parent link is filled from
///    the records the app sees: the `/refresh` delta, a record tab's own
///    change ([DocumentMirror]), and [relinkParents].
///  * **A change here is a change to the parent's embedded copy too**, so a
///    rename, a visibility change or a delete patches the parent's
///    `documents` column through [ownerFor].
///  * **Only the fields a save changed are sent** — see [save].
class DocumentRepository
    extends BaseEntityRepository<DocumentRecord, DocumentApi>
    implements DocumentMirror {
  DocumentRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.document,
         requiresPasswordFor: const {MutationKind.delete},
       );

  final DocumentsApi api;
  final int pageSize;

  /// The repository holding a parent's embedded `documents` column, by the
  /// parent's type. Bound late by the wiring (the parent repos are built
  /// after this one); null — tests, or a type no repo owns — skips the patch,
  /// which the parent's next refresh makes good.
  EmbeddedDocumentsOwner? Function(EntityType type)? ownerFor;

  /// Ids written from a server copy while a full sweep of the company is
  /// running — what the sweep must not prune.
  final Map<String, Set<String>> _sweeps = {};

  /// Per company, the files this session has seen removed server-side. A
  /// delete leaves no tombstone, so a `/refresh` the server built just before
  /// it would otherwise put the file straight back. A hard-deleted id never
  /// returns, so nothing expires; a server copy from the list itself (proof
  /// it exists) takes an id back out.
  final Map<String, Set<String>> _gone = {};

  @override
  String get entityTypeName => 'document';

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.documentDao;

  /// Always empty — the documents table has no `is_deleted` column, and
  /// `QueryFilters::status` reads it for `archived` / `deleted`, so either
  /// one fails the query server-side. The server never archives a document
  /// (`DocumentRepository::archive` is empty), so every file is active. `{}`
  /// does also return a trashed one (`QueryFilters::apply` ends in
  /// `withTrashed()`), which only a company delete produces. The one repo
  /// that overrides this — see the base's doc.
  @override
  Map<String, String> stateQueryParams(Set<EntityState> states) => const {};

  // -------------------- reads --------------------

  /// The first [loadedPages] pages of the list. [loadedPages] is 1-based.
  Stream<List<DocumentRecord>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    String sortField = DocumentFieldIds.createdAt,
    bool sortAscending = false,
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    return db.documentDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          sortField: sortField,
          sortAscending: sortAscending,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.documentDao.watchCount(companyId: companyId);

  @override
  Stream<DocumentRecord?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.documentDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  // -------------------- fetches --------------------

  /// Fetch one page from the server and upsert it into Drift.
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
    // Never `excludeDeletedClients`: `without_deleted_clients` reads a
    // `client` relation a Document doesn't have.
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => _upsertServerCopies(companyId, byId),
  );

  /// Hydrate one document by id — a detail screen opened from a link.
  Future<EnsureLoadedOutcome> ensureLoaded({
    required String companyId,
    required String id,
  }) => ensureLoadedTemplate(
    companyId: companyId,
    id: id,
    fetch: (id) async => (await api.get(id)).data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => _upsertServerCopies(companyId, byId),
  );

  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<DocumentApi, DocumentRecordsCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => _upsertServerCopies(companyId, byId),
    );
  }

  /// Walk the whole list. A [full] sweep that reached the end also removes
  /// the rows it never saw — the only way a document deleted from another
  /// device or the web leaves this cache, since a hard delete reports nothing
  /// to a delta. A partial sweep never prunes: its page 1 is a delta and its
  /// later pages start at row 51, so it never sees the newest rows.
  Future<void> refreshAll({
    required String companyId,
    bool full = false,
  }) async {
    if (!full) {
      await refreshAllTemplate(
        companyId: companyId,
        full: false,
        fetchPage: ensurePageLoaded,
      );
      return;
    }
    final seen = <String>{};
    _sweeps[companyId] = seen;
    try {
      final complete = await refreshAllTemplate(
        companyId: companyId,
        full: true,
        fetchPage: ensurePageLoaded,
      );
      if (complete) await _pruneUnseen(companyId, seen);
    } finally {
      if (identical(_sweeps[companyId], seen)) _sweeps.remove(companyId);
    }
    await relinkParents(companyId: companyId);
  }

  /// Link the rows that don't yet know their record, from the `documents`
  /// arrays cached on the records themselves — see
  /// `DocumentDao.relinkFromParentTables`. Cheap when there is nothing to
  /// link; the list runs it each time it opens.
  Future<void> relinkParents({required String companyId}) async {
    try {
      if (!await db.documentDao.hasUnlinked(companyId: companyId)) return;
      await db.documentDao.relinkFromParentTables(companyId: companyId);
    } catch (e, st) {
      // A missing link costs a "Linked to" cell, never the list.
      _log.warning('Linking documents to their records failed', e, st);
    }
  }

  // -------------------- writes --------------------

  /// Rename a document or change its visibility, offline-first: the local
  /// row is updated and flagged dirty, and an `update` row queued with **only
  /// the fields that changed**.
  ///
  /// Never the whole record, for two reasons. `PUT /documents/{id}` runs
  /// `fill($request->all())` and `Document::$fillable` also lists
  /// `is_default`. And a rename that also sent `is_public` would put back
  /// whatever visibility this device last cached — undoing a "make private"
  /// queued on the record's own Documents tab (which doesn't touch this row
  /// until it drains), or made on another device. `UpdateDocumentRequest`
  /// validates both fields as `sometimes`, so a partial body is fine.
  ///
  /// `dedupPendingMutations` deletes an earlier save of this file that is
  /// still pending, so that row's keys are carried into this one — a rename
  /// then a toggle sends both.
  Future<SaveResult<DocumentRecord>> save({
    required String companyId,
    required DocumentRecord document,
  }) async {
    var rowId = 0;
    await db.transaction(() async {
      final existing = await db.documentDao.byId(
        companyId: companyId,
        id: document.id,
      );
      // Against the stored row, which already reflects any earlier unsynced
      // edit of this file.
      final changed = <String, dynamic>{
        if (existing == null || existing.name != document.name)
          'name': document.name,
        if (existing == null || existing.isPublic != document.isPublic)
          'is_public': document.isPublic,
      };
      final carried = <String, dynamic>{
        for (final row in await db.outboxDao.pendingRowsForEntity(
          companyId: companyId,
          entityType: entityTypeName,
          entityId: document.id,
          mutationKind: MutationKind.update.wireName,
        ))
          ..._payloadOf(row.payload),
      };
      final payload = <String, dynamic>{...carried, ...changed};
      // Nothing changed: still a valid save, so send the one field that
      // can't undo anything.
      if (payload.isEmpty) payload['name'] = document.name;
      final api = existing == null
          ? _toApi(document)
          : DocumentApi.fromJson(
              jsonDecode(existing.payload) as Map<String, dynamic>,
            ).copyWith(name: document.name, isPublic: document.isPublic);
      if (existing == null) {
        await db.documentDao.upsert(
          _apiToCompanion(
            api,
            companyId,
            parentType: document.parentType,
            parentId: document.parentId,
          ).copyWith(isDirty: const Value(true)),
        );
      } else {
        await db.documentDao.writeLocalEdit(
          companyId: companyId,
          id: document.id,
          name: document.name,
          isPublic: document.isPublic,
          payload: jsonEncode(api.toJson()),
        );
      }
      await dedupPendingMutations(
        companyId: companyId,
        entityId: document.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: document.id,
        kind: MutationKind.update,
        payload: payload,
      );
    });
    return SaveResult(entity: document, outboxRowId: rowId);
  }

  /// Flip one document between public and private — a [save] of just that.
  Future<void> setVisibility({
    required String companyId,
    required DocumentRecord document,
    required bool isPublic,
  }) => save(
    companyId: companyId,
    document: document.copyWith(isPublic: isPublic),
  );

  /// Queue a download of [ids] as an emailed zip. Not an outbox mutation: it
  /// changes nothing server-side, and offline the user should hear "failed"
  /// now rather than get an email hours later — the Projects precedent.
  Future<void> bulkDownload({required List<String> ids}) =>
      api.bulkDownload(ids: ids, idempotencyKey: uuid.v4());

  // -------------------- sync engine --------------------

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required DocumentApi serverResponse,
  }) async {
    await applyEchoTemplate(
      companyId: companyId,
      id: serverResponse.id,
      write: () async {
        _noteSeen(companyId, [serverResponse.id]);
        // An older server's PUT echo names no parent; the stored link is kept
        // because the companion then leaves those columns absent.
        await db.documentDao.upsert(_apiToCompanion(serverResponse, companyId));
        final parent = await _parentOf(companyId, serverResponse.id);
        if (parent == null) return;
        await ownerFor
            ?.call(parent.type)
            ?.applyDocumentChanged(
              companyId: companyId,
              entityId: parent.id,
              document: serverResponse,
            );
      },
    );
  }

  /// The server confirmed a delete (or reported the file already gone). Hard
  /// delete — there is no "Deleted" view to keep it for — and drop it from
  /// the parent's embedded copy, so the record's own Documents tab agrees.
  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) => db.transaction(() async {
    await _dropFromParent(companyId, id);
    await db.documentDao.deleteById(companyId: companyId, id: id);
    _noteGone(companyId, [id]);
  });

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.documentDao.deleteById(companyId: companyId, id: id);

  /// Also clears the pending-delete flag — see
  /// `DocumentDao.clearDirtyAndDeleted`.
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.documentDao.clearDirtyAndDeleted(companyId: companyId, id: id);

  // -------------------- DocumentMirror --------------------

  @override
  Future<void> applyServerCopy({
    required String companyId,
    required DocumentApi document,
    EntityType? parentType,
    String? parentId,
  }) async {
    try {
      final existing = await db.documentDao.byId(
        companyId: companyId,
        id: document.id,
      );
      if (existing?.isDirty ?? false) return;
      _noteSeen(companyId, [document.id]);
      await db.documentDao.upsert(
        _apiToCompanion(
          document,
          companyId,
          parentType: parentType,
          parentId: parentId,
        ),
      );
    } catch (e, st) {
      _log.warning('Mirroring document ${document.id} failed', e, st);
    }
  }

  @override
  Future<void> removeConfirmed({
    required String companyId,
    required String documentId,
  }) async {
    try {
      _noteGone(companyId, [documentId]);
      // `deleteByIds` skips a dirty row: a Documents-list edit still queued,
      // whose own drain gets the server's answer (a conflict whose Discard
      // removes it). One statement, so no edit can land between a check and
      // the delete.
      await db.documentDao.deleteByIds(companyId: companyId, ids: [documentId]);
    } catch (e, st) {
      _log.warning('Removing document $documentId failed', e, st);
    }
  }

  /// A view or download found the file gone (`NotFoundException`): drop the
  /// row and the parent's embedded copy, so the list stops offering a file
  /// that can't be opened. Same guards as [removeConfirmed]. Returns whether
  /// anything was removed.
  Future<bool> forgetMissing({
    required String companyId,
    required String documentId,
  }) => db.transaction(() async {
    final existing = await db.documentDao.byId(
      companyId: companyId,
      id: documentId,
    );
    if (existing == null || existing.isDirty) return false;
    await _dropFromParent(companyId, documentId);
    await db.documentDao.deleteById(companyId: companyId, id: documentId);
    _noteGone(companyId, [documentId]);
    return true;
  });

  // -------------------- /refresh delta --------------------

  /// Harvest this company's documents from a `/refresh` DELTA: every record
  /// the delta carries brings its complete `documents` array, which gives each
  /// file its parent link and shows which files a record no longer has.
  ///
  /// Writes only what changed, so a quiet tick (the groups and the company's
  /// own files arrive on every one) repaints nothing: the whole server copy
  /// when the file is new or strictly newer, and **only the link** when the
  /// link is the news — the copy may be older than the row stored, since the
  /// server built this response before an echo that has already landed.
  /// Skips files this session has seen removed ([_gone]).
  ///
  /// Prunes per [DocumentParentSlice.prunable] parent, and only rows that are
  /// clean, outbox-free and older than the parent: a row newer than the record
  /// was written after the server built this response (an upload confirmed
  /// while it was in flight). One batched lookup for every record, not one
  /// query per record — this all runs inside the refresh transaction.
  ///
  /// Never touches the list's own sync cursor: harvested rows can be old, and
  /// a non-admin's `GET /documents` sees only their own files while the delta
  /// carries every file on the records they can see.
  Future<void> applyRefreshDelta({
    required String companyId,
    required List<DocumentParentSlice> parents,
  }) async {
    if (parents.isEmpty) return;
    final gone = _gone[companyId] ?? const <String>{};
    final incoming =
        <String, ({DocumentApi doc, EntityType type, String parentId})>{};
    for (final p in parents) {
      for (final d in p.documents ?? const <DocumentApi>[]) {
        if (d.id.isEmpty || gone.contains(d.id)) continue;
        incoming[d.id] = (doc: d, type: p.type, parentId: p.id);
      }
    }
    // Keyed by type AND id: hashed ids are per-table encodings, so an
    // invoice and a client can share one.
    final prunable = <String, DocumentParentSlice>{
      for (final p in parents)
        if (p.prunable && p.documents != null)
          if (documentParentWireName(p.type) case final wire?)
            '$wire/${p.id}': p,
    };
    if (incoming.isEmpty && prunable.isEmpty) return;
    await db.transaction(() async {
      final ids = incoming.keys.toList(growable: false);
      final stored = await db.documentDao.updatedAtAmong(
        companyId: companyId,
        ids: ids,
      );
      final links = await db.documentDao.parentsOf(
        companyId: companyId,
        ids: ids,
      );
      final byId = <String, DocumentRecordsCompanion>{};
      for (final entry in incoming.entries) {
        final (:doc, :type, :parentId) = entry.value;
        final wire = documentParentWireName(type);
        final storedAt = stored[entry.key];
        final link = links[entry.key];
        final newlyLinked =
            wire != null && (link?.type != wire || link?.id != parentId);
        if (storedAt == null || doc.updatedAt > storedAt) {
          byId[entry.key] = _apiToCompanion(
            doc,
            companyId,
            parentType: type,
            parentId: parentId,
          );
        } else if (newlyLinked) {
          await db.documentDao.setParent(
            companyId: companyId,
            id: entry.key,
            parentType: wire,
            parentId: parentId,
          );
        }
      }
      // Every file the delta named exists server-side.
      _noteSeen(companyId, incoming.keys);
      if (byId.isNotEmpty) {
        await db.documentDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        );
      }
      if (prunable.isEmpty) return;
      final linked = await db.documentDao.linkedToAny(
        companyId: companyId,
        parentIds: {for (final p in prunable.values) p.id}.toList(),
      );
      final keep = <String, Set<String>>{
        for (final e in prunable.entries)
          e.key: {for (final d in e.value.documents!) d.id},
      };
      final candidates = <String>[
        for (final r in linked)
          if (prunable['${r.parentType}/${r.parentId}'] case final p?)
            if (!keep['${r.parentType}/${r.parentId}']!.contains(r.id) &&
                !r.isDirty &&
                r.updatedAt < p.updatedAt)
              r.id,
      ];
      // Only now, and only when there is something to delete: groups arrive
      // on every tick, so reading the outbox up front would cost every tick.
      if (candidates.isEmpty) return;
      final held = await db.outboxDao.documentIdsInOutbox(companyId: companyId);
      final removed = [
        for (final id in candidates)
          if (!held.contains(id)) id,
      ];
      if (removed.isEmpty) return;
      await db.documentDao.deleteByIds(companyId: companyId, ids: removed);
      _noteGone(companyId, removed);
    });
  }

  // -------------------- helpers --------------------

  /// A queued row's JSON body, or nothing when it isn't a JSON object.
  static Map<String, dynamic> _payloadOf(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _upsertServerCopies(
    String companyId,
    Map<String, DocumentRecordsCompanion> byId,
  ) async {
    _noteSeen(companyId, byId.keys);
    // The server just listed them: whatever this session thought, they exist.
    _gone[companyId]?.removeAll(byId.keys);
    await db.documentDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    );
  }

  void _noteSeen(String companyId, Iterable<String> ids) =>
      _sweeps[companyId]?.addAll(ids);

  void _noteGone(String companyId, Iterable<String> ids) =>
      (_gone[companyId] ??= <String>{}).addAll(ids);

  /// After a full sweep that reached the end: remove every row it didn't see,
  /// except a dirty one, a `tmp_` one, one an outbox row still speaks for —
  /// and **one a cached record still lists**.
  ///
  /// That last guard is what makes this safe for anyone but an admin:
  /// `GET /documents` shows a user without `view_document` only the files they
  /// uploaded or are assigned, while the `/refresh` harvest files every file
  /// on the records they can see. Unguarded, each Sync deleted all of those.
  /// The record tables are fresh by now — the documents step runs last in
  /// the Sync pass, after each of them was re-downloaded with its documents —
  /// so a file a record still lists still exists.
  ///
  /// One transaction, so a rename saved mid-prune can't lose its row (and
  /// `deleteByIds` skips a dirty row regardless).
  Future<void> _pruneUnseen(String companyId, Set<String> seen) =>
      db.transaction(() async {
        final rows = await db.documentDao.allIds(companyId: companyId);
        final unseen = [
          for (final r in rows)
            if (!seen.contains(r.id) && !r.isDirty && !r.id.startsWith('tmp_'))
              r.id,
        ];
        if (unseen.isEmpty) return;
        final listed = await db.documentDao.idsListedOnRecords(
          companyId: companyId,
        );
        final held = await db.outboxDao.documentIdsInOutbox(
          companyId: companyId,
        );
        final removed = [
          for (final id in unseen)
            if (!listed.contains(id) && !held.contains(id)) id,
        ];
        if (removed.isEmpty) return;
        _log.fine(
          'Full sweep: removing ${removed.length} document(s) the server no '
          'longer has for company $companyId',
        );
        await db.documentDao.deleteByIds(companyId: companyId, ids: removed);
        _noteGone(companyId, removed);
      });

  Future<({EntityType type, String id})?> _parentOf(
    String companyId,
    String documentId,
  ) async {
    final link = (await db.documentDao.parentsOf(
      companyId: companyId,
      ids: [documentId],
    ))[documentId];
    if (link == null) return null;
    final type = documentParentTypeFromWire(link.type);
    return type == null ? null : (type: type, id: link.id);
  }

  Future<void> _dropFromParent(String companyId, String documentId) async {
    final parent = await _parentOf(companyId, documentId);
    if (parent == null) return;
    await ownerFor
        ?.call(parent.type)
        ?.applyDocumentDeleted(
          companyId: companyId,
          entityId: parent.id,
          documentId: documentId,
        );
  }

  DocumentApi _toApi(DocumentRecord d) => DocumentApi(
    id: d.id,
    name: d.name,
    hash: d.hash,
    type: d.type,
    size: d.size,
    width: d.width,
    height: d.height,
    userId: d.userId,
    assignedUserId: d.assignedUserId,
    isPublic: d.isPublic,
    createdAt: dateToEpochSeconds(d.createdAt),
    updatedAt: dateToEpochSeconds(d.updatedAt),
  );

  /// [parentType] / [parentId] override what the document itself says; when
  /// neither names a parent the columns are left ABSENT, so an upsert keeps
  /// the link already stored rather than clearing it.
  DocumentRecordsCompanion _apiToCompanion(
    DocumentApi a,
    String companyId, {
    EntityType? parentType,
    String? parentId,
  }) {
    var type = parentType;
    var parent = parentId;
    if (type == null || parent == null || parent.isEmpty) {
      type = documentParentTypeFromWire(a.documentableType);
      parent = a.documentableId;
    }
    final wire = type == null ? null : documentParentWireName(type);
    final linked = wire != null && parent != null && parent.isNotEmpty;
    return DocumentRecordsCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      fileType: Value(a.type),
      size: Value(a.size),
      width: Value(a.width),
      height: Value(a.height),
      isPublic: Value(a.isPublic),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      // Value(null), not absent, so an upsert clears a stale value.
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: const Value(false),
      parentType: linked ? Value(wire) : const Value.absent(),
      parentId: linked ? Value(parent) : const Value.absent(),
      payload: jsonEncode(a.toJson()),
    );
  }

  /// Decoded once per distinct row — see [decodeRow].
  DocumentRecord _fromRow(DocumentRecordRow row) =>
      decodeRow('${row.companyId}/${row.id}', row, _decode);

  DocumentRecord _decode(DocumentRecordRow row) {
    final api = DocumentApi.fromJson(
      jsonDecode(row.payload) as Map<String, dynamic>,
    );
    return DocumentRecord.fromApi(
      api,
      parentType: documentParentTypeFromWire(row.parentType),
      parentId: row.parentId,
    ).copyWith(
      // Local flags and the columns a local edit writes are authoritative.
      name: row.name,
      isPublic: row.isPublic,
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      createdAt: epochSecondsToUtc(row.createdAt),
      updatedAt: epochSecondsToUtc(row.updatedAt),
    );
  }
}
