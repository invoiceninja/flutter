import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/nav_state_prefs_carry.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

/// A key's name is a row on installed devices, and its scope decides what a
/// sign-out does with that row — so both are pinned here, and a change to
/// either has to be made on purpose.
void main() {
  /// Every name that has shipped, in the order it was added. Append; never
  /// rename, reorder or remove one — a removed preference must keep its name
  /// out of reuse, or a new preference would read the old one's rows.
  const shipped = <String, PrefScope>{
    'locale': PrefScope.device,
    'theme_mode': PrefScope.device,
    'light_variant': PrefScope.device,
    'dark_variant': PrefScope.device,
    'custom_theme_json': PrefScope.device,
    'text_scale': PrefScope.device,
    'keyboard_shortcuts_json': PrefScope.device,
    'sidebar_badge_modes_json': PrefScope.account,
    'confirm_actions': PrefScope.account,
    'status_tabs': PrefScope.device,
    'contacts_sync_json': PrefScope.account,
    'phone_actions_json': PrefScope.device,
    'sidebar_menu_json': PrefScope.account,
    'tasks_view': PrefScope.account,
    'hide_unverified_users': PrefScope.account,
    'hide_empty_panels': PrefScope.account,
    'sidebar_collapsed': PrefScope.device,
  };

  final names = [for (final k in DevicePrefKeys.all) k.name];

  test('the key list only ever grows at the end', () {
    expect(
      names.take(shipped.length).toList(),
      shipped.keys.toList(),
      reason:
          'a shipped key was renamed, reordered or removed. Append new keys '
          'to DevicePrefKeys.all and to `shipped` here.',
    );
    expect(names.length, greaterThanOrEqualTo(shipped.length));
  });

  test('names are unique, and none takes the reserved marker', () {
    expect(names.toSet(), hasLength(names.length));
    expect(names, isNot(contains(kPrefsCarriedFromNavState)));
  });

  test('each key keeps the scope it shipped with', () {
    for (final key in DevicePrefKeys.all) {
      final pinned = shipped[key.name];
      if (pinned == null) continue; // not shipped yet — add it above
      expect(
        key.scope,
        pinned,
        reason:
            '${key.name} changed scope, which changes what a sign-out does '
            'with it. If that is the intent, update the pin.',
      );
    }
  });

  test('a wipe keeps exactly the device keys and the marker', () {
    expect(DevicePrefKeys.keptOnWipe, {
      for (final k in DevicePrefKeys.all)
        if (k.scope == PrefScope.device) k.name,
      kPrefsCarriedFromNavState,
    });
  });

  test('every nav_state column v12 carries lands on a key of that name', () {
    expect(names, containsAll(kNavStatePrefColumns));
  });

  group('codecs', () {
    test('booleans are 1 / 0, and read what SQLite made of a BOOLEAN', () {
      const codec = PrefCodec.boolean;
      expect(codec.encode(true), '1');
      expect(codec.encode(false), '0');
      expect(codec.decode('1'), isTrue);
      expect(codec.decode('0'), isFalse);
      expect(codec.decode('true'), isTrue);
      expect(codec.decode('false'), isFalse);
      expect(codec.decode('yes'), isNull);
    });

    test('decimals round-trip, and garbage reads as unset', () {
      const codec = PrefCodec.decimal;
      expect(codec.decode(codec.encode(1.2)), 1.2);
      expect(codec.decode('1.2'), 1.2);
      expect(codec.decode('big'), isNull);
    });

    test('strings are stored as they are', () {
      expect(PrefCodec.string.encode('{"a":1}'), '{"a":1}');
      expect(PrefCodec.string.decode(''), '');
    });
  });
}
