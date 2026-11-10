import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/feature_row.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget row) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      home: Scaffold(body: row),
    ),
  );

  testWidgets('a tappable row ends in a chevron by default', (tester) async {
    var taps = 0;
    await pump(
      tester,
      FeatureRow(icon: Icons.star, title: 'T', body: 'B', onTap: () => taps++),
    );
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('T'));
    expect(taps, 1);
  });

  testWidgets('a row with no tap has no trailing icon', (tester) async {
    await pump(
      tester,
      const FeatureRow(icon: Icons.star, title: 'T', body: 'B'),
    );
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
