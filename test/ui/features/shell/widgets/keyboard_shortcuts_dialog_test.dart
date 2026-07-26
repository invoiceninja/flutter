import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/features/shell/widgets/keyboard_shortcuts_dialog.dart';

import '../../../../_localization_helper.dart';

/// The dialog resolves its Global/Create rows through the live shortcut
/// controller, so it needs a `Services` ancestor. Everything else throws so the
/// test fails loudly if the dialog reaches for more.
class _FakeServices implements Services {
  _FakeServices(this.keyboardShortcuts);
  @override
  final KeyboardShortcutsController keyboardShortcuts;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _open(WidgetTester tester) async {
  // No `db` — the controller resolves catalog defaults purely in memory.
  final shortcuts = KeyboardShortcutsController();
  addTearDown(shortcuts.dispose);
  await tester.pumpWidget(
    Provider<Services>.value(
      value: _FakeServices(shortcuts),
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showKeyboardShortcutsDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('platformModifierLabel', () {
    test('returns ⌘ on macOS and iOS', () {
      expect(platformModifierLabel(TargetPlatform.macOS), '⌘');
      expect(platformModifierLabel(TargetPlatform.iOS), '⌘');
    });

    test('returns Ctrl on other platforms', () {
      expect(platformModifierLabel(TargetPlatform.windows), 'Ctrl');
      expect(platformModifierLabel(TargetPlatform.linux), 'Ctrl');
      expect(platformModifierLabel(TargetPlatform.android), 'Ctrl');
      expect(platformModifierLabel(TargetPlatform.fuchsia), 'Ctrl');
    });
  });

  group('platformHistoryModifierLabel', () {
    test('returns ⌘ on macOS and iOS', () {
      expect(platformHistoryModifierLabel(TargetPlatform.macOS), '⌘');
      expect(platformHistoryModifierLabel(TargetPlatform.iOS), '⌘');
    });

    test('returns Alt+ on other platforms (browser convention)', () {
      expect(platformHistoryModifierLabel(TargetPlatform.windows), 'Alt+');
      expect(platformHistoryModifierLabel(TargetPlatform.linux), 'Alt+');
      expect(platformHistoryModifierLabel(TargetPlatform.android), 'Alt+');
      expect(platformHistoryModifierLabel(TargetPlatform.fuchsia), 'Alt+');
    });
  });

  group('showKeyboardShortcutsDialog', () {
    testWidgets('renders every section and the footer hint', (tester) async {
      await _open(tester);

      expect(find.text('Keyboard Shortcuts'), findsWidgets);
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
      // "Search" now renders once (the Search section title); the Global
      // Cmd+/ row reads "Search everything" after the relabel.
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Search everything'), findsOneWidget);
      expect(find.text('Forms'), findsOneWidget);
      expect(find.text('Create new record'), findsOneWidget);
      expect(find.text('Edit the current record'), findsOneWidget);
      expect(find.text('Toggle Sidebar'), findsOneWidget);
      expect(find.text('Jump to section'), findsOneWidget);
      expect(find.text('Go Back'), findsOneWidget);
      expect(find.text('Go Forward'), findsOneWidget);
      expect(
        find.text('Shortcuts are disabled while typing in a field.'),
        findsOneWidget,
      );
    });

    testWidgets('Close button dismisses the dialog', (tester) async {
      await _open(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('two-column layout on desktop renders every section', (
      tester,
    ) async {
      // Force a desktop-width window so MediaQuery.sizeOf returns >= 900.
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _open(tester);

      // Every section title still renders, just split across two columns.
      expect(find.text('Global'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
      // "Search" now renders once (the Search section title); the Global
      // Cmd+/ row reads "Search everything" after the relabel.
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Search everything'), findsOneWidget);
      expect(find.text('Forms'), findsOneWidget);
    });
  });
}
