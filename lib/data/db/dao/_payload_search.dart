import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_search_fold.dart';

/// Builds a case- and accent-insensitive search over one or more JSON keys dug
/// out of an entity's `payload` blob with SQLite's JSON1 `json_extract`.
///
/// [search] is bound as a `?` variable by [searchLike] — it is **never**
/// string-interpolated into the SQL text, so a `'` (or any other character) in
/// the user's search term is treated as a literal, not as SQL. The JSON keys
/// are hardcoded call-site literals, never user input, so interpolating them
/// into the path is safe.
///
/// Replaces the hand-built per-DAO helpers that concatenated the raw search
/// term straight into a `LIKE` clause in the SQL text, which both broke on
/// apostrophes and was injectable.
Expression<bool> payloadJsonLike(String search, List<String> jsonKeys) {
  Expression<bool> likeKey(String key) => searchLike(
    CustomExpression<String>("COALESCE(json_extract(payload, '\$.$key'), '')"),
    search,
  );

  return jsonKeys.map(likeKey).reduce((a, b) => a | b);
}
