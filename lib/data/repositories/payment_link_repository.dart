import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/payment_link_dao.dart';
import 'package:admin/data/models/api/subscription_api_model.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/subscriptions_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('PaymentLinkRepository');

/// Repository for Payment Link rows. Wire-side these are Subscriptions
/// (decoded by [SubscriptionApi]); internally we use `PaymentLink` to
/// match the user-facing label.
///
/// Mirrors [ExpenseCategoryRepository] — bundled-AND-paginated, full
/// CRUD via the outbox, settings-only UX.
///
/// [applyBundle] is **upsert-only — it never deletes**. A payment link
/// hard-deleted server-side while the device is offline lingers locally
/// until the user pulls `refreshAll(full: true)` from the Payment Links
/// list. Acceptable for this tiny entity (typical workspaces carry tens
/// of rows); not worth the bookkeeping a delete-by-omission pass would
/// add to the bundled seed path.
class PaymentLinkRepository
    extends BaseEntityRepository<PaymentLink, SubscriptionApi> {
  PaymentLinkRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.paymentLink,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final SubscriptionsApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'payment_link';

  Stream<List<PaymentLink>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = PaymentLinkFieldIds.name,
    bool sortAscending = true,
  }) {
    return db.paymentLinkDao
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

  @override
  Stream<PaymentLink?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.paymentLinkDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Seed the local `payment_links` table from the `/refresh` envelope's
  /// bundled `data[N].company.subscriptions` array. Called from
  /// `AuthRepository._persistAndActivate` via [WiredEntities.bundleAppliers]
  /// so the first paint of the Payment Links screen reads from Drift
  /// instead of firing a redundant `GET /subscriptions`.
  ///
  /// Upserts only — never deletes — so rows with pending local edits
  /// (`is_dirty = true`) keep their outbox-bound payload until the next
  /// real sync.
  Future<void> applyBundle({
    required String companyId,
    required List<SubscriptionApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.paymentLinkDao.upsertAllPreservingDirty(
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
    upsert: (byId) => db.paymentLinkDao.upsertAllPreservingDirty(
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
          'refreshAll hit the $maxPages page safety cap for $companyId',
        );
        break;
      }
    }
  }

  Future<SaveResult<PaymentLink>> create({
    required String companyId,
    required PaymentLink draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.paymentLinkDao.upsert(companion);
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

  Future<SaveResult<PaymentLink>> save({
    required String companyId,
    required PaymentLink paymentLink,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(paymentLink.id);
    if (resolvedId != paymentLink.id) {
      paymentLink = paymentLink.copyWith(id: resolvedId);
    }

    final companion = _domainToCompanion(paymentLink, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.paymentLinkDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: paymentLink.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: paymentLink.id,
        kind: MutationKind.update,
        payload: paymentLink.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: paymentLink, outboxRowId: rowId);
  }

  /// Hard-delete on the server. Password-gated per [requiresPasswordFor].
  /// Fetch the step catalog with each step's dependency list. Cached by
  /// the edit ViewModel for the screen lifetime — small payload, rarely
  /// changes.
  Future<List<PaymentLinkStep>> listSteps() async {
    final apis = await api.listSteps();
    return apis.map(PaymentLinkStep.fromApi).toList(growable: false);
  }

  /// Authoritative server-side validation. The Steps tab computes per-row
  /// markers from the dependency lists returned by [listSteps] as the
  /// primary feedback; this round-trip catches server-only rules clients
  /// don't model.
  Future<List<String>> checkSteps(List<String> orderedStepIds) =>
      api.checkSteps(orderedStepIds);

  /// This DAO doesn't extend `BaseEntityDao`, so the base's `localDao` hook is
  /// null and the discard-reconciliation clear would be a no-op. Combined with
  /// `upsertAllPreservingDirty` on every refresh path, that pinned a discarded
  /// edit permanently — see [paymentLinkDao.clearDirtyById].
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.paymentLinkDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.paymentLinkDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required SubscriptionApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.paymentLinkDao.upsert,
    deleteById: (id) =>
        db.paymentLinkDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required SubscriptionApi serverResponse,
  }) async {
    await db.paymentLinkDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.paymentLinkDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.paymentLinkDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  PaymentLinksCompanion _apiToCompanion(SubscriptionApi a, String companyId) {
    final domain = PaymentLink.fromApi(a);
    return PaymentLinksCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      priceCents: Value(_priceCents(domain.price)),
      purchasePage: Value(a.purchasePage),
      groupId: Value(a.groupId),
      assignedUserId: Value(a.assignedUserId),
      frequencyId: Value(a.frequencyId),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  PaymentLinksCompanion _domainToCompanion(
    PaymentLink s,
    String companyId, {
    required bool isDirty,
  }) {
    return PaymentLinksCompanion.insert(
      id: s.id,
      companyId: companyId,
      name: Value(s.name),
      priceCents: Value(_priceCents(s.price)),
      purchasePage: Value(s.purchasePage),
      groupId: Value(s.groupId),
      assignedUserId: Value(s.assignedUserId),
      frequencyId: Value(s.frequencyId),
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

  /// Lift a Drift row back into the domain model. Re-applies the
  /// local-only `is_dirty` flag so the UI's "Unsynced" pill survives an
  /// app restart. Mirrors `ExpenseCategoryRepository._fromRow`.
  ///
  /// The payload blob may carry either the bundled API JSON shape
  /// (from `_apiToCompanion` writing `a.toJson()`) or the outbox-bound
  /// shape (from `_domainToCompanion` writing `s.toApiJson(
  /// preserveTempId: true)`). Both contain the full field set thanks
  /// to the `preserveTempId` branch in `toApiJson` — see [PaymentLinkPayload].
  PaymentLink _fromRow(PaymentLinkRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = SubscriptionApi.fromJson(json);
    return PaymentLink.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }
}

int _secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

int _priceCents(Decimal price) {
  final hundred = Decimal.fromInt(100);
  return (price * hundred).truncate().toBigInt().toInt();
}
