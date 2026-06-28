/// Classifies a URL host as a "local network" address — loopback, private-LAN,
/// link-local, or CGNAT/Tailscale — or a non-publicly-routable local hostname
/// suffix.
///
/// Used by the self-hosted login flow ([resolveSelfHostedBaseUrl]) to decide
/// when plain (cleartext) `http://` is acceptable: a server on the user's own
/// network is a far smaller risk than an arbitrary public host. Public /
/// routable hosts return `false`, so the login screen keeps requiring
/// `https://` for them in release builds.
///
/// Pure Dart (no `dart:io`) so it runs on web and is unit-testable in
/// isolation. [host] is expected to be a [Uri.host] value (IPv6 brackets
/// already stripped), but a bracketed literal is tolerated defensively.
bool isLocalNetworkHost(String host) {
  var h = host.toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) {
    h = h.substring(1, h.length - 1); // tolerate a bracketed IPv6 literal
  }
  if (h.isEmpty) return false;
  if (h == 'localhost') return true;

  // Non-publicly-routable hostname suffixes. `.local` (mDNS), `.internal` and
  // `.home.arpa` are IANA-reserved; `.lan` is conventional (undelegated today).
  // This branch trusts the local resolver — an on-LAN mDNS responder is the
  // residual risk (see the self-hosted login security note).
  for (final suffix in const ['.local', '.lan', '.home.arpa', '.internal']) {
    if (h.endsWith(suffix)) return true;
  }

  // IPv6 literal — parse to bytes so we test the real address, not a text
  // prefix (`fe8::1` is `0fe8::1`, not link-local; `fc::1` is `00fc::1`).
  if (h.contains(':')) {
    final List<int> bytes;
    try {
      bytes = Uri.parseIPv6Address(h);
    } on FormatException {
      return false;
    }
    if (bytes[15] == 1 && bytes.take(15).every((byte) => byte == 0)) {
      return true; // ::1 loopback
    }
    if ((bytes[0] & 0xfe) == 0xfc) return true; // fc00::/7 unique-local
    if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) {
      return true; // fe80::/10 link-local
    }
    return false;
  }

  // IPv4 literal — canonical dotted-decimal only.
  final parts = h.split('.');
  if (parts.length != 4) return false;
  final octets = <int>[];
  for (final part in parts) {
    // Reject leading-zero / 0x / signed octets: a resolver may read `010` as
    // octal 8 while int.parse reads decimal 10 — a validator-vs-resolver split
    // that could classify a public IP as local.
    if (!_ipv4Octet.hasMatch(part)) return false;
    final n = int.parse(part);
    if (n > 255) return false;
    octets.add(n);
  }
  final a = octets[0], b = octets[1];
  return a ==
          127 // 127.0.0.0/8 loopback
          ||
      a ==
          10 // 10.0.0.0/8
          ||
      (a == 192 && b == 168) // 192.168.0.0/16
      ||
      (a == 172 && b >= 16 && b <= 31) // 172.16.0.0/12
      ||
      (a == 169 && b == 254) // 169.254.0.0/16 link-local
      ||
      (a == 100 && b >= 64 && b <= 127); // 100.64.0.0/10 CGNAT (Tailscale)
}

/// A single canonical decimal IPv4 octet: `0`, or 1–3 digits with no leading
/// zero (and no `0x` / sign). Non-canonical forms are rejected so the classifier
/// can't disagree with the OS resolver about which address a host string names.
final RegExp _ipv4Octet = RegExp(r'^(0|[1-9]\d{0,2})$');
