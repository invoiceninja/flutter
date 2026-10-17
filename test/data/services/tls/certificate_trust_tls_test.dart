import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/http_client_factory.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_seam_io.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';

/// The whole path against a real TLS handshake: a local HTTPS server, the
/// `HttpOverrides` `main.dart` installs, the store, and `AuthService`'s
/// mapping. On CI (Linux) the OS verifier is BoringSSL; on the macOS dev
/// machines it is SecTrust (docs/trusting-a-self-hosted-certificate.md).
///
/// Fixtures — test-only keys for localhost, never used anywhere else. The
/// test CA's key was thrown away; regenerate all four `chain_*` files
/// together from a fresh CA if they ever need to change.
///
///     cd test/fixtures/tls
///     # A self-signed certificate, and another for a different name.
///     openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
///       -keyout localhost.key -out localhost.crt -subj "/CN=localhost" \
///       -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
///     openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
///       -keyout other_host.key -out other_host.crt \
///       -subj "/CN=example.invalid" -addext "subjectAltName=DNS:example.invalid"
///     # Two leaves from one private CA ("Admin Test CA"), each served with
///     # its chain: chain_<name>.crt = leaf + CA.
///     openssl req -x509 -newkey rsa:2048 -nodes -days 36500 -keyout ca.key \
///       -out ca.crt -subj "/CN=Admin Test CA" \
///       -addext "basicConstraints=critical,CA:TRUE" \
///       -addext "keyUsage=critical,keyCertSign,cRLSign"
///     # chain_localhost: CN=localhost, SAN DNS:localhost,IP:127.0.0.1
///     # chain_other:     CN=attacker.example, SAN DNS:attacker.example
///     openssl req -newkey rsa:2048 -nodes -keyout chain_X.key -out X.csr \
///       -subj "/CN=…"
///     openssl x509 -req -in X.csr -CA ca.crt -CAkey ca.key -days 36500 \
///       -CAcreateserial -out X.leaf.crt -extfile <(printf \
///       "subjectAltName=…\nbasicConstraints=CA:FALSE\nextendedKeyUsage=serverAuth")
///     cat X.leaf.crt ca.crt > chain_X.crt
///
/// `registrar_servers_leaf.crt` is a public shared-hosting default
/// certificate (Namecheap's `*.registrar-servers.com`), used only for
/// parsing.
const _localhostSha256 =
    '905ad9eebccce88902f0be704003aea5be28587c55d05c31067e7a78a045628c';
const _otherHostSha256 =
    '0a6b710cae09eadaf074baa76af186edbb8160251ed9fdd8573ebd463b7ca894';
const _chainLocalhostLeafSha256 =
    'c1b5378b6ffca47da7f69cbc4a34f06e6baee29c1d112ccf435a41eb7f72709c';
const _chainOtherLeafSha256 =
    '350d34d3bc6d499f81b46de02f9202d867710cd4d2717ab4cc5cb0ba6c2faa78';

Future<HttpServer> _serve(String fixture, {int port = 0}) async {
  final context = SecurityContext()
    ..useCertificateChain('test/fixtures/tls/$fixture.crt')
    ..usePrivateKey('test/fixtures/tls/$fixture.key');
  final server = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    port,
    context,
  );
  server.listen((request) async {
    await request.drain<void>();
    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'methods': <String>[], 'secret_required': false}));
    await request.response.close();
  });
  return server;
}

