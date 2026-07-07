import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

import 'package:admin/data/services/biometric_service.dart';

/// Fake backend capturing the `biometricOnly` argument and throwing whatever
/// the test configures — mirrors the failure shapes of the real platform
/// implementations (LocalAuthException on 3.x paths, PlatformException on
/// legacy paths, UnsupportedError from local_auth_windows' biometricOnly
/// rejection, MissingPluginException on Linux).
class _FakeAuth implements LocalAuthentication {
  bool deviceSupported = true;
  bool canCheck = true;
  Object? authenticateThrows;
  Object? isAvailableThrows;
  bool authenticateResult = true;
  bool? lastBiometricOnly;

  @override
  Future<bool> isDeviceSupported() async {
    final error = isAvailableThrows;
    if (error != null) throw error;
    return deviceSupported;
  }

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    // Widened from Iterable<AuthMessages> — the type isn't exported by
    // package:local_auth and a contravariant parameter is a legal override.
    Iterable<Object?> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    lastBiometricOnly = biometricOnly;
    final error = authenticateThrows;
    if (error != null) throw error;
    return authenticateResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuth backend;
  late LocalAuthBiometricService service;

  setUp(() {
    backend = _FakeAuth();
    service = LocalAuthBiometricService(backend);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('authenticate', () {
    test('returns true on success', () async {
      expect(await service.authenticate(reason: 'unlock'), isTrue);
    });

    test('LocalAuthException (user cancel) maps to false', () async {
      backend.authenticateThrows = const LocalAuthException(
        code: LocalAuthExceptionCode.userCanceled,
      );
      expect(await service.authenticate(reason: 'unlock'), isFalse);
    });

    test('PlatformException maps to false', () async {
      backend.authenticateThrows = PlatformException(code: 'NotEnrolled');
      expect(await service.authenticate(reason: 'unlock'), isFalse);
    });

    test('MissingPluginException (Linux) maps to false', () async {
      backend.authenticateThrows = MissingPluginException('local_auth');
      expect(await service.authenticate(reason: 'unlock'), isFalse);
    });

    test('UnsupportedError (windows biometricOnly rejection) maps to false '
        'instead of escaping as an uncaught Error', () async {
      backend.authenticateThrows = UnsupportedError(
        "Windows doesn't support the biometricOnly parameter.",
      );
      expect(await service.authenticate(reason: 'unlock'), isFalse);
    });

    test('passes biometricOnly:false on Windows (Hello PIN allowed)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await service.authenticate(reason: 'unlock');
      expect(backend.lastBiometricOnly, isFalse);
    });

    test('passes biometricOnly:true on macOS and iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await service.authenticate(reason: 'unlock');
      expect(backend.lastBiometricOnly, isTrue);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await service.authenticate(reason: 'unlock');
      expect(backend.lastBiometricOnly, isTrue);
    });
  });

  group('isAvailable', () {
    test('true when supported and biometrics checkable', () async {
      expect(await service.isAvailable(), isTrue);
    });

    test('false when the device is unsupported', () async {
      backend.deviceSupported = false;
      expect(await service.isAvailable(), isFalse);
    });

    test('MissingPluginException (Linux) maps to false', () async {
      backend.isAvailableThrows = MissingPluginException('local_auth');
      expect(await service.isAvailable(), isFalse);
    });
  });
}
