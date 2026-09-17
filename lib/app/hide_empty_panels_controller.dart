import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';

final _log = Logger('HideEmptyPanelsController');

/// Owns the user's "leave dashboard panels with nothing to show off the
/// dashboard" preference and persists it to `nav_state.hide_empty_panels` —
/// the same single-row, device-local pattern as [TasksViewController]
/// (invoiceninja/flutter#161).
///
/// **Null means automatic**, and automatic depends on the device: on for a
/// phone, off for a tablet or a desktop, because the issue is about a phone's
/// scroll budget. That answer needs a `MediaQuery` (`Breakpoints.isPhone`), so
/// it cannot live in a SQL default or in this controller — callers resolve it
/// through [effectiveFor] and [set], and every UI caller goes through the
/// `effectiveIn` / `setIn` extension (`dashboard/helpers/hide_empty_panels.dart`)
/// so the device question is asked in exactly one place. Keeping this class
/// free of UI imports is deliberate.
///
/// **Automatic stays reachable.** A switch can only say on or off, so [set]
/// stores null whenever the chosen value is the one this device would pick
/// anyway. Only a choice that *differs* from the device default sticks — which
/// is what keeps a foldable (a phone folded, a tablet open) or a split-screen
/// window adapting until the user actually overrides it.
///
/// Read live via a listener — the dashboard stays mounted behind
/// `/settings/**` while the switch is flipped, and its own view model never
/// notifies for a device preference.
class HideEmptyPanelsController extends ValueNotifier<bool?> {
  HideEmptyPanelsController({
    required AppDatabase db,
    DateTime Function()? now,
    bool? initial,
  }) : _db = db,
       _now = now ?? DateTime.now,
       super(initial);

  final AppDatabase _db;
  final DateTime Function() _now;

  /// Whether empty panels are hidden on this device: the stored choice, or —
  /// when the user never made one — whether this device is a phone.
  bool effectiveFor({required bool isPhone}) => value ?? isPhone;

  /// No stored row (fresh install) and a never-set column both leave the value
  /// alone — never a throw, because this runs inside `main`'s boot
  /// `Future.wait`.
  Future<void> restore() async {
    final row = await _db.navStateDao.current();
    final stored = row?.hideEmptyPanels;
    if (stored == null) return;
    value = stored;
  }

  /// Drop the choice without touching the database, so the next user on this
  /// install starts on automatic.
  ///
  /// Wired to `AuthRepository.onBeforeDataWipe`, **not** `onBeforeLogout`:
  /// `onBeforeLogout` also runs on the idle-timeout / 401 re-lock path, which
  /// keeps `nav_state` — so resetting there would turn a phone user's explicit
  /// "off" back into automatic (i.e. on) until the next launch, for the same
  /// user. The wipe hook fires exactly when the stored value is destroyed: a
  /// deliberate sign-out, or a different identity signing in.
  void resetInMemory() => value = null;

  /// Record [enabled] as seen on a device whose automatic answer is [isPhone]:
  /// the device default is stored as null (automatic), anything else as an
  /// explicit override.
  Future<void> set(bool enabled, {required bool isPhone}) async {
    final next = enabled == isPhone ? null : enabled;
    if (value == next) return;
    value = next;
    try {
      await _db.navStateDao.saveHideEmptyPanels(
        enabled: next,
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory value — the user still
      // sees their chosen state until next launch.
      _log.warning('Failed to persist hide-empty-panels', e, st);
    }
  }
}
