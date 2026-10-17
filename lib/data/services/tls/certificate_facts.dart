import 'package:crypto/crypto.dart' as crypto;

/// What a server certificate says about itself — the parts `dart:io`'s
/// `X509Certificate` exposes, plus the subject alternative names it doesn't,
/// read out of the DER (`subjectAltNamesOf`).
///
/// A leaf: it imports nothing from the app, so the trust store, the login
/// view model and the dialog can all share it (docs/trusting-a-self-hosted-
/// certificate.md).
class CertificateFacts {
  const CertificateFacts({
    required this.sha256,
    required this.subject,
    required this.issuer,
    required this.notBefore,
    required this.notAfter,
    this.subjectAltNames = const [],
  });

  /// From the fields `X509Certificate` carries. [der] is the whole
  /// certificate; its SHA-256 is what a trust pins, and is the same value
  /// `openssl x509 -noout -fingerprint -sha256` prints.
  factory CertificateFacts.fromCertificate({
    required List<int> der,
    required String subject,
    required String issuer,
    required DateTime notBefore,
    required DateTime notAfter,
  }) => CertificateFacts(
    sha256: crypto.sha256.convert(der).toString(),
    subject: subject,
    issuer: issuer,
    notBefore: notBefore.toUtc(),
    notAfter: notAfter.toUtc(),
    subjectAltNames: subjectAltNamesOf(der) ?? const [],
  );

  /// Lower-case hex, 64 characters.
  final String sha256;

  /// OpenSSL's one-line form, `/C=GB/O=Sectigo Limited/CN=…`.
  final String subject;
  final String issuer;
  final DateTime notBefore;
  final DateTime notAfter;

  /// The DNS names and IP addresses the certificate covers. Empty when it
  /// has none (or they couldn't be read) — then [commonName] is the name.
  final List<String> subjectAltNames;

  String? get commonName => distinguishedNameField(subject, 'CN');

  /// The names this certificate is for, as a person would list them: its
  /// subject alternative names, else its common name.
  List<String> get names =>
      subjectAltNames.isNotEmpty ? subjectAltNames : [?commonName];

  /// Who issued it, readably: the issuer's CN, else its organisation, else
  /// the raw one-line name.
  String get issuerName =>
      distinguishedNameField(issuer, 'CN') ??
      distinguishedNameField(issuer, 'O') ??
      issuer;

  /// Subject and issuer are the same name — the usual shape of a
  /// self-signed certificate.
  bool get isSelfIssued => subject.isNotEmpty && subject == issuer;

  /// `AB:CD:…`, the form browsers and `openssl` show.
  String get displayFingerprint => _pairs(sha256).join(':');

  /// The first eight bytes of [displayFingerprint], for a list row.
  String get shortFingerprint => '${_pairs(sha256).take(8).join(':')}…';

  static Iterable<String> _pairs(String hex) => [
    for (var i = 0; i + 1 < hex.length; i += 2)
      hex.substring(i, i + 2).toUpperCase(),
  ];

  Map<String, dynamic> toJson() => {
    'sha256': sha256,
    'subject': subject,
    'issuer': issuer,
    'not_before': notBefore.toUtc().toIso8601String(),
    'not_after': notAfter.toUtc().toIso8601String(),
    if (subjectAltNames.isNotEmpty) 'san': subjectAltNames,
  };

