import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/standing_card.dart';

import '../../../_responsive_helper.dart';

/// `EntityRecordColumn` puts a record's slots in one order at every width;
/// only the header band rearranges.

Widget _box(String label, {double height = 60}) =>
    SizedBox(height: height, child: Text(label));

Widget _column({
  Widget? quickActions,
  Widget? comments,
  Widget? standing,
  bool withProfile = true,
}) => EntityRecordColumn(
  header: _box('header'),
  quickActions: quickActions,
  standing: standing ?? _box('standing'),
  comments: comments,
  profile: withProfile ? _box('profile') : null,
);

double _top(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label)).dy;

void main() {
  testWidgets('narrow: one stack, in the order every entity uses', (
    tester,
  ) async {
    await pumpAt(
      tester,
      500,
      _column(quickActions: _box('actions'), comments: _box('comments')),
    );
    final order = ['header', 'actions', 'standing', 'comments', 'profile'];
    for (var i = 1; i < order.length; i++) {
      expect(
        _top(tester, order[i]),
        greaterThan(_top(tester, order[i - 1])),
        reason: '${order[i]} is below ${order[i - 1]}',
      );
    }
  });

  testWidgets('wide: standing sits beside the header, the rest stays below', (
    tester,
  ) async {
    await pumpAt(tester, 1200, _column(quickActions: _box('actions')));
    expect(_top(tester, 'standing'), _top(tester, 'header'));
    expect(
      tester.getTopLeft(find.text('standing')).dx,
      greaterThan(tester.getTopLeft(find.text('header')).dx),
    );
    expect(_top(tester, 'actions'), greaterThan(_top(tester, 'header')));
    expect(_top(tester, 'profile'), greaterThan(_top(tester, 'standing')));
  });

  testWidgets('narrow: the stack is capped and centred on a wide-ish pane', (
    tester,
  ) async {
    // 900 px is under the two-column breakpoint but over the form cap, so the
    // column must centre rather than run edge to edge.
    await pumpAt(tester, 900, _column());
    expect(tester.getTopLeft(find.text('header')).dx, greaterThan(0));
  });

  testWidgets('the profile is always there — nothing to open', (tester) async {
    for (final width in [500.0, 1200.0]) {
      await pumpAt(tester, width, _column());
      expect(find.text('profile'), findsOneWidget, reason: '$width');
    }
  });

  testWidgets('a self-hiding slot leaves no gap of its own', (tester) async {
    // Quick actions and comments both own their trailing gap, because either
    // can empty itself after layout. So a slot that builds nothing must cost
    // exactly nothing — measured against the same column without the slot.
    await pumpAt(tester, 500, _column());
    final without = _top(tester, 'profile');
    await pumpAt(
      tester,
      500,
      _column(
        quickActions: const SizedBox.shrink(),
        comments: const SizedBox.shrink(),
      ),
    );
    expect(_top(tester, 'profile'), without);
  });

  group('wide: the two sides of the band end on one line', () {
    // The band was a top-aligned row, so the shorter side stopped short: the
    // Balance card ended 26 px above the tiles beside it on a client with no
    // credit, and the tiles ended above the card on one with a past-due line.
    // Each side is a coloured box here so its *own* bottom edge is measured,
    // not its label's.
    Widget side(String label, {required double height}) => Container(
      key: ValueKey(label),
      // A floor, not a size: the band must be able to make it taller.
      constraints: BoxConstraints(minHeight: height),
      color: const Color(0xFFEEEEEE),
      child: Text(label),
    );

    Future<({double actions, double standing, double profile})> measure(
      WidgetTester tester, {
      required double actions,
      required double standing,
      TextDirection direction = TextDirection.ltr,
    }) async {
      await pumpAt(
        tester,
        1200,
        Directionality(
          textDirection: direction,
          child: EntityRecordColumn(
            header: _box('header'),
            // Stands in for the real strip, which owns a trailing gap.
            quickActions: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: side('actions', height: actions),
            ),
            standing: side('standing', height: standing),
            profile: _box('profile'),
          ),
        ),
      );
      return (
        actions: tester.getBottomLeft(find.byKey(const ValueKey('actions'))).dy,
        standing: tester
            .getBottomLeft(find.byKey(const ValueKey('standing')))
            .dy,
        profile: _top(tester, 'profile'),
      );
    }

    testWidgets('the standing card stretches down to the tiles', (
      tester,
    ) async {
      final m = await measure(tester, actions: 56, standing: 60);
      expect(m.standing, m.actions);
    });

    testWidgets('the tiles drop to the foot of a taller standing card', (
      tester,
    ) async {
      final m = await measure(tester, actions: 56, standing: 320);
      expect(m.actions, m.standing);
      // …and the header has not moved to make that happen.
      expect(_top(tester, 'header'), _top(tester, 'standing'));
    });

    testWidgets('the gap under the band is the same either way', (
      tester,
    ) async {
      final short = await measure(tester, actions: 56, standing: 60);
      final tall = await measure(tester, actions: 56, standing: 320);
      expect(short.profile - short.actions, tall.profile - tall.actions);
    });

    testWidgets('right to left, the sides swap and still end level', (
      tester,
    ) async {
      final m = await measure(
        tester,
        actions: 56,
        standing: 320,
        direction: TextDirection.rtl,
      );
      expect(m.actions, m.standing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('standing'))).dx,
        lessThan(tester.getTopLeft(find.text('header')).dx),
      );
    });

    testWidgets('a side that grows after the first frame is still level, '
        'and does not overflow', (tester) async {
      // The past-due line lands after the card has been laid out, and makes
      // it taller. Stretched with a *fixed* height the shorter side became a
      // relayout boundary: it re-laid itself out inside the old height,
      // overflowed by the difference, and the band never heard about it.
      final extra = ValueNotifier<double>(0);
      addTearDown(extra.dispose);
      await pumpAt(
        tester,
        1200,
        EntityRecordColumn(
          header: _box('header'),
          quickActions: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: side('actions', height: 56),
          ),
          // Shorter than the other side to begin with, so it is the one the
          // band stretches.
          standing: Container(
            key: const ValueKey('standing'),
            color: const Color(0xFFEEEEEE),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40, child: Text('standing')),
                ValueListenableBuilder<double>(
                  valueListenable: extra,
                  builder: (_, height, _) => SizedBox(height: height),
                ),
              ],
            ),
          ),
          profile: _box('profile'),
        ),
      );
      double bottom(String key) =>
          tester.getBottomLeft(find.byKey(ValueKey(key))).dy;
      expect(bottom('standing'), bottom('actions'));

      // Now taller than the other side ever was.
      extra.value = 300;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(bottom('actions'), bottom('standing'));
      expect(_top(tester, 'profile'), greaterThan(bottom('standing')));

      // …and back.
      extra.value = 0;
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(bottom('standing'), bottom('actions'));
    });

    testWidgets('with the real tiles and the real card', (tester) async {
      // Both contain a `LayoutBuilder`, which is why the band is a render
      // object and not `IntrinsicHeight`: this is the case that would throw.
      EntityQuickAction<String> tile(String label) => EntityQuickAction(
        shortLabel: label,
        item: EntityActionItem<String>(
          kind: label,
          icon: Icons.add,
          label: label,
          enabled: true,
          onTap: () {},
        ),
      );
      await pumpAt(
        tester,
        1400,
        EntityRecordColumn(
          header: _box('header'),
          quickActions: EntityQuickActions<String>(
            priority: [tile('Invoice'), tile('Payment'), tile('Email')],
          ),
          standing: const StandingCard(
            primary: [
              StandingFigure(label: 'Balance', value: r'$10.00'),
              StandingFigure(label: 'Paid to Date', value: r'$0.00'),
            ],
          ),
          profile: _box('profile'),
        ),
      );
      expect(tester.takeException(), isNull);
      final tiles = tester.getRect(
        find.byType(EntityQuickActions<String>).first,
      );
      final card = tester.getRect(find.byType(StandingCard));
      // The strip's own rect includes its trailing gap; the card's does not —
      // so "level" is the last tile's bottom edge against the card's.
      final tileBottom = tester.getRect(find.byType(InkWell).first).bottom;
      expect(card.bottom, moreOrLessEquals(tileBottom, epsilon: 0.5));
      expect(card.top, lessThan(tiles.top), reason: 'beside the header');

      // The figures sit in the middle of the stretched card, not above a
      // blank strip: as much room over the caption as under the amount.
      expect(card.height, greaterThan(90), reason: 'it was stretched');
      final above = tester.getRect(find.text('BALANCE')).top - card.top;
      final below = card.bottom - tester.getRect(find.text(r'$10.00')).bottom;
      expect(above, moreOrLessEquals(below, epsilon: 2));
    });
  });
}
