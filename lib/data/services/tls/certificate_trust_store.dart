import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';

final _log = Logger('tls');

/// A certificate the user chose to trust for one self-hosted host:port.
class TrustedCertificate {
  const TrustedCertificate({
    required this.host,
    required this.port,
    required this.facts,
    required this.trustedAt,
  });

  final String host;
  final int port;
  final CertificateFacts facts;
  final DateTime trustedAt;

  String get key => certificateHostKey(host, port);

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    ...facts.toJson(),
    'trusted_at': trustedAt.toUtc().toIso8601String(),
  };

  factory TrustedCertificate.fromJson(Map<String, dynamic> json) =>
      TrustedCertificate(
        host: normalizeCertificateHost(json['host'] as String),
        port: (json['port'] as num).toInt(),
        facts: CertificateFacts.fromJson(json),
        trustedAt: DateTime.parse(json['trusted_at'] as String).toUtc(),
      );
}

/// A server certificate this device refused — always the server's own (the
/// leaf), read after the handshake by `TrustedCertificateHttpOverrides`.
class CertificateRejection {
  const CertificateRejection({
    required this.host,
    required this.port,
    required this.facts,
    required this.serial,
  });

  final String host;
  final int port;
  final CertificateFacts facts;

  /// Its place in [CertificateTrustStore.rejectionSerial]'s sequence.
  final int serial;

  String get key => certificateHostKey(host, port);
}

String certificateHostKey(String host, int port) =>
    '${normalizeCertificateHost(host)}:$port';

/// Whether [host] is the hosted service, whose certificate is never ours to
/// overrule: a failure there means an intercepting network or a wrong
/// clock, never a server the user runs.
bool isHostedCertificateHost(String host) {
  final h = normalizeCertificateHost(host);
  final hosted = Uri.tryParse(Env.hostedApiUrl)?.host.toLowerCase() ?? '';
  return (hosted.isNotEmpty && h == hosted) ||
      h == 'invoicing.co' ||
      h.endsWith('.invoicing.co');
}

