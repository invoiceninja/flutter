import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';

import '../../../_localization_helper.dart';

void main() {
  Widget wrapIn(InTheme tokens, Widget child) => MaterialApp(
    theme: buildInTheme(tokens),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Scaffold(body: child),
  );

  Widget wrap(Widget child) => wrapIn(InTheme.light, child);

  testWidgets(
    'many fields mount in one frame without a duplicate-IME throw and '
    'tap promotes reader→editor, blur reverts',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              for (var i = 0; i < 4; i++)
                MarkdownTextField(
                  label: 'F$i',
                  initialValue: 'body $i',
                  height: 80,
                  onChanged: (_) {},
                ),
            ],
          ),
        ),
      );
      await tester.pump();

      // All four render read-only — no SuperEditor (and thus no IME client)
      // mounted, so no "Found N duplicate input IDs this frame".
      expect(tester.takeException(), isNull);
      expect(find.byType(SuperReader), findsNWidgets(4));
      expect(find.byType(SuperEditor), findsNothing);

      // Tapping a field promotes exactly that one to the editing SuperEditor.
      // (Tap the field root, not SuperReader — the reader is a sliver, and it
      // sits under a SliverIgnorePointer; the tap layer is the host
      // GestureDetector, which shares the arena with the now-live inner
      // Scrollable. This case is the guard that a tap still beats the drag.)
      await tester.tap(find.byType(MarkdownTextField).first);
      await tester.pump(); // run the post-frame callback in _enterEditing
      await tester.pump(); // rebuild with the editor
      expect(find.byType(SuperEditor), findsOneWidget);
      expect(find.byType(SuperReader), findsNWidgets(3));
      expect(tester.takeException(), isNull);

      // Blur reverts it back to a reader (≤1 SuperEditor invariant holds).
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump();
      expect(find.byType(SuperEditor), findsNothing);
      expect(find.byType(SuperReader), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reseeds the document when externalValueKey changes', (
    tester,
  ) async {
    final emissions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: MarkdownTextField(
                label: 'Terms',
                initialValue: 'first',
                externalValueKey: 'k1',
                onChanged: emissions.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Reseed with a different value + key. Pumping the new widget should
    // replace the document content with no spurious onChanged emission.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: MarkdownTextField(
                label: 'Terms',
                initialValue: 'second',
                externalValueKey: 'k2',
                onChanged: emissions.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(emissions, isEmpty);
  });

  testWidgets('reader mode scrolls a value taller than the box', (
    tester,
  ) async {
    // invoiceninja/flutter#107: the read-only reader used to sit under a
    // box-level IgnorePointer that also switched off its own CustomScrollView,
    // so anything past the fixed height was cut off with no way to reach it —
    // by drag on a phone or by wheel on desktop.
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Notes',
              showLabel: false,
              height: 120,
              maxHeight: 120,
              initialValue: [
                for (var i = 0; i < 40; i++) 'line $i',
              ].join('\n\n'),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SuperReader), findsOneWidget);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, 0);

    await tester.drag(find.byType(MarkdownTextField), const Offset(0, -60));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('grows with its content between height and maxHeight', (
    tester,
  ) async {
    Finder viewportOf(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(CustomScrollView),
    );
    String lines(int n) => [for (var i = 0; i < n; i++) 'line $i'].join('\n\n');

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            for (final (key, value) in [
              ('short', 'one line'),
              ('medium', lines(6)),
              ('long', lines(80)),
            ])
              SizedBox(
                width: 400,
                child: MarkdownTextField(
                  key: ValueKey(key),
                  label: key,
                  showLabel: false,
                  height: 100,
                  maxHeight: 300,
                  initialValue: value,
                  onChanged: (_) {},
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pump();

    final short = tester.getSize(viewportOf('short')).height;
    final medium = tester.getSize(viewportOf('medium')).height;
    final long = tester.getSize(viewportOf('long')).height;

    // Content shorter than the floor still renders at the floor, so short and
    // empty fields look exactly as they did before.
    expect(short, 100);
    expect(medium, greaterThan(100));
    expect(medium, lessThan(300));
    // Past the ceiling the field stops growing and scrolls instead.
    expect(long, 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps HTML list content the markdown parser would drop', (
    tester,
  ) async {
    // The React client stores TinyMCE HTML in these fields. A raw `<ul>` is
    // parsed as an HTML block running to the next blank line and then dropped,
    // so the list — and everything after it — used to vanish, and the next
    // edit persisted the loss.
    final controller = MarkdownFieldController();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Terms',
              showLabel: false,
              controller: controller,
              initialValue: '<p>Intro</p><ul><li>One</li><li>Two</li></ul>',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // `flush()` serializes the live document, so this reads what the editor
    // actually holds — and what a save would persist.
    // Assert the shape, not just the words: `contains('One')` would pass even
    // if the list had collapsed into a single paragraph.
    // super_editor's own serialization of an unordered list — indented `*`
    // rather than the `-` we fed it, which is exactly why the assertion is on
    // the round-tripped shape rather than the input.
    expect(controller.flush(), 'Intro\n\n  * One\n  * Two');
  });

  testWidgets('keeps an ordered list ordered through deserialization', (
    tester,
  ) async {
    final controller = MarkdownFieldController();
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Terms',
              showLabel: false,
              controller: controller,
              initialValue: '<ol><li>One</li><li>Two</li></ol>',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The `1.` prefixes prove these are ordered `ListItemNode`s: two
    // paragraphs of literal text would serialize with no marker at all.
    // (super_editor emits `1.` per item rather than renumbering.)
    expect(controller.flush(), '  1. One\n  1. Two');
  });

  testWidgets('an empty value renders at height and emits nothing', (
    tester,
  ) async {
    // The default state of Private Notes and Footer, and the only path that
    // takes `MutableDocument.empty()` instead of the markdown deserializer.
    final emissions = <String>[];
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Notes',
              showLabel: false,
              height: 140,
              initialValue: '',
              onChanged: emissions.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getSize(find.byType(CustomScrollView)).height, 140);
    expect(emissions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a disabled field can still be scrolled', (tester) async {
    // The #107 defect survived here: `enabled: false` wrapped the whole frame
    // in an `IgnorePointer`, which switches off the editor's own scroll view
    // as well as its input. Reachable through OverridableMarkdownField, where
    // a plan-gated or cascade-inherited value is shown read-only.
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Notes',
              showLabel: false,
              enabled: false,
              height: 120,
              maxHeight: 120,
              initialValue: [
                for (var i = 0; i < 40; i++) 'line $i',
              ].join('\n\n'),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(MarkdownTextField), const Offset(0, -60));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('a readOnly field scrolls and never promotes to an editor', (
    tester,
  ) async {
    // The state `OverridableMarkdownField` puts an inherited cascade value in:
    // readable and scrollable, but the override checkbox is the only way in.
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Terms',
              showLabel: false,
              readOnly: true,
              height: 120,
              maxHeight: 120,
              initialValue: [
                for (var i = 0; i < 40; i++) 'line $i',
              ].join('\n\n'),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    await tester.drag(find.byType(MarkdownTextField), const Offset(0, -60));
    await tester.pump();
    expect(position.pixels, greaterThan(0));

    await tester.tap(find.byType(MarkdownTextField));
    await tester.pump();
    // Long enough to retire SuperReader's double-tap countdown — the reader's
    // own recognizers are live in this mode, which is the point.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SuperEditor), findsNothing);
    expect(find.byType(SuperReader), findsOneWidget);
  });

  testWidgets('a tap still promotes a field whose content scrolls', (
    tester,
  ) async {
    // The union the arena comment claims: the inner drag recognizer is live,
    // and a movement-free tap still has to beat it.
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Notes',
              showLabel: false,
              height: 120,
              maxHeight: 120,
              initialValue: [
                for (var i = 0; i < 40; i++) 'line $i',
              ].join('\n\n'),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(MarkdownTextField));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SuperEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expand mode fills a bounded parent and scrolls', (tester) async {
    // The desktop notes pane: `expand: true` takes the parent's height instead
    // of growing, and the same sliver-level pointer block applies there.
    await tester.pumpWidget(
      wrap(
        Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: MarkdownTextField(
              label: 'Terms',
              showLabel: false,
              expand: true,
              initialValue: [
                for (var i = 0; i < 40; i++) 'line $i',
              ].join('\n\n'),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 200 less the frame's 1px border on each side.
    expect(tester.getSize(find.byType(CustomScrollView)).height, 198);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    await tester.drag(find.byType(MarkdownTextField), const Offset(0, -60));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('the mobile caret and handles are the accent, not the surface', (
    tester,
  ) async {
    // invoiceninja/flutter#108. On Android/iOS super_editor paints the caret
    // and drag handles with `Theme.of(context).primaryColor`, which
    // `buildInTheme` leaves Flutter to derive — `colorScheme.surface` in dark
    // mode, i.e. this field's own background, so the caret was invisible.
    // `flutter test` runs as Android, so the platform handle layer is the one
    // that builds here; every other test in this file is light-themed, where
    // the derivation already lands on the accent and the bug can't show.
    const tokens = InTheme.dark;
    await tester.pumpWidget(
      wrapIn(
        tokens,
        Center(
          child: SizedBox(
            width: 400,
            child: MarkdownTextField(
              label: 'Public notes',
              showLabel: false,
              initialValue: 'Test',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The reader needs it too: `SuperReader` reads `primaryColor` for its own
    // Android handles and consults no controls scope, so it has no other seam.
    expect(
      Theme.of(tester.element(find.byType(SuperReader))).primaryColor,
      tokens.accent,
    );

    await tester.tap(find.byType(MarkdownTextField));
    await tester.pump(); // run the post-frame callback in _enterEditing
    await tester.pump(); // rebuild with the editor
    expect(find.byType(SuperEditor), findsOneWidget);

    // The handles' color source. The drag handles, the floating toolbar and the
    // iOS magnifier are `OverlayPortal` children of this subtree, and the SDK
    // guarantees an overlay child resolves inherited widgets — `Theme` by name
    // — from the portal's position, so this one lookup is what colors them.
    // Asserted here rather than on the widget because `AndroidSelectionHandle`
    // isn't exported from `package:super_editor/super_editor.dart`. It covers
    // iOS too: its caret and handles read the same inherited `primaryColor`.
    expect(
      Theme.of(tester.element(find.byType(SuperEditor))).primaryColor,
      tokens.accent,
    );

    // The color super_editor will paint, read straight off the Android layer —
    // no selection or blink timing required.
    final layer = tester.state<AndroidControlsDocumentLayerState>(
      find.byType(AndroidHandlesDocumentLayer),
    );
    expect(layer.caretColor, tokens.accent);
    expect(layer.caretColor, isNot(tokens.surface)); // the #108 failure

    // And the painted article: tap inside the now-live editor to place a
    // collapsed caret, then read the box that actually renders it. Tap by
    // coordinate — `SuperEditor` is a sliver, so `tap()` can't target it.
    await tester.pump(const Duration(milliseconds: 300)); // retire double-tap
    await tester.tapAt(
      tester.getTopLeft(find.byType(CustomScrollView)) + const Offset(30, 12),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final caret = tester.widget<ColoredBox>(find.byKey(DocumentKeys.caret));
    // Alpha is the blink phase; the caret jumps opaque on a move, but pin the
    // hue rather than depend on that.
    expect(caret.color.withValues(alpha: 1), tokens.accent);
    expect(caret.color.withValues(alpha: 1), isNot(tokens.surface));
  });
}
