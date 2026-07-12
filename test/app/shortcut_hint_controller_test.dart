import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/shortcut_hint_controller.dart';

void main() {
  group('ShortcutHintController', () {
    test('activeHints unions scopes in registration order, de-duped', () {
      final c = ShortcutHintController();
      c.register('global', const [
        ShortcutHint(keys: ['⌘', 'K'], labelKey: 'switch_company'),
        ShortcutHint(keys: ['⌘', 'S'], labelKey: 'save'),
      ]);
      c.register('ctx', const [
        ShortcutHint(keys: ['⌘', 'S'], labelKey: 'save'), // duplicate of above
        ShortcutHint(keys: ['⌘', 'N'], labelKey: 'add_items'),
      ]);
      expect(c.activeHints.map((h) => h.labelKey).toList(), [
        'switch_company',
        'save',
        'add_items',
      ]);
    });

    test('unregister removes only that scope', () {
      final c = ShortcutHintController();
      c.register('a', const [
        ShortcutHint(keys: ['⌘', 'K'], labelKey: 'switch_company'),
      ]);
      c.register('b', const [
        ShortcutHint(keys: ['⌘', 'S'], labelKey: 'save'),
      ]);
      c.unregister('a');
      expect(c.activeHints.map((h) => h.labelKey), ['save']);
    });

    test('reveal is a no-op (no notify) when there are no active hints', () {
      final c = ShortcutHintController();
      var notified = 0;
      c.addListener(() => notified++);
      c.reveal();
      expect(c.visible, isFalse);
      expect(notified, 0);
    });

    test('reveal shows when hints exist; hide clears', () {
      final c = ShortcutHintController();
      c.register('g', const [
        ShortcutHint(keys: ['⌘', 'K'], labelKey: 'switch_company'),
      ]);
      c.reveal();
      expect(c.visible, isTrue);
      c.hide();
      expect(c.visible, isFalse);
    });

    test('reset clears visibility and every scope', () {
      final c = ShortcutHintController();
      c.register('g', const [
        ShortcutHint(keys: ['⌘', 'K'], labelKey: 'switch_company'),
      ]);
      c.reveal();
      c.reset();
      expect(c.visible, isFalse);
      expect(c.activeHints, isEmpty);
    });

    test('ShortcutHint equality is by (keys, labelKey)', () {
      const a = ShortcutHint(keys: ['⌘', 'S'], labelKey: 'save');
      const b = ShortcutHint(keys: ['⌘', 'S'], labelKey: 'save');
      const differentKeys = ShortcutHint(keys: ['⌘', 'N'], labelKey: 'save');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(differentKeys)));
    });
  });
}
