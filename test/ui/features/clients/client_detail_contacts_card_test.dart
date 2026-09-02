import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_contacts_card.dart';

import '../../../_localization_helper.dart';
import '../../../_support/phone_actions_test_services.dart';

/// The Call / Message pair on a contact row reads the tap-to-call preference,
/// and the row that builds it is NOT the widget that owns the listener — so
/// "does it restyle in place" is the assertion that matters here. The number
/// itself carries its own `PhoneActionsScope`; the buttons are built one level
/// up, which is exactly where a stale read hides.
void main() {
  late PhoneActionsTestServices services;

  Contact contact({String phone = '+1 415 555 2672', String link = ''}) =>
      Contact.fromApi(
        ContactApi(
          id: 'ct1',
          firstName: 'Jane',
          lastName: 'Smith',
          email: 'jane@acme.example.com',
          phone: phone,
          link: link,
        ),
      );

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
}
