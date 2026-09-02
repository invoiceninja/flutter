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
/// worth asserting here is that the wiring reached this tile at all, and that
/// the picker doesn't claim to know a vendor's local time.
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
