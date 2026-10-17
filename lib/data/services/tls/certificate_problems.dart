import 'package:admin/data/services/tls/certificate_facts.dart';

/// Why a certificate was refused, as far as the app can tell. Ordered by how
/// the dialog leads: the first one present is the headline.
enum CertificateProblem {
  /// Its validity starts in the future — often this device's clock.
  notYetValid,

  /// Its validity has ended.
  expired,

  /// None of the names it is for covers the host.
  nameMismatch,

  /// It signed itself.
  selfSigned,

  /// Signed by an authority this device doesn't trust, or the server isn't
  /// sending the intermediate that links it to one. Also the fallback when
  /// nothing more specific can be named.
  untrustedIssuer,
}

/// The problems with [facts] as presented for [host], most telling first;
/// never empty.
///
/// Two sources, because neither is enough alone. The certificate's own
/// fields answer for dates, names and self-signing on every platform. The OS
/// reason ([osReason], from [verifyReasonOf]) is the only evidence of a
/// missing intermediate — but BoringSSL (Android, Windows, Linux) reports
/// just the first error it hit, and Apple's verifier reports none at all
/// ("application verification failure").
List<CertificateProblem> certificateProblems({
  required String host,
  required CertificateFacts facts,
  required DateTime now,
  String? osReason,
}) {
  final reason = osReason?.toLowerCase() ?? '';
  final problems = <CertificateProblem>{};
  if (now.isBefore(facts.notBefore) || reason.contains('not yet valid')) {
    problems.add(CertificateProblem.notYetValid);
  }
  if (now.isAfter(facts.notAfter) || reason.contains('expired')) {
    problems.add(CertificateProblem.expired);
  }
  final names = facts.names;
  if (reason.contains('hostname mismatch') ||
      (names.isNotEmpty && !names.any((n) => hostMatchesName(host, n)))) {
    problems.add(CertificateProblem.nameMismatch);
  }
  if (facts.isSelfIssued ||
      reason.contains('self signed') ||
      reason.contains('self-signed')) {
    problems.add(CertificateProblem.selfSigned);
  }
  if (reason.contains('unable to get local issuer') ||
      reason.contains('unable to get issuer') ||
      reason.contains('unable to verify the first certificate') ||
      problems.isEmpty) {
    problems.add(CertificateProblem.untrustedIssuer);
  }
  return [
    for (final p in CertificateProblem.values)
      if (problems.contains(p)) p,
  ];
}

/// Whether [name] (a certificate's DNS name or IP) covers [host], by
/// RFC 6125's rules as browsers apply them: case-insensitive, a trailing
/// dot ignored, a wildcard only as the whole left-most label and covering
/// exactly one label (`*.example.com` covers `a.example.com`, not
/// `example.com` or `a.b.example.com`), and an IP address matched exactly.
bool hostMatchesName(String host, String name) {
  final h = normalizeCertificateHost(host);
  final n = normalizeCertificateHost(name);
  if (h.isEmpty || n.isEmpty) return false;
  final hostIp = _ipBytes(h);
  if (hostIp != null) {
    final nameIp = _ipBytes(n);
    return nameIp != null && _sameBytes(hostIp, nameIp);
  }
  if (!n.startsWith('*.')) return h == n;
  final suffix = n.substring(1); // `.example.com`
  // A wildcard over a single label (`*.com`) covers nothing.
  if (!suffix.substring(1).contains('.')) return false;
  if (!h.endsWith(suffix)) return false;
  final label = h.substring(0, h.length - suffix.length);
  return label.isNotEmpty && !label.contains('.');
}

/// Lower-cased, without a trailing dot or IPv6 brackets — the key a host is
/// stored and compared under.
String normalizeCertificateHost(String host) {
  var h = host.trim().toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  while (h.endsWith('.')) {
    h = h.substring(0, h.length - 1);
  }
  return h;
}

/// The verifier's reason out of a TLS error's OS message —
/// `CERTIFICATE_VERIFY_FAILED: Hostname mismatch(handshake.cc:393)` gives
/// `Hostname mismatch`. Null when there is no such reason.
String? verifyReasonOf(String? osMessage) {
  if (osMessage == null) return null;
  final match = RegExp(
    r'CERTIFICATE_VERIFY_FAILED:\s*([^\n(]+)',
  ).firstMatch(osMessage);
  final reason = match?.group(1)?.trim();
  return reason == null || reason.isEmpty ? null : reason;
}

List<int>? _ipBytes(String host) {
  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host)) {
    try {
      return Uri.parseIPv4Address(host);
    } on FormatException {
      return null;
    }
  }
  if (host.contains(':')) {
    try {
      return Uri.parseIPv6Address(host);
    } on FormatException {
      return null;
    }
  }
  return null;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
