import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_email_candidates.dart';

/// `vendorEmailCandidates` decides whether a vendor gets an Email tile at
/// all, and who the picker offers when it does. The vendor twin of
/// `clientEmailCandidates`.
Vendor _vendor(List<VendorContactApi> contacts) =>
    Vendor.fromApi(VendorApi(id: 'v1', name: 'Acme', contacts: contacts));

void main() {
  test('the primary contact leads, whatever the declaration order', () {
    final out = vendorEmailCandidates(
      _vendor(const [
        VendorContactApi(id: 'a', firstName: 'Ann', email: 'ann@acme.test'),
        VendorContactApi(
          id: 'b',
          firstName: 'Bob',
          lastName: 'Ray',
          email: 'bob@acme.test',
          isPrimary: true,
        ),
      ]),
    );
    expect(out.map((c) => c.email), ['bob@acme.test', 'ann@acme.test']);
    expect(out.first.label, 'Bob Ray');
    expect(out.first.isPrimary, isTrue);
  });

  test('nobody to write to is an empty list — no tile', () {
    expect(vendorEmailCandidates(_vendor(const [])), isEmpty);
    // The all-blank contact the server keeps on every vendor.
    expect(
      vendorEmailCandidates(
        _vendor(const [VendorContactApi(id: 'blank', isPrimary: true)]),
      ),
      isEmpty,
    );
    // A contact with a name and a phone but no address.
    expect(
      vendorEmailCandidates(
        _vendor(const [
          VendorContactApi(id: 'a', firstName: 'Ann', phone: '555-1234'),
        ]),
      ),
      isEmpty,
    );
  });

  test('a deleted contact is not offered', () {
    expect(
      vendorEmailCandidates(
        _vendor(const [
          VendorContactApi(
            id: 'a',
            firstName: 'Ann',
            email: 'ann@acme.test',
            isDeleted: true,
          ),
        ]),
      ),
      isEmpty,
    );
  });

  test('the address the server minted for the portal is never offered', () {
    // `VendorContact.fromApi` strips it out of `email`, so a contact that was
    // only ever given a name has nothing to write to.
    expect(
      vendorEmailCandidates(
        _vendor(const [
          VendorContactApi(
            id: 'a',
            firstName: 'Ann',
            email: 'dq9GHaI6Dncm0Zd@example.com',
          ),
        ]),
      ),
      isEmpty,
    );
  });

  test('something that is not exactly one address is dropped', () {
    expect(
      vendorEmailCandidates(
        _vendor(const [
          VendorContactApi(
            id: 'a',
            firstName: 'Ann',
            email: 'a@x.test, b@x.test',
          ),
          VendorContactApi(id: 'b', firstName: 'Bob', email: 'not an address'),
        ]),
      ),
      isEmpty,
    );
  });

  test('two contacts sharing an address are one entry', () {
    final out = vendorEmailCandidates(
      _vendor(const [
        VendorContactApi(id: 'a', firstName: 'Ann', email: 'ap@acme.test'),
        VendorContactApi(
          id: 'b',
          firstName: 'Bob',
          email: 'AP@acme.test',
          isPrimary: true,
        ),
      ]),
    );
    expect(out, hasLength(1));
    expect(out.single.label, 'Bob', reason: 'the primary is the one kept');
  });
}
