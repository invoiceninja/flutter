import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/detail_refresh_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_record_page.dart';

import '../../../_responsive_helper.dart';

/// `EntityRecordPage` is the scrolling shell of a summary-first record
/// screen: what sits above the tabs, the strip pinned once it reaches the top,
/// and the active tab's body under it.

/// Counts how many times its `State` is created — a tab body that survives a
/// relayout builds once.
class _Probe extends StatefulWidget {
  const _Probe(this.created);
  final List<int> created;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.created.add(1);
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 3000, child: Text('long body'));
}

Widget _page({
  required List<int> created,
  double topHeight = 300,
  TabSelectionController? select,
  EntityRecordPageController? controller,
}) => EntityDetailTabs(
  selectTab: select,
  onReveal: controller?.revealTabs,
  tabs: [
    EntityDetailTab(
      id: 'a',
      label: 'Tab a',
      icon: Icons.circle_outlined,
      bodyBuilder: (_) => _Probe(created),
    ),
    EntityDetailTab(
      id: 'b',
      label: 'Tab b',
      icon: Icons.circle_outlined,
      bodyBuilder: (_) => const SizedBox(height: 3000, child: Text('Body b')),
    ),
  ],
  layoutBuilder: (context, strip, body) => EntityRecordPage(
    controller: controller,
    tabStrip: strip,
    tabBody: body,
    top: EntityRecordColumn(
      header: SizedBox(height: topHeight, child: const Text('header')),
      standing: const SizedBox(height: 80, child: Text('standing')),
    ),
  ),
);

ScrollPosition _vertical(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byType(Scrollable))
    .map((s) => s.position)
    .firstWhere((p) => p.axis == Axis.vertical);

