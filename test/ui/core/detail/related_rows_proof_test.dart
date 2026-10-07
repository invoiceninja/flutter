import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/related_rows_proof.dart';
import 'package:admin/ui/core/detail/related_tab_counts.dart';

/// `RelatedRowsProof` hands a record's related rows over only when they are
/// all of them. The fetch-and-latch rules are exercised end to end through
/// its first user (`vendor_spend_view_model_test.dart`); this file pins what
/// the class adds for a second one — the difference between [rows] and
/// [held], and that "held" is counted by the caller's notion of an id.

class _Counts extends ChangeNotifier implements TabCounts {
  int? value;

  @override
  int? countFor(String tabId) => tabId == 'tasks' ? value : null;

  void set(int? v) {
    value = v;
    notifyListeners();
  }
}

class _World {
  static const int pageSize = 2;

  final counts = _Counts();
  final _local = <String>[];
  final _controllers = <String, StreamController<List<String>>>{};
  List<String> serverRows = const [];
  final fetched = <(String, int)>[];
  bool offline = false;

  late final RelatedRowsProof<String> proof = RelatedRowsProof<String>(
    watch: (parentId) {
      final c = _controllers[parentId] = StreamController<List<String>>();
      c.add(List.of(_local));
      return c.stream;
    },
    fetchPage: (parentId, page) async {
      fetched.add((parentId, page));
      if (offline) throw StateError('offline');
      final rows = serverRows.skip((page - 1) * pageSize).take(pageSize);
      for (final r in rows) {
        if (!_local.contains(r)) _local.add(r);
      }
      _controllers[parentId]?.add(List.of(_local));
      return rows.length >= pageSize;
    },
    // A row is its own id here.
    idOf: (row) => row,
    pageSize: pageSize,
    counts: counts,
    countTabId: 'tasks',
    isCurrent: () => true,
    maxPages: 3,
    debounce: const Duration(milliseconds: 10),
  );

  void seed(List<String> rows) => _local.addAll(rows);

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  void dispose() {
    proof.dispose();
    counts.dispose();
    for (final c in _controllers.values) {
      unawaited(c.close());
    }
  }
}

void main() {
  late _World w;
  setUp(() => w = _World());
  tearDown(() => w.dispose());

  test('before the local read comes back there is nothing to hand over', () {
    w.proof.attach('p1');
    expect(w.proof.rows, isNull);
    expect(w.proof.held, isNull);
  });

  test('with no count, what is held is handed over — and nothing is asked '
      'for', () async {
    w.seed(['a', 'b']);
    w.proof.attach('p1');
    await w.settle();
    expect(w.proof.rows, ['a', 'b']);
    expect(w.proof.held, ['a', 'b']);
    expect(w.fetched, isEmpty);
  });

  test('known short: rows are withheld, held is still there, and the missing '
      'pages are fetched', () async {
    w
      ..seed(['a'])
      ..serverRows = ['a', 'b', 'c'];
    w.proof.attach('p1');
    await Future<void>.delayed(Duration.zero);
    w.counts.set(3);
    expect(w.proof.isKnownShort, isTrue);
    expect(w.proof.rows, isNull, reason: 'a sum of these would be wrong');
    expect(w.proof.held, ['a'], reason: 'but they are real rows');

    await w.settle();
    expect(w.fetched, [('p1', 1), ('p1', 2)]);
    expect(w.proof.isKnownShort, isFalse);
    expect(w.proof.rows, ['a', 'b', 'c']);
  });

  test(
    'a row the server has never seen does not count toward its total',
    () async {
      // Two held, but one was created offline: the server's "2" is two others.
      w
        ..seed(['a', 'tmp_1'])
        ..serverRows = ['a', 'b'];
      w.proof.attach('p1');
      await Future<void>.delayed(Duration.zero);
      w.counts.set(2);
      expect(w.proof.isKnownShort, isTrue);
      await w.settle();
      expect(w.proof.rows, containsAll(<String>['a', 'b', 'tmp_1']));
    },
  );

  test('a record that is not on the server asks for nothing', () async {
    w.seed(['tmp_9']);
    w.proof.attach('tmp_parent');
    await Future<void>.delayed(Duration.zero);
    w.counts.set(5);
    await w.settle();
    expect(w.fetched, isEmpty);
  });

  test(
    'offline the rows stay withheld, and are asked for again when back',
    () async {
      w
        ..seed(['a'])
        ..serverRows = ['a', 'b']
        ..offline = true;
      w.proof.attach('p1');
      await Future<void>.delayed(Duration.zero);
      w.counts.set(2);
      await w.settle();
      expect(w.proof.rows, isNull);

      w.offline = false;
      w.proof.retryIfUnanswered();
      await w.settle();
      expect(w.proof.rows, ['a', 'b']);
    },
  );

  test('more than it will fetch for: withheld, and no request made', () async {
    w.seed(['a']);
    w.proof.attach('p1');
    await Future<void>.delayed(Duration.zero);
    // Three pages of two is the cap; this is four.
    w.counts.set(7);
    await w.settle();
    expect(w.fetched, isEmpty);
    expect(w.proof.rows, isNull);
    expect(w.proof.held, ['a']);
  });

  test('a new parent starts again from nothing', () async {
    w.seed(['a', 'b']);
    w.proof.attach('p1');
    await w.settle();
    expect(w.proof.rows, isNotNull);
    w.proof.attach('p2');
    expect(w.proof.rows, isNull, reason: 'the old parent\'s rows are gone');
    await w.settle();
    expect(w.proof.rows, ['a', 'b']);
  });
}
