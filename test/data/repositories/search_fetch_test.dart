import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/search_fetch.dart';

typedef Call = ({String term, bool phrase});

void main() {
  /// [hasMore] is what every fetch answers, unless [hasMoreFor] names the
  /// call (`'<term>|<phrase>'`).
  Future<List<Call>> run(
    String search, {
    required bool serverSplits,
    bool hasMore = true,
    Map<String, bool> hasMoreFor = const {},
  }) async {
    final asked = <Call>[];
    await ensureSearchLoaded(
      search,
      serverSplits: serverSplits,
      fetchPage1: (t, {phrase = false}) async {
        asked.add((term: t, phrase: phrase));
        return hasMoreFor['$t|$phrase'] ?? hasMore;
      },
    );
    return asked;
  }

  test(
    'a phrase-matching server gets the phrase and the selective words',
    () async {
      final asked = await run('galaxy s22 oled screen', serverSplits: false);
      // The phrase lands a record whose name is the text (no duplicate Create);
      // the words land the rest, the model number first. The first word is
      // asked as the whole text: the repository sends `s22` on the wire, and
      // checks its memo against every word.
      expect(asked, [
        (term: 'galaxy s22 oled screen', phrase: true),
        (term: 'galaxy s22 oled screen', phrase: false),
        (term: 'galaxy', phrase: false),
      ]);
      expect(asked, hasLength(1 + kSearchFetchWords));
    },
  );

  test('the second word is not asked when the first one\'s page 1 was its '
      'last — every row the search can match is already local', () async {
    final asked = await run(
      'galaxy s22 oled screen',
      serverSplits: false,
      hasMoreFor: {'galaxy s22 oled screen|false': false},
    );
    expect(asked, [
      (term: 'galaxy s22 oled screen', phrase: true),
      (term: 'galaxy s22 oled screen', phrase: false),
    ]);
  });

  test('the phrase being complete does not skip the words: it misses the '
      'words in another order', () async {
    final asked = await run(
      'galaxy s22',
      serverSplits: false,
      hasMoreFor: {'galaxy s22|true': false},
    );
    expect(asked, hasLength(3));
  });

  test(
    'a server that splits words is asked once, with the whole text',
    () async {
      expect(await run('hans müller', serverSplits: true), [
        (term: 'hans müller', phrase: true),
      ]);
    },
  );

  test('one word is one fetch; a blank search is none', () async {
    expect(await run(' acme ', serverSplits: false), [
      (term: 'acme', phrase: true),
    ]);
    expect(await run('  ', serverSplits: false), isEmpty);
  });

  test('a failed fetch fails the call, as a single fetch would', () async {
    await expectLater(
      ensureSearchLoaded(
        's22 120hz',
        serverSplits: false,
        fetchPage1: (t, {phrase = false}) async => throw Exception('offline'),
      ),
      throwsException,
    );
  });
}
