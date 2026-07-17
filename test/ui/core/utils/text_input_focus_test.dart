import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/utils/text_input_focus.dart';

void main() {
  group('isTextInputFocused', () {
    testWidgets('returns false when nothing is focused', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('idle'))),
      );
      expect(isTextInputFocused(), isFalse);
    });

    testWidgets('returns true when a TextField has focus', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TextField(focusNode: focusNode)),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      // Sanity: the canonical historical check is broken in current
      // Flutter — primaryFocus.context.widget resolves to the inner
      // Focus widget Flutter's EditableText builds, not EditableText
      // itself. We assert that here so the regression hand-off is
      // explicit if/when Flutter ever changes the internal wiring.
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
        reason:
            'historical guard `widget is EditableText` would silently fail; '
            'isTextInputFocused() must look further up the tree',
      );

      expect(isTextInputFocused(), isTrue);
    });

    testWidgets(
      'returns true when focus is inside a TextInputFocusScope marker',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TextInputFocusScope(
                child: Focus(focusNode: focusNode, child: const Text('x')),
              ),
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();

        expect(isTextInputFocused(), isTrue);
      },
    );

    testWidgets('returns false when a non-text widget has focus', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(focusNode: focusNode, child: const Text('x')),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      expect(isTextInputFocused(), isFalse);
    });
  });

  group('GuardedShortcutAction', () {
    testWidgets('invokes when no text input has focus', (tester) async {
      var fired = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.keyF): _ProbeIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _ProbeIntent: GuardedShortcutAction<_ProbeIntent>(
                    onInvoke: (_) {
                      fired++;
                      return null;
                    },
                  ),
                },
                child: const Focus(autofocus: true, child: SizedBox()),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(fired, 1);
    });

    testWidgets('is disabled while a TextField has focus — key falls through', (
      tester,
    ) async {
      var fired = 0;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.keyF): _ProbeIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _ProbeIntent: GuardedShortcutAction<_ProbeIntent>(
                    onInvoke: (_) {
                      fired++;
                      return null;
                    },
                  ),
                },
                child: TextField(controller: controller, focusNode: focusNode),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(
        fired,
        0,
        reason:
            'GuardedShortcutAction must report isEnabled=false while a '
            'text input is focused so the key falls through to the field.',
      );
    });

    testWidgets('is disabled while the shell leader sequence is armed — key '
        'falls through to the leader handler (U3)', (tester) async {
      var fired = 0;
      // Global flag — never let it leak into other tests.
      addTearDown(() => leaderModeArmed = false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.keyF): _ProbeIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _ProbeIntent: GuardedShortcutAction<_ProbeIntent>(
                    onInvoke: (_) {
                      fired++;
                      return null;
                    },
                  ),
                },
                child: const Focus(autofocus: true, child: SizedBox()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // `G` was pressed; the shell is waiting for the second key.
      leaderModeArmed = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pump();

      expect(
        fired,
        0,
        reason:
            'an armed leader sequence must stand the single-key shortcut down '
            'so the second key reaches the shell leader handler (Tasks `S` '
            'must not hijack `G then S`).',
      );
    });
  });
}

class _ProbeIntent extends Intent {
  const _ProbeIntent();
}
