import 'package:admin/ui/core/widgets/laid_out_traversal_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A nested Navigator whose first page is covered from the start, the way a
/// restored or deep-linked route stack (and every `StatefulShellRoute`
/// branch) builds it: the covered page is mounted but never laid out. A
/// focusable button sits outside the Navigator, in the scope above it.
Widget _app({
  required FocusTraversalPolicy? policy,
  required FocusNode outer,
  required FocusNode covered,
}) {
  final body = Scaffold(
    body: Row(
      children: [
        SizedBox(
          width: 200,
          child: TextButton(
            focusNode: outer,
            onPressed: () {},
            child: const Text('outer'),
          ),
        ),
        Expanded(
          child: Navigator(
            pages: [
              MaterialPage<void>(
                child: Scaffold(
                  body: Column(
                    children: [
                      // Buttons, not fields: focusing a never-laid-out
                      // text field throws on its own, before any traversal.
                      TextButton(
                        focusNode: covered,
                        onPressed: () {},
                        child: const Text('covered'),
                      ),
                      TextButton(onPressed: () {}, child: const Text('two')),
                    ],
                  ),
                ),
              ),
              const MaterialPage<void>(
                child: Scaffold(body: TextField(key: Key('top'))),
              ),
            ],
            onDidRemovePage: (_) {},
          ),
        ),
      ],
    ),
  );
  return MaterialApp(
    home: policy == null
        ? body
        : FocusTraversalGroup(policy: policy, child: body),
  );
}

Future<(FocusNode, FocusNode)> _pump(
  WidgetTester tester,
  FocusTraversalPolicy? policy,
) async {
  final outer = FocusNode(debugLabel: 'outer');
  final covered = FocusNode(debugLabel: 'covered');
  addTearDown(outer.dispose);
  addTearDown(covered.dispose);
  await tester.pumpWidget(_app(policy: policy, outer: outer, covered: covered));
  return (outer, covered);
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pump();
}

void main() {
  group('the stock policy (pins the upstream bug this works around)', () {
    testWidgets('an arrow key from above the Navigator measures the covered '
        'page', (tester) async {
      final (outer, _) = await _pump(tester, null);
      outer.requestFocus();
      await tester.pump();

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(
        tester.takeException().toString(),
        contains('RenderBox was not laid out'),
      );
    });

    testWidgets('Tab from a button on the covered page measures its '
        'neighbours', (tester) async {
      final (_, covered) = await _pump(tester, null);
      covered.requestFocus();
      await tester.pump();

      await _press(tester, LogicalKeyboardKey.tab);
      expect(
        tester.takeException().toString(),
        contains('RenderBox was not laid out'),
      );
    });
  });

  group('LaidOutReadingOrderTraversalPolicy', () {
    testWidgets('an arrow key from above the Navigator reaches the top page', (
      tester,
    ) async {
      final (outer, covered) = await _pump(
        tester,
        LaidOutReadingOrderTraversalPolicy(),
      );
      outer.requestFocus();
      await tester.pump();

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(tester.takeException(), isNull);
      expect(outer.hasPrimaryFocus, isFalse, reason: 'focus moved right');
      expect(covered.hasFocus, isFalse);
      // The covered nodes it hid for the call are traversable again.
      expect(covered.skipTraversal, isFalse);
    });

    for (final shift in [false, true]) {
      testWidgets('${shift ? 'Shift+' : ''}Tab from a button on the covered '
          'page does not throw', (tester) async {
        final (_, covered) = await _pump(
          tester,
          LaidOutReadingOrderTraversalPolicy(),
        );
        covered.requestFocus();
        await tester.pump();

        if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
        await _press(tester, LogicalKeyboardKey.tab);
        if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('an arrow key from a button on the covered page does nothing', (
      tester,
    ) async {
      final (_, covered) = await _pump(
        tester,
        LaidOutReadingOrderTraversalPolicy(),
      );
      covered.requestFocus();
      await tester.pump();

      expect(
        LaidOutReadingOrderTraversalPolicy().inDirection(
          covered,
          TraversalDirection.down,
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab still walks the visible fields in reading order', (
      tester,
    ) async {
      final a = FocusNode(debugLabel: 'a');
      final b = FocusNode(debugLabel: 'b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FocusTraversalGroup(
            policy: LaidOutReadingOrderTraversalPolicy(),
            child: Scaffold(
              body: Column(
                children: [
                  TextField(focusNode: a),
                  TextField(focusNode: b),
                ],
              ),
            ),
          ),
        ),
      );
      a.requestFocus();
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.tab);
      expect(b.hasPrimaryFocus, isTrue);
    });
  });
}
