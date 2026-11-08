import 'dart:convert';

import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_authenticator.dart';
import 'package:admin/data/services/passkey_codec.dart';
import 'package:admin/data/services/passkey_readiness.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// docs/passkeys.md § Safe until the PRs merge and deploy: the app may ship
/// long before the server and hosting changes it depends on, so it offers
/// passkeys only where they are proven to work — and fails closed.
class _Authenticator implements PasskeyAuthenticator {
  _Authenticator({this.available = true});

  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> _) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> _) =>
      throw UnimplementedError();
}

class _ToggleAuthenticator extends _Authenticator {
  _ToggleAuthenticator(this._available);

  final bool Function() _available;

  @override
  Future<bool> isAvailable() async => _available();
}

const _playOrigin =
    'android:apk-key-hash:u7yL-3JO8lZ3MDGxySLAUdNd7j_OvVk69xEvq0Z96Ig';

const _aasa = {
  'applinks': {'details': <Object>[]},
  'webcredentials': {
    'apps': [kAppleAppId],
  },
};

const _assetLinks = [
  {
    'relation': [
      'delegate_permission/common.handle_all_urls',
      'delegate_permission/common.get_login_creds',
    ],
    'target': {
      'namespace': 'android_app',
      'package_name': kAndroidPackage,
      'sha256_cert_fingerprints': ['BB:BC'],
    },
  },
];

/// Serves [files] by URL; anything else is the SPA's HTML, as
/// app.invoicing.co answers every unknown path today.
MockClient _server(Map<String, Object> files, {List<String>? log}) =>
    MockClient((request) async {
      log?.add(request.url.toString());
      final body = files[request.url.toString()];
      if (body == null) {
        return http.Response('<!DOCTYPE html><html></html>', 200);
      }
      return http.Response(jsonEncode(body), 200);
    });

