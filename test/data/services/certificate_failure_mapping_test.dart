import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/data/services/upload_source.dart';

/// How each transport turns a failed TLS handshake into an exception the UI
/// can explain. The fake client does what `IOClient` does when the
/// connection hook refuses a certificate: the hook has recorded the refusal,
/// then `HandshakeException` escapes `send` unwrapped. The real handshake is
/// `tls/certificate_trust_tls_test.dart`.

final _registrar = CertificateFacts(
  sha256: 'cd' * 32,
  subject: '/CN=*.registrar-servers.com',
  issuer:
      '/C=GB/O=Sectigo Limited/CN=Sectigo Public Server Authentication CA DV R36',
  notBefore: DateTime.utc(2025, 11, 7, 12),
  notAfter: DateTime.utc(2099, 11, 17, 12),
  subjectAltNames: const ['*.registrar-servers.com', 'registrar-servers.com'],
);

HandshakeException _handshake([String reason = 'Hostname mismatch']) =>
    HandshakeException(
      'Handshake error in client',
      OSError('CERTIFICATE_VERIFY_FAILED: $reason(handshake.cc:393)', 1),
    );

/// Refuses the certificate the way the installed overrides would, for
/// whichever host [refusedHost] names (the request's own, by default).
class _RefusingClient extends http.BaseClient {
  _RefusingClient(this.store, {this.refusedHost, this.record = true});

  final CertificateTrustStore store;
  final String? refusedHost;
  final bool record;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    if (record) {
      store.recordRejection(
        refusedHost ?? request.url.host,
        request.url.port,
        _registrar,
      );
    }
    throw _handshake();
  }
}

void main() {
  late CertificateTrustStore store;
  setUp(() => store = CertificateTrustStore(prefs: DevicePrefsStore(null)));

  group('AuthService', () {
    Future<Object?> precheck(http.Client client) =>
        AuthService(httpClient: client, certificateTrust: store)
            .precheck(
              baseUrl: 'https://pay.example.com',
              isHosted: false,
              email: 'a@b.co',
            )
            .then<Object?>((_) => null, onError: (Object e) => e);

    test('names the refused certificate', () async {
      final error = await precheck(_RefusingClient(store));
      expect(error, isA<UntrustedCertificateException>());
      error as UntrustedCertificateException;
      expect(error, isA<RequestNotSentException>());
      expect(error.host, 'pay.example.com');
      expect(error.port, 443);
      expect(error.certificate, _registrar);
      expect(error.problems, [CertificateProblem.nameMismatch]);
      expect(error.osReason, 'Hostname mismatch');
      expect(error.message, isNot(contains('HandshakeException')));
    });

    test('a redirect names the host that refused it', () async {
      final error = await precheck(
        _RefusingClient(store, refusedHost: 'www.pay.example.com'),
      );
      expect(error, isA<UntrustedCertificateException>());
      expect(
        (error! as UntrustedCertificateException).host,
        'www.pay.example.com',
      );
    });

    test('an earlier refusal is never blamed on this request', () async {
      store.recordRejection('pay.example.com', 443, _registrar);
      final error = await precheck(_RefusingClient(store, record: false));
      expect(error, isA<RequestNotSentException>());
      expect(error, isNot(isA<UntrustedCertificateException>()));
      expect(
        (error! as RequestNotSentException).message,
        "Couldn't make a secure connection to pay.example.com: Hostname mismatch",
      );
    });

    test('a response clears an outstanding refusal', () async {
      store.recordRejection('pay.example.com', 443, _registrar);
      await AuthService(
        httpClient: _Answers(),
        certificateTrust: store,
      ).precheck(
        baseUrl: 'https://pay.example.com',
        isHosted: false,
        email: 'a',
      );
      expect(store.outstandingFor('pay.example.com', 443), isNull);
    });
  });

  group('ApiClient', () {
    ApiClient clientWith(http.Client http_) => ApiClient(
      credentials: ValueNotifier<ApiCredentials?>(
        const ApiCredentials(baseUrl: 'https://pay.example.com', token: 't'),
      ),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: http_,
      certificateTrust: store,
    );

    test('a JSON request', () async {
      await expectLater(
        clientWith(_RefusingClient(store)).postJson('/api/v1/clients'),
        throwsA(
          isA<UntrustedCertificateException>().having(
            (e) => e.certificate,
            'certificate',
            _registrar,
          ),
        ),
      );
    });

    test('a multipart upload', () async {
      await expectLater(
        clientWith(_RefusingClient(store)).uploadMultipart(
          path: '/api/v1/clients/1/upload',
          fields: const {},
          files: [
            http.MultipartFile.fromBytes('f', const [1], filename: 'a'),
          ],
          idempotencyKey: 'k',
        ),
        throwsA(isA<UntrustedCertificateException>()),
      );
    });

    test('a chunked upload', () async {
      await expectLater(
        clientWith(_RefusingClient(store)).uploadMultipartChunked(
          path: '/api/v1/import',
          source: BytesUploadSource(Uint8List.fromList([1, 2, 3]), 'a.csv'),
          commonFields: const {},
          commonQueryTrue: const {},
          idempotencyKey: 'k',
        ),
        throwsA(isA<UntrustedCertificateException>()),
      );
    });

    test('any response clears an outstanding refusal', () async {
      store.recordRejection('pay.example.com', 443, _registrar);
      await clientWith(_Answers()).postJson('/api/v1/clients');
      expect(store.outstandingFor('pay.example.com', 443), isNull);
    });
  });
}

class _Answers extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await request.finalize().drain<void>();
    return http.StreamedResponse(
      Stream.value('{}'.codeUnits),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