  /// Throws on a malformed entry; the store skips that entry.
  factory CertificateFacts.fromJson(Map<String, dynamic> json) {
    final sha256 = json['sha256'] as String;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256)) {
      throw FormatException('Not a SHA-256 fingerprint: $sha256');
    }
    return CertificateFacts(
      sha256: sha256,
      subject: json['subject'] as String? ?? '',
      issuer: json['issuer'] as String? ?? '',
      notBefore: DateTime.parse(json['not_before'] as String).toUtc(),
      notAfter: DateTime.parse(json['not_after'] as String).toUtc(),
      subjectAltNames: [
        for (final name in (json['san'] as List?) ?? const []) '$name',
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CertificateFacts && other.sha256 == sha256;

  @override
  int get hashCode => sha256.hashCode;
}

/// One field of a distinguished name, in either OpenSSL's one-line form
/// (`/C=GB/CN=example.com`, what `X509Certificate.subject` returns) or the
/// RFC 2253 form (`CN=example.com, O=…`). The last occurrence wins, as it
/// does for a certificate's most specific CN. Null when absent or blank.
String? distinguishedNameField(String name, String field) {
  final parts = name.startsWith('/')
      ? name.substring(1).split('/')
      : name.split(RegExp(r',\s*'));
  String? value;
  final prefix = '${field.toUpperCase()}=';
  for (final part in parts) {
    if (part.toUpperCase().startsWith(prefix)) {
      final v = part.substring(prefix.length).trim();
      if (v.isNotEmpty) value = v;
    }
  }
  return value;
}

/// The subject alternative names in a DER certificate — `dNSName` entries
/// as written, `iPAddress` entries as dotted IPv4 or uncompressed IPv6.
///
/// `dart:io`'s `X509Certificate` has no accessor for them, and they — not
/// the CN — are what a TLS client matches the host against (RFC 6125), so
/// without them a "the name doesn't match" message would be a guess. Null
/// when the DER can't be walked; an empty list when it has no SAN extension.
List<String>? subjectAltNamesOf(List<int> der) {
  try {
    final cert = _tlv(der, 0, der.length);
    final tbs = _tlv(der, cert.start, cert.end);
    var p = tbs.start;
    while (p < tbs.end) {
      final field = _tlv(der, p, tbs.end);
      p = field.end;
      // `[3] EXPLICIT Extensions`.
      if (field.tag != 0xA3) continue;
      final extensions = _tlv(der, field.start, field.end);
      var q = extensions.start;
      while (q < extensions.end) {
        final ext = _tlv(der, q, extensions.end);
        q = ext.end;
        final oid = _tlv(der, ext.start, ext.end);
        if (oid.tag != 0x06 || !_isSubjectAltNameOid(der, oid)) continue;
        var r = oid.end;
        var value = _tlv(der, r, ext.end);
        // `critical BOOLEAN DEFAULT FALSE`, present only when true.
        if (value.tag == 0x01) {
          r = value.end;
          value = _tlv(der, r, ext.end);
        }
        if (value.tag != 0x04) return const [];
        final names = _tlv(der, value.start, value.end);
        final out = <String>[];
        var n = names.start;
        while (n < names.end) {
          final name = _tlv(der, n, names.end);
          n = name.end;
          final bytes = der.sublist(name.start, name.end);
          if (name.tag == 0x82) {
            out.add(String.fromCharCodes(bytes));
          } else if (name.tag == 0x87) {
            final ip = _formatIp(bytes);
            if (ip != null) out.add(ip);
          }
        }
        return out;
      }
      return const [];
    }
    return const [];
  } catch (_) {
    return null;
  }
}

typedef _Tlv = ({int tag, int start, int end});

/// One DER tag-length-value starting at [pos], bounded by [limit].
_Tlv _tlv(List<int> b, int pos, int limit) {
  if (pos + 2 > limit) throw const FormatException('Truncated DER');
  final tag = b[pos];
  var length = b[pos + 1];
  var p = pos + 2;
  if (length & 0x80 != 0) {
    final count = length & 0x7F;
    if (count == 0 || count > 4 || p + count > limit) {
      throw const FormatException('Bad DER length');
    }
    length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | b[p++];
    }
  }
  if (p + length > limit) throw const FormatException('DER overruns');
  return (tag: tag, start: p, end: p + length);
}

/// OID 2.5.29.17 — `55 1D 11`.
bool _isSubjectAltNameOid(List<int> b, _Tlv oid) =>
    oid.end - oid.start == 3 &&
    b[oid.start] == 0x55 &&
    b[oid.start + 1] == 0x1D &&
    b[oid.start + 2] == 0x11;

String? _formatIp(List<int> bytes) {
  if (bytes.length == 4) return bytes.join('.');
  if (bytes.length == 16) {
    return [
      for (var i = 0; i < 16; i += 2)
        ((bytes[i] << 8) | bytes[i + 1]).toRadixString(16),
    ].join(':');
  }
  return null;
}
