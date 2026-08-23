import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

import '../../../_localization_helper.dart';

/// Contract for the shared "Are you sure?" gate (invoiceninja/flutter#49):
///   * confirm ⇒ true, Cancel / barrier dismiss ⇒ false;
///   * the title doubles as the confirm button's label, so the button restates
///     the verb instead of a bare "OK";
///   * `subject` names the record, and a blank one adds no empty line;
///   * `destructive: true` colours the confirm button with `colorScheme.error`;
///   * **Cancel holds the focus, the confirm button never does** — the dialog
///     exists to catch an accidental activation, so a stray Enter must not
///     complete the very action being guarded.
Future<bool?> _open(
  WidgetTester tester, {
  String title = 'Approve',
  String? message,
  String? subject,
  bool destructive = false,
}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showConfirmActionDialog(
                context,
                title: title,
                message: message,
                subject: subject,
                destructive: destructive,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('confirming returns true', (tester) async {
    await _open(tester);
    expect(find.text('Are you sure?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await tester.pumpAndSettle();

    // The dialog closed and the future completed with true.
    expect(find.text('Are you sure?'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'open'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the confirm button restates the action verb', (tester) async {
    await _open(tester, title: 'Mark Sent');
    expect(find.widgetWithText(FilledButton, 'Mark Sent'), findsOneWidget);
    expect(find.text('Mark Sent'), findsNWidgets(2)); // title + button
  });

  testWidgets('cancel closes without confirming', (tester) async {
    await _open(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure?'), findsNothing);
  });

  testWidgets('subject names the record under the message', (tester) async {
    await _open(tester, subject: 'Acme Corp');
    expect(find.text('Acme Corp'), findsOneWidget);
  });

  testWidgets('a whitespace-only subject renders no extra line', (
    tester,
  ) async {
    await _open(tester, subject: '   ');
    expect(find.text('   '), findsNothing);
    expect(find.text('Are you sure?'), findsOneWidget);
  });

  testWidgets('a long multi-line subject is clamped, not overflowed', (
    tester,
  ) async {
    // Task subjects are `task.description` and bank-transaction subjects are
    // the full bank memo — both routinely long and multi-line. `AlertDialog`
    // puts `content` in a `Flexible`, so without the clamp this same subject
    // overflows a phone-sized dialog by ~1900px (measured).
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final long = List.filled(60, 'a very long task description line').join(' ');
    await _open(tester, title: 'Archive', subject: long);

    expect(tester.takeException(), isNull, reason: 'must not overflow');
    final subject = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.startsWith('a very long task') ?? false),
      ),
    );
    expect(subject.maxLines, 2);
    expect(subject.overflow, TextOverflow.ellipsis);
  });

  testWidgets('an explicit message overrides the are_you_sure default', (
    tester,
  ) async {
    await _open(tester, message: 'Are you sure you want this invoice emailed?');
    expect(find.text('Are you sure?'), findsNothing);
    expect(
      find.text('Are you sure you want this invoice emailed?'),
      findsOneWidget,
    );
  });

  testWidgets('destructive uses the error-coloured confirm', (tester) async {
    await _open(tester, title: 'Delete', destructive: true);
    final action = tester.widget<PrimaryDialogAction>(
      find.byType(PrimaryDialogAction),
    );
    expect(action.variant, DialogActionVariant.destructive);
  });

  testWidgets('Cancel takes focus and the confirm advertises no Enter', (
    tester,
  ) async {
    // Regression guard: a stray Enter (or the tail of a rapid double-tap) must
    // land on Cancel, never on the guarded action.
    await _open(tester, title: 'Archive');
    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    final confirm = tester.widget<PrimaryDialogAction>(
      find.byType(PrimaryDialogAction),
    );
    expect(cancel.autofocus, isTrue);
    expect(confirm.autofocus, isFalse);
    expect(confirm.showEnterHint, isFalse);
  });
}
