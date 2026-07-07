import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:local_auth/local_auth.dart';
import 'package:logging/logging.dart';

final _log = Logger('BiometricService');

/// Thin abstraction over `local_auth` so the auth/lock layer can fake it in
/// tests. Mirrors admin-portal's behavior: any auth failure (cancelled, not
/// enrolled, locked out, unsupported option) is treated as "not
/// authenticated" rather than surfaced — callers decide what to do next.
/// local_auth 3.x reports those as `LocalAuthException`, older platform
/// paths as `PlatformException`; both map to false here.
abstract class BiometricService {
  /// True when the device reports both `canCheckBiometrics` and
  /// `isDeviceSupported`. The User Details toggle hides itself when this
  /// returns false, and the lock screen's auto-prompt short-circuits.
  Future<bool> isAvailable();

  /// Show the FaceID/TouchID prompt. Returns true on success, false on
  /// cancel / no biometrics enrolled / OS-revoked authentication.
  Future<bool> authenticate({required String reason});
}

/// Web has no `local_auth` implementation (no FaceID/TouchID/Windows Hello
/// equivalent reachable from a browser). [isAvailable] returns false so the
/// User Details toggle hides itself and the lock screen's auto-prompt
/// short-circuits — identical to a native device with no enrolled
/// biometrics. Selected via `kIsWeb` in `Services.build`.
class WebBiometricService implements BiometricService {
  const WebBiometricService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String reason}) async => false;
}

class LocalAuthBiometricService implements BiometricService {
  LocalAuthBiometricService([LocalAuthentication? backend])
    : _auth = backend ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } on PlatformException catch (e, st) {
      _log.fine('isAvailable() failed', e, st);
      return false;
    } on MissingPluginException catch (e, st) {
      // Linux: local_auth ships no implementation — behave like a device
      // with no biometrics rather than surfacing a plumbing error.
      _log.fine('isAvailable(): no local_auth implementation', e, st);
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // local_auth_windows throws UnsupportedError for biometricOnly:true;
        // Windows Hello (UserConsentVerifier) is the OS's strong-auth
        // surface — let it pick face/fingerprint/PIN there.
        biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e, st) {
      // local_auth 3.x: cancel / not-enrolled / lockout arrive here, not as
      // PlatformException.
      _log.fine('authenticate() failed', e, st);
      return false;
    } on PlatformException catch (e, st) {
      _log.fine('authenticate() failed', e, st);
      return false;
    } on MissingPluginException catch (e, st) {
      _log.fine('authenticate(): no local_auth implementation', e, st);
      return false;
    } on UnsupportedError catch (e, st) {
      // An Error, not an Exception — a platform impl rejecting an option
      // combination (the Windows biometricOnly case) must still map to
      // "not authenticated", never an uncaught error.
      _log.fine('authenticate() unsupported option', e, st);
      return false;
    }
  }
}
