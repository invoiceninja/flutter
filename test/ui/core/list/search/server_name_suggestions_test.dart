import 'dart:async';

import 'package:admin/ui/core/list/search/server_name_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

/// `namesWithServerSearch` — the value list behind `client:` / `vendor:` /
/// `project:`. The cache answers first; the server is asked only when the
/// cache has nothing, and the empty answer waits for it.
void main() {
  const acme = (id: 'c1', name: 'Acme Ltd');
  const beta = (id: 'c2', name: 'Beta GmbH');
  const zed = (id: 'c9', name: 'Zed Corp');

  /// A names stream backed by a controller, so a test can push the rows a
  /// fetch would have written to the cache.
  late StreamController<List<NameRow>> names;
  late List<String> fetched;

  setUp(() {
    names = StreamController<List<NameRow>>.broadcast();
    fetched = [];
  });
  tearDown(() => names.close());

  Stream<List<NameRow>> namesFrom(List<NameRow> initial) async* {
    yield initial;
    yield* names.stream;
  }

  test('an empty query is the names stream untouched', () async {
    final rows = await namesWithServerSearch(
      names: Stream.value(const [acme, beta]),
      query: '  ',
      fetch: (_) async => fetched.add('x'),
      searchedIds: (_) => const Stream.empty(),
    ).first;
    expect(rows, const [acme, beta]);
    expect(fetched, isEmpty);
  });

  test('a cached match answers at once, and the server\'s hits join it — '
      'one cached "Acme" must not hide another', () async {
    const acmeCorp = (id: 'c7', name: 'Acme Corp');
    final emissions = <List<NameRow>>[];
    final sub = namesWithServerSearch(
      names: namesFrom(const [acme, beta]),
      query: 'ACM',
      fetch: (q) async {
        fetched.add(q);
        // Only on the server until the fetch writes it to the cache.
        names.add(const [acme, acmeCorp, beta]);
      },
      searchedIds: (_) => Stream.value(const ['c1', 'c7']),
      debounce: Duration.zero,
    ).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(emissions.first, const [acme], reason: 'no wait for the network');
    expect(fetched, ['ACM']);
    expect(emissions.last, const [acme, acmeCorp]);
  });

  test('no cached match: the empty answer waits for the server, and the '
      'server hit is shown', () async {
    final emissions = <List<NameRow>>[];
    final sub = namesWithServerSearch(
      names: namesFrom(const [acme, beta]),
      query: 'zed',
      fetch: (q) async {
        fetched.add(q);
        // The fetch writes the hit to the cache.
        names.add(const [acme, beta, zed]);
      },
      searchedIds: (_) => Stream.value(const ['c9']),
      debounce: Duration.zero,
    ).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(fetched, ['zed']);
    expect(emissions.first, const [
      zed,
    ], reason: 'no [] may be emitted before the server answers');
  });

  test('a server hit matched on another field (a contact email) is shown '
      'though its name does not contain the query', () async {
    final emissions = <List<NameRow>>[];
    final sub = namesWithServerSearch(
      names: namesFrom(const [acme, beta]),
      query: 'jane@zed.example',
      fetch: (_) async => names.add(const [acme, beta, zed]),
      searchedIds: (_) => Stream.value(const ['c9']),
      debounce: Duration.zero,
    ).listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(emissions.last, const [zed]);
  });

  test('a failed fetch (offline) ends in no values', () async {
    final rows = await namesWithServerSearch(
      names: Stream.value(const [acme, beta]),
      query: 'zed',
      fetch: (_) async => throw StateError('offline'),
      searchedIds: (_) => Stream.value(const <String>[]),
      debounce: Duration.zero,
    ).first;
    expect(rows, isEmpty);
  });

  test('cancelling before the debounce fires sends no request — a fast '
      'typist fetches only the last query', () async {
    final sub = namesWithServerSearch(
      names: Stream.value(const [acme]),
      query: 'z',
      fetch: (q) async => fetched.add(q),
      searchedIds: (_) => const Stream.empty(),
      debounce: const Duration(milliseconds: 40),
    ).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await sub.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fetched, isEmpty);
  });
}
