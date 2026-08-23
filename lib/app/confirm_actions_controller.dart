import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';

final _log = Logger('ConfirmActionsController');

/// Owns the user's "prompt before running a risky action?" preference and
/// persists it to `nav_state.confirm_actions` — same single-row device-local
/// pattern as [SidebarController] / [ThemeController].
///
/// Defaults to **on**: invoiceninja/flutter#49 reported users fat-fingering
/// Approve on a quote and Archive on a record while working from a phone in
/// the field. When on, actions tagged `confirm: true` (see
/// `EntityActionItem`) open an "Are you sure?" dialog first.
///
/// Read it at the moment the action fires, never at build time — a menu built
/// before the switch was flipped must still honour the new value.
class ConfirmActionsController extends ValueNotifier<bool> {
  ConfirmActionsController({
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
    final stored = row?.confirmActions;
    if (stored == null) return;
    value = stored;
  }

  Future<void> set(bool enabled) async {
    if (value == enabled) return;
    value = enabled;
    try {
      await _db.navStateDao.saveConfirmActions(
        enabled: enabled,
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory value — the user still
      // sees their chosen state until next launch.
      _log.warning('Failed to persist confirm actions', e, st);
    }
  }
}