void main() {
  late CertificateTrustStore store;
  HttpServer? server;
  var served = 0;

  setUp(() {
    // No database: an in-memory store, loaded from the start.
    store = CertificateTrustStore(prefs: DevicePrefsStore(null));
    served = 0;
  });
  tearDown(() async {
    await server?.close(force: true);
    server = null;
  });

  /// Serve [fixture] on 127.0.0.1 — on [port] when given, so a test can put
  /// a different certificate on the same host:port.
  Future<String> start(String fixture, {int port = 0}) async {
    await server?.close(force: true);
    server = await _serve(fixture, port: port);
    return 'https://127.0.0.1:${server!.port}';
  }

  /// One precheck through a fresh `AuthService` whose client is created
  /// under the app's overrides — a zone override, because flutter_test owns
  /// the global one. A fresh client per call, so no kept-alive connection
  /// skips a handshake. Returns the error, or null when it went through.
  Future<Object?> precheck(String baseUrl, {bool withStore = true}) =>
      HttpOverrides.runWithHttpOverrides(() async {
        final client = createDefaultHttpClient();
        try {
          await AuthService(
            httpClient: client,
            certificateTrust: withStore ? store : null,
          ).precheck(baseUrl: baseUrl, isHosted: false, email: 'a@b.co');
          served++;
          return null;
        } catch (e) {
          return e;
        } finally {
          client.close();
        }
      }, TrustedCertificateHttpOverrides(() => withStore ? store : null));

  test('a self-signed certificate is named, trusted, then accepted', () async {
    final url = await start('localhost');
    final port = Uri.parse(url).port;

    final refused = await precheck(url);
    expect(refused, isA<UntrustedCertificateException>());
    refused as UntrustedCertificateException;
    expect(refused, isA<RequestNotSentException>());
    expect(refused.host, '127.0.0.1');
    expect(refused.port, port);
    expect(refused.certificate.sha256, _localhostSha256);
    expect(refused.certificate.subjectAltNames, ['localhost', '127.0.0.1']);
    // The name matches; only the self-signing is wrong.
    expect(refused.problems, [CertificateProblem.selfSigned]);
    expect(refused.message, isNot(contains('HandshakeException')));
    expect(served, 0);

    expect(await store.trust('127.0.0.1', port, refused.certificate), isTrue);
    expect(await precheck(url), isNull);
    expect(served, 1);
    expect(store.outstandingFor('127.0.0.1', port), isNull);
  });

  test("a CA-issued chain is judged by the server's own certificate", () async {
    // What a shared-hosting default does: a chain whose top is a CA. The
    // TLS callback would only ever have seen that CA.
    final url = await start('chain_localhost');
    final port = Uri.parse(url).port;

    final refused = await precheck(url);
    expect(refused, isA<UntrustedCertificateException>());
    refused as UntrustedCertificateException;
    expect(refused.certificate.sha256, _chainLocalhostLeafSha256);
    expect(refused.certificate.commonName, 'localhost');
    expect(refused.certificate.issuerName, 'Admin Test CA');
    expect(refused.problems, [CertificateProblem.untrustedIssuer]);

    await store.trust('127.0.0.1', port, refused.certificate);
    expect(await precheck(url), isNull);
  });

  test('another certificate from the same CA is refused for a trusted host — '
      'what someone intercepting the connection would present', () async {
    final url = await start('chain_localhost');
    final port = Uri.parse(url).port;
    final first = await precheck(url) as UntrustedCertificateException;
    await store.trust('127.0.0.1', port, first.certificate);
    expect(await precheck(url), isNull);

    // Same host:port, same CA, someone else's certificate.
    await start('chain_other', port: port);
    final second = await precheck(url);
    expect(second, isA<UntrustedCertificateException>());
    second as UntrustedCertificateException;
    expect(second.certificate.sha256, _chainOtherLeafSha256);
    expect(second.problems, contains(CertificateProblem.nameMismatch));
    expect(served, 1, reason: 'nothing was sent to the impostor');
  });

  test(
    'a different self-signed certificate on a trusted host is refused',
    () async {
      final url = await start('localhost');
      final port = Uri.parse(url).port;
      final first = await precheck(url) as UntrustedCertificateException;
      await store.trust('127.0.0.1', port, first.certificate);

      await start('other_host', port: port);
      final again = await precheck(url);
      expect(again, isA<UntrustedCertificateException>());
      again as UntrustedCertificateException;
      expect(again.certificate.sha256, _otherHostSha256);
      expect(again.problems, [
        CertificateProblem.nameMismatch,
        CertificateProblem.selfSigned,
      ]);

      // Trusting that one instead lets it through.
      await store.trust('127.0.0.1', port, again.certificate);
      expect(await precheck(url), isNull);
    },
  );

  // The hook lets every handshake the OS refuses finish, so it can read the
  // leaf. That is safe only while `dart:io` asks again on every connection —
  // never caching the "accepted" answer or resuming the TLS session. If it
  // ever did, `onBadCertificate` would not run, the hook would see a
  // certificate the OS trusted, and an unpinned server would be admitted.
  for (final fixture in ['localhost', 'chain_localhost']) {
    test('$fixture: a refused certificate is refused again on the next '
        'connection', () async {
      final url = await start(fixture);
      expect(await precheck(url), isA<UntrustedCertificateException>());
      expect(await precheck(url), isA<UntrustedCertificateException>());
      expect(served, 0);
    });

    test('$fixture: and again on one long-lived client', () async {
      final url = Uri.parse('${await start(fixture)}/');
      final outcomes = await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        final results = <Object?>[];
        try {
          for (var i = 0; i < 3; i++) {
            try {
              final request = await client.getUrl(url)
                ..persistentConnection = false;
              final response = await request.close();
              await response.drain<void>();
              results.add(response.statusCode);
            } catch (e) {
              results.add(e);
            }
          }
        } finally {
          client.close(force: true);
        }
        return results;
      }, TrustedCertificateHttpOverrides(() => store));
      expect(outcomes, everyElement(isA<HandshakeException>()));
      // The hook judged — and refused — all three connections.
      expect(store.rejectionSerial, 3);
    });
  }

  test('a revoked certificate is refused on the next connection', () async {
    final url = await start('localhost');
    final port = Uri.parse(url).port;
    final refused = await precheck(url) as UntrustedCertificateException;
    await store.trust('127.0.0.1', port, refused.certificate);
    expect(await precheck(url), isNull);

    await store.revoke('127.0.0.1', port);
    expect(await precheck(url), isA<UntrustedCertificateException>());
  });

  test('without a store a refusal is still a clean, unsent failure', () async {
    final url = await start('localhost');
    final error = await precheck(url, withStore: false);
    expect(error, isA<RequestNotSentException>());
    expect(error, isNot(isA<UntrustedCertificateException>()));
    expect(
      (error! as RequestNotSentException).message,
      isNot(contains('HandshakeException')),
    );
    expect(served, 0);
  });
}
