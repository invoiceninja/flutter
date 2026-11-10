import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/companion_apps.dart';

enum _Role { admin, owner, member }

enum _Plan { free, pro, enterprise, trial, selfHosted }

final int _allModules = kEnabledModulesOrder.fold<int>(
  0,
  (mask, m) => mask | m.bitmask,
);

AuthSession _session({
  _Role role = _Role.admin,
  _Plan plan = _Plan.pro,
  bool tasks = true,
  String? baseUrl,
}) {
  final hosted = plan != _Plan.selfHosted;
  return AuthSession(
    baseUrl:
        baseUrl ??
        (hosted ? 'https://invoicing.co' : 'https://billing.example.com'),
    isHosted: hosted,
    accountId: 'acct',
    plan: switch (plan) {
      _Plan.pro => 'pro',
      _Plan.enterprise => 'enterprise',
      _ => '',
    },
    trialDaysLeft: plan == _Plan.trial ? 10 : -1,
    companies: [
      AuthCompany(
        id: 'co',
        name: 'Co',
        displayName: 'Co',
        permissions: '',
        isAdmin: role == _Role.admin,
        isOwner: role == _Role.owner,
        enabledModules: tasks
            ? _allModules
            : _allModules & ~EnabledModule.tasks.bitmask,
      ),
    ],
    currentCompanyId: 'co',
  );
}

