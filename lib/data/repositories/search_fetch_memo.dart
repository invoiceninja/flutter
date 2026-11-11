import 'package:admin/utils/search_fold.dart';

/// How long a search-scoped server answer stands in for asking again.
///
/// Long enough to cover a typing session (adding words, backspacing, opening
/// a picker over a list just searched), short enough that a record created
/// elsewhere turns up on the next search a few minutes later even if the
/// `/refresh` delta has not run yet. A full wipe drops every answer at once
/// (`AppDatabase.dataGeneration`), whatever this says.
const Duration kSearchFetchMemoTtl = Duration(minutes: 5);

/// The most search terms remembered per repository; the oldest goes first.
const int kSearchFetchMemoMaxTerms = 128;

/// Remembers what this session's search-scoped fetches already put in Drift,
/// so a search whose answer is already local makes no request.
///
/// Every list endpoint but clients matches `filter=` as one phrase, so a
/// multi-word search sends one word and pages through the superset
/// (`serverSearchTerms`), and the server's search costs seconds on a large
/// account whether it matches or not (invoiceninja/invoiceninja#13433, where
/// splitting words server-side was declined for exactly that cost). Two
/// answers are therefore worth keeping:
///
/// - **A term paged to the end** (`complete`): every server row matching it is
///   in Drift. Any later search each of whose terms' words sits inside one of
///   the words it would put on the wire can only match a subset of those
///   rows, so the local every-word search over Drift is already the whole
///   answer — no request, `hasMore` false. Typing `sams` (12 rows) makes
///   `samsung` and `samsung galaxy` free (both send `samsung`), but not
///   `samsung s22`, which sends `s22`.
/// - **A page already fetched**: adding a word that leaves the wire term
///   unchanged (`samsung` → `samsung galaxy`, both send `samsung`) would ask
///   for the same pages again; the remembered `hasMore` answers instead.
///
/// Answers are keyed by `scope` — the company, the page size and every filter
/// that went on the wire — so a status tab, a state filter or a parent scope
/// never borrows another's completeness. [generation] is
/// `AppDatabase.dataGeneration`: a wipe changes it and forgets everything,
/// since the rows these answers vouch for are gone.
///
/// Pure bookkeeping; `BaseEntityRepository.ensurePageLoadedTemplate` is the
/// only caller. See docs/local-search-matching.md § A search the cache already
/// holds in full makes no request.
class SearchFetchMemo {
  SearchFetchMemo({DateTime Function()? now, this.ttl = kSearchFetchMemoTtl})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration ttl;

  int? _generation;

  /// scope → wire term → what its pages answered. Evicted by age across all
  /// scopes ([_evict]).
  final Map<String, Map<String, _TermPages>> _byScope = {};

  /// The `hasMore` to return for [page] of [search] without a request, or
  /// null when the server has to be asked.
  ///
  /// [wireTerm] is what would be sent (`wireSearchTerm`); a complete term
  /// covers the search only when it sits inside one of [wireTerm]'s words.
  bool? answer({
    required String scope,
    required int generation,
    required String search,
    required String wireTerm,
    required int page,
  }) {
    _checkGeneration(generation);
    final terms = _byScope[scope];
    if (terms == null || terms.isEmpty) return null;
    final now = _now();
    // Only the words that go on the wire can carry a cover. A word matched
    // only locally is matched across more fields than the server searches
    // (notes, a wider fold), so a row can hold a complete term's text in a
    // field the server never LIKEd for it — `march` in an invoice's notes —
    // and still be one the wire word (`hosting`) would have fetched. A row
    // the server matched for the wire word holds it in a server column, so
    // a term inside the wire word was matched there too.
    final words = [for (final w in searchWords(wireTerm)) w.toLowerCase()];
    for (final entry in terms.values) {
      if (!entry.complete || _expired(entry, now)) continue;
      if (_covers(entry.requiredWords, words)) return false;
    }
    final own = terms[wireTerm];
    if (own == null || _expired(own, now)) return null;
    return own.hasMoreByPage[page];
  }

