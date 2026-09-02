import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/phone/phone_actions_settings.dart';

final _log = Logger('PhoneActionsController');

/// Owns the device-local "Phone numbers" preferences — tap-to-call, the
/// optional in-app confirm, and the outside-business-hours warning window
/// (invoiceninja/flutter#109).
///
/// Persists to `nav_state.phone_actions_json`, the same single-row device-local
/// pattern as [ContactsSyncController]. A [ChangeNotifier] rather than a
/// `ValueNotifier<bool>` because it holds five fields — and because **every
/// phone surface listens to it**: a client detail screen sitting behind the
/// settings route stays mounted while the switch is flipped, so a build-time
/// read with no listener would leave that screen styling numbers with the old
/// value until something else happened to rebuild it.
class PhoneActionsController extends ChangeNotifier {
  PhoneActionsController({
    required AppDatabase db,
    DateTime Function()? now,
    PhoneActionsSettings? initial,
  }) : _db = db,
       _now = now ?? DateTime.now,
       _value = initial ?? PhoneActionsSettings.deviceDefaults();

  final AppDatabase _db;
  final DateTime Function() _now;

  PhoneActionsSettings _value;
  PhoneActionsSettings get value => _value;

  /// No stored row (fresh install, or a user who never opened the card) leaves
  /// [PhoneActionsSettings.deviceDefaults] in place — which is the whole reason
  /// this is a nullable blob rather than typed columns with SQL defaults.
  Future<void> restore() async {
    final row = await _db.navStateDao.current();
    final raw = row?.phoneActionsJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _value = PhoneActionsSettings.fromJson(json);
      notifyListeners();
    } catch (e, st) {
      // A corrupt blob must not wedge the app at boot; the defaults are a
      // perfectly usable starting point and the card rewrites them on the next
      // change.
      _log.warning('could not restore the phone-actions preference', e, st);
    }
  }

  Future<void> setTapToCall(bool value) =>
      _update(_value.copyWith(tapToCall: value));

  Future<void> setConfirmBeforeCall(bool value) =>
      _update(_value.copyWith(confirmBeforeCall: value));

  Future<void> setWarnOutsideBusinessHours(bool value) =>
      _update(_value.copyWith(warnOutsideBusinessHours: value));

  Future<void> setBusinessHours({int? startMinutes, int? endMinutes}) =>
      _update(
        _value.copyWith(startMinutes: startMinutes, endMinutes: endMinutes),
      );

  Future<void> _update(PhoneActionsSettings next) async {
    if (_value == next) return;
    _value = next;
    notifyListeners();
    try {
      await _db.navStateDao.savePhoneActions(
        json: jsonEncode(next.toJson()),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory value — the user still
      // sees their chosen state until next launch.
      _log.warning('Failed to persist the phone-actions preference', e, st);
    }
  }
}
