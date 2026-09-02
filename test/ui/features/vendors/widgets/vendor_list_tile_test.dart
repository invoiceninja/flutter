import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_list_tile.dart';

import '../../../../_responsive_helper.dart';
import '../../../../_support/fake_url_launcher.dart';
import '../../../../_support/phone_actions_test_services.dart';

/// The narrow vendor row's call button (invoiceninja/flutter#111) — the
/// `ClientListTile` twin. Deliberately lighter: the shared behaviour is pinned
/// in `client_list_tile_test.dart` and `party_call_button_test.dart`; what is
/// worth asserting here is that the wiring reached this tile at all, that the
/// picker doesn't claim to know a vendor's local time, and that the subtitle's
/// blank fallback (invoiceninja/flutter#112) didn't stay behind on this side.
void main() {
  late FakeUrlLauncher launcher;
  late PhoneActionsTestServices services;

  Vendor vendor({
    String phone = '',
    List<VendorContactApi> contacts = const [],
  }) => Vendor.fromApi(
    VendorApi(
      id: 'v1',
      name: 'Globex Supplies',
      phone: phone,
      contacts: contacts,
    ),
  );

  setUp(() {
    launcher = installFakeUrlLauncher();
    // No timezone, so `_outsideHoursLine` resolves null and a launch is never
    // intercepted by the quiet-hours dialog. The one test that needs a zone
    // installs a foreign one for itself.
    services = PhoneActionsTestServices(timezone: null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpRow(
    WidgetTester tester,
    Vendor v, {
    double width = 500,
    double scale = 1.0,
    bool selecting = false,
    bool wide = false,
    VoidCallback? onTap,
  }) => pumpAt(
    tester,
    width,
    Provider<Services>.value(
      value: services,
      child: VendorListTile(
        vendor: v,
        formatter: null,
        wide: wide,
        selecting: selecting,
        // Deliberately not `selecting ? null : …` — see the client twin: tying
        // the two together would let the multi-select case pass against a
        // button gated on `onAction != null`.
        onAction: (_) {},
        onTap: onTap ?? () {},
      ),
    ),
    textScale: scale,
  );

  Finder callIcon() => find.byIcon(Icons.call_outlined);

  testWidgets('is absent when the vendor has no dialable number', (
    tester,
  ) async {
    await pumpRow(tester, vendor());
    expect(callIcon(), findsNothing);
  });

  testWidgets('a subtitle with nothing to say is blank, not dashed', (
    tester,
  ) async {
    // `vendor()` has no contact, city or number — the only path to
    // `_SubtitleLine`'s fallback. The client twin carried this change too, and
    // without an assertion here the em dash could come back on one side while
    // the other stayed green.
    await pumpRow(tester, vendor());
    expect(find.text('—'), findsNothing);
    final bareNameDy = tester.getCenter(find.text('Globex Supplies')).dy;

    await pumpRow(
      tester,
      Vendor.fromApi(
        const VendorApi(id: 'v1', name: 'Globex Supplies', city: 'Springfield'),
      ),
    );

    // The name's position, not the row height: the 44 px `…` button floors the
    // row at 72 either way, so a height assertion would pass even if the blank
    // subtitle collapsed — which is the one thing this forbids.
    expect(
      tester.getCenter(find.text('Globex Supplies')).dy,
      bareNameDy,
      reason: 'the blank subtitle must keep its line box',
    );
  });

  group('the subtitle identity', () {
    // invoiceninja/flutter#118, the client twin's case with a sharper edge:
    // `VendorApi` carries no `display_name` at all, so `_displayName` runs the
    // name -> contact-name -> contact-email cascade itself. For a nameless
    // vendor the title and this line are the same string *by construction* —
    // no server involved — and the dedupe is the only thing stopping it
    // printing twice. Lighter than the client group on purpose: the fold is
    // unit-tested in `test/domain/contact_label_test.dart` and the shared
    // wiring in `client_list_tile_test.dart`.
    Vendor nameless({
      String firstName = 'Jane',
      String lastName = 'Smith',
      String email = '',
      String city = '',
      bool withContact = true,
    }) => Vendor.fromApi(
      VendorApi(
        id: 'v1',
        city: city,
        contacts: withContact
            ? [
                VendorContactApi(
                  id: '1',
                  firstName: firstName,
                  lastName: lastName,
                  email: email,
                  isPrimary: true,
                ),
              ]
            : const [],
      ),
    );

    testWidgets('a nameless vendor prints its contact once, not twice', (
      tester,
    ) async {
      await pumpRow(tester, nameless(email: 'jane@example.com', city: 'Reno'));

      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('jane@example.com · Reno'), findsOneWidget);
    });

    testWidgets('with nothing to substitute the line box survives', (
      tester,
    ) async {
      // The vendor half of #112's invariant, now reachable through the dedupe.
      await pumpRow(tester, nameless(withContact: false));
      // No contact at all, so `_displayName` bottoms out at the fallback.
      final bareNameDy = tester.getCenter(find.text('(no name)')).dy;

      await pumpRow(tester, nameless());

      expect(find.text('Jane Smith'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Jane Smith')).dy,
        bareNameDy,
        reason: 'the deduped subtitle must keep its line box',
      );
    });

    testWidgets('a named vendor keeps its contact name', (tester) async {
      // The no-regression case: `Globex Supplies` never folds to `Jane Smith`.
      await pumpRow(
        tester,
        Vendor.fromApi(
          const VendorApi(
            id: 'v1',
            name: 'Globex Supplies',
            city: 'Reno',
            contacts: [
              VendorContactApi(
                id: '1',
                firstName: 'Jane',
                lastName: 'Smith',
                isPrimary: true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Globex Supplies'), findsOneWidget);
      expect(find.text('Jane Smith · Reno'), findsOneWidget);
    });
  });

  testWidgets('is absent in multi-select and on the wide table row', (
    tester,
  ) async {
    final v = vendor(phone: '+1 415 555 2671');

    await pumpRow(tester, v, selecting: true);
    expect(callIcon(), findsNothing, reason: 'the row tap means toggle there');

    await pumpRow(tester, v, wide: true);
    expect(callIcon(), findsNothing, reason: 'narrow rows only');

    await pumpRow(tester, v);
    expect(callIcon(), findsOneWidget);
  });

  testWidgets('dials the one number without opening the record', (
    tester,
  ) async {
    var rowTapped = false;
    await pumpRow(
      tester,
      vendor(phone: '+1 415 555 2671'),
      onTap: () => rowTapped = true,
    );

    await tester.tap(callIcon());
    await tester.pump();
    await tester.pump();

    expect(launcher.launched, ['tel:+14155552671']);
    expect(rowTapped, isFalse);
  });

  testWidgets('the picker never claims to know the vendor local time', (
    tester,
  ) async {
    // A *foreign* zone (UTC+13:45), which is what would make `ContactLocalTime`
    // render if the vendor picker wrongly asked the cascade for one.
    services = PhoneActionsTestServices();
    await pumpRow(
      tester,
      vendor(
        phone: '+1 800 555 0100',
        contacts: const [
          VendorContactApi(
            id: '1',
            firstName: 'Jane',
            lastName: 'Smith',
            phone: '+1 415 555 2671',
            isPrimary: true,
          ),
        ],
      ),
    );

    await tester.tap(callIcon());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('+1 415 555 2671'), findsOneWidget);
    // A vendor has no settings cascade of its own, so `clientId` is null and
    // the cascade would resolve the *company's* zone — a false claim once
    // hoisted under "Call Globex Supplies". The harness's zone is UTC+13:45,
    // so this widget would definitely render if it were asked for.
    expect(find.byType(ContactLocalTime), findsNothing);
  });

  for (final scale in [1.0, kTextScaleMax]) {
    testWidgets('survives the floor width at ${scale}x text', (tester) async {
      await pumpRow(
        tester,
        vendor(
          phone: '+1 800 555 0100',
          contacts: const [
            VendorContactApi(
              id: '1',
              firstName: 'Jane',
              lastName: 'Smith',
              phone: '+1 415 555 2671',
              isPrimary: true,
            ),
          ],
        ),
        scale: scale,
      );

      expect(callIcon(), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      expectNoOverflow(tester);
    });
  }
}
