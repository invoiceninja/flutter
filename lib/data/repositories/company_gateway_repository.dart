import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/company_gateway_dao.dart';
import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/company_gateways_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('CompanyGatewayRepository');

/// Source of truth for CompanyGateway data. UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Gateways are a small entity — typical accounts have < 10 rows total — so
/// [pageSize] is set to a high cap and the list is loaded in a single page.
/// This still flows through the standard `ensurePageLoaded` cursor so future
/// edits or server-side additions surface naturally.
class CompanyGatewayRepository
    extends BaseEntityRepository<CompanyGateway, CompanyGatewayApi> {
  CompanyGatewayRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.companyGateway,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final CompanyGatewaysApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'company_gateway';

  /// Watch the first [loadedPages] pages worth of rows. [loadedPages] is
  /// 1-based — 1 means "show page 1," 2 means "show pages 1+2," etc.
  Stream<List<CompanyGateway>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = CompanyGatewayFieldIds.updatedAt,
    bool sortAscending = false,
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    return db.companyGatewayDao
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
      db.companyGatewayDao.watchActiveCount(companyId: companyId);

  @override
  Stream<CompanyGateway?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.companyGatewayDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Seed the local company_gateways table from the `/refresh` envelope's
  /// bundled `data[N].company.company_gateways` array. Called from
  /// `AuthRepository._persistAndActivate` so the first paint of the
  /// gateways screen reads from Drift instead of firing a redundant
  /// `GET /company_gateways` (the data is already in hand).
  ///
  /// Upserts only — never deletes — so rows with pending local edits
  /// (`is_dirty = true`) keep their outbox-bound payload until the next
  /// real sync. Sets the keyset cursor to the bundle's max `updated_at`
  /// so a subsequent `ensurePageLoaded` treats the bundle as the freshest
  /// snapshot we've seen.
  Future<void> applyBundle({
    required String companyId,
    required List<CompanyGatewayApi> bundle,
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
    upsert: (byId) => db.companyGatewayDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

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
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.companyGatewayDao.upsertAllPreservingDirty(
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
    const maxPages = 100; // gateways are bounded; cap defensively.
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

  Future<SaveResult<CompanyGateway>> create({
    required String companyId,
    required CompanyGateway draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.companyGatewayDao.upsert(companion);
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

  Future<SaveResult<CompanyGateway>> save({
    required String companyId,
    required CompanyGateway gateway,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(gateway.id);
    if (resolvedId != gateway.id) gateway = gateway.copyWith(id: resolvedId);

    final companion = _domainToCompanion(gateway, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.companyGatewayDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: gateway.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: gateway.id,
        kind: MutationKind.update,
        payload: gateway.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: gateway, outboxRowId: rowId);
  }

  /// Phase 2: ping the gateway with its currently-saved credentials. Used
  /// by the "Test credentials" button on the Credentials tab.
  Future<({bool valid, String? message})> testCredentials({
    required String id,
  }) => api.testCredentials(id);

  /// Phase 2: mint a one-time token used to redirect the user into an
  /// external OAuth setup flow (Stripe Connect, WePay, PayPal Platform,
  /// GoCardless OAuth). Returns the hash to splice into the per-provider
  /// signup URL.
  Future<String> requestOAuthSetupHash() => api.requestOneTimeToken();

  /// Phase 2: disconnect a Stripe Connect gateway. The server keeps the
  /// row but clears its `account_id`, so the gateway re-renders as
  /// "not connected" in the list. Destructive enough that the API client
  /// requires the active password.
  Future<void> disconnectStripe({required String id}) =>
      api.disconnectStripe(id: id);

  /// Phase 3: pull this Stripe gateway's customers into Invoice Ninja.
  Future<void> importStripeCustomers({required String id}) =>
      api.importStripeCustomers(id: id);

  /// Phase 3: reconcile Stripe's customer count against Invoice Ninja's.
  /// Returns the two counts so the UI can show them side-by-side.
  Future<({int stripeCount, int localCount})> verifyStripeCustomers() =>
      api.verifyStripeCustomers();

  /// This DAO doesn't extend `BaseEntityDao`, so the base's `localDao` hook is
  /// null and the discard-reconciliation clear would be a no-op. Combined with
  /// `upsertAllPreservingDirty` on every refresh path, that pinned a discarded
  /// edit permanently — see [companyGatewayDao.clearDirtyById].
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.companyGatewayDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.companyGatewayDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required CompanyGatewayApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.companyGatewayDao.upsert,
    deleteById: (id) =>
        db.companyGatewayDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required CompanyGatewayApi serverResponse,
  }) async {
    await db.companyGatewayDao.upsert(
      _apiToCompanion(serverResponse, companyId),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.companyGatewayDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.companyGatewayDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  CompanyGatewaysCompanion _apiToCompanion(
    CompanyGatewayApi a,
    String companyId,
  ) {
    return CompanyGatewaysCompanion.insert(
      id: a.id,
      companyId: companyId,
      gatewayKey: Value(a.gatewayKey),
      label: Value(a.label),
      testMode: Value(a.testMode),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  CompanyGatewaysCompanion _domainToCompanion(
    CompanyGateway g,
    String companyId, {
    required bool isDirty,
  }) {
    return CompanyGatewaysCompanion.insert(
      id: g.id,
      companyId: companyId,
      gatewayKey: Value(g.gatewayKey),
      label: Value(g.label),
      testMode: Value(g.testMode),
      updatedAt: g.updatedAt == 0
          ? DateTime.now().millisecondsSinceEpoch ~/ 1000
          : g.updatedAt,
      createdAt: Value(g.createdAt),
      // Value(null) (not absent) to match the API path above and the
      // restore-clears-archived_at invariant; equivalent here since the `== 0`
      // branch only fires for active rows whose column is already NULL.
      archivedAt: g.archivedAt > 0 ? Value(g.archivedAt) : const Value(null),
      isDirty: Value(isDirty),
      isDeleted: Value(g.isDeleted),
      payload: jsonEncode(g.toApiJson(preserveTempId: true)),
    );
  }

  CompanyGateway _fromRow(CompanyGatewayRow row) {
    final apiJson = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = CompanyGatewayApi.fromJson(apiJson);
    return CompanyGateway.fromApi(
      api,
    ).copyWith(isDirty: row.isDirty, isDeleted: row.isDeleted);
  }
}
