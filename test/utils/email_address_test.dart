import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/email_candidates.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/core/utils/mail_actions.dart';
import 'package:admin/utils/email_address.dart';

/// `cleanEmailAddress` is the gate in front of every `mailto:` the app builds.
/// A contact's email is free text, and a `mailto:` URI can carry far more than
/// an address — so the gate accepts exactly one address and nothing else.
void main() {
  group('cleanEmailAddress', () {
    test('accepts an ordinary address, trimmed', () {
      expect(
        cleanEmailAddress('  jane@acme.example.com '),
        'jane@acme.example.com',
      );
      expect(
        cleanEmailAddress('j.doe+billing@sub.acme.co.uk'),
        'j.doe+billing@sub.acme.co.uk',
      );
      expect(cleanEmailAddress("o'brien_x@acme.io"), "o'brien_x@acme.io");
    });

    test('accepts an internationalised address', () {
      expect(cleanEmailAddress('josé@exämple.de'), 'josé@exämple.de');
    });

    test('…in scripts that write a letter as a base plus marks', () {
      // `\p{L}` alone is only the base letters. Devanagari vowel signs, Thai
      // tone marks and any decomposed Latin text are `\p{M}`.
      for (final address in [
        'संपर्क@डाटामेल.भारत',
        'jose\u0301@example.com', // e + combining acute
        'ติดต่อ@ตัวอย่าง.ไทย',
      ]) {
        expect(cleanEmailAddress(address), address, reason: address);
      }
    });

    test('accepts an ampersand in the local part', () {
      // A real address shape, and the server's own email rule takes it.
      // Refused, the contact silently lost its Email action.
      expect(cleanEmailAddress('r&d@acme.com'), 'r&d@acme.com');
    });

    test(
      'rejects anything that could carry a header or a second recipient',
      () {
        for (final hostile in [
          'jane@acme.com?bcc=x@evil.io',
          'jane@acme.com?subject=Hi&body=Pay%20here',
          'jane@acme.com&cc=x@evil.io',
          'jane@acme.com,x@evil.io',
          'jane@acme.com;x@evil.io',
          'jane@acme.com%0Abcc:x@evil.io',
          'jane@acme.com\nbcc:x@evil.io',
          'jane @acme.com',
          'Jane <jane@acme.com>',
          '"jane"@acme.com',
        ]) {
          expect(cleanEmailAddress(hostile), '', reason: hostile);
        }
      },
    );

    test('rejects strings that are not an address at all', () {
      for (final junk in [
        '',
        ' ',
        'jane',
        'jane@',
        '@acme.com',
        'jane@acme',
        'jane@@acme.com',
        'jane@-acme.com',
        'jane@acme-.com',
        'jane@.com',
        'mailto:jane@acme.com',
      ]) {
        expect(cleanEmailAddress(junk), '', reason: '"$junk"');
      }
    });
  });

  group('mailtoUri', () {
    test('builds a mailto for a clean address', () {
      expect(
        mailtoUri('jane@acme.example.com').toString(),
        'mailto:jane@acme.example.com',
      );
    });

    test('is null for anything the gate refuses', () {
      expect(mailtoUri('jane@acme.com?bcc=x@evil.io'), isNull);
      expect(mailtoUri(''), isNull);
    });

    test('an ampersand goes out encoded', () {
      // The one accepted character a `mailto:` gives a meaning to. Encoded it
      // is part of the address to every client, and a separator to none.
      expect(mailtoUri('r&d@acme.com').toString(), 'mailto:r%26d@acme.com');
      final odd = mailtoUri('a&bcc=x@evil.io')!;
      expect(odd.toString(), 'mailto:a%26bcc=x@evil.io');
      expect(odd.hasQuery, isFalse);
    });

    test('never produces a query, whatever it is given', () {
      for (final input in ['a@b.co', 'a+b@c.de', "o'x@y.zz", 'r&d@y.zz']) {
        final uri = mailtoUri(input)!;
        expect(uri.scheme, 'mailto');
        expect(uri.hasQuery, isFalse, reason: input);
      }
    });
  });

  group('clientEmailCandidates', () {
    Client client(List<ContactApi> contacts) => Client.fromApi(
      ClientApi(id: 'c1', name: 'Acme', contacts: contacts, updatedAt: 1),
    );

    test('primary first, then the rest in order', () {
      final c = client(const [
        ContactApi(id: '1', firstName: 'Sam', email: 'sam@acme.io'),
        ContactApi(
          id: '2',
          firstName: 'Jane',
          email: 'jane@acme.io',
          isPrimary: true,
        ),
        ContactApi(id: '3', firstName: 'Ola', email: 'ola@acme.io'),
      ]);
      expect(
        [for (final e in clientEmailCandidates(c)) e.label],
        ['Jane', 'Sam', 'Ola'],
      );
    });

    test('drops deleted, blank and unusable contacts', () {
      final c = client(const [
        ContactApi(id: '1', isPrimary: true), // the server's blank seed
        ContactApi(
          id: '2',
          firstName: 'Gone',
          email: 'gone@acme.io',
          isDeleted: true,
        ),
        ContactApi(
          id: '3',
          firstName: 'Bad',
          email: 'bad@acme.io?bcc=x@evil.io',
        ),
        ContactApi(id: '4', firstName: 'Phone', phone: '555'),
        ContactApi(id: '5', firstName: 'Good', email: 'good@acme.io'),
      ]);
      expect(
        [for (final e in clientEmailCandidates(c)) e.email],
        ['good@acme.io'],
      );
    });

    test('two contacts sharing an address are one entry', () {
      final c = client(const [
        ContactApi(id: '1', firstName: 'Sam', email: 'Office@acme.io'),
        ContactApi(
          id: '2',
          firstName: 'Jane',
          email: 'office@acme.io',
          isPrimary: true,
        ),
      ]);
      final candidates = clientEmailCandidates(c);
      expect(candidates, hasLength(1));
      expect(candidates.single.label, 'Jane', reason: 'the primary wins');
    });
  });
}
