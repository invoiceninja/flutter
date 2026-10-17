import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';

/// Web half of the [certificate_trust_seam]: the browser verifies
/// certificates and never lets the page overrule it, so there is nothing to
/// install.
void installCertificateTrust(CertificateTrustStore? Function() trust) {}

/// The browser reports a refused certificate as an opaque network error, so
/// nothing here can recognise one.
RequestNotSentException? untrustedCertificateFrom(
  Object error, {
  required Uri uri,
  required CertificateTrustStore? trust,
  required int ticket,
}) => null;
