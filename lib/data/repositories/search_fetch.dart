import 'package:admin/utils/search_fold.dart';

/// How many of a search's words a picker fetches page 1 for, besides the
/// whole phrase, when the server can't split the text itself.
const int kSearchFetchWords = 2;

/// One server page for [term]; [phrase] asks for [term] on the wire as is.
typedef SearchPageFetch = Future<void> Function(String term, {bool phrase});

/// Warm the local cache for a picker's [search] with one-shot server fetches.
///
/// A list search sends the server one word ([serverSearchTerms]`.first`) and
/// pages on until it has enough rows. A picker reads only page 1 — so when the
/// server matches the whole text as one phrase ([serverSplits] false) and it
/// has several words, page 1 is fetched for the phrase itself and for each of
/// its first [kSearchFetchWords] words, in parallel:
///
/// - the phrase lands a record whose name *is* the text, so a picker never
///   offers to create one that exists ("Web Hosting Basic" in a catalog with
///   a hundred hosting products);
/// - the words land the rows the phrase can't find — words in another order
///   or in different fields — through whichever word they are rare under
///   (`s22`, not `screen`), and the every-word local search picks them out.
///
/// When the server splits words itself, one fetch of the whole text is exact.
///
/// [fetchPage1] is the repository's `ensurePageLoaded(page: 1, search: term,
/// phraseOnWire: phrase)` — `phrase` is true for the whole-text fetch, which
/// the repository would otherwise shrink to its most selective word.
/// A search-scoped fetch never reads or advances the sync cursor, so the
/// parallel calls don't interfere. Errors propagate (the first one), as a
/// single fetch's would.
Future<void> ensureSearchLoaded(
  String search, {
  required bool serverSplits,
  required SearchPageFetch fetchPage1,
}) async {
  final trimmed = search.trim();
  if (trimmed.isEmpty) return;
  final words = serverSearchTerms(trimmed);
  final terms = serverSplits || words.length < 2
      ? [trimmed]
      : [trimmed, ...words.take(kSearchFetchWords)];
  await Future.wait([
    // The first term is the whole text.
    for (final (i, t) in terms.indexed) fetchPage1(t, phrase: i == 0),
  ]);
}
