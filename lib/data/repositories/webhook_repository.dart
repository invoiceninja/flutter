import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/webhook_dao.dart';
import 'package:admin/data/models/api/webhook_api_model.dart';
import 'package:admin/data/models/domain/webhook.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/webhooks_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('WebhookRepository');

/// Source of truth for Webhook data. Bundled on `/refresh?first_load=true`
/// (see `services_entity_wiring.dart`'s `bundleAppliers`) and also fetched
/// page-by-page via `/api/v1/webhooks`.
class WebhookRepository extends BaseEntityRepository<Webhook, WebhookApi> {
  WebhookRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.webhook,
         // WebhookController applies no `password_protected` middleware (unlike
         // TokenController), so no webhook mutation is password-gated.
         requiresPasswordFor: const {},
       );

  final WebhooksApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'webhook';

  Stream<List<Webhook>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = WebhookFieldIds.targetUrl,
    bool sortAscending = true,
  }) {
    assert(loadedPages >= 1);
    return db.webhookDao
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

  Stream<int> watchCount({required String companyId}) =>
      db.webhookDao.watchActiveCount(companyId: companyId);

  @override
  Stream<Webhook?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.webhookDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Drain the `webhooks` array carried by `/refresh?first_load=true` into
  /// the local `webhooks` table. Upserts only — never deletes — so rows
  /// with pending local edits (`is_dirty = true`) keep their outbox-bound
  /// payload until the next real sync.
  Future<void> applyBundle({
    required String companyId,
    required List<WebhookApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.webhookDao.upsertAllPreservingDirty(
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
    upsert: (byId) => db.webhookDao.upsertAllPreservingDirty(
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
    const maxPages = 100;
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

  Future<SaveResult<Webhook>> create({
    required String companyId,
    required Webhook draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.webhookDao.upsert(companion);
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

  Future<SaveResult<Webhook>> save({
    required String companyId,
    required Webhook webhook,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(webhook.id);
    if (resolvedId != webhook.id) webhook = webhook.copyWith(id: resolvedId);

    final companion = _domainToCompanion(webhook, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.webhookDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: webhook.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: webhook.id,
        kind: MutationKind.update,
        payload: webhook.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: webhook, outboxRowId: rowId);
  }

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.webhookDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required WebhookApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.webhookDao.upsert,
    deleteById: (id) => db.webhookDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required WebhookApi serverResponse,
  }) async {
    await db.webhookDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.webhookDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.webhookDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  WebhooksCompanion _apiToCompanion(WebhookApi a, String companyId) {
    return WebhooksCompanion.insert(
      id: a.id,
      companyId: companyId,
      eventId: Value(a.eventId),
      targetUrl: Value(a.targetUrl),
      format: Value(a.format.isEmpty ? kWebhookDefaultFormat : a.format),
      restMethod: Value(
        a.restMethod.isEmpty ? kWebhookDefaultRestMethod : a.restMethod,
      ),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  WebhooksCompanion _domainToCompanion(
    Webhook w,
    String companyId, {
    required bool isDirty,
  }) {
    return WebhooksCompanion.insert(
      id: w.id,
      companyId: companyId,
      eventId: Value(w.eventId),
      targetUrl: Value(w.targetUrl),
      format: Value(w.format),
      restMethod: Value(w.restMethod),
      updatedAt: w.updatedAt.millisecondsSinceEpoch ~/ 1000,
      createdAt: Value(w.createdAt.millisecondsSinceEpoch ~/ 1000),
      archivedAt: w.archivedAt == null
          ? const Value.absent()
          : Value(w.archivedAt!.millisecondsSinceEpoch ~/ 1000),
      isDirty: Value(isDirty),
      isDeleted: Value(w.isDeleted),
      payload: jsonEncode(w.toApiJson(preserveTempId: true)),
    );
  }

  Webhook _fromRow(WebhookRow row) {
    final apiJson = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = WebhookApi.fromJson(apiJson);
    return Webhook.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }
}