void main() {
  testWidgets('the strip pins to the top while the body scrolls under it', (
    tester,
  ) async {
    await pumpAt(tester, 500, _page(created: []), height: 800, scroll: false);
    final before = tester.getTopLeft(find.text('Tab a')).dy;
    expect(before, greaterThan(300), reason: 'below the header to begin with');

    _vertical(tester).jumpTo(1500);
    await tester.pump();

    expect(find.text('header').hitTestable(), findsNothing);
    final pinned = tester.getTopLeft(find.text('Tab a')).dy;
    expect(pinned, lessThan(40), reason: 'held at the top of the viewport');
    expect(find.text('Tab a').hitTestable(), findsOneWidget);
  });

  testWidgets('tabs still switch from the pinned strip', (tester) async {
    await pumpAt(tester, 500, _page(created: []), height: 800, scroll: false);
    _vertical(tester).jumpTo(1500);
    await tester.pump();
    await tester.tap(find.text('Tab b'));
    await tester.pumpAndSettle();
    expect(find.text('Body b'), findsOneWidget);
  });

  testWidgets('a tab body keeps its state when the page changes width', (
    tester,
  ) async {
    // The master-detail pane animates through every width between its two
    // sizes when the user toggles full screen, crossing the breakpoint where
    // the column above the tabs rearranges. The tabs must not be re-inflated
    // by that: every embedded list would refetch and lose its place.
    final created = <int>[];
    for (final width in [560.0, 1048.0, 560.0]) {
      await pumpAt(
        tester,
        width,
        _page(created: created),
        height: 800,
        scroll: false,
      );
      await tester.pump();
    }
    expect(created, hasLength(1));
  });

  group('revealTabs', () {
    testWidgets('scrolls the strip up when it is below the fold', (
      tester,
    ) async {
      final select = TabSelectionController();
      final controller = EntityRecordPageController();
      addTearDown(select.dispose);
      await pumpAt(
        tester,
        500,
        _page(
          created: [],
          topHeight: 1200,
          select: select,
          controller: controller,
        ),
        height: 800,
        scroll: false,
      );
      expect(find.text('Tab a').hitTestable(), findsNothing);

      select.selectId('b');
      await tester.pumpAndSettle();

      expect(find.text('Tab b').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(find.text('Tab b')).dy, lessThan(40));
    });

    testWidgets('leaves the page alone when the strip is already in view', (
      tester,
    ) async {
      // Tapping a figure near the top to open its tab must not scroll the
      // figure away from under the pointer.
      final select = TabSelectionController();
      final controller = EntityRecordPageController();
      addTearDown(select.dispose);
      await pumpAt(
        tester,
        500,
        _page(
          created: [],
          topHeight: 120,
          select: select,
          controller: controller,
        ),
        height: 800,
        scroll: false,
      );
      select.selectId('b');
      await tester.pumpAndSettle();
      expect(_vertical(tester).pixels, 0);
    });

    testWidgets('does nothing once the strip is pinned', (tester) async {
      final select = TabSelectionController();
      final controller = EntityRecordPageController();
      addTearDown(select.dispose);
      await pumpAt(
        tester,
        500,
        _page(created: [], select: select, controller: controller),
        height: 800,
        scroll: false,
      );
      _vertical(tester).jumpTo(1500);
      await tester.pump();
      select.selectId('b');
      await tester.pumpAndSettle();
      // A shorter body can clamp the offset, but the page must not be dragged
      // back up to where the strip first pinned.
      expect(_vertical(tester).pixels, greaterThan(1000));
    });
  });

  group('refresh', () {
    Widget page({
      Future<void> Function()? onRefresh,
      required EntityRecordPageController controller,
    }) => EntityDetailTabs(
      tabs: [
        EntityDetailTab(
          id: 'a',
          label: 'Tab a',
          icon: Icons.circle_outlined,
          bodyBuilder: (_) => const SizedBox(height: 40, child: Text('short')),
        ),
      ],
      layoutBuilder: (context, strip, body) => EntityRecordPage(
        controller: controller,
        onRefresh: onRefresh,
        tabStrip: strip,
        tabBody: body,
        top: const SizedBox(height: 60, child: Text('header')),
      ),
    );

    testWidgets('a short record can still be pulled to refresh', (
      tester,
    ) async {
      // The whole page is shorter than the viewport. A scroll view handed a
      // controller is not always-scrollable by default, and then there would
      // be nothing to pull.
      final controller = EntityRecordPageController();
      addTearDown(controller.dispose);
      var refreshes = 0;
      await pumpAt(
        tester,
        500,
        page(controller: controller, onRefresh: () async => refreshes++),
        height: 800,
        scroll: false,
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.fling(find.text('header'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    });

    testWidgets('without a refresh there is no indicator', (tester) async {
      final controller = EntityRecordPageController();
      addTearDown(controller.dispose);
      await pumpAt(
        tester,
        500,
        page(controller: controller),
        height: 800,
        scroll: false,
      );
      expect(find.byType(RefreshIndicator), findsNothing);
    });

    testWidgets('the refresh signal reaches what is embedded in the page', (
      tester,
    ) async {
      // How the lists under the tabs hear about a refresh — the screen holds
      // no handle on their view models.
      final controller = EntityRecordPageController();
      addTearDown(controller.dispose);
      DetailRefreshSignal? seen;
      await pumpAt(
        tester,
        500,
        EntityDetailTabs(
          tabs: [
            EntityDetailTab(
              id: 'a',
              label: 'Tab a',
              icon: Icons.circle_outlined,
              bodyBuilder: (context) {
                seen = DetailRefreshScope.maybeOf(context);
                return const Text('body');
              },
            ),
          ],
          layoutBuilder: (context, strip, body) => EntityRecordPage(
            controller: controller,
            tabStrip: strip,
            tabBody: body,
            top: const Text('header'),
          ),
        ),
        height: 800,
        scroll: false,
      );
      expect(seen, same(controller.refreshSignal));
      var heard = 0;
      seen!.addListener(() => heard++);
      controller.refreshSignal.fire();
      expect(heard, 1);
    });
  });
}
