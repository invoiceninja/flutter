import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/tls/certificate_facts.dart';

/// The DER inside a PEM file under `test/fixtures/tls/` — see
/// `certificate_trust_tls_test.dart` for how those were made.
List<int> derOf(String fixture) {
  final pem = File('test/fixtures/tls/$fixture').readAsStringSync();
  final body = pem
      .split('\n')
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64Decode(body);
}

void main() {
  group('subjectAltNamesOf', () {
    test('reads DNS names and an IPv4 address', () {
      expect(subjectAltNamesOf(derOf('localhost.crt')), [
        'localhost',
        '127.0.0.1',
      ]);
    });

    test('reads a CA-issued wildcard certificate', () {
      // A shared-hosting default certificate (Namecheap's), which covers
      // none of its customers' names.
      expect(subjectAltNamesOf(derOf('registrar_servers_leaf.crt')), [
        '*.registrar-servers.com',
        'registrar-servers.com',
      ]);
    });

    test('is null, not a throw, for bytes that are not a certificate', () {
      expect(subjectAltNamesOf([0x30, 0x82, 0xFF]), isNull);
      expect(subjectAltNamesOf(const []), isNull);
    });
  });

  group('CertificateFacts.fromCertificate', () {
    final facts = CertificateFacts.fromCertificate(
      der: derOf('localhost.crt'),
      subject: '/CN=localhost',
      issuer: '/CN=localhost',
      notBefore: DateTime.utc(2026, 10, 17, 12),
      notAfter: DateTime.utc(2126, 9, 23, 12),
    );

    test('fingerprints the DER the way openssl does', () {
      // openssl x509 -in test/fixtures/tls/localhost.crt -noout \
      //   -fingerprint -sha256
      expect(
        facts.displayFingerprint,
        '90:5A:D9:EE:BC:CC:E8:89:02:F0:BE:70:40:03:AE:A5:'
        'BE:28:58:7C:55:D0:5C:31:06:7E:7A:78:A0:45:62:8C',
      );
      expect(facts.shortFingerprint, '90:5A:D9:EE:BC:CC:E8:89…');
    });

    test('names come from the SANs, and it is self-issued', () {
      expect(facts.names, ['localhost', '127.0.0.1']);
      expect(facts.isSelfIssued, isTrue);
    });

    test('survives a JSON round trip', () {
      final back = CertificateFacts.fromJson(
        jsonDecode(jsonEncode(facts.toJson())) as Map<String, dynamic>,
      );
      expect(back, facts);
      expect(back.subjectAltNames, facts.subjectAltNames);
      expect(back.notAfter, facts.notAfter);
      expect(back.issuer, facts.issuer);
    });

    test('rejects a fingerprint that is not one', () {
      expect(
        () => CertificateFacts.fromJson({
          ...facts.toJson(),
          'sha256': 'not-a-hash',
        }),
        throwsFormatException,
      );
    });
  });

  group('distinguishedNameField', () {
    test("reads OpenSSL's one-line form, last value winning", () {
      const issuer =
          '/C=GB/O=Sectigo Limited/CN=Sectigo Public Server Authentication CA DV R36';
      expect(
        distinguishedNameField(issuer, 'CN'),
        'Sectigo Public Server Authentication CA DV R36',
      );
      expect(distinguishedNameField(issuer, 'O'), 'Sectigo Limited');
      expect(distinguishedNameField('/CN=a/CN=b', 'CN'), 'b');
    });

    test('reads the RFC 2253 form', () {
      expect(
        distinguishedNameField('CN=*.registrar-servers.com, O=X', 'CN'),
        '*.registrar-servers.com',
      );
    });

    test('is null when the field is absent or blank', () {
      expect(distinguishedNameField('/O=mkcert development', 'CN'), isNull);
      expect(distinguishedNameField('/CN=', 'CN'), isNull);
    });

    test('issuerName falls back from CN to O to the raw name', () {
      CertificateFacts withIssuer(String issuer) => CertificateFacts(
        sha256: '0' * 64,
        subject: '/CN=x',
        issuer: issuer,
        notBefore: DateTime.utc(2026),
        notAfter: DateTime.utc(2027),
      );
      expect(withIssuer('/O=Acme/CN=Acme CA').issuerName, 'Acme CA');
      expect(withIssuer('/O=Acme').issuerName, 'Acme');
      expect(withIssuer('weird').issuerName, 'weird');
    });
  });
}
