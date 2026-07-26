import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';

/// Distinct dummy intent per action id so `activatorsFor` mappings can be
/// asserted by identity (Flutter's real intents live in the shell).
class _DummyIntent extends Intent {
  const _DummyIntent(this.id);
  final String id;
}

Map<String, Intent> _allIntents() => {
  for (final d in kShortcutCatalog) d.id: _DummyIntent(d.id),
};

// The signature helper mirrors KeyBinding.activatorSignatures (SingleActivator /
// CharacterActivator use identity equality, so tests compare canonical strings).
String _keySig(LogicalKeyboardKey k, {bool shift = false}) =>
    'key:${k.keyId}:shift=$shift';

void main() {
  group('KeyBinding codec + expansion', () {
    test('primary-modified logical chord expands to meta + control', () {
      final b = KeyBinding.logical(
        LogicalKeyboardKey.keyK.keyId,
        usesPrimary: true,
      );
      final activators = b.toActivators();
      expect(activators, hasLength(2));
      expect(activators.every((a) => a is SingleActivator), isTrue);
      expect(b.activatorSignatures(), [
        '${_keySig(LogicalKeyboardKey.keyK)}:meta',
        '${_keySig(LogicalKeyboardKey.keyK)}:control',
      ]);
    });

    test('character trigger → single CharacterActivator', () {
      const b = KeyBinding.character('?');
      expect(b.toActivators(), hasLength(1));
      expect(b.toActivators().single, isA<CharacterActivator>());
      expect(b.activatorSignatures(), ['char:?']);
    });

    test('unmodified logical chord → single SingleActivator', () {
      final b = KeyBinding.logical(LogicalKeyboardKey.keyN.keyId);
      expect(b.toActivators(), hasLength(1));
      expect(b.toActivators().single, isA<SingleActivator>());
      // Two signatures, one activator: an unmodified chord also types a
      // character, so it has to be comparable against a CharacterActivator
      // binding (which would match the same keystroke and lose at dispatch).
      expect(b.activatorSignatures(), [
        _keySig(LogicalKeyboardKey.keyN),
        'char:n',
      ]);
    });

    test(
      'a primary-modified chord types nothing, so has no char signature',
      () {
        final b = KeyBinding.logical(
          LogicalKeyboardKey.keyN.keyId,
          usesPrimary: true,
        );
        expect(
          b.activatorSignatures().where((s) => s.startsWith('char:')),
          isEmpty,
        );
      },
    );

    test('a chord on a key that types nothing has no char signature', () {
      final b = KeyBinding.logical(LogicalKeyboardKey.f5.keyId);
      expect(b.activatorSignatures(), [_keySig(LogicalKeyboardKey.f5)]);
    });

    test('json round-trips logical + character bindings', () {
      final logical = KeyBinding.logical(
        LogicalKeyboardKey.keyB.keyId,
        usesPrimary: true,
        shift: true,
      );
      expect(KeyBinding.fromJson(logical.toJson()), logical);
      const char = KeyBinding.character('/');
      expect(KeyBinding.fromJson(char.toJson()), char);
    });

    test('fromJson returns null for an empty/garbage payload', () {
      expect(KeyBinding.fromJson(const {}), isNull);
      expect(KeyBinding.fromJson(const {'nonsense': 1}), isNull);
    });

    test('displayGlyphs uses the injected modifier label', () {
      final b = KeyBinding.logical(
        LogicalKeyboardKey.comma.keyId,
        usesPrimary: true,
      );
      expect(b.displayGlyphs('⌘'), ['⌘', ',']);
      expect(const KeyBinding.character('?').displayGlyphs('⌘'), ['?']);
    });
  });

  group('golden defaults — byte-identical to the old const shell map', () {
    // If any of these change, the shell's live map changed too — update
    // deliberately. History ⌘/Alt+Arrow stays fixed (merged in the shell, not
    // here) and the G-leader is handled by the Focus, so neither appears.
    final expectedDefaults = <String, KeyBinding>{
      ShortcutActionIds.openCompanyPicker: KeyBinding.logical(
        LogicalKeyboardKey.keyK.keyId,
        usesPrimary: true,
      ),
      ShortcutActionIds.openCommandPalette: KeyBinding.logical(
        LogicalKeyboardKey.slash.keyId,
        usesPrimary: true,
      ),
      ShortcutActionIds.toggleSidebar: KeyBinding.logical(
        LogicalKeyboardKey.keyB.keyId,
        usesPrimary: true,
      ),
      ShortcutActionIds.openSettings: KeyBinding.logical(
        LogicalKeyboardKey.comma.keyId,
        usesPrimary: true,
      ),
      ShortcutActionIds.openKeyboardShortcuts: const KeyBinding.character('?'),
      ShortcutActionIds.focusSearch: const KeyBinding.character('/'),
    };

    test('each general shortcut resolves to its historical default', () {
      final c = KeyboardShortcutsController();
      expectedDefaults.forEach((id, expected) {
        expect(c.resolvedBinding(id), expected, reason: id);
      });
    });

    test('the global activator set is exactly the 10 historical entries', () {
      final c = KeyboardShortcutsController();
      final map = c.activatorsFor(ShortcutScope.global, _allIntents());
      // 4 primary chords (×2 = meta+control) + 2 character triggers = 10.
      expect(map.length, 10);
    });

    test('create actions ship unbound → contribute no activators', () {
      final c = KeyboardShortcutsController();
      for (final type in kCreateShortcutEntities) {
        expect(c.resolvedBinding(ShortcutActionIds.create(type)), isNull);
      }
    });

    test('company-picker maps to both meta + control; help maps once', () {
      final c = KeyboardShortcutsController();
      final intents = _allIntents();
      final map = c.activatorsFor(ShortcutScope.global, intents);
      final company = intents[ShortcutActionIds.openCompanyPicker];
      final help = intents[ShortcutActionIds.openKeyboardShortcuts];
      expect(map.values.where((v) => identical(v, company)).length, 2);
      expect(map.values.where((v) => identical(v, help)).length, 1);
    });

    test('an action with no provided intent is skipped', () {
      final c = KeyboardShortcutsController();
      expect(c.activatorsFor(ShortcutScope.global, const {}), isEmpty);
    });
  });

  group('three-state resolution', () {
    const id = ShortcutActionIds.openCompanyPicker;
    final defaultBinding = KeyBinding.logical(
      LogicalKeyboardKey.keyK.keyId,
      usesPrimary: true,
    );

    test('default → custom → cleared → reset', () {
      final c = KeyboardShortcutsController();
      expect(c.isOverridden(id), isFalse);
      expect(c.resolvedBinding(id), defaultBinding);

      final custom = KeyBinding.logical(
        LogicalKeyboardKey.keyG.keyId,
        usesPrimary: true,
      );
      c.setBinding(id, custom);
      expect(c.isOverridden(id), isTrue);
      expect(c.resolvedBinding(id), custom);

      c.clearBinding(id);
      expect(c.isOverridden(id), isTrue);
      expect(c.resolvedBinding(id), isNull);

      c.resetBinding(id);
      expect(c.isOverridden(id), isFalse);
      expect(c.resolvedBinding(id), defaultBinding);
    });

    test('a cleared general shortcut drops out of activatorsFor', () {
      final c = KeyboardShortcutsController();
      final intents = _allIntents();
      c.clearBinding(ShortcutActionIds.focusSearch);
      final map = c.activatorsFor(ShortcutScope.global, intents);
      final search = intents[ShortcutActionIds.focusSearch];
      expect(map.values.where((v) => identical(v, search)), isEmpty);
      expect(map.length, 9); // 10 minus the cleared '/'
    });

    test('resetAll clears every override', () {
      final c = KeyboardShortcutsController();
      c.setBinding(
        ShortcutActionIds.toggleSidebar,
        const KeyBinding.character('z'),
      );
      c.clearBinding(ShortcutActionIds.focusSearch);
      c.resetAll();
      expect(c.isOverridden(ShortcutActionIds.toggleSidebar), isFalse);
      expect(c.isOverridden(ShortcutActionIds.focusSearch), isFalse);
    });

    test('notifies listeners on a binding change', () {
      final c = KeyboardShortcutsController();
      var notified = 0;
      c.addListener(() => notified++);
      c.setBinding(ShortcutActionIds.toggleSidebar, defaultBinding);
      expect(notified, 1);
    });
  });

  group('conflicts', () {
    test('two actions bound to the same chord are both flagged', () {
      final c = KeyboardShortcutsController();
      final createId = ShortcutActionIds.create(kCreateShortcutEntities.first);
      c.setBinding(
        createId,
        KeyBinding.logical(LogicalKeyboardKey.keyK.keyId, usesPrimary: true),
      );
      final conflicts = c.conflictingIds();
      expect(conflicts, contains(ShortcutActionIds.openCompanyPicker));
      expect(conflicts, contains(createId));
    });

    test('distinct default bindings do not conflict', () {
      expect(KeyboardShortcutsController().conflictingIds(), isEmpty);
    });

    test('a clashing binding loses to the earlier catalog entry', () {
      // "First catalog entry wins" has to be enforced, not incidental — the
      // activator types use identity equality, so a Map keyed by them can't
      // dedupe on its own.
      final c = KeyboardShortcutsController();
      final createId = ShortcutActionIds.create(kCreateShortcutEntities.first);
      c.setBinding(
        createId,
        KeyBinding.logical(LogicalKeyboardKey.keyK.keyId, usesPrimary: true),
      );
      final intents = _allIntents();
      final map = c.activatorsFor(ShortcutScope.global, intents);
      expect(
        map.values,
        contains(intents[ShortcutActionIds.openCompanyPicker]),
        reason: 'the earlier catalog entry keeps the chord',
      );
      expect(
        map.values,
        isNot(contains(intents[createId])),
        reason: 'the later, clashing entry contributes nothing',
      );
    });

    // A recorded chord is always a logical key, but two catalog defaults are
    // CharacterActivators (`?` help, `/` focus-search). Both shapes can match
    // the SAME physical keystroke, and Flutter's dispatch prefers the
    // trigger-keyed SingleActivator — so the recorded one silently wins and the
    // built-in stops working. Signatures must therefore cross the shapes.
    test('an unmodified logical key conflicts with the character it types', () {
      final c = KeyboardShortcutsController();
      final createId = ShortcutActionIds.create(kCreateShortcutEntities.first);
      c.setBinding(
        createId,
        KeyBinding.logical(LogicalKeyboardKey.slash.keyId),
      );
      expect(
        c.conflictingIds(),
        containsAll([ShortcutActionIds.focusSearch, createId]),
        reason: 'bare `/` shadows the built-in focus-search shortcut',
      );
    });

    test('shift + that key conflicts with the shifted character', () {
      final c = KeyboardShortcutsController();
      final createId = ShortcutActionIds.create(kCreateShortcutEntities.first);
      c.setBinding(
        createId,
        KeyBinding.logical(LogicalKeyboardKey.slash.keyId, shift: true),
      );
      expect(
        c.conflictingIds(),
        containsAll([ShortcutActionIds.openKeyboardShortcuts, createId]),
        reason: 'Shift+/ types `?` and shadows the help dialog',
      );
    });

    test('a primary-modified key does NOT conflict with the bare glyph', () {
      // ⌘/ is search_everything's default and must not be reported as clashing
      // with the bare `/` focus-search default — the modifier disambiguates.
      expect(KeyboardShortcutsController().conflictingIds(), isEmpty);
    });

    test('a primary chord conflicts with the same key on either modifier', () {
      final c = KeyboardShortcutsController();
      // ⌘/Ctrl B is toggle_sidebar's default; assigning ⌘/Ctrl B to a create
      // action collides on both the meta and control signatures.
      final createId = ShortcutActionIds.create(kCreateShortcutEntities.first);
      c.setBinding(
        createId,
        KeyBinding.logical(LogicalKeyboardKey.keyB.keyId, usesPrimary: true),
      );
      expect(
        c.conflictingIds(),
        containsAll([ShortcutActionIds.toggleSidebar, createId]),
      );
    });
  });

  group('persistence round-trip (in-memory codec)', () {
    test('overridesToJson → restoreFromJson preserves custom + cleared', () {
      final c = KeyboardShortcutsController();
      c.setBinding(
        ShortcutActionIds.toggleSidebar,
        KeyBinding.logical(LogicalKeyboardKey.keyB.keyId, usesPrimary: true),
      );
      c.clearBinding(ShortcutActionIds.focusSearch);

      final restored = KeyboardShortcutsController();
      restored.restoreFromJson(_encode(c.overridesToJson()));
      expect(
        restored.resolvedBinding(ShortcutActionIds.toggleSidebar),
        KeyBinding.logical(LogicalKeyboardKey.keyB.keyId, usesPrimary: true),
      );
      expect(restored.isOverridden(ShortcutActionIds.focusSearch), isTrue);
      expect(restored.resolvedBinding(ShortcutActionIds.focusSearch), isNull);
    });

    test('restoreFromJson ignores unknown action ids', () {
      final c = KeyboardShortcutsController();
      c.restoreFromJson('{"totally_unknown_action":{"char":"x"}}');
      expect(c.isOverridden('totally_unknown_action'), isFalse);
    });

    test('restoreFromJson tolerates null / empty', () {
      final c = KeyboardShortcutsController();
      c.restoreFromJson(null);
      c.restoreFromJson('');
      c.restoreFromJson('not json');
      expect(c.conflictingIds(), isEmpty);
    });
  });
}

// Minimal JSON encoder so the test doesn't reach into the controller's private
// serialization. Values are either null (cleared) or a flat {key/char/...} map.
String _encode(Map<String, dynamic> m) {
  String encodeVal(dynamic v) {
    if (v == null) return 'null';
    final inner = (v as Map).entries
        .map(
          (ie) =>
              '"${ie.key}":'
              '${ie.value is String ? '"${ie.value}"' : ie.value}',
        )
        .join(',');
    return '{$inner}';
  }

  final entries = m.entries.map((e) => '"${e.key}":${encodeVal(e.value)}');
  return '{${entries.join(',')}}';
}
