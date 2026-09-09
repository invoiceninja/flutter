import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';

import 'package:admin/app/services.dart';
import 'package:provider/provider.dart';

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

  // The four tests below pass neither `clientId:` nor `vendorId:`, which is
  // what keeps them valid on `PhoneActionsTestServices` — that stub's
  // `noSuchMethod` throws, so `promptLogCallFor` must not touch
  // `services.clients` / `.vendors` outside the branch a caller opts into.
  // The party-resolution group at the bottom uses the real shell fixture.

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
  group('the party behind a record', () {
    // invoiceninja/flutter#129: a document carries only a `clientId` /
    // `vendorId`, so `promptLogCallFor` resolves the party itself and hands its
    // contacts to the sheet. Before this only Client and Vendor passed a
    // candidate list — every document opened the form with a blank Contact
    // field and no picker icon, and nothing failed.
    final acme = Client.fromApi(
      const ClientApi(
        id: 'cl1',
        displayName: 'Acme Corporation',
        contacts: [
          ContactApi(
            id: 'ct1',
            firstName: 'Jane',
            lastName: 'Smith',
            isPrimary: true,
          ),
        ],
      ),
    );
    final supplies = Vendor.fromApi(
      const VendorApi(
        id: 'vn1',
        name: 'Acme Supplies',
        contacts: [
          VendorContactApi(
            id: 'vc1',
            firstName: 'Ada',
            lastName: 'Byron',
            isPrimary: true,
          ),
        ],
      ),
    );

    String contactText(WidgetTester tester) => tester
        .widget<TextField>(find.widgetWithText(TextField, 'Contact').first)
        .controller!
        .text;

    late PhoneActionsTestServices services;

    Future<void> openFor(
      WidgetTester tester, {
      String? clientId,
      String? vendorId,
      bool clientHydratesOnEnsureLoaded = false,
      bool clientWatchError = false,
    }) async {
      services = PhoneActionsTestServices(
        client: acme,
        vendor: supplies,
        clientHydratesOnEnsureLoaded: clientHydratesOnEnsureLoaded,
        clientWatchError: clientWatchError,
      );
      await tester.pumpWidget(
        Provider<Services>.value(
          value: services,
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => promptLogCallFor(
                    context,
                    companyId: 'co',
                    entityId: 'inv1',
                    subject: '#0064',
                    clientId: clientId,
                    vendorId: vendorId,
                    submit: (t) async => submitted = t,
                  ),
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

    testWidgets('a clientId seeds the contact and offers the picker', (
      tester,
    ) async {
      await openFor(tester, clientId: 'cl1');

      expect(contactText(tester), 'Jane Smith');
      expect(find.byIcon(Icons.contacts_outlined), findsOneWidget);
    });

    testWidgets('a vendorId wins over a clientId on the same record', (
      tester,
    ) async {
      // Expenses, recurring expenses and purchase orders carry both.
      await openFor(tester, vendorId: 'vn1', clientId: 'cl1');

      expect(contactText(tester), 'Ada Byron');

      // And the resolved party — not the record's `subject` — heads the
      // picker. Without this the other half of the fix is unpinned on this
      // seam: reverting `partyName: party.name` to `partyName: subject` puts
      // "Call #0064" back with every other test still green.
      await tester.tap(find.byIcon(Icons.contacts_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Acme Supplies'), findsOneWidget);
      expect(find.text('Call #0064'), findsNothing);
    });

    testWidgets('an unresolvable vendorId never falls through to the client', (
      tester,
    ) async {
      // Falling through would file the client's contact against a
      // vendor-facing record, into a note that is append-only and permanent.
      await openFor(tester, vendorId: 'nope', clientId: 'cl1');

      expect(contactText(tester), isEmpty);
      expect(find.byIcon(Icons.contacts_outlined), findsNothing);
    });

    testWidgets('a party missing from Drift is hydrated, then seeds', (
      tester,
    ) async {
      // The bounded hydrate: first read misses, `ensureLoaded` populates, the
      // second read hits. Reachable in the field on a wide table whose Client
      // and money columns are all hidden, or a narrow recurring-expense row —
      // see `_kPartyHydrateBudget`. Nothing else exercises it.
      await openFor(
        tester,
        clientId: 'cl1',
        clientHydratesOnEnsureLoaded: true,
      );

      expect(contactText(tester), 'Jane Smith');
      expect(find.byIcon(Icons.contacts_outlined), findsOneWidget);
      // Once, not per read — the hydrate sits behind the miss, not in front of
      // every lookup.
      expect(services.clientEnsureLoadedCalls, 1);
    });

    testWidgets('a failing party lookup still opens the form', (tester) async {
      // `promptLogCallFor` runs as a fire-and-forget `onLogCall`, so an
      // escaping drift-stream error would swallow the tap entirely — no sheet,
      // no toast, nothing. It must degrade to the pre-#129 rendering instead.
      await openFor(tester, clientId: 'cl1', clientWatchError: true);

      expect(find.widgetWithText(TextField, 'Summary'), findsOneWidget);
      expect(contactText(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty party id is not a party', (tester) async {
      // `clientId: x.clientId` where the field is blank is the lint's first
      // acknowledged blind spot, so pin the runtime behaviour instead: no
      // repository is touched at all, which the throwing stub would prove by
      // failing this test.
      await openFor(tester, clientId: '');

      expect(find.widgetWithText(TextField, 'Summary'), findsOneWidget);
      expect(contactText(tester), isEmpty);
      expect(services.clientEnsureLoadedCalls, 0);
    });

    testWidgets('an unresolvable party still opens the form', (tester) async {
      // The seed is a convenience; the field is free text and the note must
      // still be writable. Degrades to the pre-#129 rendering, never a dead tap.
      await openFor(tester, clientId: 'nope');

      expect(find.widgetWithText(TextField, 'Summary'), findsOneWidget);
      expect(contactText(tester), isEmpty);
      expect(find.byIcon(Icons.contacts_outlined), findsNothing);
    });
  });
}
