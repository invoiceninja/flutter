import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/tag_api_model.dart'
    show kGlobalTagEntityType;
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/tables/tags_table.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags])
class TagDao extends DatabaseAccessor<AppDatabase>
    with _$TagDaoMixin, CompanyScopedDao {
  TagDao(super.db);

  /// `entity_type IN (<type>, 'global')` — the local mirror of the server's
  /// `TagFilters::entity_type`, which is literally
  /// `whereIn('entity_type', [$entity_type, Tag::GLOBAL_ENTITY_TYPE])`.
  ///
  /// A global tag is attachable to any entity, so anything that resolves or
  /// offers tags **for an entity** must see them; only the Settings → Tags
  /// management list wants the type in isolation ([includeGlobal] `false`).
  Expression<bool> _entityTypeMatches(
    Tags t,
    String entityType, {
    required bool includeGlobal,
  }) => includeGlobal
      ? t.entityType.isIn([entityType, kGlobalTagEntityType])
      : t.entityType.equals(entityType);

  /// Watch tags for a company, scoped to a single [entityType] when provided.
  /// Used by the picker, the list filter suggestions, the read-only chips, and
  /// the Settings → Tags list. Tags are a small set, so there is no pagination
  /// — the full (filtered) set is returned in name order.
  Stream<List<TagRow>> watchAll({
    required String companyId,
    String? entityType,
    bool includeArchived = false,
    bool includeGlobal = true,
  }) {
    final q = select(tags)
      ..where((t) => t.companyId.equals(companyId) & t.isDeleted.equals(false));
    if (entityType != null) {
      q.where(
        (t) => _entityTypeMatches(t, entityType, includeGlobal: includeGlobal),
      );
    }
    if (!includeArchived) {
      q.where((t) => t.archivedAt.isNull());
    }
    q.orderBy([(t) => OrderingTerm(expression: t.name.lower())]);
    return q.watch().distinctRows();
  }

  /// Watch every tag for [entityType] regardless of lifecycle (active,
  /// archived, AND soft-deleted), in name order. Backs the inline-create
  /// collision check: the server's UNIQUE(company_id, entity_type, name) has no
  /// soft-delete predicate, so creating a name that collides with an archived
  /// or deleted tag 422s — the picker must suppress "Create" for any such name,
  /// not just names of the active pool (M1).
  Stream<List<TagRow>> watchAllAnyState({
    required String companyId,
    required String entityType,
    bool includeGlobal = true,
  }) {
    final q = select(tags)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            _entityTypeMatches(t, entityType, includeGlobal: includeGlobal),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.name.lower())]);
    return q.watch().distinctRows();
  }

  Stream<TagRow?> watchById({required String companyId, required String id}) {
    final q = select(tags)
      ..where((t) => t.companyId.equals(companyId) & t.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  /// One-shot batch read by id — mirrors `TaskStatusDao.getByIds`.
  Future<List<TagRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <TagRow>[]);
    final q = select(tags)
      ..where((t) => t.companyId.equals(companyId) & t.id.isIn(list));
    return q.get();
  }

  Future<void> upsert(TagsCompanion row) =>
      into(tags).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<TagsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(tags, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by `refreshAll`
  /// so a queued offline edit isn't clobbered by a stale server payload.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, TagsCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(tags)
      ..addColumns([tags.id])
      ..where(
        tags.companyId.equals(companyId) &
            tags.id.isIn(candidateIds) &
            tags.isDirty.equals(true),
      );
    final dirty = {for (final r in await dirtyQ.get()) r.read(tags.id)!};
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      tags,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).go();
  }

  /// Optimistic archive: stamp `archived_at` and mark the row dirty so the
  /// active list drops it immediately offline and a `/refresh` won't clobber
  /// the flip before sync. Mirrors `BaseEntityDao.setArchived` (M4).
  Future<void> setArchived({
    required String companyId,
    required String id,
    required int atEpochSeconds,
  }) {
    return (update(
      tags,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).write(
      TagsCompanion(
        archivedAt: Value(atEpochSeconds),
        isDirty: const Value(true),
      ),
    );
  }

  /// Optimistic restore: clear archived/deleted flags and mark the row dirty
  /// (the inverse of [setArchived] and [markDeletedDirty]).
  Future<void> markRestored({required String companyId, required String id}) {
    return (update(
      tags,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).write(
      const TagsCompanion(
        archivedAt: Value(null),
        isDeleted: Value(false),
        isDirty: Value(true),
      ),
    );
  }

  /// Optimistic delete: soft-delete the local row and mark it dirty.
  Future<void> markDeletedDirty({
    required String companyId,
    required String id,
  }) {
    return (update(
      tags,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).write(
      const TagsCompanion(isDeleted: Value(true), isDirty: Value(true)),
    );
  }

  /// Clear the local row's dirty flag — the discard-reconciliation hook
  /// (mirrors `BaseEntityDao.clearDirtyById`) so a discarded optimistic
  /// archive/restore/delete doesn't leave the tag stuck dirty + refresh-skipped.
  Future<void> clearDirtyById({required String companyId, required String id}) {
    return (update(tags)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const TagsCompanion(isDirty: Value(false)));
  }
}
