// Contact Us: images only where the server takes them, one dialog however
// fast the taps, and no losing a typed message to a stray Cancel
// (docs/feedback-screenshots.md).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/feedback/contact_us_dialog.dart';

import '../shell/_shell_test_helpers.dart';

void main() {
  setUp(debugResetContactUsOpen);

  Future<ShellFixture> pump(
    WidgetTester tester, {
    required bool isHosted,
    String? serverVersion,
  }) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme')],
      isHosted: isHosted,
    );
    addTearDown(fixture.dispose);
    fixture.services.serverVersion.value = serverVersion;
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showContactUsDialog(
              context,
              afterClosing: Future<void>.value(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    return fixture;
  }

  // Not pumpAndSettle: the fixture's Drift watch streams never settle.
  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a server that takes images offers Add Image and the privacy '
      'note', (tester) async {
    await pump(tester, isHosted: false, serverVersion: '5.13.53');
    await openDialog(tester);
    expect(find.text('Contact Us'), findsWidgets);
    expect(find.text('Add Image'), findsOneWidget);
    expect(
      find.text(
        'Screenshots can show client names and amounts. Open one to redact.',
      ),
      findsOneWidget,
    );
  });

  // An older self-hosted server would drop the images without a word.
  testWidgets('an older self-hosted server gets today\'s text-only dialog', (
    tester,
  ) async {
    await pump(tester, isHosted: false, serverVersion: '5.13.52');
    await openDialog(tester);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Add Image'), findsNothing);
  });

  testWidgets('a second tap while it opens opens no second dialog', (
    tester,
  ) async {
    await pump(tester, isHosted: true);
    await tester.tap(find.text('open'));
    await tester.tap(find.text('open'), warnIfMissed: false);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Cancel with a typed message asks first', (tester) async {
    await pump(tester, isHosted: true);
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), 'Something broke');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('Cancel with nothing typed just closes', (tester) async {
    await pump(tester, isHosted: true);
    await openDialog(tester);
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AlertDialog), findsNothing);
  });
}
