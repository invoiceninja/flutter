import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/variable_picker.dart';

import '../../../../../../_localization_helper.dart';

void main() {
  Future<VariablePick?> Function() open(
    WidgetTester tester, {
    Set<VariableCategory>? categories,
    Map<String, String> labels = const {},
  }) {
    VariablePick? result;
    var done = false;
    return () async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          locale: const Locale('en'),
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showVariablePicker(
                    context,
                    categories: categories ?? const {VariableCategory.client},
                    customFieldLabels: labels,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return done ? result : null;
    };
  }

  testWidgets('a field is found by its name, its example or its token', (
    tester,
  ) async {
    await open(tester)();
    expect(find.text('Client Name'), findsOneWidget);
    // Each row shows what it would print for the sample client.
    expect(find.textContaining('Acme Corporation'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'billing@');
    await tester.pump();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Client Name'), findsNothing);

    await tester.enterText(find.byType(TextField), 'vat_number');
    await tester.pump();
    expect(find.text('VAT Number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.text('No results found.'), findsOneWidget);
  });

  testWidgets('a custom field is listed under the name the company gave it', (
    tester,
  ) async {
    await open(tester, labels: const {'client1': 'Region', 'client2': ' '})();
    // The list is long; search brings the row into the built range.
    await tester.enterText(find.byType(TextField), 'region');
    await tester.pump();
    expect(find.text('Region'), findsOneWidget);
    // Unused slots are not offered as "First Custom", "Second Custom"…
    await tester.enterText(find.byType(TextField), 'custom');
    await tester.pump();
    expect(find.text('First Custom'), findsNothing);
    expect(find.text('Second Custom'), findsNothing);
    // …though the slot that is in use still answers to its token.
    expect(find.text('Region'), findsOneWidget);
  });

  testWidgets('picking returns the token and the name it was listed under', (
    tester,
  ) async {
    VariablePick? picked;
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showVariablePicker(
                context,
                categories: const {VariableCategory.invoice},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PO Number'));
    await tester.pumpAndSettle();
    expect(picked!.token, r'$invoice.po_number');
    expect(picked!.labelKey, 'po_number');
  });
}
