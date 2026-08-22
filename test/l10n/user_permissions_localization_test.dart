import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/permissions.dart';

import '../_localization_helper.dart';

/// Guards the three special permission toggles rendered above the permission
/// grid (Settings → User Management → edit user → Permissions).
///
/// They come from a loop over [kPermissionSpecial], so their strings are looked
/// up through [kPermissionSpecialLabels] / [kPermissionSpecialHelp] rather than
/// from `tr('literal')` calls a source scan could find — hence these assert the
/// maps directly, unlike `email_settings_localization_test.dart`.
///
/// This is the net that was missing when the Reports toggle shipped labelled
/// `view_reports`: that is a permission token, and no locale bundle carries a
/// string for it, so `context.tr` fell through to returning the raw key.
void main() {
  late Map<String, String> available;

  setUpAll(() {
    available = <String, String>{...enStrings(), ...pendingStrings()};
  });

  // Mirrors `Localization.lookup`, where a blank value counts as missing.
  bool resolves(String key) => (available[key] ?? '').trim().isNotEmpty;

  test('every special toggle has a title key that resolves', () {
    final missing = <String>[];
    for (final special in kPermissionSpecial) {
      final key = kPermissionSpecialLabels[special];
      if (key == null) {
        missing.add('$special — no kPermissionSpecialLabels entry');
      } else if (!resolves(key)) {
        missing.add('$special → $key');
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'These toggles would render a raw snake_case slug to users. Map them '
          'to a translated key in kPermissionSpecialLabels, or add the string '
          'to assets/i18n/_app_pending.json:\n${missing.join('\n')}',
    );
  });

  test('every special toggle subtitle key resolves', () {
    final missing =
        kPermissionSpecialHelp.entries
            .where((entry) => !resolves(entry.value))
            .map((entry) => '${entry.key} → ${entry.value}')
            .toList()
          ..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'These subtitles would render a raw snake_case slug to users:\n'
          '${missing.join('\n')}',
    );
  });

  test('the lookup maps only describe real special toggles', () {
    final special = kPermissionSpecial.toSet();
    expect(kPermissionSpecialLabels.keys.toSet().difference(special), isEmpty);
    expect(kPermissionSpecialHelp.keys.toSet().difference(special), isEmpty);
  });

  test('kPermissionNegative is a subset of kPermissionSpecial', () {
    expect(kPermissionNegative.difference(kPermissionSpecial.toSet()), isEmpty);
  });
}
