import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/settings/widgets/cascade_tabbed_settings_shell.dart';
import 'package:admin/ui/features/settings/widgets/tabbed_settings_shell.dart';

import '../../../../_localization_helper.dart';

/// A tab's `topBarLeading` is its primary action — Custom Designs' "+ New
/// Design" is the only way to create one. It rides in the preview bar, and the
/// side-by-side layout has no preview button, so it once had no bar either:
/// the button vanished on exactly the widest windows.

const _tabs = <TabbedSettingsTab>[
  TabbedSettingsTab(slug: '', labelKey: 'general_settings', body: Text('A')),
  TabbedSettingsTab(
    slug: 'b',
    labelKey: 'custom_designs',
    body: Text('B'),
    topBarLeading: Text('LEAD'),
  ),
];

class _Host extends StatefulWidget {
  const _Host({required this.initialIndex});

  final int initialIndex;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(
    length: _tabs.length,
    vsync: this,
    initialIndex: widget.initialIndex,
  );
  final ValueNotifier<bool> previewShown = ValueNotifier<bool>(false);

  @override
  void dispose() {
    controller.dispose();
    previewShown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CascadeSidePaneLayout(
      tabBarView: TabBarView(
        controller: controller,
        children: [for (final tab in _tabs) tab.body],
      ),
      sidePane: const Text('PANE'),
      previewShown: previewShown,
      fullScreenBuilder: (_) => const SizedBox.shrink(),
      tabController: controller,
      tabs: _tabs,
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required int tab,
}) async {
  // The layout keys off its own constraints, so the surface is the width.
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: _Host(initialIndex: tab)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('side by side → the tab action is drawn above the tab content', (
    tester,
  ) async {
    await _pump(tester, width: 1200, tab: 1);

    expect(find.text('LEAD'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    // Both columns at once, so nothing to toggle.
    expect(find.text('PANE'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(
      tester.getTopLeft(find.text('LEAD')).dy,
      lessThan(tester.getTopLeft(find.text('B')).dy),
    );
    expect(
      tester.getTopLeft(find.text('LEAD')).dx,
      lessThan(tester.getTopLeft(find.text('PANE')).dx),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('side by side → a tab with no action gets no strip, and '
      'switching to one that has it does not remount the tab view', (
    tester,
  ) async {
    await _pump(tester, width: 1200, tab: 0);

    expect(find.text('LEAD'), findsNothing);
    expect(
      tester.getTopLeft(find.text('A')).dy,
      tester.getTopLeft(find.byType(CascadeSidePaneLayout)).dy,
    );

    final before = tester.element(find.byType(TabBarView));
    tester.state<_HostState>(find.byType(_Host)).controller.animateTo(1);
    await tester.pumpAndSettle();

    expect(find.text('LEAD'), findsOneWidget);
    expect(identical(tester.element(find.byType(TabBarView)), before), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tablet band → the action shares the row with Show Preview', (
    tester,
  ) async {
    await _pump(tester, width: 800, tab: 1);

    expect(find.text('LEAD'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(
      tester.getCenter(find.text('LEAD')).dy,
      moreOrLessEquals(tester.getCenter(find.byType(OutlinedButton)).dy),
    );
    // The pane is behind the toggle here.
    expect(find.text('PANE'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('phone → the action shares the row with Preview', (tester) async {
    await _pump(tester, width: 500, tab: 1);

    expect(find.text('LEAD'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text('PANE'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