/// The companion-app rules (docs/companion-apps.md): which builds may name
/// the Chrome extension, and who is offered each app.
void main() {
  group('chromeExtensionPlatform', () {
    bool web(TargetPlatform p, {bool touch = false}) =>
        chromeExtensionPlatform(isWeb: true, platform: p, touchPrimary: touch);
    bool native(TargetPlatform p) => chromeExtensionPlatform(
      isWeb: false,
      platform: p,
      touchPrimary: p == TargetPlatform.iOS || p == TargetPlatform.android,
    );

    test('native macOS never names Chrome (App Review 2.3.10)', () {
      expect(native(TargetPlatform.macOS), isFalse);
      // Whatever the touch signal says.
      for (final touch in [true, false]) {
        expect(
          chromeExtensionPlatform(
            isWeb: false,
            platform: TargetPlatform.macOS,
            touchPrimary: touch,
          ),
          isFalse,
        );
      }
    });

    test('native iOS and Android never do either', () {
      expect(native(TargetPlatform.iOS), isFalse);
      expect(native(TargetPlatform.android), isFalse);
      expect(native(TargetPlatform.fuchsia), isFalse);
    });

    test('native Windows and Linux do', () {
      expect(native(TargetPlatform.windows), isTrue);
      expect(native(TargetPlatform.linux), isTrue);
    });

    test('a desktop browser does, a Mac browser included', () {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(web(p), isTrue, reason: '$p');
      }
    });

    test('a phone or tablet browser does not', () {
      expect(web(TargetPlatform.iOS, touch: true), isFalse);
      expect(web(TargetPlatform.android, touch: true), isFalse);
      // A touch-primary signal wins even over a desktop OS.
      expect(web(TargetPlatform.macOS, touch: true), isFalse);
    });

    test('the live build follows defaultTargetPlatform', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(currentChromeExtensionPlatform(), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(currentChromeExtensionPlatform(), isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(currentChromeExtensionPlatform(), isFalse);
    });
  });

  group('wordPressPluginOffered', () {
    test('admins and owners on Pro, Enterprise, a trial or self-hosted', () {
      for (final role in [_Role.admin, _Role.owner]) {
        for (final plan in [
          _Plan.pro,
          _Plan.enterprise,
          _Plan.trial,
          _Plan.selfHosted,
        ]) {
          expect(
            wordPressPluginOffered(_session(role: role, plan: plan)),
            isTrue,
            reason: '$role $plan',
          );
        }
      }
    });

    test('a free hosted account sees nothing — no upsell', () {
      for (final role in _Role.values) {
        expect(
          wordPressPluginOffered(_session(role: role, plan: _Plan.free)),
          isFalse,
        );
      }
    });

    test('a member never — the plugin needs an admin token', () {
      for (final plan in _Plan.values) {
        expect(
          wordPressPluginOffered(_session(role: _Role.member, plan: plan)),
          isFalse,
          reason: '$plan',
        );
      }
    });

    test('shown on every platform, Apple included', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final p in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = p;
        expect(wordPressPluginOffered(_session()), isTrue, reason: '$p');
      }
    });

    test('never in a demo', () {
      expect(wordPressPluginOffered(_session(baseUrl: kDemoBaseUrl)), isFalse);
      expect(wordPressPluginOffered(_session(), isDemoBuild: true), isFalse);
      expect(wordPressPluginOffered(_session(), demoMode: true), isFalse);
      expect(wordPressPluginOffered(null), isFalse);
    });

    test('the tasks module does not matter', () {
      expect(wordPressPluginOffered(_session(tasks: false)), isTrue);
    });
  });

  group('chromeExtensionOffered', () {
    test('anyone with Tasks on, on any plan — no plan or role gate', () {
      for (final role in _Role.values) {
        for (final plan in _Plan.values) {
          expect(
            chromeExtensionOffered(
              _session(role: role, plan: plan),
              platformSupported: true,
            ),
            isTrue,
            reason: '$role $plan',
          );
        }
      }
    });

    test('not with the Tasks module off', () {
      expect(
        chromeExtensionOffered(_session(tasks: false), platformSupported: true),
        isFalse,
      );
    });

    test('not where the platform cannot run it', () {
      expect(
        chromeExtensionOffered(_session(), platformSupported: false),
        isFalse,
      );
    });

    test('native macOS never offers it, whoever is signed in', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      for (final plan in _Plan.values) {
        expect(chromeExtensionOffered(_session(plan: plan)), isFalse);
      }
      for (final p in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = p;
        expect(chromeExtensionOffered(_session()), isFalse, reason: '$p');
      }
      for (final p in [TargetPlatform.windows, TargetPlatform.linux]) {
        debugDefaultTargetPlatformOverride = p;
        expect(chromeExtensionOffered(_session()), isTrue, reason: '$p');
      }
    });

    test('never in a demo', () {
      expect(
        chromeExtensionOffered(
          _session(baseUrl: kDemoBaseUrl),
          platformSupported: true,
        ),
        isFalse,
      );
      expect(
        chromeExtensionOffered(
          _session(),
          platformSupported: true,
          isDemoBuild: true,
        ),
        isFalse,
      );
      expect(
        chromeExtensionOffered(
          _session(),
          platformSupported: true,
          demoMode: true,
        ),
        isFalse,
      );
      expect(chromeExtensionOffered(null, platformSupported: true), isFalse);
    });
  });

  test('companionAppOffered routes to each app\'s own gate', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final free = _session(plan: _Plan.free);
    expect(companionAppOffered(CompanionApp.wordPress, free), isFalse);
    expect(companionAppOffered(CompanionApp.chromeExtension, free), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(companionAppOffered(CompanionApp.chromeExtension, free), isTrue);
    expect(companionAppOffered(CompanionApp.wordPress, _session()), isTrue);
  });

  test('the links', () {
    expect(CompanionApp.wordPress.url, kWordPressPluginUrl);
    expect(CompanionApp.chromeExtension.url, kChromeExtensionUrl);
    expect(kWordPressPluginUrl, startsWith('https://wordpress.org/'));
    expect(kChromeExtensionUrl, startsWith('https://chromewebstore.google'));
  });

  test('wordPressServerAddress drops /api/v1 and trailing slashes', () {
    expect(
      wordPressServerAddress('https://billing.example.com/api/v1'),
      'https://billing.example.com',
    );
    expect(
      wordPressServerAddress('https://billing.example.com/api/v1/'),
      'https://billing.example.com',
    );
    expect(
      wordPressServerAddress('https://example.com/ninja/'),
      'https://example.com/ninja',
    );
    expect(
      wordPressServerAddress(' http://10.0.0.5:8000 '),
      'http://10.0.0.5:8000',
    );
  });
}
