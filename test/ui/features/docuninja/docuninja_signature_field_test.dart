import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:admin/domain/docuninja/docuninja_signature.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_signature_field.dart';

import '../shell/_shell_test_helpers.dart';

void main() {
  testWidgets('a signature drawn on the pad is stored as a JPEG', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final values = <String>[];
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: SingleChildScrollView(
            child: DnSignatureField(
              label: 'Signature',
              value: '',
              kind: DnSignatureKind.signature,
              onChanged: values.add,
            ),
          ),
        ),
      ),
    );
    // Nothing to clear yet.
    expect(find.text('Clear'), findsNothing);

    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byKey(const ValueKey('dn-signature-pad')));
    final gesture = await tester.startGesture(box.center - const Offset(60, 0));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(20, 4));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    // Rendering the pad to an image runs outside the fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Done'));
      for (var i = 0; i < 50 && values.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(values, hasLength(1));
    expect(values.single, startsWith('data:image/jpeg;base64,'));
    expect(dnSignatureBytes(values.single), isNotEmpty);
  });

  testWidgets('a stored signature shows, and Clear empties it', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    final values = <String>[];
    // A 1×1 white JPEG.
    const stored =
        'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==';
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: SingleChildScrollView(
            child: DnSignatureField(
              label: 'Signature',
              value: stored,
              kind: DnSignatureKind.signature,
              onChanged: values.add,
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Signature'), findsWidgets);
    await tester.tap(find.text('Clear'));
    expect(values, ['']);
  });

  testWidgets('a tap on the pad is a dot, not nothing', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: SingleChildScrollView(
            child: DnSignatureField(
              label: 'Signature',
              value: '',
              kind: DnSignatureKind.initials,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    bool doneEnabled() => tester
        .widgetList<ButtonStyleButton>(
          find.ancestor(
            of: find.text('Done'),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
          ),
        )
        .any((b) => b.onPressed != null);
    expect(doneEnabled(), isFalse);
    // A touch tap: no movement, so a pan would never start.
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('dn-signature-pad'))),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    expect(doneEnabled(), isTrue, reason: 'the dot is ink');
  });

  testWidgets('a second finger draws nothing', (tester) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: SingleChildScrollView(
            child: DnSignatureField(
              label: 'Signature',
              value: '',
              kind: DnSignatureKind.signature,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    final pad = tester.getRect(find.byKey(const ValueKey('dn-signature-pad')));
    final one = await tester.startGesture(pad.center, pointer: 1);
    await one.moveBy(const Offset(10, 0));
    // A palm comes down and moves while the first finger draws.
    final two = await tester.startGesture(
      pad.center + const Offset(0, 30),
      pointer: 2,
    );
    await two.moveBy(const Offset(10, 0));
    await one.up();
    await two.up();
    await tester.pump();
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byKey(const ValueKey('dn-signature-pad')),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((c) => c.painter)
        .whereType<CustomPainter>()
        .single;
    // One stroke, from the first finger only.
    expect((painter as dynamic).strokes.length, 1);
  });

  group('on a phone', () {
    Future<void> pumpField(
      WidgetTester tester,
      ValueChanged<String> onChanged,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = await buildFixture(
        companies: [FakeCompany(id: 'co1', name: 'Acme')],
      );
      addTearDown(fixture.dispose);
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Scaffold(
            body: SingleChildScrollView(
              child: DnSignatureField(
                label: 'Signature',
                value: '',
                kind: DnSignatureKind.signature,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the pad is full screen, full width and tall', (tester) async {
      await pumpField(tester, (_) {});
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        tester.widget<Dialog>(find.byType(Dialog)).insetPadding,
        EdgeInsets.zero,
        reason: 'Dialog.fullscreen',
      );
      final pad = tester.getRect(
        find.byKey(const ValueKey('dn-signature-pad')),
      );
      // Was ~265 × 88 in the dialog.
      expect(pad.width, greaterThan(393 - 40));
      expect(pad.height, greaterThan(250));
      // ✕, the title and Done in the bar; Clear in the pad's corner.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byTooltip('Clear'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('dn-signature-clear'))).top,
        closeTo(pad.top, 1),
      );
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('a square drawn on the tall pad is stored square', (
      tester,
    ) async {
      final values = <String>[];
      await pumpField(tester, values.add);
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
      final pad = tester.getRect(
        find.byKey(const ValueKey('dn-signature-pad')),
      );
      // The pad is far from the stored 3:1: per-axis fractions would have
      // stretched this square into a wide box.
      expect(pad.width / pad.height, lessThan(2));
      final gesture = await tester.startGesture(
        pad.center - const Offset(50, 50),
        kind: PointerDeviceKind.touch,
      );
      for (final step in const [
        Offset(10, 0),
        Offset(0, 10),
        Offset(-10, 0),
        Offset(0, -10),
      ]) {
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(step);
          await tester.pump();
        }
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Done'));
        for (var i = 0; i < 50 && values.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(values, hasLength(1));
      final image = img.decodeJpg(dnSignatureBytes(values.single)!)!;
      var left = image.width, top = image.height, right = -1, bottom = -1;
      for (final p in image) {
        if (p.luminance > 128) continue;
        if (p.x < left) left = p.x;
        if (p.x > right) right = p.x;
        if (p.y < top) top = p.y;
        if (p.y > bottom) bottom = p.y;
      }
      expect(right, greaterThan(left), reason: 'there is ink');
      final ratio = (right - left) / (bottom - top);
      expect(ratio, closeTo(1, 0.1));
    });

    testWidgets('upload offers Photos, and nothing says click', (tester) async {
      await pumpField(tester, (_) {});
      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Camera'), findsOneWidget);
      expect(find.textContaining('click'), findsNothing);
    });
  });

  test('the render keeps one scale on both axes', () {
    // A 300 × 100 stroke on the pad, in its logical pixels.
    final canvas = dnStrokeCanvas([
      [const Offset(20, 40), const Offset(320, 140)],
    ]);
    expect(canvas.origin, const Offset(20, 40));
    final inkW = canvas.size.width - canvas.margin * 2;
    final inkH = canvas.size.height - canvas.margin * 2;
    expect(inkW / inkH, closeTo(3, 1e-9));
    expect(inkW, closeTo(300 * canvas.scale, 1e-9));
    // A huge drawing is scaled down, still evenly.
    final big = dnStrokeCanvas([
      [Offset.zero, const Offset(4000, 1000)],
    ]);
    expect(big.size.width, lessThanOrEqualTo(3000));
    expect(
      (big.size.width - big.margin * 2) / (big.size.height - big.margin * 2),
      closeTo(4, 1e-9),
    );
  });

  test("Generate's initials are the first letters of the user's names", () {
    // React's `Details.tsx`: first name's first letter, then last name's.
    expect(dnInitialsOf('Jane', 'Doe'), 'JD');
    expect(dnInitialsOf(' Jane ', ''), 'J');
    expect(dnInitialsOf('', 'Doe'), 'D');
    expect(dnInitialsOf('', ''), '');
    // A letter is a grapheme, not a UTF-16 unit.
    expect(dnInitialsOf('Émile', 'Zola'), 'ÉZ');
  });
}
