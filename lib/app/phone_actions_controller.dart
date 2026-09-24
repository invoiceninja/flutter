import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/phone/phone_actions_settings.dart';

final _log = Logger('PhoneActionsController');

/// Owns the device-local "Phone numbers" preferences — tap-to-call, the
/// optional in-app confirm, and the outside-business-hours warning window
/// (invoiceninja/flutter#109).
///
/// One JSON blob (`DevicePrefKeys.phoneActions`). A [ChangeNotifier] rather
/// than a `ValueNotifier<bool>` because it holds five fields — and because
/// **every phone surface listens to it**: a client detail screen sitting
/// behind the settings route stays mounted while the switch is flipped, so a
/// build-time read with no listener would leave that screen styling numbers
/// with the old value until something else happened to rebuild it.
class PhoneActionsController extends ChangeNotifier {
  PhoneActionsController({required DevicePrefsStore prefs})
    : _prefs = prefs,
      _value = _read(prefs) {
    prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;

  PhoneActionsSettings _value;
  PhoneActionsSettings get value => _value;

  /// Nothing stored (a fresh install, or a user who never opened the card)
  /// leaves [PhoneActionsSettings.deviceDefaults] in place — which is the
  /// whole reason this is a blob rather than typed values with fixed defaults.
  static PhoneActionsSettings _read(DevicePrefsStore prefs) {
    final raw = prefs.read(DevicePrefKeys.phoneActions);
    if (raw == null || raw.isEmpty) {
      return PhoneActionsSettings.deviceDefaults();
    }
    try {
      return PhoneActionsSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e, st) {
      // A corrupt blob must not wedge the app at boot; the defaults are a
      // perfectly usable starting point and the card rewrites them on the next
      // change.
      _log.warning('could not restore the phone-actions preference', e, st);
      return PhoneActionsSettings.deviceDefaults();
    }
  }

  void _sync() {
    final next = _read(_prefs);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  Future<void> setTapToCall(bool value) =>
      _update(_value.copyWith(tapToCall: value));

  Future<void> setConfirmBeforeCall(bool value) =>
      _update(_value.copyWith(confirmBeforeCall: value));

  Future<void> setWarnOutsideBusinessHours(bool value) =>
      _update(_value.copyWith(warnOutsideBusinessHours: value));

  Future<void> setOfferToLogCalls(bool value) =>
      _update(_value.copyWith(offerToLogCalls: value));

  Future<void> setBusinessHours({int? startMinutes, int? endMinutes}) =>
      _update(
        _value.copyWith(startMinutes: startMinutes, endMinutes: endMinutes),
      );

  Future<void> _update(PhoneActionsSettings next) async {
    if (_value == next) return;
    _value = next;
    notifyListeners();
    await _prefs.write(DevicePrefKeys.phoneActions, jsonEncode(next.toJson()));
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}
