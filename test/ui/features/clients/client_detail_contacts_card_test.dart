import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
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

  /// A contact whose ONLY content is the address the **server** minted when it
  /// first reached the portal (`Str::random(15) . '@example.com'`) — blanked by
  /// `Contact.fromApi`, so this row carries no user content at all
  /// (invoiceninja/flutter#116).
  Contact placeholderOnly({
    String id = 'minted',
    String email = 'dq9GHaI6Dncm0Zd@example.com',
  }) => contact(
    id: id,
    firstName: '',
    lastName: '',
    email: email,
    phone: '',
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

  // The row's actions are icon buttons now — the first two that apply get one
  // each, the rest sit behind `⋮` — where they used to be four text buttons
  // in a `Wrap`. Found by tooltip, which is the button's accessible name.
  final callButton = find.byTooltip('Call');
  final emailButton = find.byTooltip('Email');
  final moreButton = find.byTooltip('More');

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
  }

  testWidgets('a contact with a phone gets Call, with Message behind ⋮', (
    tester,
  ) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact()]);

    expect(callButton, findsOneWidget);
    expect(emailButton, findsOneWidget);
    expect(find.byType(LinkText), findsOneWidget, reason: 'the number too');
    await openMore(tester);
    expect(find.text('Send SMS'), findsOneWidget);
  });

  testWidgets('the actions show without a portal link', (tester) async {
    // The action `Wrap` used to be gated on `contact.link.isNotEmpty`, back
    // when the only things in it were the two portal buttons. A contact with
    // no portal link must still get Call / Message.
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(link: '')]);

    expect(callButton, findsOneWidget);
    await openMore(tester);
    expect(find.text('View Portal'), findsNothing);
    expect(find.text('Send SMS'), findsOneWidget);
  });

  testWidgets('a portal link adds Copy link and View portal', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(link: 'https://portal.example.com/abc')]);

    await openMore(tester);
    // Named for the portal: the record's own menu has a "Copy Link" too.
    expect(find.text('Client Portal: Copy Link'), findsOneWidget);
    expect(find.text('View Portal'), findsOneWidget);
  });

  testWidgets('with calling off, a desktop gets Email and the portal copy', (
    tester,
  ) async {
    // The first two actions that apply get a button. Without Call that is
    // Email and Copy portal link — what a desktop user does with a contact —
    // and with only View Portal left there is still a `⋮` for it.
    await services.phoneActions.setTapToCall(false);
    await pump(tester, [contact(link: 'https://portal.example.com/abc')]);

    expect(callButton, findsNothing);
    expect(emailButton, findsOneWidget);
    expect(find.byTooltip('Client Portal: Copy Link'), findsOneWidget);
    await openMore(tester);
    expect(find.text('View Portal'), findsOneWidget);
    expect(find.text('Send SMS'), findsNothing);
  });

  testWidgets('a contact with no phone gets neither', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(phone: '')]);

    expect(callButton, findsNothing);
    // Email is the only action left, so there is nothing to put behind `⋮`.
    expect(emailButton, findsOneWidget);
    expect(moreButton, findsNothing);
  });

  testWidgets('an undialable number gets neither', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(phone: 'call the office')]);

    expect(callButton, findsNothing);
    expect(find.byType(LinkText), findsNothing);
  });

  testWidgets('tap-to-call off hides Call and Message', (tester) async {
    await services.phoneActions.setTapToCall(false);
    await pump(tester, [contact()]);

    expect(callButton, findsNothing);
    expect(moreButton, findsNothing, reason: 'Message was all it held');
  });

  testWidgets('an address that is not one address gets no Email action', (
    tester,
  ) async {
    // A `mailto:` built from this would carry a second recipient. The row
    // offers no way to send it; the text is still there to copy.
    await services.phoneActions.setTapToCall(false);
    await pump(tester, [contact(email: 'jane@acme.example.com?bcc=x@evil.io')]);

    expect(emailButton, findsNothing);
    expect(find.text('jane@acme.example.com?bcc=x@evil.io'), findsOneWidget);
  });

  testWidgets(
    'flipping the preference removes the actions from a mounted card',
    (tester) async {
      // The regression: the actions are built in the row, one level above the
      // `PhoneActionsScope` that the number carries. A detail screen stays
      // mounted behind `/settings/**` while the switch is flipped, so a bare
      // read left a live Call button beside a number that had already
      // reverted to plain text — and tapping it still placed the call.
      await services.phoneActions.setTapToCall(true);
      await pump(tester, [contact()]);
      expect(callButton, findsOneWidget);

      await services.phoneActions.setTapToCall(false);
      await tester.pump();

      expect(find.byType(LinkText), findsNothing, reason: 'number went inert');
      expect(
        callButton,
        findsNothing,
        reason: 'the button must go inert with it',
      );
    },
  );

  testWidgets('the primary star and the exceptions are named', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, [
      Contact.fromApi(
        const ContactApi(
          id: 'ct1',
          firstName: 'Jane',
          lastName: 'Smith',
          isPrimary: true,
          isLocked: true,
          ccOnly: true,
        ),
      ),
    ]);
    // A bare star says nothing to a screen reader; a bare red icon said
    // nothing to anyone.
    expect(find.bySemanticsLabel('Primary Contact'), findsOneWidget);
    expect(find.text('Unsubscribed'), findsOneWidget);
    expect(find.text('CC Only'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('an expanded list can be collapsed again', (tester) async {
    // Inline expansion (a window 600 px or wider — the harness default) used
    // to be one-way: thirty contacts stayed thirty rows tall.
    await pump(tester, people(5));
    await tester.tap(find.textContaining('more'));
    await tester.pump();
    expect(find.text('Person 5'), findsOneWidget);

    await tester.tap(find.text('Less'));
    await tester.pump();
    expect(find.text('Person 5'), findsNothing);
    expect(find.textContaining('more'), findsOneWidget);
  });

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

    test('a server-minted portal placeholder is not content', () {
      expect(ClientDetailContactsCard.hasContent([placeholderOnly()]), isFalse);
    });

    test('a REAL example.com address is still content', () {
      // Every contact in the seeded demo dataset lives at example.com; a
      // blanket rule would empty this card across the public demo build.
      expect(
        ClientDetailContactsCard.hasContent([
          placeholderOnly(email: 'cboyle@example.com'),
        ]),
        isTrue,
        reason: 'real contact in the demo dataset',
      );
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

  testWidgets(
    'a named contact keeps its name but never shows the minted email',
    (tester) async {
      // The issue's screenshot: "Jimmy" over `dq9GHaI6Dncm0Zd@example.com`,
      // an address the user never typed.
      await pump(tester, [
        contact(
          firstName: 'Jimmy',
          lastName: '',
          email: 'dq9GHaI6Dncm0Zd@example.com',
        ),
      ]);

      expect(find.text('Jimmy'), findsOneWidget);
      expect(find.textContaining('@example.com'), findsNothing);
    },
  );

  testWidgets('a real example.com address is still rendered', (tester) async {
    // The over-match guard, at the widget layer: the demo dataset's contacts
    // all live at example.com and must keep their addresses.
    await pump(tester, [
      contact(
        firstName: 'Luigi',
        lastName: 'Collier',
        email: 'cboyle@example.com',
      ),
    ]);

    expect(find.text('cboyle@example.com'), findsOneWidget);
  });

  testWidgets('a contact whose only email was minted shows no card', (
    tester,
  ) async {
    await pump(tester, [placeholderOnly()]);

    expect(find.byType(DashboardCardShell), findsNothing);
    expect(find.text('(no name)'), findsNothing);
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
    expect(find.byTooltip('Client Portal: Copy Link'), findsNothing);
  });

  testWidgets('a custom value with no label for it does not keep a blank '
      'contact', (tester) async {
    // Nothing would be printed for it — the row shows a custom field only
    // under the label the company gave it — so the row would be `(no name)`
    // and nothing else.
    await pump(tester, [blank(customValue1: 'VIP')]);

    expect(find.byType(DashboardCardShell), findsNothing);
  });

  test('a custom value the company has labelled is content', () {
    // The row prints contact custom fields now, so a contact whose only entry
    // is one has a line to show. `Contact.isBlank` leaves custom values out
    // on purpose and says a card that renders them must widen its own test —
    // this is that. React's row makes the same call.
    final company = Company(
      id: 'co1',
      name: 'Co',
      customFields: const {'contact1': 'Department'},
    );
    // Labels a *different* slot from the one the contact filled.
    final elsewhere = Company(
      id: 'co1',
      name: 'Co',
      customFields: const {'contact2': 'Other'},
    );
    final onlyCustom = blank(customValue1: 'Accounts');

    expect(visibleClientContacts([onlyCustom]), isEmpty, reason: 'no labels');
    expect(visibleClientContacts([onlyCustom], company: company), [onlyCustom]);
    expect(
      visibleClientContacts([onlyCustom], company: elsewhere),
      isEmpty,
      reason: 'slot 1 has no label there, so nothing would print',
    );
    expect(primaryClientContact([onlyCustom], company: company), onlyCustom);
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
