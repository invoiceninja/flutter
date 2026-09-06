import 'package:admin/data/db/app_database.dart';

/// Shared tag-denormalization + local tag-filter helpers for the tag-bearing
/// entities (tasks, projects — the next one gets them for free). One home so
/// the `tag_names` sort-key format (written from the server echo AND from
/// local save/create) and the post-decode `tag:` filter mirror can't drift
/// between repositories — divergence would make the same tag set sort or
/// filter differently on the Tasks vs Projects lists with no error anywhere.

/// The `tag_names` column format: comma-joined, lowercased, empties dropped.
/// Every writer (server-echo `_apiToCompanion` and the local-save resolver
/// below) must produce exactly this shape or local rows sort differently
/// from their own server echo.
String joinTagNames(Iterable<String> names) =>
    names.where((n) => n.isNotEmpty).join(',').toLowerCase();

/// OR-membership local mirror of the server's `tag_ids` filter
/// (`QueryFilters::tag_ids` — `whereHas('tags', whereIn)`): any selected id
/// matches. Applied post-decode because tag ids live only in the row payload
/// (the `tag_names` column holds names, for sort).
bool matchesTagIdFilter(List<String> rowTagIds, Set<String> selectedTagIds) =>
    rowTagIds.any(selectedTagIds.contains);

/// Resolves tag ids to the denormalized [joinTagNames] sort key through the
/// local tag cache. Mixed into tag-bearing repositories (which all expose
/// `db`). Call it BEFORE the save transaction — the read needs no atomicity,
/// and holding the exclusive write lock across an extra SELECT lengthens
/// save latency (web's single WASM connection serializes everything on it).
mixin TagNameResolver {
  AppDatabase get db;

  /// Name order follows [tagIds] order for parity with the server echo.
  ///
  /// Alias-tolerant: an id whose tag row is gone is retried through `id_remap`,
  /// so a tag whose inline create round-tripped while the form was open still
  /// contributes its name. Callers should have run [canonicalizeTagIds] first —
  /// this is the belt-and-braces half, for any caller that hasn't.
  Future<String> resolveTagNames(String companyId, List<String> tagIds) async {
    if (tagIds.isEmpty) return '';
    final rows = await db.tagDao.getByIds(companyId: companyId, ids: tagIds);
    final byId = {for (final r in rows) r.id: r.name};
    // Materialized: the predicate closes over `byId`, which is mutated
    // below, so a lazy view would change meaning as it is walked.
    final missing = tagIds.where((id) => !byId.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      final aliases = await db.idRemapDao.resolveAllAnyType(missing);
      if (aliases.isNotEmpty) {
        final extra = await db.tagDao.getByIds(
          companyId: companyId,
          ids: aliases.values.toList(),
        );
        final extraById = {for (final r in extra) r.id: r.name};
        for (final e in aliases.entries) {
          final name = extraById[e.value];
          if (name != null) byId[e.key] = name;
        }
      }
    }
    return joinTagNames(tagIds.map((id) => byId[id] ?? ''));
  }

  /// [tagIds] with every `tmp_` id that has already round-tripped rewritten to
  /// its real id, order preserved, duplicates collapsed keeping the first
  /// occurrence.
  ///
  /// Call it in `create`/`save` beside the entity's own `resolveId` rebind and
  /// BEFORE [resolveTagNames]. A tag created inline hands the parent draft a
  /// `tmp_` id; if that create drains while the form is still open, the tmp tag
  /// row is deleted and the draft's id names nothing — the row's `tag_names`
  /// sort key silently loses that tag, and the stored payload carries a token
  /// only `SyncRepository._healResolvedTempRefs` can rescue. Canonicalizing
  /// here fixes the sort key, the payload and the local `tag:` filter mirror at
  /// once, and makes that heal a backstop rather than a dependency.
  ///
  /// The dedupe is not cosmetic: a draft can legitimately hold both the tmp and
  /// the real id for one tag (rows saved before this shipped, when the picker
  /// re-offered a just-created tag under its real id).
  ///
  /// Like [resolveTagNames], call it OUTSIDE the save transaction.
  Future<List<String>> canonicalizeTagIds(List<String> tagIds) async {
    if (tagIds.isEmpty) return tagIds;
    final aliases = await db.idRemapDao.resolveAllAnyType(tagIds);
    // No early return on an empty alias map: the dedupe below is part of the
    // contract, and a draft can hold the same real id twice.
    final seen = <String>{};
    return [
      for (final id in tagIds)
        if (seen.add(aliases[id] ?? id)) aliases[id] ?? id,
    ];
  }
}
