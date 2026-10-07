import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/party_contact_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_contacts_card.dart';

import '../../../../../_localization_helper.dart';
import '../../../../../_support/phone_actions_test_services.dart';

/// The vendor record screen's Contacts card.
///
/// invoiceninja/flutter#115: a vendor carries an all-blank contact the user
/// never filled in, so `contacts.isEmpty` is never the question — the card
/// used to render that row as `(no name)` beside a primary star.
///
/// Each row is a `PartyContactRow` now, the same row a client's contacts get:
/// the first two actions that apply are icon buttons, the rest sit behind `⋮`.
void main() {
  late PhoneActionsTestServices services;

  VendorContact contact({
    String id = 'vc1',
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String link = '',
    String customValue1 = '',
    bool isPrimary = false,
    bool ccOnly = false,
    bool isDeleted = false,
  }) => VendorContact.fromApi(
    VendorContactApi(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      link: link,
      customValue1: customValue1,
      isPrimary: isPrimary,
      ccOnly: ccOnly,
      isDeleted: isDeleted,
    ),
  );

  /// The row the server seeds and the user never touches.
  VendorContact blank() => contact(isPrimary: true);

  /// A contact whose ONLY content is the address the **server** minted when it
  /// first reached the vendor portal (`Str::random(15) . '@example.com'`) —
  /// blanked by `VendorContact.fromApi` (invoiceninja/flutter#116).
  VendorContact placeholderOnly({
    String email = 'dq9GHaI6Dncm0Zd@example.com',
  }) => contact(email: email, isPrimary: true);

  Future<void> pump(WidgetTester tester, List<VendorContact> contacts) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: VendorDetailContactsCard(
                contacts: contacts,
                vendorId: 'v1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => services = PhoneActionsTestServices());

  group('hasContent', () {
    test('no contacts at all', () {
      expect(VendorDetailContactsCard.hasContent(const []), isFalse);
    });

    test('only the seeded blank contact', () {
      expect(VendorDetailContactsCard.hasContent([blank()]), isFalse);
    });

    test('a named contact beside the blank one', () {
      expect(
        VendorDetailContactsCard.hasContent([
          blank(),
          contact(firstName: 'Ada'),
        ]),
        isTrue,
      );
    });

    test('whitespace-only fields are still blank', () {
      expect(
        VendorDetailContactsCard.hasContent([
          contact(firstName: '   ', email: ' '),
        ]),
        isFalse,
      );
    });

    test('a server-minted portal placeholder is not content', () {
      expect(VendorDetailContactsCard.hasContent([placeholderOnly()]), isFalse);
    });

    test('a REAL example.com address is still content', () {
      // Every contact in the seeded demo dataset lives at example.com; a
      // blanket rule would empty this card across the public demo build.
      expect(
        VendorDetailContactsCard.hasContent([
          placeholderOnly(email: 'cboyle@example.com'),
        ]),
        isTrue,
        reason: 'real contact in the demo dataset',
      );
    });

    test('a deleted contact is not this vendor\'s contact any more', () {
      expect(
        VendorDetailContactsCard.hasContent([
          contact(firstName: 'Ada', isDeleted: true),
        ]),
        isFalse,
      );
    });

    test('a custom value counts only once the company has labelled it', () {
      // The row prints a contact custom field only under a configured label.
      // With no company to say there is one, a contact holding nothing else
      // would be a row reading `(no name)`.
      expect(
        VendorDetailContactsCard.hasContent([contact(customValue1: 'VIP')]),
        isFalse,
      );
    });
  });

  testWidgets('a vendor whose only contact is blank shows no card', (
    tester,
  ) async {
    await pump(tester, [blank()]);

    expect(find.text('(no name)'), findsNothing);
    expect(find.text('Contacts'), findsNothing);
    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets(
    'a named contact keeps its name but never shows the minted email',
    (tester) async {
      await pump(tester, [
        contact(firstName: 'Jimmy', email: 'dq9GHaI6Dncm0Zd@example.com'),
      ]);

      expect(find.text('Jimmy'), findsOneWidget);
      expect(find.textContaining('@example.com'), findsNothing);
      // …and with no address there is nothing for an Email button to write to.
      expect(find.byTooltip('Email'), findsNothing);
    },
  );

  testWidgets('a contact whose only email was minted shows no card', (
    tester,
  ) async {
    await pump(tester, [placeholderOnly()]);

    expect(find.byType(DashboardCardShell), findsNothing);
    expect(find.text('(no name)'), findsNothing);
  });

  testWidgets('several blank contacts still show no card', (tester) async {
    await pump(tester, [blank(), contact(), contact()]);

    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('a blank contact is dropped, the real one is kept', (
    tester,
  ) async {
    await pump(tester, [
      blank(),
      contact(firstName: 'Ada', lastName: 'Lovelace'),
    ]);

    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('(no name)'), findsNothing);
    // One surviving row ⇒ `DetailRowStack` emits no divider.
    expect(find.byType(DetailRowDivider), findsNothing);
  });

  testWidgets('an email-only contact survives and titles itself', (
    tester,
  ) async {
    await pump(tester, [contact(email: 'ada@example.com')]);

    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('(no name)'), findsNothing);
    expect(find.byTooltip('Email'), findsOneWidget);
  });

  testWidgets('a phone-only contact survives, still titled (no name), and '
      'can be rung', (tester) async {
    // The predicate is "nothing to show", not "has a name" — a number with no
    // name attached is a real contact, and the `no_name_fallback` title cascade
    // is still what gives its row a heading.
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(phone: '+1 415 555 2672')]);

    expect(find.text('(no name)'), findsOneWidget);
    expect(find.byTooltip('Call'), findsOneWidget);
  });

  testWidgets('with tap-to-call off there is no Call button', (tester) async {
    await services.phoneActions.setTapToCall(false);
    await pump(tester, [contact(firstName: 'Ada', phone: '+1 415 555 2672')]);

    expect(find.text('Ada'), findsOneWidget);
    expect(find.byTooltip('Call'), findsNothing);
  });

  testWidgets('a portal link alone does not keep a blank contact', (
    tester,
  ) async {
    // Regression lock: the server mints a link for the seeded contact too, so
    // counting `link` would filter nothing. The portal stays reachable from
    // the vendor actions menu.
    await pump(tester, [contact(link: 'https://portal.example.com/abc')]);

    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('the primary star alone does not keep a blank contact', (
    tester,
  ) async {
    await pump(tester, [contact(isPrimary: true)]);

    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('the first two actions that apply are buttons; the portal is '
      'named for what it is', (tester) async {
    // No phone, so Email and the portal link are the two — the pair a desktop
    // user wants from a contact.
    await pump(tester, [
      contact(
        firstName: 'Ada',
        email: 'ada@acme.test',
        link: 'https://portal.example.com/vendor/key_login/abc',
      ),
    ]);

    expect(find.byTooltip('Email'), findsOneWidget);
    // Not a bare "Copy Link": the record's own menu has one of those, and it
    // copies a link to this screen.
    expect(find.byTooltip('Vendor Portal: Copy Link'), findsOneWidget);
    // View Portal is the third, behind the row's `⋮`.
    expect(find.text('View Portal'), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('View Portal'), findsOneWidget);
  });

  testWidgets('a contact with no portal link offers no portal action', (
    tester,
  ) async {
    await pump(tester, [contact(firstName: 'Ada', email: 'ada@acme.test')]);

    expect(find.byTooltip('Email'), findsOneWidget);
    expect(find.byTooltip('Vendor Portal: Copy Link'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('a CC-only contact says so', (tester) async {
    await pump(tester, [
      contact(firstName: 'Accounts', email: 'ap@acme.test', ccOnly: true),
    ]);

    expect(find.byType(PartyContactPill), findsOneWidget);
    expect(find.text('CC Only'), findsOneWidget);
  });

  testWidgets('more than three contacts: the rest open in place, and close '
      'again', (tester) async {
    await pump(tester, [
      for (var i = 1; i <= 5; i++) contact(id: 'c$i', firstName: 'Contact $i'),
    ]);

    expect(find.text('Contact 3'), findsOneWidget);
    expect(find.text('Contact 4'), findsNothing);
    expect(find.text('+2 more'), findsOneWidget);

    await tester.tap(find.text('+2 more'));
    await tester.pump();
    expect(find.text('Contact 5'), findsOneWidget);
    expect(find.text('+2 more'), findsNothing);

    // An expansion has to be undoable.
    await tester.tap(find.text('Less'));
    await tester.pump();
    expect(find.text('Contact 4'), findsNothing);
    expect(find.text('+2 more'), findsOneWidget);
  });

  testWidgets('three contacts need no "more"', (tester) async {
    await pump(tester, [
      for (var i = 1; i <= 3; i++) contact(id: 'c$i', firstName: 'Contact $i'),
    ]);

    expect(find.text('Contact 3'), findsOneWidget);
    expect(find.textContaining('more'), findsNothing);
    expect(find.text('Less'), findsNothing);
  });

  testWidgets('"+N more" counts only contacts that would draw a row', (
    tester,
  ) async {
    // Four real ones and two blanks: one is hidden, not three.
    await pump(tester, [
      blank(),
      for (var i = 1; i <= 4; i++) contact(id: 'c$i', firstName: 'Contact $i'),
      contact(id: 'b2'),
    ]);

    expect(find.text('+1 more'), findsOneWidget);
  });
}
