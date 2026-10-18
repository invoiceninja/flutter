import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/billing_shared/email/recipient_email_fix.dart';

import '../../../../_localization_helper.dart';

/// The add-email dialog used to own nothing: its caller made the controller,
/// awaited `showDialog`, and disposed it. That future resolves as the route
/// pops — before its exit transition — so the autofocused field was still
/// mounted, with a live input connection, behind a disposed controller. Losing
/// focus clears an IME word's composing range through that controller, which
/// asserted in debug on any touch device mid-word.
void main() {
  /// Pumps a button that opens the dialog; [onResult] gets what it returns.
  Future<void> pumpOpener(
    WidgetTester tester,
    ValueChanged<String?> onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult(
                await showAddContactEmailDialog(context, contactLabel: 'Jane'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Cancel while a word is composing throws nothing', (
    tester,
  ) async {
    String? result = 'unset';
    await pumpOpener(tester, (r) => result = r);

    // The field autofocused, so the IME is attached: start composing a word.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'jane',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 0, end: 4),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Save returns the trimmed address', (tester) async {
    String? result;
    await pumpOpener(tester, (r) => result = r);

    await tester.enterText(find.byType(TextField), '  jane@acme.test ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, 'jane@acme.test');
  });
}
