import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_contacts_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

import '../../../_localization_helper.dart';
import '../../../_support/phone_actions_test_services.dart';

/// The Call / Message pair on a contact row reads the tap-to-call preference,
/// and the row that builds it is NOT the widget that owns the listener — so
/// "does it restyle in place" is the assertion that matters here. The number
/// itself carries its own `PhoneActionsScope`; the buttons are built one level
/// up, which is exactly where a stale read hides.
void main() {
  late PhoneActionsTestServices services;

  Contact contact({
    String id = 'ct1',
    String firstName = 'Jane',
    String lastName = 'Smith',
    String email = 'jane@acme.example.com',
    String phone = '+1 415 555 2672',
    String link = '',
    String customValue1 = '',
    bool isPrimary = false,
  }) => Contact.fromApi(
    ContactApi(
      id: id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      link: link,
      customValue1: customValue1,
      isPrimary: isPrimary,
    ),
  );

  /// The all-blank row the server creates for every client.
  ///
  /// [email] defaults to a **single space**, which is what
  /// `ClientContactRepository::save` actually writes (`$new_contact->email =
  /// ' ';`) — nothing between the wire and `Contact` trims it, so this is the
  /// shape production sends and the reason `isBlank` trims.
  Contact blank({
    String id = 'blank',
    String email = ' ',
    String link = '',
    String customValue1 = '',
  }) => contact(
    id: id,
    firstName: '',
    lastName: '',
    email: email,
    phone: '',
    link: link,
    customValue1: customValue1,
    isPrimary: true,
  );

  /// [n] real contacts, named `Person 1`… so "+N more" can be counted.
  List<Contact> people(int n) => [
    for (var i = 1; i <= n; i++)
      contact(id: 'ct$i', firstName: 'Person', lastName: '$i'),
  ];

  Future<void> pump(WidgetTester tester, List<Contact> contacts) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
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
              child: ClientDetailContactsCard(
                contacts: contacts,
                clientHash: 'hash',
                clientId: 'c1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  setUp(() => services = PhoneActionsTestServices());

  testWidgets('a contact with a phone gets Call and Message', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact()]);

    expect(find.widgetWithText(TextButton, 'Call'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Send SMS'), findsOneWidget);
    expect(find.byType(LinkText), findsOneWidget, reason: 'the number too');
  });

  testWidgets('the buttons show without a portal link', (tester) async {
    // The action `Wrap` used to be gated on `contact.link.isNotEmpty`, back
    // when the only things in it were the two portal buttons. A contact with
    // no portal link must still get Call / Message.
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(link: '')]);

    expect(find.widgetWithText(TextButton, 'View portal'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Call'), findsOneWidget);
  });

  testWidgets('a contact with no phone gets neither', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(phone: '')]);

    expect(find.widgetWithText(TextButton, 'Call'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Send SMS'), findsNothing);
  });

  testWidgets('an undialable number gets neither', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(phone: 'call the office')]);

    expect(find.widgetWithText(TextButton, 'Call'), findsNothing);
    expect(find.byType(LinkText), findsNothing);
  });

  testWidgets('tap-to-call off hides the buttons', (tester) async {
    await services.phoneActions.setTapToCall(false);
    await pump(tester, [contact()]);

    expect(find.widgetWithText(TextButton, 'Call'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Send SMS'), findsNothing);
  });

  testWidgets(
    'flipping the preference removes the buttons from a mounted card',
    (tester) async {
      // The regression: the buttons are built in `_ContactRow.build`, one level
      // above the `PhoneActionsScope` that the number carries. A detail screen
      // stays mounted behind `/settings/**` while the switch is flipped, so a
      // bare read left a live Call button beside a number that had already
      // reverted to plain text — and tapping it still placed the call.
      await services.phoneActions.setTapToCall(true);
      await pump(tester, [contact()]);
      expect(find.widgetWithText(TextButton, 'Call'), findsOneWidget);

      await services.phoneActions.setTapToCall(false);
      await tester.pump();

      expect(find.byType(LinkText), findsNothing, reason: 'number went inert');
      expect(
        find.widgetWithText(TextButton, 'Call'),
        findsNothing,
        reason: 'the button must go inert with it',
      );
    },
  );

  // ─────────── invoiceninja/flutter#115: blank contacts ───────────
  //
  // The API enforces at least one contact per client, so `contacts.isEmpty` is
  // never the question — the seeded all-blank row rendered as `(no name)`.

  group('hasContent', () {
    test('no contacts at all', () {
      expect(ClientDetailContactsCard.hasContent(const []), isFalse);
    });

    test('only the seeded blank contact', () {
      expect(ClientDetailContactsCard.hasContent([blank()]), isFalse);
    });

    test('a whitespace-only email does not count as content', () {
      // The server writes a literal space, so `''` would pass a predicate that
      // this shape fails. Kept as its own case since the fixture default could
      // drift back to `''`.
      expect(ClientDetailContactsCard.hasContent([blank(email: ' ')]), isFalse);
      expect(ClientDetailContactsCard.hasContent([blank(email: '')]), isFalse);
    });

    test('a real contact beside the blank one', () {
      expect(ClientDetailContactsCard.hasContent([blank(), contact()]), isTrue);
    });
  });

  testWidgets('a client whose only contact is blank shows no card', (
    tester,
  ) async {
    await pump(tester, [blank()]);

    expect(find.text('(no name)'), findsNothing);
    expect(find.text('Contacts'), findsNothing);
    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets("the server's space-only email still shows no card", (
    tester,
  ) async {
    // Pre-fix this rendered a row whose title was the space itself — an
    // invisible heading beside the primary star, rather than the `(no name)`
    // a vendor got.
    await pump(tester, [blank(email: ' ')]);

    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('a blank contact is dropped, the real one is kept', (
    tester,
  ) async {
    await pump(tester, [blank(), contact()]);

    expect(find.text('Jane Smith'), findsOneWidget);
    expect(find.text('(no name)'), findsNothing);
    // One surviving row ⇒ `DetailRowStack` emits no divider.
    expect(find.byType(DetailRowDivider), findsNothing);
  });

  testWidgets('a portal link alone does not keep a blank contact', (
    tester,
  ) async {
    // Regression lock: the server mints a link for the seeded contact too, so
    // counting `link` would make this card filter nothing at all. The portal
    // stays reachable from `ClientAction.clientPortal`.
    await pump(tester, [blank(link: 'https://portal.example.com/abc')]);

    expect(find.byType(DashboardCardShell), findsNothing);
    expect(find.widgetWithText(TextButton, 'View portal'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Copy link'), findsNothing);
  });

  testWidgets('a contact custom value alone does not keep a blank contact', (
    tester,
  ) async {
    // React counts contact custom fields because its row renders them; this
    // card doesn't, so a row kept alive by one would paint only `(no name)`.
    await pump(tester, [blank(customValue1: 'VIP')]);

    expect(find.byType(DashboardCardShell), findsNothing);
  });

  testWidgets('"+N more" counts the filtered list, not the raw one', (
    tester,
  ) async {
    // 4 contacts, one of them blank → 3 real ones → exactly the inline limit,
    // so there is nothing to overflow. Before the fix this offered "+1 more"
    // and revealed a row that paints nothing.
    await pump(tester, [blank(), ...people(3)]);

    expect(find.textContaining('more'), findsNothing);
    expect(find.text('Person 3'), findsOneWidget);
  });

  testWidgets('"+N more" still fires, and its sheet is filtered too', (
    tester,
  ) async {
    // 5 contacts, one blank → 4 real → 3 inline + "+1 more".
    //
    // The card picks its overflow presentation from `MediaQuery.sizeOf` (it
    // has to — the grid above it uses `IntrinsicHeight`, which `LayoutBuilder`
    // can't answer). `setSurfaceSize` does NOT move that: `MediaQuery.fromView`
    // reads `view.physicalSize / devicePixelRatio`, which stays at the harness
    // default of 800. Drive the view itself to reach the narrow (bottom-sheet)
    // branch — `_openSheet` re-filters independently of `build`, so this is
    // the only assertion that covers it.
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pump(tester, [blank(), ...people(4)]);
    expect(find.textContaining('more'), findsOneWidget);

    await tester.tap(find.textContaining('more'));
    await tester.pumpAndSettle();

    // The sheet re-renders the title, so two "Contacts" prove it opened. Don't
    // scope by `BottomSheet` — `showModalBottomSheet` doesn't put one in the
    // tree here. Person 4 exists only in the sheet (the card caps at 3).
    expect(find.text('Contacts'), findsNWidgets(2));
    expect(
      find.text('Person 4'),
      findsOneWidget,
      reason: 'the sheet lists every real contact',
    );
    expect(find.text('(no name)'), findsNothing, reason: 'card or sheet');
  });
}
