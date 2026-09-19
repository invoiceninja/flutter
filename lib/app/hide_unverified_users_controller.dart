import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';

final _log = Logger('HideUnverifiedUsersController');

/// Owns the user's "keep people who have never confirmed their email address
/// out of Assigned User fields" preference and persists it to
/// `nav_state.hide_unverified_users` — the same single-row, device-local
/// pattern as [StatusTabsController] / [ConfirmActionsController].
///
/// Defaults to **off**, which is the opposite of its two bool siblings and is
/// deliberate. invoiceninja/flutter#150 asked for the toggle, but
/// `email_verified_at` conflates four states (BACKEND.md § F4) and three of
/// them are active, working users — so the cost of a wrong default here is a
/// colleague silently missing from every assignee field, not a little extra
/// chrome. `lib/domain/assignable_users.dart` narrows *which* users the rule
/// catches; this default is the other half of that trade.
///
/// Read live via a `ValueListenableBuilder` — `AssignedUserPickerField` and the
/// User Management roster both stay mounted behind the `/settings/**` route
/// while the switch is flipped, so a build-time read with no listener would
/// keep rendering the old answer until some unrelated rebuild.
class HideUnverifiedUsersController extends ValueNotifier<bool> {
  HideUnverifiedUsersController({
    required AppDatabase db,
    DateTime Function()? now,
    bool initial = false,
  }) : _db = db,
       _now = now ?? DateTime.now,
       super(initial);

  final AppDatabase _db;
  final DateTime Function() _now;

  /// No stored row (fresh install) leaves the default in place. The column is
  /// non-nullable with a `false` default, so an upgraded database reads back
  /// `false` too.
  Future<void> restore() async {
    final row = await _db.navStateDao.current();
    final stored = row?.hideUnverifiedUsers;
    if (stored == null) return;
    value = stored;
  }

  /// Drop the choice without touching the database — runs from
  /// `AuthRepository.onBeforeDataWipe` beside
  /// [HideEmptyPanelsController.resetInMemory], for the same reason. This
  /// controller is built once in `Services.build` and outlives a logout, and
  /// [restore] early-returns on a null stored value so it can never clear
  /// itself: without this, a second user signing in on the same install without
  /// relaunching inherits the first one's setting, and with it **every colleague
  /// the roster cannot prove has confirmed their email silently disappears from
  /// their Assigned User fields** — while the switch in Settings reads *off*.
  ///
  /// Not in `onBeforeLogout`: that also runs on the idle-timeout / 401 re-lock
  /// path, which *keeps* `nav_state`, so resetting there would quietly undo the
  /// same user's own choice until the next launch (invoiceninja/flutter#161 is
  /// that bug, fixed for this controller's three siblings and missed here).
  void resetInMemory() {
    if (!value) return;
    value = false;
  }

  Future<void> set(bool enabled) async {
    if (value == enabled) return;
    value = enabled;
    try {
      await _db.navStateDao.saveHideUnverifiedUsers(
        enabled: enabled,
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory value — the user still
      // sees their chosen state until next launch.
      _log.warning('Failed to persist hide-unverified-users', e, st);
    }
  }
}
