import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/activity_window.dart';

Map<String, Object?> _row(int id, int createdAt) => {
  'id': '$id',
  'created_at': createdAt,
};

List<String> _ids(List<Object?> rows) => [
  for (final r in rows) (r! as Map)['id'] as String,
];

void main() {
  test('a refresh that overlaps the window keeps the older rows', () {
    // Window held: ids 10..1 (createdAt 1000..100). The card refreshes the
    // newest three, two of them new.
    final cached = [for (var i = 10; i >= 1; i--) _row(i, i * 100)];
    final fetched = [_row(12, 1200), _row(11, 1100), _row(10, 1000)];

    final merged = mergeActivityWindow(fetched: fetched, cached: cached);
    expect(_ids(merged), [
      '12', '11', '10', '9', '8', '7', '6', '5', '4', '3', '2', '1', //
    ]);
  });

  test('a refresh that leaves a gap replaces the window', () {
    // Activity happened between the two windows that neither holds; keeping
    // the old rows would draw a quiet stretch that wasn't.
    final cached = [_row(2, 200), _row(1, 100)];
    final fetched = [_row(9, 900), _row(8, 800)];

    expect(_ids(mergeActivityWindow(fetched: fetched, cached: cached)), [
      '9',
      '8',
    ]);
  });

  test('a cached row inside the fetched span that the fetch dropped goes', () {
    final cached = [_row(3, 300), _row(2, 200), _row(1, 100)];
    // Row 2 is gone server-side; the fetch reaches back to 100.
    final fetched = [_row(3, 300), _row(1, 100)];

    expect(_ids(mergeActivityWindow(fetched: fetched, cached: cached)), [
      '3',
      '1',
    ]);
  });

  test('rows sharing the fetch\'s oldest second are carried, not lost', () {
    // The fetch cut through a second: row 4 shares 300 with row 5 but missed
    // the window.
    final cached = [_row(5, 300), _row(4, 300), _row(3, 200)];
    final fetched = [_row(6, 400), _row(5, 300)];

    expect(_ids(mergeActivityWindow(fetched: fetched, cached: cached)), [
      '6',
      '5',
      '4',
      '3',
    ]);
  });

  test('the window is trimmed to the cap, oldest first', () {
    final cached = [for (var i = 5; i >= 1; i--) _row(i, i * 100)];
    final fetched = [_row(6, 600), _row(5, 500)];

    expect(
      _ids(mergeActivityWindow(fetched: fetched, cached: cached, cap: 3)),
      ['6', '5', '4'],
    );
  });

  test('nothing cached, or nothing fetched, is a plain replace', () {
    final fetched = [_row(1, 100)];
    expect(_ids(mergeActivityWindow(fetched: fetched, cached: null)), ['1']);
    expect(mergeActivityWindow(fetched: const [], cached: fetched), isEmpty);
  });

  test('a created_at sent as a string still orders', () {
    final merged = mergeActivityWindow(
      fetched: [
        {'id': '1', 'created_at': '100'},
        {'id': '2', 'created_at': '200'},
      ],
      cached: null,
    );
    expect(_ids(merged), ['2', '1']);
  });

  group('paging back with the cursor', () {
    test('the cursor row is the oldest held', () {
      final rows = [_row(3, 300), _row(1, 100), _row(2, 200)];
      expect((oldestActivityRow(rows)! as Map)['id'], '1');
      expect(oldestActivityRow(const []), isNull);
    });

    test(
      'a page whose rows are no newer than the cursor second honoured it',
      () {
        final boundary = _row(5, 500);
        // Same second as the boundary is allowed: the server splits a second
        // by microseconds the payload doesn't carry.
        expect(
          pageHonouredCursor([_row(4, 500), _row(3, 400)], boundary),
          isTrue,
        );
        expect(pageHonouredCursor(const [], boundary), isTrue);
      },
    );

    test('a page carrying newer rows is a server that ignored the cursor', () {
      // An older server answers `before=` with the newest rows.
      expect(
        pageHonouredCursor([_row(9, 900), _row(8, 800)], _row(5, 500)),
        isFalse,
      );
    });

    test('an older page is appended, skipping rows already held', () {
      final cached = [_row(6, 600), _row(5, 500)];
      final older = [_row(5, 500), _row(4, 400), _row(3, 300)];

      expect(_ids(appendOlderActivities(cached: cached, older: older)), [
        '6',
        '5',
        '4',
        '3',
      ]);
    });

    test('appending trims to the cap, dropping the oldest', () {
      final cached = [_row(6, 600), _row(5, 500)];
      final older = [_row(4, 400), _row(3, 300)];

      expect(
        _ids(appendOlderActivities(cached: cached, older: older, cap: 3)),
        ['6', '5', '4'],
      );
    });
  });
}