void main() {
  PasskeyReadiness readiness(
    PasskeyPlatform platform, {
    Map<String, Object> files = const {},
    bool available = true,
    String pageHost = '',
    List<String>? log,
    DateTime Function()? now,
    List<String> appOrigins = const [_playOrigin],
  }) => PasskeyReadiness(
    authenticator: _Authenticator(available: available),
    client: _server(files, log: log),
    platform: platform,
    pageHost: pageHost,
    now: now,
    appOrigins: () async => appOrigins,
  );

  const hostedApi = 'https://invoicing.co';

  group('Android', () {
    test('needs the relying party to grant the app get_login_creds', () async {
      expect(
        await readiness(
          PasskeyPlatform.android,
        ).isReady(apiBaseUrl: hostedApi, isHosted: true),
        isFalse,
        reason: 'app.invoicing.co serves only index.html today',
      );
      expect(
        await readiness(
          PasskeyPlatform.android,
          files: {
            'https://app.invoicing.co/.well-known/assetlinks.json': _assetLinks,
          },
        ).isReady(apiBaseUrl: hostedApi, isHosted: true),
        isTrue,
      );
    });

    test('a self-hosted relying party is the API host', () async {
      final log = <String>[];
      final ready = await readiness(
        PasskeyPlatform.android,
        log: log,
        files: {
          'https://billing.example.com/.well-known/assetlinks.json':
              _assetLinks,
        },
      ).isReady(apiBaseUrl: 'https://billing.example.com', isHosted: false);

      expect(ready, isTrue);
      expect(log, ['https://billing.example.com/.well-known/assetlinks.json']);
    });

    test(
      'options from a server that lists no app origin are refused',
      () async {
        final r = readiness(
          PasskeyPlatform.android,
          files: {
            'https://app.invoicing.co/.well-known/assetlinks.json': _assetLinks,
          },
        );
        const named = {'rpId': 'app.invoicing.co'};

        expect(
          await r.allowsCeremony(
            apiBaseUrl: hostedApi,
            isHosted: true,
            options: const PasskeyLoginOptions(
              publicKey: named,
              challengeToken: 't',
            ),
          ),
          isFalse,
          reason: 'a server without the fix would reject the assertion',
        );
        expect(
          await r.allowsCeremony(
            apiBaseUrl: hostedApi,
            isHosted: true,
            options: const PasskeyLoginOptions(
              publicKey: named,
              challengeToken: 't',
              androidOrigins: [_playOrigin],
            ),
          ),
          isTrue,
        );
      },
    );

    test(
      'options that list another build, not this one, are refused',
      () async {
        // A debug or upload-key install: Credential Manager would sign, the
        // server would reject the assertion, and the email would take a
        // lockout strike.
        final r = readiness(
          PasskeyPlatform.android,
          appOrigins: const ['android:apk-key-hash:debugKeyHash'],
          files: {
            'https://app.invoicing.co/.well-known/assetlinks.json': _assetLinks,
          },
        );

        expect(
          await r.allowsCeremony(
            apiBaseUrl: hostedApi,
            isHosted: true,
            options: const PasskeyLoginOptions(
              publicKey: {'rpId': 'app.invoicing.co'},
              challengeToken: 't',
              androidOrigins: [_playOrigin],
            ),
          ),
          isFalse,
        );
      },
    );

    test('a loopback relying party is never ready', () async {
      expect(
        await readiness(PasskeyPlatform.android).isReady(
          apiBaseUrl: 'https://billing.example.com',
          isHosted: false,
          rpId: 'localhost',
        ),
        isFalse,
      );
    });
  });

  group('iOS / macOS', () {
    final files = {
      'https://app.invoicing.co/.well-known/apple-app-site-association': _aasa,
    };

    test(
      'needs the hosted AASA to list the app under webcredentials',
      () async {
        expect(
          await readiness(
            PasskeyPlatform.apple,
          ).isReady(apiBaseUrl: hostedApi, isHosted: true),
          isFalse,
        );
        expect(
          await readiness(
            PasskeyPlatform.apple,
            files: files,
          ).isReady(apiBaseUrl: hostedApi, isHosted: true),
          isTrue,
        );
      },
    );

    test(
      'never for a self-hosted server: the entitlement is compile-time',
      () async {
        expect(
          await readiness(
            PasskeyPlatform.apple,
            files: files,
          ).isReady(apiBaseUrl: 'https://billing.example.com', isHosted: false),
          isFalse,
        );
      },
    );

    test('options naming another relying party are refused', () async {
      expect(
        await readiness(PasskeyPlatform.apple, files: files).allowsCeremony(
          apiBaseUrl: hostedApi,
          isHosted: true,
          options: const PasskeyLoginOptions(
            publicKey: {'rpId': 'evil.example.com'},
            challengeToken: 't',
          ),
        ),
        isFalse,
      );
    });
  });

  group('Windows', () {
    test('needs no association file', () async {
      final log = <String>[];
      expect(
        await readiness(
          PasskeyPlatform.windows,
          log: log,
        ).isReady(apiBaseUrl: hostedApi, isHosted: true),
        isTrue,
      );
      expect(log, isEmpty);
    });
  });

  group('web', () {
    test('needs the page on the relying party host or below it', () async {
      Future<bool> on(String page) => readiness(
        PasskeyPlatform.web,
        pageHost: page,
      ).isReady(apiBaseUrl: hostedApi, isHosted: true);

      expect(await on('app.invoicing.co'), isTrue);
      expect(await on('beta.app.invoicing.co'), isTrue);
      expect(await on('hillelcoren.github.io'), isFalse);
      expect(await on('evilapp.invoicing.co'), isFalse);
    });

    test(
      'a developer page on localhost can use a localhost relying party',
      () async {
        expect(
          await readiness(PasskeyPlatform.web, pageHost: 'localhost').isReady(
            apiBaseUrl: 'http://localhost:8000',
            isHosted: false,
            rpId: 'localhost',
          ),
          isTrue,
        );
      },
    );
  });

  test('a device that cannot show a passkey sheet is never ready', () async {
    expect(
      await readiness(
        PasskeyPlatform.windows,
        available: false,
      ).isReady(apiBaseUrl: hostedApi, isHosted: true),
      isFalse,
    );
    expect(
      await readiness(
        PasskeyPlatform.none,
      ).isReady(apiBaseUrl: hostedApi, isHosted: true),
      isFalse,
    );
  });

  test(
    'answers are cached, then asked again once the files may have changed',
    () async {
      var clock = DateTime(2026, 11, 7, 12);
      final log = <String>[];
      final r = readiness(PasskeyPlatform.android, log: log, now: () => clock);

      await r.isReady(apiBaseUrl: hostedApi, isHosted: true);
      await r.isReady(apiBaseUrl: hostedApi, isHosted: true);
      expect(log, hasLength(1));

      clock = clock.add(PasskeyReadiness.cacheFor);
      await r.isReady(apiBaseUrl: hostedApi, isHosted: true);
      expect(log, hasLength(2));
    },
  );

  test('a failure to ask is not remembered; an answer is', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) throw http.ClientException('offline');
      return http.Response(jsonEncode(_assetLinks), 200);
    });
    final r = PasskeyReadiness(
      authenticator: _Authenticator(),
      client: client,
      platform: PasskeyPlatform.android,
    );

    expect(await r.isReady(apiBaseUrl: hostedApi, isHosted: true), isFalse);
    expect(await r.isReady(apiBaseUrl: hostedApi, isHosted: true), isTrue);
    expect(await r.isReady(apiBaseUrl: hostedApi, isHosted: true), isTrue);
    expect(calls, 2, reason: 'the answer is cached, the failure was not');
  });

  test('a device that could not show a sheet is asked again', () async {
    var available = false;
    final r = PasskeyReadiness(
      authenticator: _ToggleAuthenticator(() => available),
      client: _server(const {}),
      platform: PasskeyPlatform.windows,
    );

    expect(await r.isReady(apiBaseUrl: hostedApi, isHosted: true), isFalse);
    available = true;
    expect(await r.isReady(apiBaseUrl: hostedApi, isHosted: true), isTrue);
  });

  group('parsers', () {
    test('AASA', () {
      expect(appleAssociationGrantsWebCredentials(_aasa), isTrue);
      expect(
        appleAssociationGrantsWebCredentials({'applinks': <String, Object>{}}),
        isFalse,
      );
      expect(
        appleAssociationGrantsWebCredentials({
          'webcredentials': {
            'apps': ['TEAMID.com.other'],
          },
        }),
        isFalse,
      );
      expect(appleAssociationGrantsWebCredentials('<html>'), isFalse);
    });

    test('assetlinks', () {
      expect(assetLinksGrantLoginCredentials(_assetLinks), isTrue);
      final linksOnly = jsonDecode(jsonEncode(_assetLinks)) as List;
      (linksOnly.first as Map)['relation'] = [
        'delegate_permission/common.handle_all_urls',
      ];
      expect(assetLinksGrantLoginCredentials(linksOnly), isFalse);
      final otherApp = jsonDecode(jsonEncode(_assetLinks)) as List;
      ((otherApp.first as Map)['target'] as Map)['package_name'] = 'com.other';
      expect(assetLinksGrantLoginCredentials(otherApp), isFalse);
      expect(assetLinksGrantLoginCredentials({'not': 'a list'}), isFalse);
    });

    test('loopback relying parties', () {
      for (final host in [
        'localhost',
        'LOCALHOST',
        'localhost.',
        'app.localhost',
        '127.0.0.1',
        '127.0.1.1',
        '0.0.0.0',
        '::1',
        '[::1]',
        '0::1',
        '::',
      ]) {
        expect(isLoopbackRelyingParty(host), isTrue, reason: host);
      }
      for (final host in [
        'app.invoicing.co',
        '10.0.0.1',
        'mylocalhost.com',
        '2001:db8::1',
        '',
      ]) {
        expect(isLoopbackRelyingParty(host), isFalse, reason: host);
      }
    });
  });

  test('base64url round-trips without padding', () {
    final bytes = List<int>.generate(33, (i) => i * 7 % 256);
    final encoded = encodeBase64Url(bytes);
    expect(encoded, isNot(contains('=')));
    expect(encoded, isNot(contains('+')));
    expect(decodeBase64Url(encoded), bytes);
    // The server's vector for the Play certificate hash.
    expect(
      encodeBase64Url(
        decodeBase64Url('u7yL-3JO8lZ3MDGxySLAUdNd7j_OvVk69xEvq0Z96Ig'),
      ),
      'u7yL-3JO8lZ3MDGxySLAUdNd7j_OvVk69xEvq0Z96Ig',
    );
  });
}
