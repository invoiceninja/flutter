import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/services/api_credentials.dart';

/// Why a session ended without the user signing out.
enum SignOutReason {
  /// The web's idle timeout (`IdleTimeoutController`).
  inactivity,

  /// A 401 the server's `/ping` confirmed (`ApiClient`'s session check).
  sessionRejected,
}

/// The reason the last session ended on its own, kept for the sign-in screen
/// to say once — the owner of [DevicePrefKeys.signOutNotice].
///
/// Release builds keep no diagnostics log, so before this an automatic
/// sign-out left the user on the sign-in screen with no idea why, and a
/// report of one left nothing to go on. A device preference, so it survives
/// the wipe a sign-out can do; it is dropped as soon as a session is live
/// again, and by the screen's ✕.
class SignOutNotice extends ChangeNotifier {
  SignOutNotice({
    required DevicePrefsStore prefs,
    required ValueListenable<ApiCredentials?> credentials,
  }) : _prefs = prefs,
       _credentials = credentials {
    _sync();
    _prefs.addListener(_sync);
    _credentials.addListener(_onCredentials);
  }

  final DevicePrefsStore _prefs;
  final ValueListenable<ApiCredentials?> _credentials;

  /// What to tell the user, or null.
  ({SignOutReason reason, String? detail})? get pending => _pending;
  ({SignOutReason reason, String? detail})? _pending;

  /// Store why the session is about to end. Awaited before the logout, so a
  /// wipe that follows keeps it.
  Future<void> record(SignOutReason reason, {String? detail}) async {
    _pending = (reason: reason, detail: detail);
    notifyListeners();
    await _prefs.write(
      DevicePrefKeys.signOutNotice,
      jsonEncode({'reason': reason.name, if (detail != null) 'detail': detail}),
    );
  }

  /// Forget it — the sign-in screen's ✕, or a live session.
  Future<void> dismiss() async {
    if (_pending == null && _prefs.read(DevicePrefKeys.signOutNotice) == null) {
      return;
    }
    _pending = null;
    notifyListeners();
    await _prefs.write<String>(DevicePrefKeys.signOutNotice, null);
  }

  bool get _signedIn => _credentials.value?.isAuthenticated ?? false;

  void _onCredentials() {
    if (_signedIn) dismiss();
  }

  /// Re-read the store (its `load`, or a wipe). A notice found while a session
  /// is live is stale — the user is past the sign-in screen it was for.
  void _sync() {
    final next = _decode(_prefs.read(DevicePrefKeys.signOutNotice));
    if (next != null && _signedIn) {
      dismiss();
      return;
    }
    if (next == _pending) return;
    _pending = next;
    notifyListeners();
  }

  static ({SignOutReason reason, String? detail})? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final name = json['reason'];
      final reason = SignOutReason.values
          .where((r) => r.name == name)
          .firstOrNull;
      if (reason == null) return null;
      final detail = json['detail'];
      return (reason: reason, detail: detail is String ? detail : null);
    } on FormatException {
      return null;
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    _credentials.removeListener(_onCredentials);
    super.dispose();
  }
}
