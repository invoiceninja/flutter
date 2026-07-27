import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/transaction_rule_dao.dart';
import 'package:admin/data/models/api/transaction_rule_api_model.dart';
import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/transaction_rules_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('TransactionRuleRepository');

/// Source of truth for TransactionRule (`bank_transaction_rule`) data.
/// List + get carry `?include=vendor,expense_category` so the joined
/// names render without a second fetch.
class TransactionRuleRepository
    extends BaseEntityRepository<TransactionRule, TransactionRuleApi> {
  TransactionRuleRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.transactionRule,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final TransactionRulesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'transaction_rule';

  Stream<List<TransactionRule>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TransactionRuleFieldIds.name,
    bool sortAscending = true,
  }) {
    assert(loadedPages >= 1);
    return db.transactionRuleDao
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
      db.transactionRuleDao.watchActiveCount(companyId: companyId);

  Stream<List<TransactionRule>> watchAll({required String companyId}) {
    return db.transactionRuleDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * 4,
          sortField: TransactionRuleFieldIds.name,
          sortAscending: true,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<TransactionRule>> watchAllIncludingArchived({
    required String companyId,
  }) {
    return db.transactionRuleDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * 4,
          states: const {EntityState.active, EntityState.archived},
          sortField: TransactionRuleFieldIds.name,
          sortAscending: true,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<TransactionRule?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.transactionRuleDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Drain the `bank_transaction_rules` array carried by `/login` and
  /// `/refresh?first_load=true` into the local `transaction_rules` table.
  /// Wired through `services_entity_wiring.dart`'s `bundleAppliers` so the
  /// Banking → Rules list reads from Drift on first paint without firing a
  /// paged `/api/v1/bank_transaction_rules`. Upserts only — never deletes.
  Future<void> applyBundle({
    required String companyId,
    required List<TransactionRuleApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.transactionRuleDao.upsertAllPreservingDirty(
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
    // The vendor + expense_category joins are read-only display columns;
    // request them on every list pull so the table renders the names
    // without a second fetch.
    staticFilters: const {'include': 'vendor,expense_category'},
    ignoreCursor: ignoreCursor,
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.transactionRuleDao.upsertAllPreservingDirty(
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

  Future<SaveResult<TransactionRule>> create({
    required String companyId,
    required TransactionRule draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.transactionRuleDao.upsert(companion);
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

  Future<SaveResult<TransactionRule>> save({
    required String companyId,
    required TransactionRule rule,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(rule.id);
    if (resolvedId != rule.id) rule = rule.copyWith(id: resolvedId);

    final companion = _domainToCompanion(rule, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.transactionRuleDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: rule.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: rule.id,
        kind: MutationKind.update,
        payload: rule.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: rule, outboxRowId: rowId);
  }

  /// This DAO doesn't extend `BaseEntityDao`, so the base's `localDao` hook is
  /// null and the discard-reconciliation clear would be a no-op. Combined with
  /// `upsertAllPreservingDirty` on every refresh path, that pinned a discarded
  /// edit permanently — see [transactionRuleDao.clearDirtyById].
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.transactionRuleDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.transactionRuleDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TransactionRuleApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.transactionRuleDao.upsert,
    deleteById: (id) =>
        db.transactionRuleDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required TransactionRuleApi serverResponse,
  }) async {
    await db.transactionRuleDao.upsert(
      _apiToCompanion(serverResponse, companyId),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.transactionRuleDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.transactionRuleDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  TransactionRulesCompanion _apiToCompanion(
    TransactionRuleApi a,
    String companyId,
  ) {
    final domain = TransactionRule.fromApi(a);
    return TransactionRulesCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(domain.name),
      appliesTo: Value(domain.appliesTo),
      matchesOnAll: Value(domain.matchesOnAll),
      autoConvert: Value(domain.autoConvert),
      vendorId: Value(domain.vendorId),
      categoryId: Value(domain.categoryId),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  TransactionRulesCompanion _domainToCompanion(
    TransactionRule r,
    String companyId, {
    required bool isDirty,
  }) {
    return TransactionRulesCompanion.insert(
      id: r.id,
      companyId: companyId,
      name: Value(r.name),
      appliesTo: Value(r.appliesTo),
      matchesOnAll: Value(r.matchesOnAll),
      autoConvert: Value(r.autoConvert),
      vendorId: Value(r.vendorId),
      categoryId: Value(r.categoryId),
      updatedAt: r.updatedAt.millisecondsSinceEpoch ~/ 1000,
      createdAt: Value(r.createdAt.millisecondsSinceEpoch ~/ 1000),
      archivedAt: r.archivedAt == null
          ? const Value.absent()
          : Value(r.archivedAt!.millisecondsSinceEpoch ~/ 1000),
      isDirty: Value(isDirty),
      isDeleted: Value(r.isDeleted),
      payload: jsonEncode(r.toApiJson(preserveTempId: true)),
    );
  }

  TransactionRule _fromRow(TransactionRuleRow row) {
    final apiJson = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = TransactionRuleApi.fromJson(apiJson);
    return TransactionRule.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }
}
