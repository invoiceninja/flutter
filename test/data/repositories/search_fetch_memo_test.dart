import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/search_fetch_memo.dart';

/// `SearchFetchMemo` on its own: when a search-scoped fetch may be answered
/// without a request. The repository wiring is pinned in
/// `vendor_repository_test.dart` › a search the cache already holds in full.
void main() {
  late DateTime now;
  late SearchFetchMemo memo;

  setUp(() {
    now = DateTime(2026, 11, 10, 12);
    memo = SearchFetchMemo(now: () => now);
  });

  void record(
    String wireTerm, {
    int page = 1,
    required bool hasMore,
    bool serverSplits = false,
    String scope = 's',
    int generation = 0,
  }) => memo.record(
    scope: scope,
    generation: generation,
    wireTerm: wireTerm,
    serverSplits: serverSplits,
    page: page,
    hasMore: hasMore,
  );

  bool? answer(
    String search, {
    String? wireTerm,
    int page = 1,
    String scope = 's',
    int generation = 0,
  }) => memo.answer(
    scope: scope,
    generation: generation,
    search: search,
    wireTerm: wireTerm ?? search,
    page: page,
  );

  test('a complete term covers a search one of whose words holds it', () {
    record('sams', hasMore: false);
    expect(answer('samsung', wireTerm: 'samsung'), isFalse);
    expect(answer('Galaxy SAMSUNG', wireTerm: 'samsung'), isFalse);
    expect(answer('galaxy', wireTerm: 'galaxy'), isNull);
    // Any page of a covered search: the local window widens on its own.
    expect(answer('samsung', page: 3), isFalse);
  });

  test('cover is literal, not folded: the server LIKE promised no more', () {
    record('mull', hasMore: false);
    expect(answer('müller'), isNull);
    expect(answer('Muller'), isFalse);
  });

  test('a phrase term (with a space) covers no other search', () {
    record('web hosting', hasMore: false);
    expect(answer('web hosting basic', wireTerm: 'hosting'), isNull);
    // …but repeats its own pages.
    expect(answer('web hosting', wireTerm: 'web hosting'), isFalse);
  });

  test('a server that splits words covers a search holding every word', () {
    record('acme ltd', hasMore: false, serverSplits: true);
    expect(answer('ltd acme gmbh'), isFalse);
    expect(answer('acme'), isNull, reason: '`ltd` is not in the search');
  });

  test('a term is complete only when every page up to its last landed '
      'in order', () {
    record('acme', hasMore: true);
    record('acme', page: 3, hasMore: false);
    expect(answer('acme corp', wireTerm: 'acme', page: 4), isNull);
    record('acme', page: 2, hasMore: false);
    expect(answer('acme corp', wireTerm: 'acme', page: 4), isFalse);
  });

  test('only a word that goes on the wire carries a cover', () {
    // The local search matches more fields than the server (an invoice's
    // notes), so an invoice with `March` only in its notes was never in the
    // server's `march` answer, yet `hosting` on the wire would fetch it.
    record('march', hasMore: false);
    expect(answer('march hosting', wireTerm: 'hosting'), isNull);
    expect(answer('hosting march', wireTerm: 'march'), isFalse);
    // A phrase on the wire holds every one of its words in one column.
    expect(answer('march hosting', wireTerm: 'march hosting'), isFalse);
  });

  test('a fetched page answers its own hasMore; an unfetched one asks', () {
    record('samsung', hasMore: true);
    expect(answer('samsung galaxy', wireTerm: 'samsung'), isTrue);
    expect(answer('samsung galaxy', wireTerm: 'samsung', page: 2), isNull);
  });

  test('a new page 1 starts the term over', () {
    record('acme', hasMore: true);
    record('acme', page: 2, hasMore: true);
    record('acme', hasMore: true);
    expect(answer('acme', page: 2), isNull);
  });

  test('answers expire after the TTL', () {
    record('sams', hasMore: false);
    now = now.add(kSearchFetchMemoTtl - const Duration(seconds: 1));
    expect(answer('samsung', wireTerm: 'samsung'), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(answer('samsung', wireTerm: 'samsung'), isNull);
    expect(answer('sams'), isNull);
  });

  test('scopes and generations are kept apart', () {
    record('sams', hasMore: false);
    expect(answer('samsung', scope: 'other'), isNull);
    expect(answer('samsung', generation: 1), isNull);
    expect(
      answer('samsung'),
      isNull,
      reason: 'the generation change forgot everything',
    );
  });

  test('a page recorded under an older generation is dropped, and keeps '
      'what was recorded since', () {
    expect(answer('acme', generation: 1), isNull);
    record('beta', hasMore: false, generation: 1);
    record('acme', hasMore: false, generation: 0);
    expect(answer('acme', generation: 1), isNull);
    expect(answer('beta', generation: 1), isFalse);
  });

  test('keeps at most kSearchFetchMemoMaxTerms terms, oldest out first', () {
    for (var i = 0; i <= kSearchFetchMemoMaxTerms; i++) {
      now = now.add(const Duration(milliseconds: 1));
      record('t$i', hasMore: true);
    }
    expect(answer('t0'), isNull);
    expect(answer('t1'), isTrue);
    expect(answer('t$kSearchFetchMemoMaxTerms'), isTrue);
  });
}