/// The certificates this device trusts beyond what the OS does, and the
/// ones it has just refused.
///
/// Owns `DevicePrefKeys.trustedCertificates` and follows [DevicePrefsStore]
/// the way `PhoneActionsController` does. The connection hook
/// (`certificate_trust_seam_io.dart`) asks [isTrusted] about the server's own
/// certificate once a handshake the OS refused has finished, and reports a
/// refusal to [recordRejection] — both synchronous, between the handshake and
/// the first byte of the request.
///
/// A trust is a pin: one exact certificate (its SHA-256) for one host:port.
/// A different certificate on the same server is refused again, which is
/// the point — that is what someone intercepting the connection looks like.
/// Never for the hosted service ([isHostedCertificateHost]).
class CertificateTrustStore extends ChangeNotifier {
  CertificateTrustStore({
    required DevicePrefsStore prefs,
    bool Function(String host)? isHostedHost,
    DateTime Function()? now,
  }) : _prefs = prefs,
       _isHostedHost = isHostedHost ?? isHostedCertificateHost,
       _now = now ?? DateTime.now,
       _pins = _read(prefs) {
    prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;
  final bool Function(String host) _isHostedHost;
  final DateTime Function() _now;

  /// How many recent rejections [rejectionAfter] can look back over — far
  /// more than one request's connection records.
  static const _kRecentRejections = 16;

  List<TrustedCertificate> _pins;
  final List<CertificateRejection> _recent = [];
  final Map<String, CertificateRejection> _outstanding = {};
  final List<CertificateRejection> _toLog = [];
  int _serial = 0;
  bool _notifyScheduled = false;
  bool _disposed = false;

  /// Every trusted certificate, oldest first.
  List<TrustedCertificate> get pins => _pins;

  bool isHosted(String host) => _isHostedHost(host);

  /// Whether the certificate [sha256] is trusted for [host]:[port]. Called on
  /// every connection the OS refused, so it must be cheap and must not throw.
  bool isTrusted(String host, int port, String sha256) {
    if (_isHostedHost(host)) return false;
    final key = certificateHostKey(host, port);
    for (final pin in _pins) {
      if (pin.key == key && pin.facts.sha256 == sha256) return true;
    }
    return false;
  }

  TrustedCertificate? pinFor(String host, int port) {
    final key = certificateHostKey(host, port);
    for (final pin in _pins) {
      if (pin.key == key) return pin;
    }
    return null;
  }

  /// Bumped by every [recordRejection]. A caller reads it before a request
  /// and hands it to [rejectionAfter], so a refusal recorded earlier — by
  /// another request — is never blamed on this one. A counter rather than a
  /// time: the clock is exactly what an expired or not-yet-valid
  /// certificate may have wrong.
  int get rejectionSerial => _serial;

  /// Note that [facts] were refused for [host]:[port]. Synchronous — it runs
  /// on the connection path; listeners and the diagnostics log hear about it
  /// on the next microtask.
  ///
  /// Ignored until the preferences have loaded: before then a pin may simply
  /// not be read yet, and the request it failed will be retried anyway.
  void recordRejection(String host, int port, CertificateFacts facts) {
    if (!_prefs.isLoaded || _disposed) return;
    final rejection = CertificateRejection(
      host: normalizeCertificateHost(host),
      port: port,
      facts: facts,
      serial: ++_serial,
    );
    _recent.add(rejection);
    if (_recent.length > _kRecentRejections) _recent.removeAt(0);
    final previous = _outstanding[rejection.key];
    _outstanding[rejection.key] = rejection;
    if (previous?.facts != facts) {
      _toLog.add(rejection);
      _scheduleNotify();
    }
  }

  /// The refusal that explains a request which failed its handshake: one
  /// recorded since [ticket] for [host]:[port] — or, when the request was
  /// redirected to another host, the only one recorded since. Null when
  /// nothing since [ticket] can be pinned on it.
  CertificateRejection? rejectionAfter(
    int ticket, {
    required String host,
    required int port,
  }) {
    final since = [
      for (final r in _recent)
        if (r.serial > ticket) r,
    ];
    if (since.isEmpty) return null;
    final key = certificateHostKey(host, port);
    for (final r in since.reversed) {
      if (r.key == key) return r;
    }
    final keys = {for (final r in since) r.key};
    return keys.length == 1 ? since.last : null;
  }

  /// The latest refusal for [host]:[port] that nothing has resolved yet —
  /// no trust, no revoke, and no response from that server since.
  CertificateRejection? outstandingFor(String host, int port) =>
      _outstanding[certificateHostKey(host, port)];

  /// A response came back from [host]:[port], so its connection is fine
  /// again. On every response, so it returns at once when nothing is
  /// outstanding.
  void noteReached(String host, int port) {
    if (_outstanding.isEmpty) return;
    if (_outstanding.remove(certificateHostKey(host, port)) != null) {
      _scheduleNotify();
    }
  }

  /// Trust [facts] for [host]:[port], replacing whatever was trusted there.
  /// False — and nothing stored — for the hosted service.
  Future<bool> trust(String host, int port, CertificateFacts facts) async {
    final h = normalizeCertificateHost(host);
    if (_isHostedHost(h)) return false;
    final pin = TrustedCertificate(
      host: h,
      port: port,
      facts: facts,
      trustedAt: _now().toUtc(),
    );
    _pins = List.unmodifiable([
      for (final p in _pins)
        if (p.key != pin.key) p,
      pin,
    ]);
    _outstanding.remove(pin.key);
    _log.info(
      'Trusted the certificate ${facts.shortFingerprint} for ${pin.key}',
    );
    notifyListeners();
    await _write();
    return true;
  }

  /// Stop trusting whatever is pinned for [host]:[port].
  Future<void> revoke(String host, int port) async {
    final key = certificateHostKey(host, port);
    final next = [
      for (final p in _pins)
        if (p.key != key) p,
    ];
    if (next.length == _pins.length) return;
    _pins = List.unmodifiable(next);
    _outstanding.remove(key);
    _log.info('Stopped trusting the pinned certificate for $key');
    notifyListeners();
    await _write();
  }

  Future<void> _write() => _prefs.write(
    DevicePrefKeys.trustedCertificates,
    _pins.isEmpty ? null : jsonEncode([for (final p in _pins) p.toJson()]),
  );

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (_disposed) return;
      for (final r in _toLog) {
        _log.warning(
          'Refused the certificate for ${r.key}: '
          '${certificateProblems(host: r.host, facts: r.facts, now: _now()).map((p) => p.name).join(', ')}; '
          'issued to ${r.facts.names.join(', ')} by ${r.facts.issuerName}; '
          'SHA-256 ${r.facts.shortFingerprint}',
        );
      }
      _toLog.clear();
      notifyListeners();
    });
  }

  static List<TrustedCertificate> _read(DevicePrefsStore prefs) {
    final raw = prefs.read(DevicePrefKeys.trustedCertificates);
    if (raw == null || raw.isEmpty) return const [];
    final List<dynamic> entries;
    try {
      entries = jsonDecode(raw) as List<dynamic>;
    } catch (e, st) {
      // A corrupt blob trusts nothing — the safe reading — rather than
      // wedging boot. The next trust rewrites it.
      _log.warning('Could not read the trusted certificates', e, st);
      return const [];
    }
    final pins = <TrustedCertificate>[];
    for (final entry in entries) {
      try {
        pins.add(
          TrustedCertificate.fromJson(Map<String, dynamic>.from(entry as Map)),
        );
      } catch (e) {
        _log.warning('Skipped an unreadable trusted certificate: $e');
      }
    }
    return List.unmodifiable(pins);
  }

  void _sync() {
    final next = _read(_prefs);
    if (listEquals(
      [for (final p in next) '${p.key}|${p.facts.sha256}'],
      [for (final p in _pins) '${p.key}|${p.facts.sha256}'],
    )) {
      return;
    }
    _pins = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _prefs.removeListener(_sync);
    super.dispose();
  }
}
