import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/search_focus_registry.dart';

void main() {
  group('SearchFocusRegistry', () {
    test('starts null', () {
      expect(SearchFocusRegistry().current, isNull);
    });

    test('stores and clears the active focus node', () {
      final registry = SearchFocusRegistry();
      final node = FocusNode();
      addTearDown(node.dispose);

      registry.current = node;
      expect(registry.current, same(node));

      registry.current = null;
      expect(registry.current, isNull);
    });

    test('releasing the top claim hands the slot back to the one beneath', () {
      // A record pane's embedded list mounts a second search field over the
      // main list's. As one slot, the pane's field claimed it and nulled it on
      // dispose, and nothing made the main list claim again — so `/` was dead
      // after closing the pane.
      final registry = SearchFocusRegistry();
      final mainList = FocusNode();
      final paneList = FocusNode();
      addTearDown(mainList.dispose);
      addTearDown(paneList.dispose);

      registry.current = mainList;
      registry.current = paneList;
      expect(registry.current, same(paneList));

      registry.release(paneList);
      expect(registry.current, same(mainList));

      registry.release(mainList);
      expect(registry.current, isNull);
    });

    test('re-claiming moves a node to the top without duplicating it', () {
      final registry = SearchFocusRegistry();
      final a = FocusNode();
      final b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      registry.current = a;
      registry.current = b;
      registry.current = a;
      expect(registry.current, same(a));

      registry.release(a);
      expect(registry.current, same(b));
      registry.release(b);
      expect(registry.current, isNull);
    });

    test('releasing a node that holds no claim is a no-op', () {
      final registry = SearchFocusRegistry();
      final a = FocusNode();
      final stranger = FocusNode();
      addTearDown(a.dispose);
      addTearDown(stranger.dispose);

      registry.current = a;
      registry.release(stranger);
      expect(registry.current, same(a));
    });
  });
}
