import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/list/master_detail_nav_scope.dart';

void main() {
  group('itemById', () {
    test('returns the object index-aligned with itemIds', () {
      final c = MasterDetailNavController()
        ..update(
          selectedId: 'b',
          itemIds: ['a', 'b', 'c'],
          items: ['A', 'B', 'C'],
        );

      expect(c.itemById('a'), 'A');
      expect(c.itemById('b'), 'B');
      expect(c.itemById('c'), 'C');
    });

    test('returns null for a row the list never rendered', () {
      final c = MasterDetailNavController()
        ..update(selectedId: null, itemIds: ['a'], items: ['A']);

      expect(c.itemById('zz'), isNull);
    });

    test('returns null rather than throwing when items is shorter than '
        'itemIds', () {
      // Belt-and-braces: the two are built from one pass with one predicate,
      // but a range error here would crash a detail screen on open.
      final c = MasterDetailNavController()
        ..update(selectedId: null, itemIds: ['a', 'b'], items: ['A']);

      expect(c.itemById('a'), 'A');
      expect(c.itemById('b'), isNull);
    });

    test('a caller that omits items (J/K only) still works', () {
      final c = MasterDetailNavController()
        ..update(selectedId: 'a', itemIds: ['a', 'b']);

      expect(c.itemById('a'), isNull);
      expect(c.nextId(), 'b');
    });
  });

  group('nextId / prevId are unchanged by the items snapshot', () {
    MasterDetailNavController seeded(String? selected) =>
        MasterDetailNavController()..update(
          selectedId: selected,
          itemIds: ['a', 'b', 'c'],
          items: ['A', 'B', 'C'],
        );

    test('walks forward and back', () {
      expect(seeded('a').nextId(), 'b');
      expect(seeded('b').prevId(), 'a');
    });

    test('stops at the ends', () {
      expect(seeded('c').nextId(), isNull);
      expect(seeded('a').prevId(), isNull);
    });

    test('with nothing selected, next is the first and prev is the last', () {
      expect(seeded(null).nextId(), 'a');
      expect(seeded(null).prevId(), 'c');
    });

    test('an empty list yields nothing in either direction', () {
      final c = MasterDetailNavController()
        ..update(selectedId: null, itemIds: const [], items: const []);

      expect(c.nextId(), isNull);
      expect(c.prevId(), isNull);
    });
  });

  test('lastTab round-trips (the pane\'s tab memory)', () {
    final c = MasterDetailNavController();
    expect(c.lastTab, isNull);
    c.lastTab = (index: 3, count: 6);
    expect(c.lastTab?.index, 3);
    expect(c.lastTab?.count, 6);
  });
}
