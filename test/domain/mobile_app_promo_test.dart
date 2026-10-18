import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/mobile_app_promo.dart';

AuthSession _session({
  String baseUrl = 'https://invoicing.co',
  bool isHosted = true,
  String provider = '',
  bool hasPassword = true,
  int enabledModules = 0x7fffffff,
}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: isHosted,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: '',
      isAdmin: true,
      isOwner: true,
      enabledModules: enabledModules,
    ),
  ],
  currentCompanyId: 'co',
  userEmail: 'me@example.com',
  userOauthProviderId: provider,
  userHasPassword: hasPassword,
);

/// The promo's store-policy rules live here, so they are pinned here
/// (docs/mobile-app-promo.md).
void main() {
  const ios = MobilePromoTarget.ios;
  const android = MobilePromoTarget.android;

  group('mobilePromoTargets', () {
    test('native macOS offers Apple phones only (App Review 2.3.10)', () {
      expect(mobilePromoTargets(isWeb: false, platform: TargetPlatform.macOS), [
        ios,
      ]);
    });

    test('native Windows and Linux offer both phones', () {
      for (final p in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(mobilePromoTargets(isWeb: false, platform: p), [ios, android]);
      }
    });

    test('the phone apps themselves offer nothing', () {
      for (final p in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        expect(mobilePromoTargets(isWeb: false, platform: p), isEmpty);
      }
    });

    test('a phone browser offers its own phone; any other browser both', () {
      expect(mobilePromoTargets(isWeb: true, platform: TargetPlatform.iOS), [
        ios,
      ]);
      expect(
        mobilePromoTargets(isWeb: true, platform: TargetPlatform.android),
        [android],
      );
      // A Mac *browser* is not the App Store build — 2.3.10 doesn't reach it.
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(mobilePromoTargets(isWeb: true, platform: p), [ios, android]);
      }
    });

    test('the Android link belongs to the Android target only', () {
      expect(ios.url, kMobileAppIosUrl);
      expect(android.url, kMobileAppAndroidUrl);
      expect(kMobileAppIosUrl, isNot(contains('google')));
    });
  });

  test('only a touch browser gets the store button', () {
    expect(
      mobilePromoPresentation(isWeb: true, touch: true),
      MobilePromoPresentation.storeButton,
    );
    for (final (isWeb, touch) in [
      (true, false),
      (false, false),
      (false, true),
    ]) {
      expect(
        mobilePromoPresentation(isWeb: isWeb, touch: touch),
        MobilePromoPresentation.qr,
      );
    }
  });

  group('mobilePromoEligible', () {
    bool eligible(AuthSession? s, {bool demoBuild = false}) =>
        mobilePromoEligible(s, isDemoBuild: demoBuild, demoMode: false);

    test('a signed-in hosted or reachable self-hosted session', () {
      expect(eligible(_session()), isTrue);
      expect(
        eligible(_session(baseUrl: 'https://in.example.com', isHosted: false)),
        isTrue,
      );
      // A LAN server is reachable from a phone on the same network.
      expect(
        eligible(_session(baseUrl: 'http://192.168.1.20', isHosted: false)),
        isTrue,
      );
    });

    test('not signed in, the demo, or a server only this machine reaches', () {
      expect(eligible(null), isFalse);
      expect(eligible(_session(), demoBuild: true), isFalse);
      expect(
        eligible(_session(baseUrl: 'https://demo.invoiceninja.com')),
        isFalse,
      );
      for (final url in [
        'http://localhost:8000',
        'http://127.0.0.1',
        'http://[::1]:8000',
        'http://app.localhost',
      ]) {
        expect(
          eligible(_session(baseUrl: url, isHosted: false)),
          isFalse,
          reason: url,
        );
      }
    });
  });

  test('isPrivateNetworkHost — the login classifier, minus loopback', () {
    for (final url in [
      'http://10.0.0.5',
      'http://172.16.0.1',
      'http://172.31.255.1',
      'http://192.168.0.10:8080',
      'http://169.254.1.1',
      'http://100.64.0.1',
      'http://ninja.local',
      'http://nas.lan',
      'http://[fd00::1]',
      'http://[fe90::1]',
    ]) {
      expect(isPrivateNetworkHost(url), isTrue, reason: url);
    }
    for (final url in [
      'https://invoicing.co',
      'http://172.32.0.1',
      'http://8.8.8.8',
      'https://fdic.gov',
      // `fc::1` is 00fc::1 — public, despite the text prefix.
      'http://[fc::1]',
      // Loopback is unreachable from a phone, not "same network".
      'http://127.0.0.1',
      'http://localhost',
      '',
    ]) {
      expect(isPrivateNetworkHost(url), isFalse, reason: url);
    }
  });

  test('isLoopbackHost', () {
    for (final url in [
      'http://localhost:8000',
      'http://app.localhost',
      'http://127.0.0.1',
      'http://0.0.0.0',
      'http://[::1]',
      'http://[0:0:0:0:0:0:0:1]',
    ]) {
      expect(isLoopbackHost(url), isTrue, reason: url);
    }
    for (final url in ['http://10.0.0.1', 'http://[::2]', 'https://x.co']) {
      expect(isLoopbackHost(url), isFalse, reason: url);
    }
  });

  group('mobileSignInProviderGap', () {
    test('a password, or no OAuth, means no gap', () {
      expect(mobileSignInProviderGap(_session(), android), isNull);
      expect(
        mobileSignInProviderGap(_session(provider: 'microsoft'), android),
        isNull,
      );
      expect(
        mobileSignInProviderGap(_session(hasPassword: false), ios),
        isNull,
      );
    });

    test('Google works on both phones, Apple on iPhone only, Microsoft on '
        'neither', () {
      AuthSession oauth(String p) => _session(provider: p, hasPassword: false);
      expect(mobileSignInProviderGap(oauth('google'), ios), isNull);
      expect(mobileSignInProviderGap(oauth('google'), android), isNull);
      expect(mobileSignInProviderGap(oauth('apple'), ios), isNull);
      expect(mobileSignInProviderGap(oauth('apple'), android), 'apple');
      expect(mobileSignInProviderGap(oauth('microsoft'), ios), 'microsoft');
    });

    test('self-hosted has no social sign-in at all', () {
      final s = _session(
        baseUrl: 'https://in.example.com',
        isHosted: false,
        provider: 'google',
        hasPassword: false,
      );
      expect(mobileSignInProviderGap(s, ios), 'google');
    });
  });

  test('MobilePromoAccount reads the session once', () {
    final hosted = MobilePromoAccount.fromSession(
      _session(provider: 'apple', hasPassword: false),
    );
    expect(hosted.email, 'me@example.com');
    expect(hosted.serverUrl, isNull, reason: 'hosted has no address to type');
    expect(hosted.providerGaps, {android: 'apple'});

    final lan = MobilePromoAccount.fromSession(
      _session(baseUrl: 'http://192.168.1.20', isHosted: false),
    );
    expect(lan.serverUrl, 'http://192.168.1.20');
    expect(lan.privateNetwork, isTrue);

    final noExpenses = MobilePromoAccount.fromSession(
      _session(enabledModules: EnabledModule.invoices.bitmask),
    );
    expect(noExpenses.expensesEnabled, isFalse);
  });
}
