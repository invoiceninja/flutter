import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/entity_list_section_header.dart';

import '../../../_localization_helper.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool collapsed,
  required VoidCallback onToggle,
  String label = 'Hardware',
  int count = 12,
  bool isFirst = false,
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: EntityListSectionHeader(
          label: label,
          count: count,
          collapsed: collapsed,
          onToggle: onToggle,
          isFirst: isFirst,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders the label uppercase with its loaded count', (
    tester,
  ) async {
    await _pump(tester, collapsed: false, onToggle: () {});
    expect(find.text('HARDWARE'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('the chevron reflects the folded state', (tester) async {
    await _pump(tester, collapsed: false, onToggle: () {});
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

    await _pump(tester, collapsed: true, onToggle: () {});
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
  });

  testWidgets('the whole row is the tap target', (tester) async {
    var taps = 0;
    await _pump(tester, collapsed: false, onToggle: () => taps++);
    // Tap the label, not the chevron — folding shouldn't require hitting a
    // 18 px glyph.
    await tester.tap(find.text('HARDWARE'));
    expect(taps, 1);
  });

  testWidgets('grows past the touch floor instead of clipping', (tester) async {
    await _pump(tester, collapsed: false, onToggle: () {});
    final normal = tester.getSize(find.byType(EntityListSectionHeader)).height;
    // On a touch target the 44 px floor swallows small scale bumps, so probe
    // well past it: Inter Tight's descenders clip inside a FIXED line box,
    // and this is what proves the height is a floor rather than a clamp.
    await _pump(tester, collapsed: false, onToggle: () {}, textScale: 3);
    final scaled = tester.getSize(find.byType(EntityListSectionHeader)).height;
    expect(scaled, greaterThan(normal));
  });

  testWidgets('the first group carries no top hairline', (tester) async {
    await _pump(tester, collapsed: false, onToggle: () {}, isFirst: true);
    final first = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null);
    expect(first, isEmpty);

    await _pump(tester, collapsed: false, onToggle: () {});
    final later = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null);
    expect(later, isNotEmpty);
  });
}
