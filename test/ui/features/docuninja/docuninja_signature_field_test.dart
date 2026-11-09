import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
