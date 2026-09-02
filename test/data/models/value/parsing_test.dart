import 'package:admin/data/models/value/parsing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPortalPlaceholderEmail (invoiceninja/flutter#116)', () {
    test(
      'matches the 15-char address the portal invitation controller mints',
      () {
        // The exact value from the issue's screenshot.
        expect(isPortalPlaceholderEmail('dq9GHaI6Dncm0Zd@example.com'), isTrue);
        expect(isPortalPlaceholderEmail('A1b2C3d4E5f6G7h@example.com'), isTrue);
      },
    );

    test('matches the 6-char address the key-login middleware mints', () {
      expect(isPortalPlaceholderEmail('aB3xY9@example.com'), isTrue);
      expect(isPortalPlaceholderEmail('Kf3Xq9@example.com'), isTrue);
    });

    test('leading / trailing whitespace does not defeat the match', () {
      expect(isPortalPlaceholderEmail('  aB3xY9@example.com '), isTrue);
    });

    test('does NOT match the real addresses in the demo dataset', () {
      // Measured against demo.invoiceninja.com: 96 contacts, every one of them
      // at example.com/.net/.org (Faker seed data behind the public demo
      // build). These three are the only ones a length-only rule would have
      // hidden — they are why the predicate demands an uppercase letter.
      expect(
        isPortalPlaceholderEmail('shad30@example.com'),
        isFalse,
        reason: 'real contact in the demo dataset',
      );
      expect(
        isPortalPlaceholderEmail('cboyle@example.com'),
        isFalse,
        reason: 'real contact in the demo dataset',
      );
      expect(
        isPortalPlaceholderEmail('lucy17@example.com'),
        isFalse,
        reason: 'real contact in the demo dataset',
      );
      expect(isPortalPlaceholderEmail('jenkins.aliyah@example.com'), isFalse);
      expect(isPortalPlaceholderEmail('ahirthe@example.com'), isFalse);
    });

    test('does not match an ordinary address', () {
      expect(isPortalPlaceholderEmail('accounts@acme.com'), isFalse);
      expect(isPortalPlaceholderEmail('Jimmy@acme.com'), isFalse);
    });

    test('does not match empty, or the server-seeded blank contact', () {
      expect(isPortalPlaceholderEmail(''), isFalse);
      // ClientContactRepository::save writes a literal single space.
      expect(isPortalPlaceholderEmail(' '), isFalse);
    });

    test('domain must be exactly example.com', () {
      // The server never mints these; 65 demo contacts live at .net / .org.
      expect(isPortalPlaceholderEmail('aB3xY9@example.net'), isFalse);
      expect(isPortalPlaceholderEmail('aB3xY9@example.org'), isFalse);
      expect(isPortalPlaceholderEmail('aB3xY9@Example.com'), isFalse);
      expect(isPortalPlaceholderEmail('aB3xY9@acme.example.com'), isFalse);
      expect(isPortalPlaceholderEmail('aB3xY9@example.com.co'), isFalse);
    });

    test('local part length must be exactly 6 or 15', () {
      expect(isPortalPlaceholderEmail('aB3xY@example.com'), isFalse); // 5
      expect(isPortalPlaceholderEmail('aB3xY99@example.com'), isFalse); // 7
      expect(
        isPortalPlaceholderEmail('A1b2C3d4E5f6G7@example.com'),
        isFalse,
      ); // 14
      expect(
        isPortalPlaceholderEmail('A1b2C3d4E5f6G7h8@example.com'),
        isFalse,
      ); // 16
    });

    test('local part must be alphanumeric only', () {
      expect(isPortalPlaceholderEmail('aB3.Y9@example.com'), isFalse);
      expect(isPortalPlaceholderEmail('aB3-Y9@example.com'), isFalse);
      expect(isPortalPlaceholderEmail('aB3_Y9@example.com'), isFalse);
    });

    test('documents the accepted miss: an all-lowercase mint slips through', () {
      // (36/62)^6 ≈ 3.8% of 6-char mints and ≈ 0.029% of 15-char ones come out
      // with no uppercase letter. Deliberate: a miss shows one junk address, a
      // false positive hides a real one.
      expect(isPortalPlaceholderEmail('dq9ghai6dncm0zd@example.com'), isFalse);
      expect(isPortalPlaceholderEmail('ab3xy9@example.com'), isFalse);
    });
  });
}
