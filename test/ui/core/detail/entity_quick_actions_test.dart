import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';

import '../../../_responsive_helper.dart';

/// The quick-action strip is a second *render* of actions a record already
/// has. These pin which ones it shows and that it gets out of the way when
/// there are none.

EntityActionItem<String> _item(
  String kind, {
  bool enabled = true,
  VoidCallback? onTap,
  List<EntityActionItem<String>>? children,
}) => EntityActionItem<String>(
  kind: kind,
  icon: Icons.bolt,
  label: 'Full $kind',
  enabled: enabled,
  onTap: onTap ?? () {},
  children: children,
);

EntityQuickAction<String> _quick(
  String kind, {
  bool applies = true,
  bool enabled = true,
  VoidCallback? onTap,
  ValueNotifier<bool>? busy,
}) => EntityQuickAction<String>(
  item: _item(kind, enabled: enabled, onTap: onTap),
  shortLabel: kind,
  applies: applies,
  busy: busy,
);

void main() {
  group('pickQuickActions', () {
    test('takes the first that apply, in the host\'s order', () {
      final picked = pickQuickActions<String>([
        _quick('a'),
        _quick('b', applies: false),
        _quick('c', enabled: false),
        _quick('d'),
        _quick('e'),
      ], max: 2);
      // `b` does not apply to this record and `c` cannot run at all; each
      // yields its slot to the next rather than leaving a hole.
      expect([for (final q in picked) q.shortLabel], ['a', 'd']);
    });
  });

  group('findActionItem', () {
    test('finds a leaf inside a group\'s fly-out', () {
      final items = [
        _item('edit'),
        _item('new', children: [_item('invoice'), _item('quote')]),
      ];
      expect(findActionItem<String>(items, 'quote')?.label, 'Full quote');
      expect(findActionItem<String>(items, 'missing'), isNull);
      // The group itself is not an action.
      expect(findActionItem<String>(items, 'new'), isNull);
    });
  });

  group('EntityQuickActions', () {
    testWidgets('four tiles in a pane, six where there is room', (
      tester,
    ) async {
      final all = [for (final k in 'abcdefg'.split('')) _quick(k)];
      await pumpAt(tester, 440, EntityQuickActions<String>(priority: all));
      expect(find.byIcon(Icons.bolt), findsNWidgets(4));
      await pumpAt(tester, 700, EntityQuickActions<String>(priority: all));
      expect(find.byIcon(Icons.bolt), findsNWidgets(6));
    });

    testWidgets('builds nothing, and takes no height, with nothing to show', (
      tester,
    ) async {
      await pumpAt(
        tester,
        440,
        EntityQuickActions<String>(priority: [_quick('a', applies: false)]),
      );
      expect(tester.getSize(find.byType(EntityQuickActions<String>)).height, 0);
    });

    testWidgets('tiles are the same height and clear the touch floor', (
      tester,
    ) async {
      await pumpAt(
        tester,
        390,
        EntityQuickActions<String>(
          priority: [
            _quick('a'),
            // A label far too long for its tile: it scales down instead of
            // wrapping, so it cannot make this tile taller than the others.
            _quick('Klantenportaal en nog veel meer'),
          ],
        ),
      );
      final heights = tester
          .widgetList<InkWell>(find.byType(InkWell))
          .map((w) => tester.getSize(find.byWidget(w)).height)
          .toSet();
      expect(heights, hasLength(1));
      expect(heights.single, greaterThanOrEqualTo(44));
      expectNoOverflow(tester);
    });

    testWidgets('a tap runs the action', (tester) async {
      var taps = 0;
      await pumpAt(
        tester,
        440,
        EntityQuickActions<String>(
          priority: [_quick('a', onTap: () => taps++)],
        ),
      );
      await tester.tap(find.text('a'));
      expect(taps, 1);
    });

    testWidgets('announces the full label, not the short one', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAt(
        tester,
        440,
        EntityQuickActions<String>(priority: [_quick('a')]),
      );
      expect(
        tester.getSemantics(find.text('a')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          label: 'Full a',
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a busy tile stays in place and does nothing', (tester) async {
      final busy = ValueNotifier<bool>(true);
      addTearDown(busy.dispose);
      var taps = 0;
      await pumpAt(
        tester,
        440,
        EntityQuickActions<String>(
          priority: [_quick('a', onTap: () => taps++, busy: busy)],
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('a'));
      expect(taps, 0);
      busy.value = false;
      await tester.pump();
      await tester.tap(find.text('a'));
      expect(taps, 1);
    });
  });
}
