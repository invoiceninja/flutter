import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_picker.dart';

import '../../../../_localization_helper.dart';

class _Harness {
  TemplateVariablePick? result;
  bool closed = false;
}

/// A button that opens the picker and records what it returned.
Future<_Harness> _open(
  WidgetTester tester, {
  TemplateVariableScope scope = TemplateVariableScope.invoice,
  String? currentToken,
  bool forSubject = false,
  Map<String, TemplateVariableValue> values = const {},
  Size size = const Size(1200, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final harness = _Harness();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                harness.result = await showTemplateVariablePicker(
                  context,
                  scope: scope,
                  currentToken: currentToken,
                  forSubject: forSubject,
                  values: values,
                );
                harness.closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('insert: titled "Insert variable", grouped, no Remove', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Insert variable'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('INVOICE'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    // The list is lazy; the next group is further down.
    await tester.scrollUntilVisible(
      find.text('CLIENT'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('CLIENT'), findsOneWidget);
  });

  testWidgets('tapping a row picks its token', (tester) async {
    final harness = await _open(tester);
    await tester.tap(find.text('Invoice Number'));
    await tester.pumpAndSettle();
    expect((harness.result! as TemplateVariablePicked).token, r'$number');
  });

  testWidgets('change: the current variable leads, checked; tapping it '
      'just closes', (tester) async {
    final harness = await _open(tester, currentToken: r'$company.name');
    expect(find.text('Change variable'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    // Listed once — pinned first, not again in its group.
    expect(find.text(r'$company.name'), findsOneWidget);
    await tester.tap(find.text('Company Name'));
    await tester.pumpAndSettle();
    expect(harness.closed, isTrue);
    expect(harness.result, isNull);
  });

  testWidgets('Remove sits in the header and returns Removed', (tester) async {
    final harness = await _open(tester, currentToken: r'$number');
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(harness.result, isA<TemplateVariableRemoved>());
  });

  testWidgets('a typo gets a "Did you mean" row', (tester) async {
    final harness = await _open(tester, currentToken: r'$compnay.name');
    expect(find.text('DID YOU MEAN COMPANY NAME?'), findsOneWidget);
    await tester.tap(find.text(r'$company.name'));
    await tester.pumpAndSettle();
    expect((harness.result! as TemplateVariablePicked).token, r'$company.name');
  });

  testWidgets('search matches label, token and value', (tester) async {
    await _open(
      tester,
      values: const {r'$company.name': TemplateVariableResolved('Acme Ltd')},
    );
    await tester.enterText(find.byType(TextField), 'acme');
    await tester.pumpAndSettle();
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Invoice Number'), findsNothing);

    await tester.enterText(find.byType(TextField), r'po_number');
    await tester.pumpAndSettle();
    expect(find.text('PO Number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xyzzy');
    await tester.pumpAndSettle();
    expect(find.text('No records found'), findsOneWidget);
  });

  testWidgets('Enter on an empty query picks nothing; with a query, the '
      'first row', (tester) async {
    final harness = await _open(tester);
    await tester.showKeyboard(find.byType(TextField));
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(harness.closed, isFalse);

    await tester.enterText(find.byType(TextField), 'client city');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect((harness.result! as TemplateVariablePicked).token, r'$client.city');
  });

  testWidgets('the subject picker hides variables whose value is HTML', (
    tester,
  ) async {
    await _open(tester, forSubject: true);
    expect(find.text(r'$view_button'), findsNothing);
    expect(find.text(r'$payment_button'), findsNothing);
    expect(find.text(r'$number'), findsOneWidget);
  });

  testWidgets('values show beside their variables', (tester) async {
    await _open(
      tester,
      values: const {
        r'$number': TemplateVariableResolved('0012'),
        r'$po_number': TemplateVariableEmpty(),
      },
    );
    expect(find.text('0012'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('a narrow window gets a bottom sheet', (tester) async {
    await _open(tester, size: const Size(400, 800));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Escape closes it', (tester) async {
    final harness = await _open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(harness.closed, isTrue);
    expect(harness.result, isNull);
  });
}
