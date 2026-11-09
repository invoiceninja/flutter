import 'package:admin/utils/search_fold.dart';

/// How many of a search's words a picker fetches page 1 for, besides the
/// whole phrase, when the server can't split the text itself.
const int kSearchFetchWords = 2;

/// Page 1 of the server's matches for [term], landed in Drift; returns
/// whether more pages remain (the repository's `ensurePageLoaded`).
///
/// [phrase] asks for [term] on the wire as is; without it the repository sends
/// [term]'s most selective word ([serverSearchTerms]`.first`) — and answers
/// from its memo, with no request, when every row [term] can match is already
/// in Drift (`SearchFetchMemo`).
typedef SearchPageFetch = Future<bool> Function(String term, {bool phrase});

/// Warm the local cache for a picker's [search] with one-shot server fetches.
///
/// A list search sends the server one word ([serverSearchTerms]`.first`) and
/// pages on until it has enough rows. A picker reads only page 1 — so when the
/// server matches the whole text as one phrase ([serverSplits] false) and it
/// has several words, page 1 is fetched for the phrase itself and for each of
/// its first [kSearchFetchWords] words:
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
/// The phrase and the first word go out together, the first word as the
/// whole text without [SearchPageFetch]'s `phrase` (the repository sends that
/// same word, but checks its memo against every word of the search). The
/// second word goes only when the first reported more pages: when it did not,
/// every row the search can match is already in Drift. The server's search
/// costs seconds on a large account (invoiceninja/invoiceninja#13433), so a
/// selective first word (`s22`) saves a third of a picker's requests, and a
/// search an earlier one already covered (`samsung s22` after a complete
/// `sams`) makes none.
///
/// [fetchPage1] is the repository's `ensurePageLoaded(page: 1, search: term,
/// phraseOnWire: phrase)`. A search-scoped fetch never reads or advances the
/// sync cursor, so the parallel calls don't interfere. Errors propagate (the
/// first one), as a single fetch's would.
Future<void> ensureSearchLoaded(
  String search, {
  required bool serverSplits,
  required SearchPageFetch fetchPage1,
}) async {
  final trimmed = search.trim();
  if (trimmed.isEmpty) return;
  final words = serverSearchTerms(trimmed);
  if (serverSplits || words.length < 2) {
    await fetchPage1(trimmed, phrase: true);
    return;
  }
  final [_, firstWordHasMore] = await Future.wait([
    fetchPage1(trimmed, phrase: true),
    // On the wire: `words.first`.
    fetchPage1(trimmed, phrase: false),
  ]);
  if (!firstWordHasMore) return;
  for (final word in words.skip(1).take(kSearchFetchWords - 1)) {
    if (!await fetchPage1(word, phrase: false)) return;
  }
}
