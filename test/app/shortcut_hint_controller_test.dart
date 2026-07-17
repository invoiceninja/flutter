import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/shortcut_hint_controller.dart';

void main() {
  // Several cases below are plain `test()` (no widget pump) yet call controller
  // methods that consult `SchedulerBinding.instance` (the build/layout-phase
  // deferral in `_notify`). Initialize the test binding up front so that access
  // resolves regardless of test order.
  TestWidgetsFlutterBinding.ensureInitialized();

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

    // Regression: an entity edit screen's `ShortcutHintScope` registers from
    // `didChangeDependencies`, which runs inside the edit scaffold's
    // `LayoutBuilder` layout callback. A synchronous `notifyListeners()` there
    // marked the sibling `ShortcutHintOverlay` (`ListenableBuilder`) dirty
    // mid-build → "setState() called during build", failing every edit-screen
    // integration test. Registering during a layout-phase build must not throw.
    testWidgets(
      'register() during a layout-phase build does not crash a listening '
      'sibling',
      (tester) async {
        final c = ShortcutHintController();
        addTearDown(c.dispose);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                // Stand-in for the app-root ShortcutHintOverlay: a sibling
                // that rebuilds whenever the controller notifies.
                ListenableBuilder(
                  listenable: c,
                  builder: (_, _) => const SizedBox(),
                ),
                // Stand-in for an edit screen: register() fires from inside a
                // LayoutBuilder's layout callback (persistentCallbacks phase).
                LayoutBuilder(
                  builder: (context, _) {
                    c.register('edit', const [
                      ShortcutHint(keys: ['⌘', 'S'], labelKey: 'save'),
                    ]);
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        );
        // Flush the deferred post-frame notification.
        await tester.pump();
        expect(tester.takeException(), isNull);
        // The state mutation itself is synchronous — only the notify defers.
        expect(c.activeHints.map((h) => h.labelKey), ['save']);
      },
    );
  });
}
