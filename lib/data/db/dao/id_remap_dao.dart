import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/tables/id_remap_table.dart';

part 'id_remap_dao.g.dart';

@DriftAccessor(tables: [IdRemap])
class IdRemapDao extends DatabaseAccessor<AppDatabase> with _$IdRemapDaoMixin {
  IdRemapDao(super.db);

  Future<void> remember({
    required String entityType,
    required String tempId,
    required String realId,
    required int now,
  }) => into(idRemap).insertOnConflictUpdate(
    IdRemapCompanion.insert(
      entityType: entityType,
      tempId: tempId,
      realId: realId,
      createdAt: now,
    ),
  );

  Future<String?> resolve({
    required String entityType,
    required String tempId,
  }) async {
    final row =
        await (select(idRemap)
              ..where(
                (r) =>
                    r.entityType.equals(entityType) & r.tempId.equals(tempId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row?.realId;
  }

  /// Resolve a `tmp_` id to its real id WITHOUT knowing the entity type.
  /// `tmp_` ids are uuid-v4 (globally unique across entity types), so a bare
  /// tempId lookup is unambiguous. Used by the sync drain to heal a payload
  /// `tmp_` token whose owning entity already synced — the token may belong to
  /// a different entity type than the row carrying it (e.g. a `tmp_` tag id
  /// embedded in a task's `tags` array, whose tag create already round-tripped
  /// and was deleted before the task row was even enqueued).
  Future<String?> resolveAnyType(String tempId) async {
    final row =
        await (select(idRemap)
              ..where((r) => r.tempId.equals(tempId))
              ..limit(1))
            .getSingleOrNull();
    return row?.realId;
  }

  /// Batched [resolveAnyType]: one query for a whole id set, returning only
  /// the ids that actually map. Callers resolve a *list* of referenced ids
  /// (an entity's `tag_ids`, say), and N sequential awaits are the shape the
  /// mixin doc at `tag_denormalization.dart` warns about — web runs every
  /// statement through a single serialized WASM connection.
  Future<Map<String, String>> resolveAllAnyType(
    Iterable<String> tempIds,
  ) async {
    final ids = tempIds.where((t) => t.startsWith('tmp_')).toSet().toList();
    if (ids.isEmpty) return const <String, String>{};
    final rows = await (select(
      idRemap,
    )..where((r) => r.tempId.isIn(ids))).get();
    return {for (final r in rows) r.tempId: r.realId};
  }

  /// Every `tmp_ -> real` mapping recorded for [entityType], as a live map.
  ///
  /// Backs `TagRepository.watchLookup`, which folds it into the tag stream so a
  /// surface rendering a name from an id survives the create swap: the tmp row
  /// is DELETED the moment the create round-trips (`applyCreateResponseTemplate`),
  /// so a lookup keyed on the stored id misses from that point on.
  ///
  /// `distinctRows()` before the map is load-bearing, not tidiness — drift
  /// watches are table-grained and `id_remap` collects a row for every offline
  /// create of *every* entity type, so without it each unrelated create would
  /// rebuild every tag chip on screen.
  ///
  /// Deliberately not company-scoped: the table has no `company_id` column, and
  /// tmp ids are uuid-v4, which is the same assumption [resolveAnyType] already
  /// relies on.
  Stream<Map<String, String>> watchAliases({required String entityType}) {
    final q = select(idRemap)..where((r) => r.entityType.equals(entityType));
    return q.watch().distinctRows().map(
      (rows) => {for (final r in rows) r.tempId: r.realId},
    );
  }

  /// Emits the real id whenever a remap row appears for
  /// `(entityType, tempId)`. Used by `ClientRepository.watch` so an open
  /// detail screen survives an in-flight tmp→real swap without going blank.
  /// Emits null when no remap row exists yet.
  Stream<String?> watchRealId({
    required String entityType,
    required String tempId,
  }) {
    final q = select(idRemap)
      ..where((r) => r.entityType.equals(entityType) & r.tempId.equals(tempId))
      ..limit(1);
    return q.watchSingleOrNull().map((row) => row?.realId);
  }
}
