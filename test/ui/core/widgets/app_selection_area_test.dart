import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/app_selection_area.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';

/// invoiceninja/flutter#188: read-only text was not selectable on a phone —
/// the detail body skipped its `SelectionArea` on native mobile. It now has
/// one everywhere, and on touch [AppSelectionArea] adds the two dismissals
/// Flutter's selection lacks: a tap a child claims (a row, a tab, a
/// tap-to-copy value) and Android's back.
///
/// `flutter test` reports android, so the default here is the touch path.
/// Pumped through a real `GoRouter`: the back claim hangs off
/// `Router.backButtonDispatcher`, which a bare `MaterialApp` doesn't have.
void main() {
  String? copied;

  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Whether the notes paragraph is mounted — flipped to unmount a selection
  /// with no gesture, as a tab switch or a record refresh does.
  late ValueNotifier<bool> notesMounted;

  Future<GoRouter> pump(
    WidgetTester tester, {
    required List<String> log,
  }) async {
    notesMounted = ValueNotifier(true);
    addTearDown(notesMounted.dispose);
    final router = GoRouter(
      initialLocation: '/list',
      routes: [
        GoRoute(path: '/list', builder: (_, _) => const Text('the list')),
        GoRoute(
          path: '/detail',
          builder: (_, _) => Scaffold(
            // Outside the region, like the detail screen's own app bar.
            appBar: AppBar(
              actions: [
                TextButton(
                  onPressed: () => log.add('action'),
                  child: const Text('Bar action'),
                ),
              ],
            ),
            body: AppSelectionArea(
              child: ListView(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: notesMounted,
                    builder: (_, mounted, _) => mounted
                        ? const Text('Project notes here')
                        : const SizedBox(height: 20),
                  ),
                  const SizedBox(height: 40),
                  InkWell(
                    onTap: () => log.add('row'),
                    child: const SizedBox(height: 48, child: Text('A row')),
                  ),
                  const SizedBox(height: 40),
                  const CopyableValue(value: 'VAT-123', child: Text('VAT-123')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildInTheme(InTheme.light),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    // Pushed, so back has somewhere to go.
    unawaited(router.push('/detail'));
    await tester.pumpAndSettle();
    return router;
  }

  /// What is selected in [text]'s paragraph.
  List<TextSelection> selectionIn(WidgetTester tester, String text) => tester
      // Under a `SelectionArea` a `Text` puts a `MouseRegion` above its
      // paragraph, so the paragraph is the `RichText` below it.
      .renderObject<RenderParagraph>(
        find.descendant(of: find.text(text), matching: find.byType(RichText)),
      )
      .selections
      .where((s) => !s.isCollapsed)
      .toList();

  /// Long-press the first word of [text].
  Future<void> selectWordIn(WidgetTester tester, String text) async {
    await tester.longPressAt(
      tester.getTopLeft(find.text(text)) + const Offset(6, 6),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a long-press selects a word and offers Copy', (tester) async {
    await pump(tester, log: []);

    await selectWordIn(tester, 'Project notes here');

    expect(selectionIn(tester, 'Project notes here'), [
      const TextSelection(baseOffset: 0, extentOffset: 7),
    ]);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('a tap-to-copy value is selectable by long-press too', (
    tester,
  ) async {
    await pump(tester, log: []);

    await selectWordIn(tester, 'VAT-123');

    expect(selectionIn(tester, 'VAT-123'), isNotEmpty);
    expect(copied, isNull, reason: 'a long-press selects, it does not copy');
  });

  testWidgets('a tap a child claims runs it AND dismisses the selection', (
    tester,
  ) async {
    final log = <String>[];
    await pump(tester, log: log);
    await selectWordIn(tester, 'Project notes here');
    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('A row'));
    await tester.pumpAndSettle();

    expect(log, ['row'], reason: 'the row still gets its tap');
    expect(selectionIn(tester, 'Project notes here'), isEmpty);
    expect(find.text('Copy'), findsNothing, reason: 'no orphaned toolbar');
  });

  testWidgets('tap-to-copy with a selection showing dismisses, not copies', (
    tester,
  ) async {
    await pump(tester, log: []);
    await selectWordIn(tester, 'Project notes here');

    await tester.tap(find.text('VAT-123'));
    await tester.pumpAndSettle();

    expect(copied, isNull, reason: 'the tap was spent on the selection');
    expect(selectionIn(tester, 'Project notes here'), isEmpty);

    await tester.tap(find.text('VAT-123'));
    await tester.pumpAndSettle();
    expect(copied, 'VAT-123', reason: 'with nothing selected, tap copies');
  });

  testWidgets('back dismisses a selection before it leaves the page', (
    tester,
  ) async {
    final router = await pump(tester, log: []);
    await selectWordIn(tester, 'Project notes here');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(selectionIn(tester, 'Project notes here'), isEmpty);
    expect(find.text('Copy'), findsNothing);
    expect(router.state.uri.path, '/detail', reason: 'back must not navigate');
  });

  testWidgets('with nothing selected, back is not claimed', (tester) async {
    await pump(tester, log: []);
    // A selection made and dismissed must give the claim back.
    await selectWordIn(tester, 'Project notes here');
    await tester.tap(find.text('A row'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('the list'), findsOneWidget, reason: 'no stale claim');
  });

  testWidgets('a tap outside the region (the app bar) dismisses it too', (
    tester,
  ) async {
    final log = <String>[];
    await pump(tester, log: log);
    await selectWordIn(tester, 'Project notes here');

    await tester.tap(find.text('Bar action'));
    await tester.pumpAndSettle();

    expect(log, ['action']);
    expect(selectionIn(tester, 'Project notes here'), isEmpty);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets("the menu's Select all is not taken for a dismissal", (
    tester,
  ) async {
    await pump(tester, log: []);
    await selectWordIn(tester, 'Project notes here');

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();

    expect(selectionIn(tester, 'Project notes here'), [
      const TextSelection(baseOffset: 0, extentOffset: 18),
    ]);
  });

  testWidgets('a selection that unmounts leaves no claim behind', (
    tester,
  ) async {
    await pump(tester, log: []);
    await selectWordIn(tester, 'Project notes here');

    // No gesture: the selected text simply goes away.
    notesMounted.value = false;
    await tester.pumpAndSettle();

    await tester.tap(find.text('VAT-123'));
    await tester.pumpAndSettle();
    expect(copied, 'VAT-123', reason: 'nothing showed, so the tap copies');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('the list'), findsOneWidget, reason: 'back navigates');
  });

  testWidgets('with a mouse it is a bare SelectionArea', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pump(tester, log: []);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.byType(SelectionListener), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a scroll with a selection showing leaves it alone', (
    tester,
  ) async {
    await pump(tester, log: []);
    await selectWordIn(tester, 'Project notes here');

    await tester.drag(find.text('A row'), const Offset(0, -30));
    await tester.pumpAndSettle();

    expect(selectionIn(tester, 'Project notes here'), isNotEmpty);
  });

  testWidgets('iOS: a tap on the selection toggles its menu, keeping it', (
    tester,
  ) async {
    // Reset inside the body: the foundation-vars invariant check runs before
    // tear-downs.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pump(tester, log: []);
      await selectWordIn(tester, 'Project notes here');
      expect(find.text('Copy'), findsOneWidget);

      // Mid-word: iOS draws its start handle over the word's first glyph.
      await tester.tapAt(
        tester.getTopLeft(find.text('Project notes here')) +
            const Offset(25, 8),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy'), findsNothing, reason: 'the menu toggles off');
      expect(
        selectionIn(tester, 'Project notes here'),
        isNotEmpty,
        reason: 'a tap the region handled itself is not a dismissal',
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
