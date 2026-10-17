import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: one place decides which server certificates the app accepts.
///
/// `certificate_trust_seam_io.dart` installs, through `HttpOverrides.global`,
/// the only `connectionFactory` — which, when the OS refuses a certificate,
/// reads the server's own certificate after the handshake and admits it only
/// when it is the one pinned for that self-hosted host:port. `lib/main.dart`
/// installs it before `Services.build` creates the first `HttpClient`.
///
/// Two things nothing else would notice: a `badCertificateCallback`
/// anywhere (`=> true` for a quick fix) accepts any certificate on every
/// connection it touches — and even a careful one is handed the top of the
/// chain, not the server's certificate, so it can't pin anything; and an
/// install after the build leaves ApiClient's and AuthService's clients
/// without the pin (docs/trusting-a-self-hosted-certificate.md).
void main() {
  const seam = 'lib/data/services/tls/certificate_trust_seam_io.dart';

  test('nothing in lib sets badCertificateCallback; only the seam sets '
      'connectionFactory or HttpOverrides.global', () {
    final anywhere = RegExp(r'badCertificateCallback\s*=');
    final seamOnly = RegExp(r'connectionFactory\s*=|HttpOverrides\.global');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final code = entity
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      if (anywhere.hasMatch(code) ||
          (path != seam && seamOnly.hasMatch(code))) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Certificate acceptance goes through CertificateTrustStore and the '
          'one connection hook in $seam. Found: ${offenders.join(', ')}',
    );
    expect(
      File(seam).readAsStringSync(),
      allOf(
        contains('connectionFactory ='),
        contains('peerCertificate'),
        contains('HttpOverrides.global'),
      ),
    );
  });

  test('main.dart installs the trust before building Services', () {
    final main = File('lib/main.dart').readAsStringSync();
    final install = main.indexOf('installCertificateTrust(');
    final build = main.indexOf('Services.build(');
    expect(install, isNonNegative, reason: 'main.dart must install it');
    expect(build, isNonNegative);
    expect(
      install,
      lessThan(build),
      reason:
          'An HttpClient created before the overrides are installed never '
          'consults a trusted certificate.',
    );
    expect(
      main,
      contains('_certificateTrustRef = services.certificateTrust'),
      reason: 'the hook reads the store through this late-bound ref',
    );
  });
}
