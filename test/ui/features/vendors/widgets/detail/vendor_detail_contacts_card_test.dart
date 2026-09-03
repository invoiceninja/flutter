import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_cards.dart';

import '../../../../../_localization_helper.dart';
import '../../../../../_support/phone_actions_test_services.dart';

/// invoiceninja/flutter#115. A vendor carries an all-blank contact the user
/// never filled in, so `contacts.isEmpty` is never the question — the card
/// used to render that row as `(no name)` beside a primary star.
///
/// The card's grid wiring (the wide column and the stacked entry, both gated
/// on [VendorDetailContactsCard.hasContent]) is not pumped here:
/// `VendorDetailDetailsCard` builds a `WatchBuilder<Company?>` unconditionally,
/// so `VendorDetailCardsGrid` can't run under `PhoneActionsTestServices`. The
/// gating is two lines identical to the client grid's, which
/// `clients/client_detail_cards_grid_test.dart` does pin.
void main() {
  late PhoneActionsTestServices services;

  VendorContact contact({
    String firstName = '',
    String lastName = '',
    String email = '',
    String phone = '',
    String link = '',
    String customValue1 = '',
    bool isPrimary = false,
  }) => VendorContact.fromApi(
    VendorContactApi(
      id: 'vc1',
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      link: link,
      customValue1: customValue1,
      isPrimary: isPrimary,
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
  });

  testWidgets('a phone-only contact survives, still titled (no name)', (
    tester,
  ) async {
    // The predicate is "nothing to show", not "has a name" — a number with no
    // name attached is a real contact, and the `no_name_fallback` title cascade
    // is still what gives its row a heading.
    await services.phoneActions.setTapToCall(true);
    await pump(tester, [contact(phone: '+1 415 555 2672')]);

    expect(find.text('(no name)'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Call'), findsOneWidget);
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

  testWidgets('a contact custom value alone does not keep a blank contact', (
    tester,
  ) async {
    // React counts contact custom fields because its row renders them; this
    // card doesn't, so a row kept alive by one would paint only `(no name)`.
    await pump(tester, [contact(customValue1: 'VIP')]);

    expect(find.byType(DashboardCardShell), findsNothing);
  });
}
