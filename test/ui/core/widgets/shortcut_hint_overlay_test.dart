import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/key_cap.dart';
import 'package:admin/ui/core/widgets/shortcut_hint_overlay.dart';

import '../../../_localization_helper.dart';

ShortcutHintController _controllerWithHint() =>
    ShortcutHintController()..register('g', const [
      ShortcutHint(keys: ['⌘', 'K'], labelKey: 'switch_company'),
    ]);

Widget _host(ShortcutHintController controller) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(body: ShortcutHintOverlay(controller: controller)),
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('hidden by default (nothing revealed)', (tester) async {
    _setSize(tester, const Size(1200, 800));
    await tester.pumpWidget(_host(_controllerWithHint()));
    expect(find.byType(KeyCap), findsNothing);
  });

  testWidgets('reveal() shows the bar with a keycap per key', (tester) async {
    _setSize(tester, const Size(1200, 800));
    final controller = _controllerWithHint();
    await tester.pumpWidget(_host(controller));

    controller.reveal();
    await tester.pump(); // rebuild from notifyListeners
    await tester.pump(const Duration(milliseconds: 150)); // AnimatedSwitcher

    // ⌘ + K for the hint, plus the trailing "? All shortcuts" pointer chip.
    expect(find.byType(KeyCap), findsNWidgets(3));
    expect(find.text('Switch Company'), findsOneWidget);
    expect(find.text('All shortcuts'), findsOneWidget);
  });

  testWidgets('stays hidden below 600px even when visible', (tester) async {
    _setSize(tester, const Size(500, 800));
    final controller = _controllerWithHint();
    await tester.pumpWidget(_host(controller));

    controller.reveal();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(KeyCap), findsNothing);
  });
}
