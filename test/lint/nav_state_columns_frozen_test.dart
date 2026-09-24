import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// `nav_state` holds where the user was — the route, each list's filters, the
/// recently viewed records — and nothing else may join it.
///
/// Through schema v11 every device preference was a column here, so each one
/// cost a schema bump and an `onUpgrade` run on every installed database — the
/// path whose failure wipes the store. v12 moved them to `device_prefs`, where
/// a preference is a `DevicePrefKeys` entry and needs no migration. The legacy
/// columns stay declared (a build rolled back past v12 still opens the store);
/// this list keeps a new one from appearing.
void main() {
  test('the nav_state column list is frozen', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      [for (final c in db.navState.$columns) c.name],
      const [
        'id',
        'current_route',
        'selected_company_id',
        'locale',
        'theme_mode',
        'light_variant',
        'dark_variant',
        'custom_theme_json',
        'text_scale',
        'filters_json',
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
        'recent_entities_json',
        'sidebar_collapsed',
        'updated_at',
      ],
      reason:
          'A device preference is a DevicePrefKeys entry '
          '(lib/data/prefs/device_pref_keys.dart), not a nav_state column — '
          'it needs no schema change at all.',
    );
  });
}
