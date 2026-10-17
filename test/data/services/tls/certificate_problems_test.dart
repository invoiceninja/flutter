import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';

// Fixed instants mid-day UTC, so no time zone moves them across a day.
final _now = DateTime.utc(2026, 10, 17, 12);

CertificateFacts _facts({
  String subject = '/CN=pay.example.com',
  String issuer = '/C=GB/O=Sectigo Limited/CN=Sectigo DV R36',
  List<String> san = const [],
  DateTime? notBefore,
  DateTime? notAfter,
}) => CertificateFacts(
  sha256: 'ab' * 32,
  subject: subject,
  issuer: issuer,
  notBefore: notBefore ?? DateTime.utc(2026, 1, 1, 12),
  notAfter: notAfter ?? DateTime.utc(2027, 1, 1, 12),
  subjectAltNames: san,
);

void main() {
  group('hostMatchesName', () {
    final cases = <(String host, String name, bool matches)>[
      // A shared-hosting default certificate on a customer's domain.
      ('pay.example.com', '*.registrar-servers.com', false),
      ('pay.example.com', 'registrar-servers.com', false),
      ('a.example.com', '*.example.com', true),
      ('A.Example.COM.', '*.example.com', true),
      ('example.com', '*.example.com', false),
      ('a.b.example.com', '*.example.com', false),
      ('example.com', 'example.com', true),
      ('www.example.com', 'example.com', false),
      // A wildcard over a single label covers nothing.
      ('example.com', '*.com', false),
      // Partial-label wildcards are not honoured.
      ('foo.example.com', 'f*.example.com', false),
      ('127.0.0.1', '127.0.0.1', true),
      ('127.0.0.1', '*.0.0.1', false),
      ('192.168.0.10', '192.168.0.11', false),
      ('::1', '0:0:0:0:0:0:0:1', true),
      ('[::1]', '0:0:0:0:0:0:0:1', true),
      ('localhost', '127.0.0.1', false),
    ];
    for (final (host, name, matches) in cases) {
      test('$host vs $name → $matches', () {
        expect(hostMatchesName(host, name), matches);
      });
    }
  });

  group('verifyReasonOf', () {
    test('takes the reason out of a BoringSSL message', () {
      expect(
        verifyReasonOf(
          'CERTIFICATE_VERIFY_FAILED: Hostname mismatch(handshake.cc:393)',
        ),
        'Hostname mismatch',
      );
      expect(
        verifyReasonOf(
          '\n\tCERTIFICATE_VERIFY_FAILED: self signed certificate(handshake.cc:393)',
        ),
        'self signed certificate',
      );
    });

    test('is null when there is no verify reason', () {
      expect(verifyReasonOf(null), isNull);
      expect(verifyReasonOf('WRONG_VERSION_NUMBER(tls_record.cc:242)'), isNull);
    });
  });

  group('certificateProblems', () {
    test('a shared-hosting default: a name mismatch, and nothing else', () {
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: _facts(
            subject: '/CN=*.registrar-servers.com',
            san: ['*.registrar-servers.com', 'registrar-servers.com'],
          ),
          now: _now,
          osReason: 'application verification failure',
        ),
        [CertificateProblem.nameMismatch],
      );
    });

    test('a matching SAN is a match even when the CN is not', () {
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: _facts(subject: '/CN=Server', san: ['pay.example.com']),
          now: _now,
        ),
        [CertificateProblem.untrustedIssuer],
      );
    });

    test('with no SAN, the CN is the name', () {
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: _facts(subject: '/CN=other.example.com'),
          now: _now,
        ),
        [CertificateProblem.nameMismatch],
      );
    });

    test('no names at all claims no mismatch', () {
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: _facts(subject: '/O=mkcert development certificate'),
          now: _now,
        ),
        [CertificateProblem.untrustedIssuer],
      );
    });

    test('a self-signed LAN certificate', () {
      expect(
        certificateProblems(
          host: '192.168.0.10',
          facts: _facts(
            subject: '/CN=invoiceninja',
            issuer: '/CN=invoiceninja',
            san: ['192.168.0.10'],
          ),
          now: _now,
        ),
        [CertificateProblem.selfSigned],
      );
    });

    test('dates lead, in order, ahead of everything else', () {
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: _facts(
            subject: '/CN=x',
            issuer: '/CN=x',
            notAfter: DateTime.utc(2026, 6, 1, 12),
          ),
          now: _now,
        ),
        [
          CertificateProblem.expired,
          CertificateProblem.nameMismatch,
          CertificateProblem.selfSigned,
        ],
      );
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: _facts(
            san: ['pay.example.com'],
            notBefore: DateTime.utc(2027, 1, 1, 12),
            notAfter: DateTime.utc(2028, 1, 1, 12),
          ),
          now: _now,
        ),
        [CertificateProblem.notYetValid],
      );
    });

    test('the OS reason names what the fields cannot', () {
      final facts = _facts(san: ['pay.example.com']);
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: facts,
          now: _now,
          osReason: 'unable to get local issuer certificate',
        ),
        [CertificateProblem.untrustedIssuer],
      );
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: facts,
          now: _now,
          osReason: 'Hostname mismatch',
        ),
        [CertificateProblem.nameMismatch],
      );
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: facts,
          now: _now,
          osReason: 'self-signed certificate',
        ),
        [CertificateProblem.selfSigned],
      );
      expect(
        certificateProblems(
          host: 'pay.example.com',
          facts: facts,
          now: _now,
          osReason: 'certificate has expired',
        ),
        [CertificateProblem.expired],
      );
    });
  });
}
