import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_header.dart';

import '../../../../../_localization_helper.dart';

/// `vendorDisplayName` is what a vendor is called in the record screen's
/// header and in the bar that replaces it once it has scrolled away. One
/// cascade for both, so a vendor that is "Jane Doe" up top is never "(no
/// name)" in the bar.
void main() {
  Future<String> nameOf(
    WidgetTester tester, {
    String name = '',
    List<VendorContactApi> contacts = const [],
  }) async {
    late String out;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) {
            out = vendorDisplayName(
              context,
              Vendor.fromApi(
                VendorApi(id: 'v1', name: name, contacts: contacts),
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    return out;
  }

  testWidgets('its own name, when it has one', (tester) async {
    expect(
      await nameOf(
        tester,
        name: 'Acme Supply',
        contacts: const [VendorContactApi(id: 'c1', firstName: 'Jane')],
      ),
      'Acme Supply',
    );
  });

  testWidgets('else the primary contact, wherever it sits in the list', (
    tester,
  ) async {
    expect(
      await nameOf(
        tester,
        contacts: const [
          VendorContactApi(id: 'c1', firstName: 'Sam', lastName: 'Lee'),
          VendorContactApi(
            id: 'c2',
            firstName: 'Jane',
            lastName: 'Doe',
            isPrimary: true,
          ),
        ],
      ),
      'Jane Doe',
    );
  });

  testWidgets('else the first contact', (tester) async {
    expect(
      await nameOf(
        tester,
        contacts: const [
          VendorContactApi(id: 'c1', firstName: 'Sam'),
          VendorContactApi(id: 'c2', firstName: 'Jane'),
        ],
      ),
      'Sam',
    );
  });

  testWidgets('a contact with no name lends its address', (tester) async {
    expect(
      await nameOf(
        tester,
        contacts: const [VendorContactApi(id: 'c1', email: 'ap@acme.test')],
      ),
      'ap@acme.test',
    );
  });

  testWidgets('never the address the server minted for the portal', (
    tester,
  ) async {
    expect(
      await nameOf(
        tester,
        contacts: const [
          VendorContactApi(id: 'c1', email: 'dq9GHaI6Dncm0Zd@example.com'),
        ],
      ),
      '(no name)',
    );
  });

  testWidgets('nothing at all is said so, not left blank', (tester) async {
    expect(await nameOf(tester), '(no name)');
    expect(
      await nameOf(
        tester,
        contacts: const [VendorContactApi(id: 'blank', isPrimary: true)],
      ),
      '(no name)',
    );
  });
}
