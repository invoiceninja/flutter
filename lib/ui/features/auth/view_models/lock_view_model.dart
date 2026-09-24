import 'package:flutter/foundation.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/biometric_service.dart';

/// Drives the cold-launch lock screen. The screen auto-triggers [unlock] on
/// mount; the user can retry via the Unlock button or bail out via [signOut].
class LockViewModel extends ChangeNotifier {
  LockViewModel({
    required AuthRepository auth,
    required BiometricService biometric,
  }) : _auth = auth,
       _biometric = biometric;

  final AuthRepository _auth;
  final BiometricService _biometric;

  bool _busy = false;
  bool _disposed = false;

  /// True while a biometric prompt OR a sign-out is in flight. The screen
  /// gates both buttons on this so a stray double-tap can't race two
  /// platform calls at once.
  bool get busy => _busy;

  Future<void> unlock(String reason) async {
    if (_busy) return;
    _busy = true;
    _safeNotify();
    try {
      final ok = await _biometric.authenticate(reason: reason);
      if (ok) _auth.completeBiometricUnlock();
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    _safeNotify();
    try {
      // The lock screen asked about unsynced work before calling this.
      await _auth.logout(data: LocalDataPolicy.destroy);
    } finally {
      _busy = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
