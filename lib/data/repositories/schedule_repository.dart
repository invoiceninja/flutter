import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/schedule_dao.dart';
import 'package:admin/data/models/api/schedule_api_model.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/schedules_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('ScheduleRepository');

class ScheduleRepository extends BaseEntityRepository<Schedule, ScheduleApi> {
  ScheduleRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.schedule,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final SchedulesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'schedule';

  Stream<List<Schedule>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Set<String> templates = const <String>{},
    String sortField = ScheduleFieldIds.nextRun,
    bool sortAscending = true,
  }) {
    return db.scheduleDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          templates: templates,
          sortField: sortField,
          sortAscending: sortAscending,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Watch every active schedule for a company in canonical next-run order.
  /// Used by the settings list screen.
  Stream<List<Schedule>> watchAll({required String companyId}) {
    return db.scheduleDao
        .watchAll(companyId: companyId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Watch active **and** archived schedules. Used by the "Show archived"
  /// toggle on the list scaffold.
  Stream<List<Schedule>> watchAllIncludingArchived({
    required String companyId,
  }) {
    return db.scheduleDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: 200,
          states: const {EntityState.active, EntityState.archived},
          sortField: ScheduleFieldIds.nextRun,
          sortAscending: true,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Schedule?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.scheduleDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Seed the local schedules table from the `/refresh` envelope's bundled
  /// `data[N].company.task_schedulers` array. Upsert-only — never deletes
  /// — so rows with pending local edits (`is_dirty=true`) keep their
  /// outbox-bound payload until the next real sync.
  Future<void> applyBundle({
    required String companyId,
    required List<ScheduleApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.scheduleDao.upsertAllPreservingDirty(
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
    upsert: (byId) => db.scheduleDao.upsertAllPreservingDirty(
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

  Future<SaveResult<Schedule>> create({
    required String companyId,
    required Schedule draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    // Clamp next_run to today — the server rejects past dates on every
    // template (`next_run after_or_equal:today`).
    final stored = draft.copyWith(id: tmpId).withNextRunNotBefore(Date.today());
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.scheduleDao.upsert(companion);
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

  Future<SaveResult<Schedule>> save({
    required String companyId,
    required Schedule schedule,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(schedule.id);
    if (resolvedId != schedule.id) schedule = schedule.copyWith(id: resolvedId);

    // Clamp next_run to today — the server rejects past dates on every
    // template (`next_run after_or_equal:today`). Covers payment_schedule
    // (hidden field) and editing a schedule whose next_run already lapsed.
    final clamped = schedule.withNextRunNotBefore(Date.today());
    final companion = _domainToCompanion(clamped, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.scheduleDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: clamped.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: clamped.id,
        kind: MutationKind.update,
        payload: clamped.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: clamped, outboxRowId: rowId);
  }

  /// Toggle the paused flag. The full schedule payload is sent on the wire
  /// because the server's PUT replaces the row in full; we can't PATCH
  /// `is_paused` in isolation.
  Future<void> setPaused({
    required String companyId,
    required Schedule schedule,
    required bool paused,
  }) async {
    final updated = schedule.copyWith(isPaused: paused);
    await save(companyId: companyId, schedule: updated);
  }

  /// This DAO doesn't extend `BaseEntityDao`, so the base's `localDao` hook is
  /// null and the discard-reconciliation clear would be a no-op. Combined with
  /// `upsertAllPreservingDirty` on every refresh path, that pinned a discarded
  /// edit permanently — see [scheduleDao.clearDirtyById].
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.scheduleDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.scheduleDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required ScheduleApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.scheduleDao.upsert,
    deleteById: (id) => db.scheduleDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required ScheduleApi serverResponse,
  }) async {
    await db.scheduleDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.scheduleDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.scheduleDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  SchedulesCompanion _apiToCompanion(ScheduleApi a, String companyId) {
    return SchedulesCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      template: Value(a.template),
      frequencyId: Value(a.frequencyId),
      nextRun: Value(a.nextRun),
      isPaused: Value(a.isPaused),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  SchedulesCompanion _domainToCompanion(
    Schedule s,
    String companyId, {
    required bool isDirty,
  }) {
    return SchedulesCompanion.insert(
      id: s.id,
      companyId: companyId,
      name: Value(s.name),
      template: Value(s.template),
      frequencyId: Value(s.frequencyId),
      nextRun: Value(s.nextRun?.toIso() ?? ''),
      isPaused: Value(s.isPaused),
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

  Schedule _fromRow(ScheduleRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    // Local-only flags overlay the DTO defaults — see CLAUDE.md § Sync.
    final api = ScheduleApi.fromJson(_normalizePayload(json));
    return Schedule.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }

  /// The Drift `payload` column round-trips both server responses (the
  /// shape produced by `_apiToCompanion`) and locally-edited drafts (the
  /// shape produced by `toApiJson`). The local-draft shape may be missing
  /// timestamps the DTO expects as ints — fall through to the
  /// authoritative row columns.
  Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    return <String, dynamic>{
      ...payload,
      // Force the parameters map back to a plain Map so the JSON decoder
      // doesn't trip on nested LinkedHashMap edge cases.
      if (payload['parameters'] is Map)
        'parameters': Map<String, dynamic>.from(payload['parameters'] as Map),
    };
  }
}

int _secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
