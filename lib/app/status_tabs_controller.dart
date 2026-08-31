import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';

final _log = Logger('StatusTabsController');

/// Owns the user's "show the status tab strip above lists" preference and
/// persists it to `nav_state.status_tabs` — the same single-row, device-local
/// pattern as [ConfirmActionsController] / [SidebarController].
///
/// Defaults to **on**. invoiceninja/flutter#98 asked for the strip precisely
/// because surfacing a draft through the search field's filter menu is three or
/// four taps; shipping it off by default would leave that cost in place for
/// everyone who never opens Settings. The switch is for people who would rather
/// have the vertical space back.
///
/// Turning it off hides the strip but does **not** clear an active tab — a list
/// can still be narrowed by a `badge_mode` restored from `nav_state` or applied
/// by a saved view. `EntityListScreenScaffold` therefore renders the strip
/// whenever a tab is active regardless of this flag, so a live filter always has
/// visible UI to clear it with.
class StatusTabsController extends ValueNotifier<bool> {
  StatusTabsController({
    required AppDatabase db,
    DateTime Function()? now,
    bool initial = true,
  }) : _db = db,
       _now = now ?? DateTime.now,
       super(initial);

  final AppDatabase _db;
  final DateTime Function() _now;

  /// No stored row (fresh install) leaves the default in place. The column is
  /// non-nullable with a `true` default, so an upgraded database reads back
  /// `true` too.
  Future<void> restore() async {
    final row = await _db.navStateDao.current();
    final stored = row?.statusTabs;
    if (stored == null) return;
    value = stored;
  }

  Future<void> set(bool enabled) async {
    if (value == enabled) return;
    value = enabled;
    try {
      await _db.navStateDao.saveStatusTabs(
        enabled: enabled,
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory value — the user still
      // sees their chosen state until next launch.
      _log.warning('Failed to persist status tabs', e, st);
    }
  }
}
