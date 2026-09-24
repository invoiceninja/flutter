import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

/// The `nav_state` columns that held device preferences through schema v11.
/// Each value now lives in the `device_prefs` row named after its column. The
/// columns stay declared — a build rolled back past v12 still opens the store
/// and finds its preferences as they were at the upgrade — but nothing reads
/// or writes them any more (`test/lint/nav_state_columns_frozen_test.dart`).
const List<String> kNavStatePrefColumns = [
  'locale',
  'theme_mode',
  'light_variant',
  'dark_variant',
  'custom_theme_json',
  'text_scale',
  'keyboard_shortcuts_json',
  'sidebar_badge_modes_json',
  'confirm_actions',
  'status_tabs',
  'contacts_sync_json',
  'phone_actions_json',
  'sidebar_menu_json',
  'tasks_view',
  'hide_unverified_users',
  'hide_empty_panels',
  'sidebar_collapsed',
];

/// Copy the [kNavStatePrefColumns] of the `nav_state` row into `device_prefs`
/// — once per store.
///
/// Runs from the v12 upgrade step, after a failed upgrade is repaired instead
/// (`repairSchema` creates the table but copies nothing), and after a salvage
/// import from a store older than v12. A marker row ([kPrefsCarriedFromNavState])
/// records that it ran, so a re-run can never resurrect a value the user has
/// since changed or reset: an upgrade re-applied after the app was killed, a
/// rollback past v12 and back, or a salvaged v12 store (whose marker came
/// across with its rows). `INSERT OR IGNORE`, so an existing row always wins.
///
/// SQLite converts on the way in: the `value` column is TEXT, so a BOOLEAN
/// column arrives as `'1'` / `'0'` and `text_scale` as `'1.2'` — the forms
/// `PrefCodec.boolean` and `PrefCodec.decimal` read.
Future<void> carryNavStatePrefs(AppDatabase db) async {
  final done = await db
      .customSelect(
        'SELECT 1 FROM device_prefs WHERE "key" = ?',
        variables: [Variable.withString(kPrefsCarriedFromNavState)],
      )
      .getSingleOrNull();
  if (done != null) return;
  for (final column in kNavStatePrefColumns) {
    // `column` comes from the const list above — never user input.
    await db.customStatement(
      'INSERT OR IGNORE INTO device_prefs ("key", "value", "updated_at") '
      'SELECT ?, "$column", "updated_at" FROM nav_state '
      'WHERE "id" = 0 AND "$column" IS NOT NULL',
      [column],
    );
  }
  await db.customStatement(
    'INSERT OR IGNORE INTO device_prefs ("key", "value", "updated_at") '
    'VALUES (?, ?, ?)',
    [kPrefsCarriedFromNavState, '1', DateTime.now().millisecondsSinceEpoch],
  );
}
