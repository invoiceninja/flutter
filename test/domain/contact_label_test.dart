import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/contact_label.dart';

/// invoiceninja/flutter#118. The predicate behind the Clients / Vendors row
/// de-duplication — pure strings, so it is unit-tested here rather than pumped
/// (the same reason `test/domain/phone/phone_candidates_test.dart` sits beside
/// its own helper). The tile tests pin the *wiring*; the subtlety is here.
void main() {
  group('isSamePartyName', () {
    test('matches an identical name', () {
      expect(isSamePartyName('Jane Smith', 'Jane Smith'), isTrue);
    });

    test('matches the server\'s untrimmed concat', () {
      // `ClientPresenter::name()` returns
      // `$contact->first_name . ' ' . $contact->last_name` **untrimmed**, so a
      // contact with only a first name reaches `display_name` as `'Jane '`
      // while the tile composes the same fields and trims. This is the
      // commonest individual shape there is, and a bare `==` misses it.
      expect(isSamePartyName('Jane ', 'Jane'), isTrue);
      expect(isSamePartyName(' Jane', 'Jane'), isTrue);
    });

    test('ignores case', () {
      expect(isSamePartyName('jane smith', 'Jane Smith'), isTrue);
    });

    test('collapses internal whitespace runs', () {
      expect(isSamePartyName('Jane  Smith', 'Jane Smith'), isTrue);
      expect(isSamePartyName('Jane\tSmith', 'Jane Smith'), isTrue);
    });

    test('collapses a non-breaking space', () {
      // Dart's `RegExp` is ECMA-262, so `\s` covers U+00A0 — what a name
      // pasted out of Word or Outlook carries, and what `trim()` alone would
      // leave sitting in the middle of the string; a hand-rolled `[ \t]` class
      // would fail this. Spelled out rather than pasted, because an invisible
      // NBSP in a source literal is unreviewable and one reformat away from
      // silently becoming an ordinary space.
      expect(isSamePartyName('Jane\u00a0Smith', 'Jane Smith'), isTrue);
    });

    test('blank never matches blank', () {
      // A blank string is "no name", not a name two records happen to share —
      // otherwise every nameless contact would count as a duplicate of every
      // nameless client and the row would silently drop its own fallback.
      expect(isSamePartyName('', ''), isFalse);
      expect(isSamePartyName('   ', ''), isFalse);
      expect(isSamePartyName('', 'Jane Smith'), isFalse);
    });

    test('keeps genuinely different names apart', () {
      expect(isSamePartyName('Jane Smith', 'Jane Smyth'), isFalse);
      expect(isSamePartyName('Jane', 'Jane Smith'), isFalse);
      expect(isSamePartyName('Acme Corporation', 'Jane Smith'), isFalse);
    });

    test('does not treat containment as a match', () {
      // `Smith & Sons` is a company named after its owner — exactly where a
      // prefix or substring rule would fire wrongly and blank a real contact.
      expect(isSamePartyName('Smith', 'Smith & Sons'), isFalse);
      expect(isSamePartyName('Smith & Sons', 'Smith'), isFalse);
    });

    test('does not fold diacritics', () {
      // Deliberate: a false positive hides a genuinely different person, a
      // false negative only leaves today's noise. admin-portal's
      // `removeDiacritics` is for *sorting*, which has the opposite asymmetry.
      expect(isSamePartyName('José García', 'Jose Garcia'), isFalse);
    });
  });

  group('contactSubtitleLabel', () {
    String label({String name = '', String email = '', String party = ''}) =>
        contactSubtitleLabel(
          contactName: name,
          contactEmail: email,
          partyName: party,
        );

    test('keeps a name that says something new', () {
      expect(
        label(name: 'Jane Smith', email: 'jane@x.com', party: 'Acme Corp'),
        'Jane Smith',
      );
    });

    test('drops a name that only repeats the title, and offers the email', () {
      expect(
        label(name: 'Jane Smith', email: 'jane@x.com', party: 'Jane Smith'),
        'jane@x.com',
      );
    });

    test('drops a redundant name with nothing to replace it', () {
      expect(label(name: 'Jane Smith', party: 'jane smith'), '');
    });

    test('falls to the email when the contact is unnamed', () {
      // The pre-#118 cascade, unchanged.
      expect(label(email: 'jane@x.com', party: 'Acme Corp'), 'jane@x.com');
    });

    test('drops an email that is itself the title', () {
      // `ClientPresenter::name()` falls to the first contact's address when
      // neither the client nor the contact has a name, so `display_name` can
      // *be* the email the fallback would print underneath it.
      expect(label(email: 'jane@x.com', party: 'jane@x.com'), '');
    });

    test('treats the seeded blank contact as having no email', () {
      // `ClientContactRepository::save` writes a literal single space
      // ("//always made sure we have one blank contact to maintain state").
      // The old `_contactLabel` already returned `c.email.trim()`, so this
      // asserts the rewrite *preserved* that: untrimmed it would be
      // `isNotEmpty` and the row would newly render a leading ` · `.
      expect(label(email: ' ', party: 'Acme Corp'), '');
    });

    test('a contact with nothing to say yields nothing', () {
      expect(label(party: 'Acme Corp'), '');
      expect(label(name: '  ', email: '  ', party: 'Acme Corp'), '');
    });

    test('a party with no name of its own suppresses nothing', () {
      // `partyName` is empty only when the row itself has no title to repeat.
      expect(label(name: 'Jane Smith'), 'Jane Smith');
      expect(label(email: 'jane@x.com'), 'jane@x.com');
    });

    test('trims what it returns', () {
      expect(label(name: '  Jane Smith  ', party: 'Acme'), 'Jane Smith');
      expect(label(email: ' jane@x.com ', party: 'Acme'), 'jane@x.com');
    });
  });
}
