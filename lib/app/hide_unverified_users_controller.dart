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
