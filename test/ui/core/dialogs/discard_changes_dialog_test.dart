import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';

import '../../../_localization_helper.dart';

void main() {
  // U4: the discard dialog is reachable via an Enter-driven navigation (e.g.
  // the command palette's onSubmitted → go → the edit route's onExit guard).
  // Buttons activate on Enter key-down INCLUDING repeats, so a held/repeated
  // Enter must not fall on the destructive "Discard". The safe "Keep editing"
  // is autofocused instead; Discard needs an explicit click.
  testWidgets('Enter activates the safe "Keep editing", not the destructive '
      'Discard', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDiscardChangesDialog(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      result,
      isFalse,
      reason: 'Enter must Keep editing (false), never Discard (true)',
    );
    expect(find.byType(AlertDialog), findsNothing, reason: 'dialog closed');
  });
}
