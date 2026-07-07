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
  Future<String> resolveTagNames(String companyId, List<String> tagIds) async {
    if (tagIds.isEmpty) return '';
    final rows = await db.tagDao.getByIds(companyId: companyId, ids: tagIds);
    final byId = {for (final r in rows) r.id: r.name};
    return joinTagNames(tagIds.map((id) => byId[id] ?? ''));
  }
}
