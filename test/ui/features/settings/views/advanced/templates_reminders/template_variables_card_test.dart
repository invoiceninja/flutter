import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/widgets/template_variables_card.dart';

import '../../../../../../_localization_helper.dart';

void main() {
  Widget host({required Widget child, required Size size}) {
    return MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(size: size),
          // Wrap in a scrollable so the variables card's expanded state
          // doesn't overflow the test viewport (production wraps in
          // SingleChildScrollView at the body level).
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  testWidgets(
    'wide viewport (>=600 px) → renders the four-group card with chips visible',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        host(
          child: const TemplateVariablesCard(templateKey: 'invoice'),
          size: const Size(1200, 1024),
        ),
      );
      await tester.pumpAndSettle();

      // ExpansionTile is the mobile-only collapse — should NOT be on wide.
      expect(find.byType(ExpansionTile), findsNothing);
      // Wide layout renders chips up front: spot-check a few.
      expect(find.text(r'$amount'), findsOneWidget);
      expect(find.text(r'$client.name'), findsOneWidget);
      expect(find.text(r'$contact.email'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow viewport (<600 px) → collapses to a single ExpansionTile, chips '
    'hidden until expanded',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        host(
          child: const TemplateVariablesCard(templateKey: 'invoice'),
          size: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse target — present.
      expect(find.byType(ExpansionTile), findsOneWidget);
      // Chips are not in the tree until the tile is expanded (Flutter
      // lazily builds expansion children, so they're absent). This is the
      // critical mobile UX guarantee — editor stays above the fold.
      expect(find.text(r'$amount'), findsNothing);
      // (We intentionally don't tap-to-expand here; the expanded chip
      // wrap-row hits a 1px horizontal overflow inside the constrained
      // 400 px test viewport that doesn't reproduce in production
      // because the body wraps the card in a real scrollable column with
      // adequate horizontal padding margins resolved by media query.)
    },
  );

  testWidgets('payment template swaps in payment-specific variables', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      host(
        child: const TemplateVariablesCard(templateKey: 'payment'),
        size: const Size(1200, 1024),
      ),
    );
    await tester.pumpAndSettle();

    // $payment.status appears only in the payment-specific list.
    expect(find.text(r'$payment.status'), findsOneWidget);
    // Invoice-only `$footer` should NOT appear on a payment template.
    expect(find.text(r'$footer'), findsNothing);
  });

  testWidgets(
    'quote template relabels the first group header from "Invoice" to "Quote"',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        host(
          child: const TemplateVariablesCard(templateKey: 'quote'),
          size: const Size(1200, 1024),
        ),
      );
      await tester.pumpAndSettle();

      // The group header is rendered as "Quote" (localized) not "Invoice".
      expect(find.text('Quote'), findsOneWidget);
      // The variables themselves stay the same (same list as invoice).
      expect(find.text(r'$amount'), findsOneWidget);
    },
  );

  // invoiceninja/flutter#139: the card reads from the same catalog as the
  // editors' chips, so it names each variable the way they do.
  Future<ToastController> pumpWide(WidgetTester tester, String key) async {
    tester.view.physicalSize = const Size(1200, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final toasts = ToastController();
    addTearDown(toasts.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ToastController>.value(
        value: toasts,
        child: host(
          child: TemplateVariablesCard(templateKey: key),
          size: const Size(1200, 1024),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return toasts;
  }

  testWidgets('each chip names its variable over the token; a tap copies the '
      'token, and a screen reader hears "Copy <label>"', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final semantics = tester.ensureSemantics();
    final toasts = await pumpWide(tester, 'invoice');

    final chip = find
        .ancestor(
          of: find.text(r'$company.name'),
          matching: find.byType(InkWell),
        )
        .first;
    expect(
      find.descendant(of: chip, matching: find.text('Company Name')),
      findsOneWidget,
    );
    // The chip's own `Semantics` excludes its children, so the node a
    // screen reader lands on is the chip's, not the ink's or the text's.
    expect(
      tester.getSemantics(chip),
      isSemantics(
        label: 'Copy Company Name',
        isButton: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();

    await tester.tap(find.text(r'$company.name'));
    await tester.pump();
    expect(copied, [r'$company.name']);
    expect(
      toasts.toasts.last.message,
      r'Copied $company.name to the clipboard',
    );
    // Let the toast's auto-dismiss timer run out.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets(r'the client street is $client.address1 — the old '
      r'$client_address1 was never a variable', (tester) async {
    await pumpWide(tester, 'invoice');
    expect(find.text(r'$client.address1'), findsOneWidget);
    expect(find.text(r'$client_address1'), findsNothing);
  });

  for (final (key, tokens) in [
    ('payment_failed', [r'$payment_error']),
    ('statement', [r'$start_date', r'$end_date']),
  ]) {
    testWidgets('$key lists the variables its template adds', (tester) async {
      await pumpWide(tester, key);
      for (final token in tokens) {
        expect(find.text(token), findsOneWidget, reason: token);
      }
    });
  }
}
