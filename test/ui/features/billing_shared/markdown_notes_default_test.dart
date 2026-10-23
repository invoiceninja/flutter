import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';

import '../../../_localization_helper.dart';

const _caption =
    'Showing the default. Edit it to change it for this document only.';

Future<void> _pump(WidgetTester tester, String value) async {
  final toasts = ToastController();
  addTearDown(toasts.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ToastController>.value(
      value: toasts,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: MarkdownNotesField(
                label: 'Terms',
                value: value,
                onChanged: (_) {},
                onSaveAsDefault: (_) {},
                defaultValue: '<p>Net 30, company terms</p>',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

TextButton _saveAsDefault(WidgetTester tester) => tester.widget<TextButton>(
  find.widgetWithText(TextButton, 'Save as default'),
);

/// A new document shows the cascade default muted under an empty field, the
/// value the server fills on create. React saves an emptied field as
/// `<p><br></p>`, which a clone copies; the server keeps that (`Purify::clean`
/// leaves it, `fillDefaults` fills only an `empty()` value), so the PDF has no
/// terms and the field must not claim it does.
void main() {
  testWidgets('an empty value shows the default', (tester) async {
    await _pump(tester, '');
    expect(find.text(_caption), findsOneWidget);
    expect(_saveAsDefault(tester).onPressed, isNull);
  });

  testWidgets('blank markup shows no default, and still cannot be saved as '
      'the default', (tester) async {
    await _pump(tester, '<p><br></p>');
    expect(find.text(_caption), findsNothing);
    // Saving it would clear the company's terms all the same.
    expect(_saveAsDefault(tester).onPressed, isNull);
  });

  testWidgets('real text shows no default and can be saved', (tester) async {
    await _pump(tester, '<p>Due on receipt</p>');
    expect(find.text(_caption), findsNothing);
    expect(_saveAsDefault(tester).onPressed, isNotNull);
  });
}
