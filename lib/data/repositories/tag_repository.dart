import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/models/domain/tag_lookup.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/utils/combine_latest.dart';

/// Repository for Tags — a small, admin-managed, name+color reference entity
/// scoped per `(company_id, entity_type)`. Unlike most reference data tags are
/// NOT bundled into the login envelope; [refreshAll] fetches every taggable
/// type on demand (company-activate + Settings pull-to-refresh). Mutations flow
/// through the standard outbox via the generic `wire<>()`.
class TagRepository extends BaseEntityRepository<Tag, TagApi> {
  TagRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
  }) : super(
         entityType: EntityType.tag,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final TagsApi api;

  @override
  String get entityTypeName => 'tag';

  /// Watch tags for a company, optionally scoped to one [entityType]. Used by
  /// the picker, the list-filter suggestions, the read-only chips, and the
  /// Settings → Tags list.
  ///
  /// [includeGlobal] mirrors the server: `?entity_type=invoice` returns invoice
  /// tags **plus** the company's global ones, because a global tag is
  /// attachable to any entity. Only the Settings management list, which edits
  /// one scope at a time, passes `false`.
  Stream<List<Tag>> watchAll({
    required String companyId,
    String? entityType,
    bool includeArchived = false,
    bool includeGlobal = true,
  }) {
    return db.tagDao
        .watchAll(
          companyId: companyId,
          entityType: entityType,
          includeArchived: includeArchived,
          includeGlobal: includeGlobal,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Watch every tag for [entityType] regardless of lifecycle (active,
  /// archived, soft-deleted). The picker derives both its active pool and the
  /// inline-create collision set (incl. archived/deleted names the server's
  /// UNIQUE rule still reserves) from this single stream — see [EntityTagsField]
  /// and M1.
  Stream<List<Tag>> watchAllAnyState({
    required String companyId,
    required String entityType,
    bool includeGlobal = true,
  }) {
    return db.tagDao
        .watchAllAnyState(
          companyId: companyId,
          entityType: entityType,
          includeGlobal: includeGlobal,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// The stream for any surface that renders a tag **by id**: every tag for
  /// [entityType] in all lifecycle states, folded together with the
  /// `tmp_ -> real` aliases from `id_remap`.
  ///
  /// [watchAllAnyState] alone is not enough for those surfaces. A create writes
  /// its optimistic row under a `tmp_` id and the parent draft keeps that id;
  /// when the create round-trips, the tmp row is DELETED and the real one
  /// inserted, so the stored id stops resolving and the chip fell back to
  /// printing `tmp_1f3c…` as the tag's name. The alias map is what keeps it
  /// resolving. Surfaces with no id to resolve — Settings → Tags, the list
  /// filter suggestions — should keep using [watchAll] / [watchAllAnyState].
  Stream<TagLookup> watchLookup({
    required String companyId,
    required String entityType,
    bool includeGlobal = true,
  }) {
    return combineLatest2(
      watchAllAnyState(
        companyId: companyId,
        entityType: entityType,
        includeGlobal: includeGlobal,
      ),
      db.idRemapDao.watchAliases(entityType: entityTypeName),
      TagLookup.new,
    );
  }

  @override
  Stream<Tag?> watchByRealId({required String companyId, required String id}) =>
      db.tagDao
          .watchById(companyId: companyId, id: id)
          .map((row) => row == null ? null : _fromRow(row));

  /// Fetch every tag for the company in ONE paged sweep.
  ///
  /// `TagFilters::entity_types` (plural) takes a CSV and normalizes each entry,
  /// so a single request covers all 14 taggable types plus the company-wide
  /// `global` scope — which has to be listed explicitly, because unlike the
  /// singular `entity_type` filter the plural one doesn't fold globals in for
  /// free. This used to be one request per type (14 serialized round trips on
  /// every company activate, each re-downloading the whole global set).
  ///
  /// An older server with no `entity_types` handler silently ignores the param
  /// (`QueryFilters::apply` skips unknown keys) and returns every tag for the
  /// company — a harmless superset, since each row is scoped by its own
  /// echoed `entity_type` on ingest.
  ///
  /// Bypasses the keyset cursor entirely; tags are a small set, so we just page
  /// until exhausted.
  Future<void> refreshAll({required String companyId}) async {
    final types = [...kTagEntityTypes, kGlobalTagEntityType].join(',');
    var page = 1;
    while (true) {
      final result = await api.list(
        page: page,
        perPage: 200,
        filters: {'entity_types': types},
      );
      final items = result.data.data;
      if (items.isEmpty) break;
      // Scope comes from the row's own `entity_type`, never from what we asked
      // for: a global tag rides along with every type, and stamping it with the
      // requested one would mislabel it (and, across several requests, let the
      // last one win).
      final byId = <String, TagsCompanion>{
        for (final a in items) a.id: _apiToCompanion(a, companyId),
      };
      await db.tagDao.upsertAllPreservingDirty(
        companyId: companyId,
        byId: byId,
      );
      if (items.length < 200) break;
      page++;
      if (page > 50) break; // safety cap (~10k tags)
    }
  }

  Future<SaveResult<Tag>> create({
    required String companyId,
    required Tag draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.tagDao.upsert(companion);
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

  Future<SaveResult<Tag>> save({
    required String companyId,
    required Tag tag,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(tag.id);
    if (resolvedId != tag.id) tag = tag.copyWith(id: resolvedId);

    final companion = _domainToCompanion(tag, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.tagDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tag.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tag.id,
        kind: MutationKind.update,
        payload: tag.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: tag, outboxRowId: rowId);
  }

  // TagDao isn't a BaseEntityDao, so the base `localDao`-gated optimistic flip
  // is a no-op for tags. Override archive/restore/delete (+ the discard hook)
  // to flip local Drift state via TagDao so offline these don't silently do
  // nothing while showing a success toast (M4).
  @override
  Future<void> archive({required String companyId, required String id}) async {
    await db.transaction(() async {
      await db.tagDao.setArchived(
        companyId: companyId,
        id: id,
        atEpochSeconds: now().millisecondsSinceEpoch ~/ 1000,
      );
      await enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.archive,
        payload: {'id': id},
      );
    });
  }

  @override
  Future<void> restore({required String companyId, required String id}) async {
    await db.transaction(() async {
      await db.tagDao.markRestored(companyId: companyId, id: id);
      await enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.restore,
        payload: {'id': id},
      );
    });
  }

  @override
  Future<void> delete({required String companyId, required String id}) async {
    await db.transaction(() async {
      await db.tagDao.markDeletedDirty(companyId: companyId, id: id);
      await enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.delete,
        payload: {'id': id},
      );
    });
  }

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.tagDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.tagDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TagApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.tagDao.upsert,
    deleteById: (id) => db.tagDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required TagApi serverResponse,
  }) async {
    await db.tagDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.tagDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.tagDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  TagsCompanion _apiToCompanion(TagApi a, String companyId) {
    // Always the row's OWN echoed scope. It used to be overridable by the
    // requested `entity_type`, which silently relabelled every global tag as
    // whichever type was being fetched at the time.
    final normalized = normalizeTagEntityType(a.entityType);
    // Store the payload with the normalized (short) entity_type so a later
    // `_fromRow` round-trip stays consistent with the column.
    final stored = a.copyWith(entityType: normalized);
    return TagsCompanion.insert(
      id: a.id,
      companyId: companyId,
      entityType: Value(normalized),
      name: Value(a.name),
      color: Value(a.color ?? ''),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(stored.toJson()),
    );
  }

  TagsCompanion _domainToCompanion(
    Tag t,
    String companyId, {
    required bool isDirty,
  }) {
    return TagsCompanion.insert(
      id: t.id,
      companyId: companyId,
      entityType: Value(t.entityType),
      name: Value(t.name),
      color: Value(t.color),
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

  // Every Tag field maps to a column, and a local `toApiJson` payload omits
  // timestamps — so build straight from the (authoritative) columns rather
  // than decoding the payload.
  Tag _fromRow(TagRow row) => Tag(
    id: row.id,
    entityType: row.entityType,
    name: row.name,
    color: row.color,
    updatedAt: epochSecondsToUtc(row.updatedAt),
    createdAt: epochSecondsToUtc(row.createdAt),
    archivedAt: row.archivedAt == null
        ? null
        : epochSecondsToUtc(row.archivedAt!),
    isDeleted: row.isDeleted,
    isDirty: row.isDirty,
  );
}

int _secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