  /// Notes what [page] of [wireTerm] returned. Pages count only in order from
  /// page 1 — a term is complete once every page up to one that answered
  /// `hasMore: false` landed in this session, under one [generation].
  void record({
    required String scope,
    required int generation,
    required String wireTerm,
    required bool serverSplits,
    required int page,
    required bool hasMore,
  }) {
    // Taken before a request a wipe overtook: what it vouches for is gone,
    // and it must not throw away answers recorded since.
    final current = _generation;
    if (current != null && generation < current) return;
    _checkGeneration(generation);
    final now = _now();
    final terms = _byScope.putIfAbsent(scope, () => {});
    var entry = terms[wireTerm];
    if (page == 1) {
      entry = _TermPages(
        requiredWords: _requiredWords(wireTerm, serverSplits: serverSplits),
        fetchedAt: now,
      );
      terms[wireTerm] = entry;
    } else if (entry == null ||
        _expired(entry, now) ||
        entry.contiguousTo != page - 1) {
      // A page out of order (its page 1 expired or was never seen here)
      // proves nothing about the rest of the term.
      return;
    }
    entry.contiguousTo = page;
    entry.hasMoreByPage[page] = hasMore;
    if (!hasMore) entry.complete = true;
    _evict(now);
  }

  /// Forget everything — a test seam, and what a generation change does.
  void clear() => _byScope.clear();

  void _checkGeneration(int generation) {
    if (_generation == generation) return;
    _generation = generation;
    _byScope.clear();
  }

  bool _expired(_TermPages entry, DateTime now) =>
      now.difference(entry.fetchedAt) >= ttl;

  void _evict(DateTime now) {
    var total = 0;
    for (final terms in _byScope.values) {
      terms.removeWhere((_, e) => _expired(e, now));
      total += terms.length;
    }
    _byScope.removeWhere((_, terms) => terms.isEmpty);
    while (total > kSearchFetchMemoMaxTerms) {
      String? oldestScope;
      String? oldestTerm;
      DateTime? oldestAt;
      _byScope.forEach((scope, terms) {
        terms.forEach((term, e) {
          if (oldestAt == null || e.fetchedAt.isBefore(oldestAt!)) {
            oldestAt = e.fetchedAt;
            oldestScope = scope;
            oldestTerm = term;
          }
        });
      });
      _byScope[oldestScope]!.remove(oldestTerm);
      if (_byScope[oldestScope]!.isEmpty) _byScope.remove(oldestScope);
      total--;
    }
  }
}

/// The words a server row matching [wireTerm] is known to contain, each in
/// some column, lowercased.
///
/// A server that matches the phrase (`serverSplits` false) requires the whole
/// term in one column — one "word", which never covers another search when it
/// holds a space, since no search word does. `ClientFilters` requires every
/// space-separated piece instead; the pieces are kept raw (a lone `-` or `0`
/// included, though the server drops `0`), because requiring a word the
/// server did not only makes a cover rarer, never wrong.
List<String> _requiredWords(String wireTerm, {required bool serverSplits}) {
  final lower = wireTerm.trim().toLowerCase();
  if (lower.isEmpty) return const [];
  if (!serverSplits) return [lower];
  return lower.split(RegExp(r'\s+')).toSet().toList();
}

/// Whether every one of [required] sits inside one of [searchWords]: then a
/// row matching the search has each required word in the same column its
/// search word matched, so it was in the term's results.
///
/// Literal (lowercased) containment, not the accent fold: the server's
/// `LIKE '%sams%'` is what produced the term's rows, and a folded match
/// (`müll` inside `mullerstrasse`) is not a promise the server kept.
bool _covers(List<String> required, List<String> searchWords) {
  if (required.isEmpty || searchWords.isEmpty) return false;
  for (final r in required) {
    if (!searchWords.any((w) => w.contains(r))) return false;
  }
  return true;
}

class _TermPages {
  _TermPages({required this.requiredWords, required this.fetchedAt});

  final List<String> requiredWords;

  /// When page 1 landed — a complete answer is as old as its oldest page.
  final DateTime fetchedAt;

  final Map<int, bool> hasMoreByPage = {};
  int contiguousTo = 0;
  bool complete = false;
}
