import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/shell/widgets/cached_stream.dart';

/// The sidebar's count streams are `distinct`, so a badge's source can go a
/// whole session without emitting again. A `StreamBuilder` created after the
/// last emission — the rail collapsing, a row moving in the menu — has only
/// this cache's replay to get a value from. `InSidebar` itself cannot be
/// widget-tested over real Drift streams, so the replay is pinned here.
void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a listener that arrives late is handed the latest value', () async {
    final source = StreamController<int>();
    final cache = CachedStream<int>(source.stream);
    addTearDown(cache.close);

    final early = <int>[];
    cache.stream.listen(early.add);
    source.add(3);
    source.add(7);
    await settle();
    expect(early, [3, 7]);

    // Nothing more is coming from the source. A bare broadcast controller
    // would leave this listener with nothing.
    final late = <int>[];
    cache.stream.listen(late.add);
    await settle();
    expect(late, [7]);

    source.add(9);
    await settle();
    expect(early, [3, 7, 9]);
    expect(late, [7, 9], reason: 'replayed once, then live like any other');
  });

  test('latest seeds a builder before it has subscribed', () async {
    final source = StreamController<int>();
    final cache = CachedStream<int>(source.stream);
    addTearDown(cache.close);

    expect(cache.latest, isNull, reason: 'nothing emitted yet');
    source.add(4);
    await settle();
    expect(cache.latest, 4);
  });

  test('a null value is a value, and is replayed', () async {
    final source = StreamController<String?>();
    final cache = CachedStream<String?>(source.stream);
    addTearDown(cache.close);
    source.add('view');
    source.add(null);
    await settle();

    final seen = <String?>[];
    cache.stream.listen(seen.add);
    await settle();
    expect(seen, [null]);
  });

  test('nothing is replayed before the source has emitted', () async {
    final source = StreamController<int>();
    final cache = CachedStream<int>(source.stream);
    addTearDown(cache.close);

    final seen = <int>[];
    cache.stream.listen(seen.add);
    await settle();
    expect(seen, isEmpty);
  });

  test('stream is one object, so a StreamBuilder does not re-subscribe', () {
    final cache = CachedStream<int>(const Stream.empty());
    addTearDown(cache.close);
    expect(cache.stream, same(cache.stream));
  });

  test('the source is listened to once, whatever the listener count', () async {
    var listens = 0;
    final source = StreamController<int>(onListen: () => listens++);
    final cache = CachedStream<int>(source.stream);
    addTearDown(cache.close);

    final a = cache.stream.listen((_) {});
    final b = cache.stream.listen((_) {});
    await a.cancel();
    await b.cancel();
    cache.stream.listen((_) {});
    await settle();
    expect(listens, 1, reason: 'a second listen would be a second Drift query');
  });

  test('close cancels the source and ends every listener', () async {
    var cancelled = false;
    final source = StreamController<int>(onCancel: () => cancelled = true);
    final cache = CachedStream<int>(source.stream);

    var done = false;
    cache.stream.listen((_) {}, onDone: () => done = true);
    await settle();

    cache.close();
    await settle();
    expect(cancelled, isTrue);
    expect(done, isTrue);
  });
}
