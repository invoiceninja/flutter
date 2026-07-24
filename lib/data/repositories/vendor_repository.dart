import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show Value, BooleanExpressionOperators, Table, TableInfo, Variable;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('VendorRepository');

/// Source of truth for Vendor data. The UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Page size is fixed at [pageSize]. Subsequent pages are fetched only on
/// demand — list screens call [ensurePageLoaded] near the scroll edge.
class VendorRepository extends BaseEntityRepository<Vendor, VendorApi>
    implements DocumentBearingRepository {
  VendorRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.vendor,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
           MutationKind.merge,
         },
       );

  final VendorsApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'vendor';

  /// Watch the first [loadedPages] pages worth of rows (so an infinite-scroll
  /// list shows everything fetched so far). [loadedPages] is 1-based — 1
  /// means "show page 1," 2 means "show pages 1+2 contiguously," etc.
  Stream<List<Vendor>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = VendorFieldIds.name,
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    return db.vendorDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          // `tag_ids` lives only in the payload — post-decode predicate over
          // the loaded page (the list VM strips it from the server fetch).
          final tagIds = extraFilters['tag_ids'] ?? const <String>{};
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((v) => matchesTagIdFilter(v.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  /// Distinct non-empty values populated by vendors in `companyId` for the
  /// given custom column (1..4). Drives the bottom-sheet option list for
  /// custom-field filtering.
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) => db.vendorDao.watchDistinctCustomValues(
    companyId: companyId,
    columnIndex: columnIndex,
  );

  /// Live non-deleted vendor count for [companyId]. Drives the sidebar
  /// badge; emits every time a vendor is added, archived, or deleted.
  Stream<int> watchCount({required String companyId}) =>
      db.vendorDao.watchCount(companyId: companyId);

  /// Stream `(id, name)` pairs for active vendors. Powers the vendor picker
  /// on the Expense edit screen.
  Stream<List<({String id, String name})>> watchActiveNames({
    required String companyId,
  }) => db.vendorDao.watchActiveNames(companyId: companyId);

  @override
  Stream<Vendor?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.vendorDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Fetch one page from the server and upsert into Drift. Idempotent: calling
  /// for the same page repeatedly is safe (Drift upserts are by id). Advances
  /// the cursor only on a successful page that returned data.
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
    // `?include=documents` makes the list response authoritative for the
    // `documents` array — see `ClientRepository.ensurePageLoaded`.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) =>
        db.vendorDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
  );

  /// Lazily hydrate one vendor by id when a reference (e.g. an expense's
  /// vendor) isn't in the prefetched page so a `*NameLabel` would show
  /// the raw id. See [ensureLoadedTemplate].
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.vendorDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  /// After a vendor **merge**, the absorbed vendor's children (expenses,
  /// purchase orders, recurring expenses) were reassigned to the survivor
  /// server-side, but locally still carry the old vendor_id in their `payload`.
  /// Return their local ids grouped by type so the merge handler can
  /// force-refetch them (the refetch lands the new vendor_id). Read off the
  /// dedicated `vendor_id` COLUMN, still the old id here.
  Future<Map<EntityType, Set<String>>> childIdsForVendor({
    required String companyId,
    required String vendorId,
  }) async {
    final tables = <EntityType, TableInfo<Table, dynamic>>{
      EntityType.expense: db.expenses,
      EntityType.purchaseOrder: db.purchaseOrders,
      EntityType.recurringExpense: db.recurringExpenses,
    };
    final result = <EntityType, Set<String>>{};
    for (final entry in tables.entries) {
      final table = entry.value;
      final rows = await db
          .customSelect(
            'SELECT id FROM ${table.actualTableName} '
            'WHERE company_id = ?1 AND vendor_id = ?2',
            variables: [
              Variable<String>(companyId),
              Variable<String>(vendorId),
            ],
            readsFrom: {table},
          )
          .get();
      final ids = rows
          .map((r) => r.read<String>('id'))
          .where((id) => id.isNotEmpty)
          .toSet();
      if (ids.isNotEmpty) result[entry.key] = ids;
    }
    return result;
  }

  /// Pull-to-refresh / foreground-resume entry point. Mirrors
  /// `ClientRepository.refreshAll`: pull every state into the local cache
  /// so the UI's state filter can flip without re-hitting the network.
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

  /// Create a new vendor offline. Returns the vendor with its tmp id so the
  /// UI can navigate to the detail screen immediately.
  Future<SaveResult<Vendor>> create({
    required String companyId,
    required Vendor draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.vendorDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: stored.toApiJson(), // server allocates real id
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  /// Save an existing vendor. The local row updates instantly via the watch
  /// stream; the outbox handles the round-trip.
  Future<SaveResult<Vendor>> save({
    required String companyId,
    required Vendor vendor,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(vendor.id);
    if (resolvedId != vendor.id) vendor = vendor.copyWith(id: resolvedId);

    final companion = _domainToCompanion(vendor, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.vendorDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: vendor.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: vendor.id,
        kind: MutationKind.update,
        payload: vendor.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: vendor, outboxRowId: rowId);
  }

  /// Permanently destroy the vendor (irreversible). Outbox row carries
  /// `requiresPassword=true` so the sync engine prompts via
  /// `ConfirmPasswordSheet` before hitting `POST /vendors/:id/purge`.
  /// Queue a document upload for this vendor.
  @override
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) async {
    await enqueueMutation(
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
  }) async {
    await enqueueMutation(
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
  }) async {
    await enqueueMutation(
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

  /// Append a user comment to this vendor's activity stream. Hits
  /// `/api/v1/activities/notes` via the outbox; the dispatcher's
  /// `customActions` map calls the `ActivitiesApi`.
  Future<void> addComment({
    required String companyId,
    required String vendorId,
    required String text,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: vendorId,
      kind: MutationKind.addComment,
      payload: {'entity_id': vendorId, 'notes': text.trim()},
    );
  }

  /// Merge [mergeFromId] (absorbed, deleted) into [mergeIntoId] (survivor).
  /// Enqueued as a password-gated mutation (the 412 gate, same as
  /// delete/purge). The dispatcher's `customActions[merge]` handler hits
  /// `POST /vendors/{into}/{from}/merge`, drops the absorbed row locally, and
  /// upserts the survivor. Mirrors `ClientRepository.merge`.
  Future<void> merge({
    required String companyId,
    required String mergeIntoId,
    required String mergeFromId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: mergeFromId,
      kind: MutationKind.merge,
      payload: {'merge_into_id': mergeIntoId, 'merge_from_id': mergeFromId},
    );
  }

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.vendorDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.vendorDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required VendorApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.vendorDao.upsert,
    deleteById: (id) => db.vendorDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required VendorApi serverResponse,
  }) async {
    await db.vendorDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.vendorDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.vendorDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // Lifecycle filtering uses the shared `BaseEntityRepository.stateQueryParams`
  // (emits the `status` param) — see the base method's doc.

  // -------------------- conversions --------------------

  VendorsCompanion _apiToCompanion(VendorApi a, String companyId) {
    return VendorsCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: a.name,
      number: a.number,
      idNumber: a.idNumber,
      vatNumber: a.vatNumber,
      city: a.city,
      countryId: a.countryId,
      currencyId: a.currencyId,
      phone: a.phone,
      displayName: _displayNameFor(name: a.name, contacts: a.contacts),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      // See `ClientRepository._apiToCompanion` for the documents-nullable
      // rationale — distinguishes JSON-omitted from JSON-empty so a
      // documents-less response doesn't clobber a populated local column.
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  VendorsCompanion _domainToCompanion(
    Vendor v,
    String companyId, {
    required bool isDirty,
  }) {
    return VendorsCompanion.insert(
      id: v.id,
      companyId: companyId,
      name: v.name,
      number: v.number,
      idNumber: v.idNumber,
      vatNumber: v.vatNumber,
      city: v.city,
      countryId: v.countryId,
      currencyId: v.currencyId,
      phone: v.phone,
      displayName: _displayNameForDomain(name: v.name, contacts: v.contacts),
      updatedAt: dateToEpochSeconds(v.updatedAt),
      createdAt: Value(dateToEpochSeconds(v.createdAt)),
      archivedAt: v.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(v.archivedAt!)),
      customValue1: Value(v.customValue1),
      customValue2: Value(v.customValue2),
      customValue3: Value(v.customValue3),
      customValue4: Value(v.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(v.isDeleted),
      documents: Value(
        jsonEncode(v.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(v.toApiJson(preserveTempId: true)),
    );
  }

  /// Drop a document from the vendor's local `documents` JSON column.
  /// Mirror of `ClientRepository.applyDocumentDeleted` — see notes there.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.vendorDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return; // not found; no-op
    await (db.update(db.vendors)
          ..where((v) => v.companyId.equals(companyId) & v.id.equals(entityId)))
        .write(
          VendorsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the vendor's local `documents`
  /// JSON column. Mirror of `ClientRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.vendorDao
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
    await (db.update(db.vendors)
          ..where((v) => v.companyId.equals(companyId) & v.id.equals(entityId)))
        .write(
          VendorsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Vendor _fromRow(VendorRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = VendorApi.fromJson(json);
    // is_dirty is local-only (not in the API payload), so we layer it on
    // from the Drift row. Without this, an unsaved edit shows up as clean
    // after app restart. `documents` lives in its own column (the API
    // `toApiJson` deliberately omits it) — decode separately and overlay.
    return Vendor.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

/// Resolve the row-level display name from the API payload. Falls back to
/// the first contact's name when the vendor's `name` is blank — matches
/// the cascade used by `Vendor` callers that want a non-empty label.
String _displayNameFor({
  required String name,
  required List<VendorContactApi> contacts,
}) {
  if (name.isNotEmpty) return name;
  if (contacts.isEmpty) return '';
  final c = contacts.first;
  final composed = ('${c.firstName} ${c.lastName}').trim();
  if (composed.isNotEmpty) return composed;
  return c.email;
}

/// Domain-side mirror of [_displayNameFor]. Kept separate because the
/// domain `VendorContact` type doesn't share a base with `VendorContactApi`.
String _displayNameForDomain({
  required String name,
  required List<dynamic> contacts,
}) {
  if (name.isNotEmpty) return name;
  if (contacts.isEmpty) return '';
  final c = contacts.first;
  final composed = ('${c.firstName} ${c.lastName}').trim();
  if (composed.isNotEmpty) return composed;
  return c.email as String;
}
