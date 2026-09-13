import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/scroll_edge_fades.dart';

/// [ScrollEdgeFades] backs the billing-doc edit strips, which still scroll in
/// German, on a 360 px phone and at large text scale after
/// invoiceninja/flutter#140. Before it there was no fade, no scroll
/// controller and no reveal anywhere on those strips: the last tab was simply
/// cut off, which is what the reporter charitably read as a deliberate hint.
Future<void> _pump(
  WidgetTester tester, {
  required double viewport,
  required double content,
  ScrollController? controller,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: viewport,
            height: 48,
            child: ScrollEdgeFades(
              color: const Color(0xFF101010),
              child: SingleChildScrollView(
                controller: controller,
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: content, height: 48),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

bool _leading(WidgetTester tester) =>
    tester.any(find.byKey(ScrollEdgeFades.leadingFadeKey));
bool _trailing(WidgetTester tester) =>
    tester.any(find.byKey(ScrollEdgeFades.trailingFadeKey));

void main() {
  testWidgets('content that fits gets no fade at either edge', (tester) async {
    await _pump(tester, viewport: 300, content: 200);
    await tester.pump();
    expect(_leading(tester), isFalse);
    expect(_trailing(tester), isFalse);
  });

  testWidgets('a trailing fade appears without anyone scrolling', (
    tester,
  ) async {
    // The reason the leaf listens to `ScrollMetricsNotification` at all:
    // attaching a position notifies no scroll listener, so a strip nobody
    // touches would otherwise never learn it has somewhere to go.
    await _pump(tester, viewport: 300, content: 600);
    await tester.pump();
    expect(_leading(tester), isFalse, reason: 'sitting at minScrollExtent');
    expect(_trailing(tester), isTrue);
  });

  testWidgets('the pair follows the scroll position', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await _pump(tester, viewport: 300, content: 600, controller: controller);
    await tester.pump();

    controller.jumpTo(150);
    await tester.pump();
    expect(_leading(tester), isTrue, reason: 'mid-strip shows both');
    expect(_trailing(tester), isTrue);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(_leading(tester), isTrue);
    expect(_trailing(tester), isFalse, reason: 'nothing left beyond the end');
  });

  testWidgets('a width change that leaves pixels alone re-resolves the fades', (
    tester,
  ) async {
    // `applyContentDimensions` only schedules a `ScrollMetricsNotification`,
    // which reaches no `ScrollController` listener. Widening the pane until
    // the strip fits must still drop the fade.
    await _pump(tester, viewport: 300, content: 600);
    await tester.pump();
    expect(_trailing(tester), isTrue);

    await _pump(tester, viewport: 700, content: 600);
    await tester.pump();
    expect(_trailing(tester), isFalse);
    expect(_leading(tester), isFalse);
  });

  testWidgets('the fades never eat a tap meant for the strip', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 48,
              child: ScrollEdgeFades(
                color: const Color(0xFF101010),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox(width: 600, height: 48),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(_trailing(tester), isTrue);
    // Right on top of the trailing gradient.
    await tester.tapAt(
      tester.getCenter(find.byType(ScrollEdgeFades)) + const Offset(140, 0),
    );
    expect(taps, 1);
  });
}
