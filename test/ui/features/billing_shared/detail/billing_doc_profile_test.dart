import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/widgets/party_contact_row.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_notes.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';

import '../../../../_localization_helper.dart';
import '_billing_doc_fixtures.dart';

const PartyContacts _contacts = {
  'k1': (name: 'Jane Doe', email: 'jane@acme.example.com'),
  'k2': (name: 'Sam Lee', email: ''),
  // The contact the server seeds for every client: nothing in it.
  'k3': (name: '', email: ' '),
};

Invoice _invoice([Map<String, dynamic> overrides = const {}]) =>
    Invoice.fromApi(InvoiceApi.fromJson({...docJson(), ...overrides}));

Future<void> _pump(WidgetTester tester, double width, Widget child) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('billingDocRecipients', () {
    test(
      'an invitation is a row when its contact has a name or an address',
      () {
        final invoice = _invoice();
        final rows = billingDocRecipients(invoice.invitations, _contacts);
        expect([for (final r in rows) r.name], ['Jane Doe', 'Sam Lee']);
        expect(rows.first.email, 'jane@acme.example.com');
        expect(rows.first.invitation.link, kPortalLink);
      },
    );

    test('the server\'s blank contact is not, though it has an invitation', () {
      // `invitations.isNotEmpty` is the wrong question in the other
      // direction here: three invitations, two people.
      final invoice = _invoice();
      expect(invoice.invitations, hasLength(3));
      expect(
        billingDocRecipients(invoice.invitations, _contacts),
        hasLength(2),
      );
    });

    test('a contact that is gone from the party drops out', () {
      final rows = billingDocRecipients(_invoice().invitations, const {
        'k2': (name: 'Sam Lee', email: ''),
      });
      expect([for (final r in rows) r.name], ['Sam Lee']);
    });

    test('nothing resolved yet is nothing to show, not a row per id', () {
      expect(billingDocRecipients(_invoice().invitations, const {}), isEmpty);
    });
  });

  group('the Contacts card', () {
    Future<void> pumpCard(WidgetTester tester, Invitation invitation) => _pump(
      tester,
      480,
      BillingDocContactsCard(
        type: BillingDocType.invoice,
        recipients: [
          BillingDocRecipient(
            invitation: invitation,
            name: 'Jane Doe',
            email: 'jane@acme.example.com',
          ),
        ],
      ),
    );

    testWidgets('a copy that bounced says so, whatever else is true of it', (
      tester,
    ) async {
      // A bounce is the answer to "why have they not paid"; that the link
      // was also opened once must not paint over it.
      await pumpCard(
        tester,
        const Invitation(
          link: kPortalLink,
          sentDate: '2000-01-02',
          viewedDate: '2000-01-03',
          emailStatus: 'bounced',
        ),
      );
      expect(find.text('Bounced'), findsOneWidget);
      expect(find.text('Viewed'), findsNothing);
    });

    testWidgets('otherwise the furthest it got: viewed over delivered', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const Invitation(
          link: kPortalLink,
          sentDate: '2000-01-02',
          viewedDate: '2000-01-03',
          emailStatus: 'delivered',
        ),
      );
      expect(find.text('Viewed'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('a document not sent to them yet carries no pill', (
      tester,
    ) async {
      await pumpCard(tester, const Invitation(link: kPortalLink));
      expect(find.text('Jane Doe'), findsOneWidget);
      for (final label in ['Sent', 'Viewed', 'Delivered', 'Opened']) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('a long list shows three, and the rest one tap away — and '
        'back', (tester) async {
      await _pump(
        tester,
        480,
        BillingDocContactsCard(
          type: BillingDocType.invoice,
          recipients: [
            for (var i = 1; i <= 5; i++)
              BillingDocRecipient(
                invitation: const Invitation(link: kPortalLink),
                name: 'Person $i',
                email: '',
              ),
          ],
        ),
      );
      expect(find.byType(PartyContactRow), findsNWidgets(3));
      expect(find.text('Person 4'), findsNothing);
      await tester.tap(find.text('+2 more'));
      await tester.pump();
      expect(find.byType(PartyContactRow), findsNWidgets(5));
      await tester.tap(find.text('Less'));
      await tester.pump();
      expect(find.byType(PartyContactRow), findsNWidgets(3));
    });

    testWidgets('no link yet, no link buttons', (tester) async {
      // A document created offline has invitations with no portal page.
      await pumpCard(tester, const Invitation());
      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('layout', () {
    Widget profile(Invoice invoice) => BillingDocProfile(
      type: BillingDocType.invoice,
      doc: invoice,
      company: null,
      contacts: _contacts,
    );

    testWidgets('narrow: one stack — Contacts, Details, Private Notes', (
      tester,
    ) async {
      await _pump(tester, 480, profile(_invoice()));
      final contacts = tester.getRect(find.byType(BillingDocContactsCard));
      final details = tester.getRect(find.byType(BillingDocDetailsCard));
      final notes = tester.getRect(find.byType(BillingDocPrivateNotesCard));
      expect(details.top, greaterThan(contacts.bottom));
      expect(notes.top, greaterThan(details.bottom));
      expect(details.left, contacts.left);
      expect(details.width, contacts.width);
    });

    testWidgets('wide: Contacts and Details are equal cards that end on one '
        'line, with the note full width under them', (tester) async {
      await _pump(tester, 1200, profile(_invoice()));
      final contacts = tester.getRect(find.byType(BillingDocContactsCard));
      final details = tester.getRect(find.byType(BillingDocDetailsCard));
      final notes = tester.getRect(find.byType(BillingDocPrivateNotesCard));
      expect(details.top, contacts.top);
      expect(details.left, greaterThan(contacts.right));
      expect(details.width, moreOrLessEquals(contacts.width, epsilon: 0.5));
      // Two contacts against one row of details: the shorter card stretches.
      expect(details.bottom, moreOrLessEquals(contacts.bottom, epsilon: 0.5));
      expect(notes.top, greaterThan(contacts.bottom));
      expect(notes.left, contacts.left);
      expect(notes.right, moreOrLessEquals(details.right, epsilon: 0.5));
    });

    testWidgets('a section with nothing in it costs no card and no gap', (
      tester,
    ) async {
      await _pump(
        tester,
        480,
        Column(
          children: [
            profile(_invoice({'po_number': '', 'private_notes': '<p></p>'})),
            const Text('AFTER'),
          ],
        ),
      );
      expect(find.byType(BillingDocDetailsCard), findsNothing);
      // Markup that renders as nothing is not a note.
      expect(find.byType(BillingDocPrivateNotesCard), findsNothing);
      final contacts = tester.getRect(find.byType(BillingDocContactsCard));
      expect(tester.getTopLeft(find.text('AFTER')).dy, contacts.bottom);
    });

    testWidgets('wide with only one lead card: it is not left half-width', (
      tester,
    ) async {
      await _pump(
        tester,
        1200,
        profile(_invoice({'po_number': '', 'private_notes': ''})),
      );
      expect(
        tester.getSize(find.byType(BillingDocContactsCard)).width,
        greaterThan(1000),
      );
      expect(find.byType(PartyContactRow), findsNWidgets(2));
    });
  });

  group('the Details card', () {
    testWidgets('holds what is set, and no row for what is not', (
      tester,
    ) async {
      await _pump(
        tester,
        480,
        BillingDocDetailsCard(
          type: BillingDocType.invoice,
          doc: _invoice(),
          company: null,
          extraRows: const [Text('HOST ROW')],
        ),
      );
      expect(find.text('PO Number'), findsOneWidget);
      expect(find.text('PO-7781'), findsOneWidget);
      expect(find.text('HOST ROW'), findsOneWidget);
      expect(find.text('Discount'), findsNothing);
      expect(find.text('Exchange Rate'), findsNothing);
      expect(find.text('Assigned User'), findsNothing);
      // A document's own date is in its header and its history is on its
      // tabs; the card does not pad itself out with timestamps.
      expect(find.text('Date Created'), findsNothing);
    });

    testWidgets('a purchase order\'s number is its PO number — no second row', (
      tester,
    ) async {
      await _pump(
        tester,
        480,
        BillingDocDetailsCard(
          type: BillingDocType.purchaseOrder,
          doc: _invoice(),
          company: null,
        ),
      );
      expect(find.text('PO Number'), findsNothing);
    });
  });

  group('the date a document is held to', () {
    test('a deposit\'s due date stands in for the document\'s own', () {
      final invoice = _invoice({
        'partial': '100',
        'partial_due_date': '2500-06-01',
      });
      expect(
        billingDocEffectiveDue(BillingDocType.invoice, invoice),
        const Date(2500, 6, 1),
      );
    });

    test('but not on a quote, whose second date is how long it is valid', () {
      final invoice = _invoice({
        'partial': '100',
        'partial_due_date': '2500-06-01',
      });
      expect(
        billingDocEffectiveDue(BillingDocType.quote, invoice),
        const Date(2999, 1, 1),
      );
    });

    test('a document with no number has no subject, not a bare "#"', () {
      expect(billingDocSubject(_invoice()), '#0042');
      expect(billingDocSubject(_invoice({'number': ''})), '');
    });
  });
}
