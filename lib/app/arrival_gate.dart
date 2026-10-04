import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';

/// Whether something that arrived from outside the app — a deep link, a file
/// shared from another app — may act yet, and a way to be told when it can.
///
/// Shared by `DeepLinkRouter` and `SharedFileIntake`: both hold what they were
/// handed while the app is signed out or biometric-locked, and replay it once
/// the user is through. Acting earlier would put a dialog over the lock screen
/// (an ordinary Scaffold, so nothing stops a `showDialog` landing on top of it)
/// or navigate behind a lock the user hasn't passed.
class ArrivalGate {
  ArrivalGate({
    required ValueListenable<AuthSession?> session,
    required ValueListenable<ApiCredentials?> credentials,
    required ValueListenable<bool> requiresBiometricUnlock,
    bool Function(AuthSession? session)? isSetupRequired,
  }) : _session = session,
       _credentials = credentials,
       _locked = requiresBiometricUnlock,
       _isSetupRequired = isSetupRequired;

  // All three are *listenables*, and [credentials] in particular must not be
  // reduced to an `isAuthenticated()` predicate: `AuthRepository` assigns
  // `_session` BEFORE `_credentials` on both login (`_persistAndActivate`) and
  // `restore()`, so a gate that reads credentials while listening only to the
  // session wakes on the session edge, still sees `isAuthenticated == false`,
  // and drops the held arrival — then replays it minutes later off an
  // unrelated background refresh. `main.dart` merges `auth.credentials` first
  // into the router's own `refreshListenable` for exactly this reason.
  final ValueListenable<AuthSession?> _session;
  final ValueListenable<ApiCredentials?> _credentials;
  final ValueListenable<bool> _locked;

  /// Optional: also hold while the active company still has to be named. The
  /// router gates every authenticated route behind `/setup` until then, so a
  /// navigation made now is redirected there and lost. Re-checked on [_session]
  /// changes, which is what the router's own setup gate reads too.
  final bool Function(AuthSession? session)? _isSetupRequired;

  VoidCallback? _onOpen;
  bool _listening = false;

  /// Signed in, session materialised, past the biometric lock (and, when
  /// asked, past setup). Reads every source it listens to, so no assignment
  /// order can strand an arrival.
  bool get isOpen =>
      (_credentials.value?.isAuthenticated ?? false) &&
      _session.value != null &&
      !_locked.value &&
      !(_isSetupRequired?.call(_session.value) ?? false);

  /// Call [onOpen] once, in the frame after the gate next opens. Replaces any
  /// earlier callback — each owner holds a single deferred arrival.
  void notifyWhenOpen(VoidCallback onOpen) {
    _onOpen = onOpen;
    if (_listening) return;
    _listening = true;
    _session.addListener(_onChanged);
    _credentials.addListener(_onChanged);
    _locked.addListener(_onChanged);
  }

  /// Stop waiting; a pending [notifyWhenOpen] callback never fires.
  void cancel() {
    _onOpen = null;
    if (!_listening) return;
    _listening = false;
    _session.removeListener(_onChanged);
    _credentials.removeListener(_onChanged);
    _locked.removeListener(_onChanged);
  }

  void _onChanged() {
    if (!isOpen) return;
    final onOpen = _onOpen;
    cancel();
    if (onOpen == null) return;
    // After the frame, not now: the router swaps the page the gate kept up
    // (`/lock`, `/login`, `/setup`) out on the next frame, and a dialog pushed
    // before then landed on that page and went with it — a company switch read
    // as cancelled and the link did nothing. The swap asks for that frame in
    // the app; ask here too, so the replay never depends on it.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => onOpen())
      ..ensureVisualUpdate();
  }
}
