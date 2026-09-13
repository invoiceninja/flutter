import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_field_shell.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_text_controller.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../../_localization_helper.dart';

class _Harness {
  _Harness(
    String text, {
    TemplateVariableScope scope = TemplateVariableScope.invoice,
  }) : controller = TemplateVariableTextController(text: text, scope: scope);

  final TemplateVariableTextController controller;
  final focus = FocusNode();
  final toasts = ToastController();
  final edits = <String>[];
  final submitted = <String>[];

  void dispose() {
    controller.dispose();
    focus.dispose();
    toasts.dispose();
  }
}

Future<_Harness> _pump(
  WidgetTester tester,
  String text, {
  String? defaultText,
  bool interactive = true,
  ValueListenable<Map<String, TemplateVariableValue>>? values,
  double width = 800,
  double textScale = 1,
}) async {
  final harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ToastController>.value(
      value: harness.toasts,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width - 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TemplateVariableFieldShell(
                      controller: harness.controller,
                      focusNode: harness.focus,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      interactive: interactive,
                      values: values,
                      defaultText: defaultText,
                      onEdited: harness.edits.add,
                      fieldBuilder: (context, decoration, onTapOutside) =>
                          TextField(
                            controller: harness.controller,
                            focusNode: harness.focus,
                            decoration: decoration,
                            onTapOutside: onTapOutside,
                            onChanged: harness.edits.add,
                            onSubmitted: harness.submitted.add,
                          ),
                    ),
                    const TextField(key: Key('other')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

Finder get _editField => find.byWidgetPredicate(
  (w) => w is TextField && w.key != const Key('other'),
);

void main() {
  testWidgets('at rest, recognised tokens are chips and the rest is text', (
    tester,
  ) async {
    await _pump(tester, r'New invoice $number from $company.name $nope');
    expect(find.byType(TemplateVariableChip), findsNWidgets(2));
    expect(find.text('Invoice Number'), findsOneWidget);
    expect(find.text('Company Name'), findsOneWidget);
    expect(_editField, findsNothing);
  });

  testWidgets('a chip opens the picker; a pick replaces it, reports it and '
      'offers Undo', (tester) async {
    final h = await _pump(tester, r'New invoice $number from $company.name');
    await tester.tap(find.text('Company Name'));
    await tester.pumpAndSettle();
    expect(find.text('Change variable'), findsOneWidget);

    // The list is lazy; the invoice group sits right under the pinned row.
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(h.controller.text, r'New invoice $number from $balance');
    expect(h.edits.last, r'New invoice $number from $balance');
    expect(h.toasts.toasts.last.message, 'Updated');

    h.toasts.toasts.last.action!.onPressed();
    await tester.pump();
    expect(h.controller.text, r'New invoice $number from $company.name');
    expect(h.edits.last, r'New invoice $number from $company.name');
    // Let the toast's auto-dismiss timer run out.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Remove takes the token and its space', (tester) async {
    final h = await _pump(tester, r'New invoice $number from $company.name');
    await tester.tap(find.text('Company Name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(h.controller.text, r'New invoice $number from');
    expect(h.toasts.toasts.last.message, 'Removed');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('tapping the text edits it raw, the caret where it was tapped; '
      'leaving brings the chips back', (tester) async {
    final h = await _pump(tester, r'New invoice $number from $company.name');
    final paragraph = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith('New invoice'),
    );
    await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(3, 8));
    await tester.pumpAndSettle();
    expect(_editField, findsOneWidget);
    expect(h.focus.hasFocus, isTrue);
    expect(h.controller.selection.baseOffset, lessThan(4));

    await tester.tap(find.byKey(const Key('other')));
    await tester.pumpAndSettle();
    expect(_editField, findsNothing);
    expect(find.byType(TemplateVariableChip), findsNWidgets(2));
  });

  testWidgets('editing reports through the field, Enter still submits', (
    tester,
  ) async {
    final h = await _pump(tester, r'Invoice $number');
    // The rest view's paragraph — the one holding the chip's placeholder,
    // not the chip's own "Invoice Number" label.
    final paragraph = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText() == 'Invoice ￼',
    );
    await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(3, 8));
    await tester.pumpAndSettle();
    await tester.enterText(_editField, r'Your invoice $number');
    expect(h.edits.last, r'Your invoice $number');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(h.submitted, [r'Your invoice $number']);
  });

  testWidgets('the default template shows muted, with its caption, and '
      'looking at it writes nothing', (tester) async {
    final h = await _pump(tester, '', defaultText: r'New invoice $number');
    expect(find.text('Invoice Number'), findsOneWidget);
    expect(
      find.text(
        'Showing the default template. Your first edit saves a '
        'custom copy.',
      ),
      findsOneWidget,
    );
    final chip = tester.widget<TemplateVariableChip>(
      find.byType(TemplateVariableChip),
    );
    expect(chip.muted, isTrue);

    // Entering edit mode seeds a copy of the default — not an edit.
    final paragraph = find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith('New'),
    );
    await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(3, 8));
    await tester.pumpAndSettle();
    expect(h.controller.text, r'New invoice $number');
    expect(h.edits, isEmpty);
  });

  testWidgets('a chip change on the default template saves a custom copy', (
    tester,
  ) async {
    final h = await _pump(tester, '', defaultText: r'New invoice $number');
    await tester.tap(find.text('Invoice Number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(h.edits.last, r'New invoice $balance');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('an inherited value is inert', (tester) async {
    final h = await _pump(tester, r'Invoice $number', interactive: false);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    await tester.tap(find.text('Invoice Number'));
    await tester.pumpAndSettle();
    expect(find.text('Change variable'), findsNothing);
    expect(_editField, findsNothing);
    expect(h.edits, isEmpty);
  });

  testWidgets('document values show in the chips; an unrecognised token '
      'warns', (tester) async {
    final values = ValueNotifier<Map<String, TemplateVariableValue>>(const {
      r'$number': TemplateVariableResolved('0012'),
      r'$compnay.name': TemplateVariableUnknown(),
    });
    addTearDown(values.dispose);
    await _pump(tester, r'Invoice $number from $compnay.name', values: values);
    expect(find.text('0012'), findsOneWidget);
    expect(find.text('Not recognized'), findsOneWidget);
  });

  testWidgets('a long subject wraps without overflowing on a small phone at '
      'large text', (tester) async {
    await _pump(
      tester,
      r'Your invoice $number from $company.name is due $due_date — '
      r'balance $balance, contact $contact.email',
      width: 320,
      textScale: 1.4,
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TemplateVariableChip), findsNWidgets(5));
  });
}
