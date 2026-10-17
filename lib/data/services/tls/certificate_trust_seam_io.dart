import 'dart:async';
import 'dart:io';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';

/// Native half of the [certificate_trust_seam].
///
/// Install the overrides that let a pinned certificate through, for every
/// `HttpClient` created from now on — ApiClient's and AuthService's, and the
/// lazily created ones behind `NetworkImage` and `WebSocket`. Called once by
/// `main.dart`, before `Services.build` constructs the first client; [trust]
/// is read on every refusal, so the store can be attached after this runs and
/// a new trust applies to the next connection without a restart.
void installCertificateTrust(CertificateTrustStore? Function() trust) {
  HttpOverrides.global = TrustedCertificateHttpOverrides(trust);
}

/// Opens every direct HTTPS connection itself, so that a certificate the OS
/// refuses is judged by the **server's own certificate** — never by whatever
/// `badCertificateCallback` would have been handed.
///
/// That callback can't identify a server: measured on both `dart:io` paths
/// (SecTrust on Apple, BoringSSL elsewhere), it receives the *top* of the
/// chain the server sent, which is the server's certificate only when the
/// chain is a single self-signed one. For a shared-hosting default
/// certificate it was "Sectigo Public Server Authentication Root R46" — so
/// pinning it would have trusted any Sectigo-issued certificate presented
/// for that host, an attacker's included (docs/trusting-a-self-hosted-certificate.md § The callback is
/// handed the top of the chain, not the server's certificate).
///
/// So when the OS refuses, the handshake is allowed to finish — which sends
/// the server nothing but the handshake — and the connection is handed to
/// `HttpClient` only if `peerCertificate`, the leaf, is the one pinned for
/// this host:port. Otherwise the socket is destroyed before a byte of the
/// request is written, the leaf is reported to the store, and the request
/// fails with a [HandshakeException], as an untrusted certificate always
/// has.
///
/// Through a proxy `HttpClient` builds the TLS tunnel itself and asks only
/// `badCertificateCallback`, which is left unset: refused.
class TrustedCertificateHttpOverrides extends HttpOverrides {
  TrustedCertificateHttpOverrides(this._trust);

  final CertificateTrustStore? Function() _trust;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      if (proxyHost != null && proxyPort != null) {
        return Socket.startConnect(proxyHost, proxyPort);
      }
      if (uri.scheme != 'https') return Socket.startConnect(uri.host, uri.port);
      return _connectSecure(uri.host, uri.port, context);
    };
    return client;
  }

  Future<ConnectionTask<Socket>> _connectSecure(
    String host,
    int port,
    SecurityContext? context,
  ) async {
    var refusedByOs = false;
    final task = await SecureSocket.startConnect(
      host,
      port,
      context: context,
      // Finish the handshake so the server's certificate can be read below;
      // nothing reaches the socket until it has been judged.
      onBadCertificate: (_) => refusedByOs = true,
    );
    return ConnectionTask.fromSocket(
      task.socket.then<Socket>(
        (socket) => refusedByOs ? _admit(socket, host, port) : socket,
      ),
      task.cancel,
    );
  }

  /// [socket] if its certificate is the one pinned for [host]:[port];
  /// otherwise it is destroyed and the leaf reported. Never throws anything
  /// but the [HandshakeException] the request fails with.
  Socket _admit(SecureSocket socket, String host, int port) {
    CertificateFacts? leaf;
    try {
      final cert = socket.peerCertificate;
      if (cert != null) {
        leaf = CertificateFacts.fromCertificate(
          der: cert.der,
          subject: cert.subject,
          issuer: cert.issuer,
          notBefore: cert.startValidity,
          notAfter: cert.endValidity,
        );
      }
    } catch (_) {
      leaf = null;
    }
    CertificateTrustStore? store;
    try {
      store = _trust();
      if (leaf != null && store != null) {
        if (store.isTrusted(host, port, leaf.sha256)) return socket;
        store.recordRejection(host, port, leaf);
      }
    } catch (_) {
      // Fail closed.
    }
    socket.destroy();
    throw const HandshakeException(
      'Handshake error in client',
      OSError('CERTIFICATE_VERIFY_FAILED', 0),
    );
  }
}

/// The typed exception for a request whose TLS handshake failed — null for
/// any other error, which the caller maps as before.
///
/// [ticket] is [CertificateTrustStore.rejectionSerial] read before the
/// request. With a refusal recorded since then, it is an
/// [UntrustedCertificateException] naming the certificate; without one (a
/// protocol mismatch, say) a plain [RequestNotSentException] whose message
/// is the verifier's reason, never the `HandshakeException` text.
RequestNotSentException? untrustedCertificateFrom(
  Object error, {
  required Uri uri,
  required CertificateTrustStore? trust,
  required int ticket,
}) {
  // A handshake precedes every byte of the request, so whatever happens
  // here, nothing was sent.
  if (error is! HandshakeException) return null;
  final reason = verifyReasonOf(error.osError?.message ?? error.message);
  final rejection = trust?.rejectionAfter(
    ticket,
    host: uri.host,
    port: uri.port,
  );
  if (rejection == null) {
    return RequestNotSentException(
      reason == null
          ? "Couldn't make a secure connection to ${uri.host}"
          : "Couldn't make a secure connection to ${uri.host}: $reason",
    );
  }
  return UntrustedCertificateException(
    host: rejection.host,
    port: rejection.port,
    certificate: rejection.facts,
    osReason: reason,
    problems: certificateProblems(
      host: rejection.host,
      facts: rejection.facts,
      osReason: reason,
      now: DateTime.now(),
    ),
  );
}
