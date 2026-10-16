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

    test('activate runs the claimant\'s onActivate in place of focusing', () {
      // The settings search field isn't mounted until the search opens, and
      // focusing a detached node does nothing — so its claim opens it.
      final registry = SearchFocusRegistry();
      final list = FocusNode();
      final settings = FocusNode();
      addTearDown(list.dispose);
      addTearDown(settings.dispose);
      var opened = 0;

      registry.current = list;
      registry.claim(settings, onActivate: () => opened++);
      registry.activate();
      expect(opened, 1);

      // Released, the slot is the list's again — and a plain claim focuses.
      registry.release(settings);
      expect(registry.current, same(list));
      registry.activate();
      expect(opened, 1);

      // A plain re-claim drops a stale onActivate.
      registry.claim(settings, onActivate: () => opened++);
      registry.claim(settings);
      registry.activate();
      expect(opened, 1);
    });

    test('a fallback claim never outranks a regular one', () {
      // The wide settings pane and a list beside it (Payment Links) both
      // re-claim when the branch returns, in no fixed order; `/` must still
      // reach the list.
      final registry = SearchFocusRegistry();
      final settings = FocusNode();
      final list = FocusNode();
      addTearDown(settings.dispose);
      addTearDown(list.dispose);

      registry.current = list;
      registry.claim(settings, fallback: true);
      expect(
        registry.current,
        same(list),
        reason: 'claimed later, still below',
      );

      registry.release(list);
      expect(registry.current, same(settings));

      registry.current = list;
      expect(registry.current, same(list));

      // Moving between tiers leaves no stale copy behind.
      registry.claim(list, fallback: true);
      registry.release(list);
      expect(registry.current, same(settings));
      registry.release(settings);
      expect(registry.current, isNull);
    });

    test('activate with nothing claimed is a no-op', () {
      SearchFocusRegistry().activate();
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
