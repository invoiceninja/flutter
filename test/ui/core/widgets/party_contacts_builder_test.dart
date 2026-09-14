import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';

void main() {
  group('invitationContactId', () {
    test('reads whichever side the document is borne by', () {
      expect(
        invitationContactId(const Invitation(id: 'i', clientContactId: 'c1')),
        'c1',
      );
      expect(
        invitationContactId(const Invitation(id: 'i', vendorContactId: 'v1')),
        'v1',
      );
      expect(invitationContactId(const Invitation(id: 'i')), '');
    });
  });

  group('partyContactLabel', () {
    const contacts = <String, ({String name, String email})>{
      'named': (name: 'Jane Doe', email: 'jane@acme.test'),
      'nameless': (name: '', email: 'jane@acme.test'),
      'blank': (name: '', email: ''),
    };

    test('prefers the name', () {
      expect(
        partyContactLabel(contacts, 'named', fallback: 'Contact'),
        'Jane Doe',
      );
    });

    test('falls back to the address we would mail', () {
      expect(
        partyContactLabel(contacts, 'nameless', fallback: 'Contact'),
        'jane@acme.test',
      );
    });

    test('a seeded blank contact is the normal case, not an edge one', () {
      // The server seeds one all-blank contact per client and per vendor, and
      // `Contact.email` already blanks the `@example.com` addresses the server
      // mints for itself — so both steps above can legitimately be empty.
      expect(
        partyContactLabel(contacts, 'blank', fallback: 'Contact'),
        'Contact',
      );
    });

    test('an id the party does not carry falls back too', () {
      expect(
        partyContactLabel(contacts, 'gone', fallback: 'Contact'),
        'Contact',
      );
      expect(
        partyContactLabel(const {}, 'any', fallback: 'Contact'),
        'Contact',
      );
    });
  });
}
