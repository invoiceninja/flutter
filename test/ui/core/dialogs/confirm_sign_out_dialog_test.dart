import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';

import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

import '../../../_localization_helper.dart';

/// Contract for the shared sign-out gate, in front of all six surfaces that
/// end a session:
///   * confirm ⇒ true; Cancel, Escape and a barrier dismiss ⇒ false (never
///     null — every caller treats the result as a bare bool);
///   * `subject` names the account, and a blank one adds no empty line;
///   * an overridden `title` also labels the confirm button, so End all
///     sessions doesn't offer a button reading "Sign out";
///   * `destructive: true` colours that button with `colorScheme.error`;
///   * **Cancel holds the focus and the confirm button never does** — a
///     logout wipes every company's local DB, so a stray Enter must not
///     complete it. The dialog this replaced had that backwards.
void main() {
  // `read` is a closure rather than a captured value: it must be evaluated
  // AFTER the dialog resolves, which is the whole assertion.
  late bool? Function() read;

  Future<void> open(
    WidgetTester tester, {
    String? title,
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
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showConfirmSignOutDialog(
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
    read = () => result;
  }

  // This is the invariant, and it is a fix rather than a preservation: the
  // dialog this replaces (inline in SettingsActions.signOut) took
  // PrimaryDialogAction's defaults, so it autofocused the sign-out button AND
  // advertised Enter. A held Enter — the setup wizard's Log out sits right
  // after a field whose Enter submits the form — wiped the local DB.
  testWidgets('Enter activates the safe Cancel, never the sign-out', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Sign out?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(read(), isFalse, reason: 'Enter must cancel, never sign out');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('a barrier dismiss reads as No, not null', (tester) async {
    await open(tester);
    // Tap the barrier, well clear of the dialog.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(read(), isFalse, reason: 'the `?? false` must absorb a dismiss');
  });

  testWidgets('the confirm returns true', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(read(), isTrue);
  });

  testWidgets('subject names the account under the message', (tester) async {
    await open(tester, subject: 'owner@example.com');
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(
      find.textContaining('removed from this device'),
      findsOneWidget,
      reason: 'the default body still renders alongside the subject',
    );
  });

  testWidgets('a blank subject adds no empty line', (tester) async {
    await open(tester, subject: '   ');
    expect(find.text('   '), findsNothing);
  });

  // End all sessions passes a title; it must reach the button too, or the
  // confirm reads "Sign out" for an action that ends everyone's session.
  testWidgets('an overridden title also labels the confirm button', (
    tester,
  ) async {
    await open(
      tester,
      title: 'End All Sessions',
      message: 'Everyone gets signed out.',
      destructive: true,
    );
    expect(find.text('Everyone gets signed out.'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'End All Sessions'),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsNothing);

    final action = tester.widget<PrimaryDialogAction>(
      find.byType(PrimaryDialogAction),
    );
    expect(action.variant, DialogActionVariant.destructive);
  });

  testWidgets('the default is not destructive-coloured', (tester) async {
    // Red is reserved for the wide blast radius. An ordinary sign-out clears
    // a local cache the next login re-downloads.
    await open(tester);
    final action = tester.widget<PrimaryDialogAction>(
      find.byType(PrimaryDialogAction),
    );
    expect(action.variant, DialogActionVariant.primary);
  });
}
