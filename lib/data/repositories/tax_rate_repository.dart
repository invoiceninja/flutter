import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/tax_rate_dao.dart';
import 'package:admin/data/models/api/tax_rate_api_model.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/tax_rates_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('TaxRateRepository');

/// Bundled-but-no-CRUD repo. Powers the default-tax pickers on
/// Settings → Tax Settings via [watchAll]. Mutation paths are wired today
/// (`create`/`save`/`delete`/`archive`/`restore`/`purge`) so the follow-up
/// Tax Rates CRUD screen can graduate from [kDisabledEntityModules] to
/// [kWiredEntityModules] without revisiting the data layer.
class TaxRateRepository extends BaseEntityRepository<TaxRate, TaxRateApi> {
  TaxRateRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.taxRate,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final TaxRatesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'tax_rate';

  Stream<List<TaxRate>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TaxRateFieldIds.name,
    bool sortAscending = true,
  }) {
    return db.taxRateDao
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

  /// Watch every active tax rate for a company. Used by the default-tax
  /// pickers on Settings → Tax Settings.
  Stream<List<TaxRate>> watchAll({required String companyId}) {
    return db.taxRateDao
        .watchAll(companyId: companyId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<TaxRate?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.taxRateDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Seed the local tax_rates table from the `/refresh` envelope's bundled
  /// `data[N].company.tax_rates` array. Same shape as [PaymentTermRepository.applyBundle]:
  /// upsert-only (preserves dirty rows), advances the keyset cursor so the
  /// follow-up CRUD screen's first `ensurePageLoaded` short-circuits.
  Future<void> applyBundle({
    required String companyId,
    required List<TaxRateApi> bundle,
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
    upsert: (byId) => db.taxRateDao.upsertAllPreservingDirty(
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
    upsert: (byId) => db.taxRateDao.upsertAllPreservingDirty(
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

  Future<SaveResult<TaxRate>> create({
    required String companyId,
    required TaxRate draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.taxRateDao.upsert(companion);
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

  Future<SaveResult<TaxRate>> save({
    required String companyId,
    required TaxRate rate,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(rate.id);
    if (resolvedId != rate.id) rate = rate.copyWith(id: resolvedId);

    final companion = _domainToCompanion(rate, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.taxRateDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: rate.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: rate.id,
        kind: MutationKind.update,
        payload: rate.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: rate, outboxRowId: rowId);
  }

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.taxRateDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TaxRateApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.taxRateDao.upsert,
    deleteById: (id) => db.taxRateDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required TaxRateApi serverResponse,
  }) async {
    await db.taxRateDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.taxRateDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.taxRateDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  TaxRatesCompanion _apiToCompanion(TaxRateApi a, String companyId) {
    return TaxRatesCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      rate: Value(a.rate),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  TaxRatesCompanion _domainToCompanion(
    TaxRate t,
    String companyId, {
    required bool isDirty,
  }) {
    return TaxRatesCompanion.insert(
      id: t.id,
      companyId: companyId,
      name: Value(t.name),
      rate: Value(t.rate),
      updatedAt: _secs(t.updatedAt),
      createdAt: Value(_secs(t.createdAt)),
      archivedAt: t.archivedAt == null
          ? const Value.absent()
          : Value(_secs(t.archivedAt!)),
      isDirty: Value(isDirty),
      isDeleted: Value(t.isDeleted),
      payload: jsonEncode(t.toApiJson(preserveTempId: true)),
    );
  }

  TaxRate _fromRow(TaxRateRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = TaxRateApi.fromJson(json);
    return TaxRate.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }
}

int _secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
