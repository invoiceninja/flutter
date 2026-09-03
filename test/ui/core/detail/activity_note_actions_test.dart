import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';

import '../../../_localization_helper.dart';
import '../../../_support/phone_actions_test_services.dart';

/// The single implementation behind every note-writing entry point — all ten
/// `⋯` menu arms and all nine Activity-tab buttons now route through here, so
/// this is the one place the whole path can be exercised without building ten
/// repositories.
///
/// Before this existed, the ten arms hand-rolled the sequence and disagreed:
/// five skipped the success toast, three skipped `requireSynced`.
void main() {
  String? submitted;

  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(BuildContext) run,
  ) async {
    submitted = null;
    await tester.pumpWidget(
      withPhoneActionsServices(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => run(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  Future<void> drainToasts(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 7));

  testWidgets('a logged call submits a marker-bearing note', (tester) async {
    // The end-to-end contract the ten action arms depend on: whatever the sheet
    // composes reaches `repo.addComment` unchanged, and it is recognisable as a
    // call afterwards (which is what drives the row icon and the Calls lens).
    await pump(
      tester,
      (context) => promptLogCallFor(
        context,
        companyId: 'co',
        entityId: 'c1',
        subject: 'Acme Corp',
        submit: (t) async => submitted = t,
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Summary'),
      'They will pay Friday',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(isCallNoteText(submitted!), isTrue);
    expect(submitted, endsWith('\nThey will pay Friday'));
    await drainToasts(tester);
  });

  testWidgets('an unsynced record is gated before the form opens', (
    tester,
  ) async {
    // `StoreNoteRequest` validates `entity_id` with `Rule::exists`, so a `tmp_`
    // id is a hard server rejection and the outbox row burns its retries.
    // Three arms used to skip this gate entirely.
    await pump(
      tester,
      (context) => promptLogCallFor(
        context,
        companyId: 'co',
        entityId: 'tmp_abc',
        subject: 'Acme Corp',
        submit: (t) async => submitted = t,
      ),
    );

    expect(find.widgetWithText(TextField, 'Summary'), findsNothing);
    expect(submitted, isNull);
    await drainToasts(tester);
  });

  testWidgets('add comment is gated the same way and submits the raw text', (
    tester,
  ) async {
    await pump(
      tester,
      (context) => promptAddCommentFor(
        context,
        entityId: 'c1',
        submit: (t) async => submitted = t,
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Comment'),
      'Chasing this up',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(submitted, 'Chasing this up');
    // A typed comment must NOT look like a call — the marker is the only thing
    // separating them.
    expect(isCallNoteText(submitted!), isFalse);
    await drainToasts(tester);
  });

  testWidgets('cancelling submits nothing', (tester) async {
    await pump(
      tester,
      (context) => promptAddCommentFor(
        context,
        entityId: 'c1',
        submit: (t) async => submitted = t,
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
  });
}
