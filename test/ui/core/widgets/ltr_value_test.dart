import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/ltr_value.dart';

void main() {
  Text pumpText(WidgetTester tester) => tester.widget<Text>(find.byType(Text));

  Future<void> pump(WidgetTester tester, TextDirection dir, Widget child) =>
      tester.pumpWidget(Directionality(textDirection: dir, child: child));

  testWidgets('in RTL a value lays out LTR, aligned to the layout end', (
    tester,
  ) async {
    await pump(
      tester,
      TextDirection.rtl,
      const LtrText(r'-$1,234.50', textAlign: TextAlign.end),
    );
    final text = pumpText(tester);
    expect(text.textDirection, TextDirection.ltr);
    // End of a right-to-left row is its left edge.
    expect(text.textAlign, TextAlign.left);
  });

  testWidgets('in LTR it is a plain Text', (tester) async {
    await pump(
      tester,
      TextDirection.ltr,
      const LtrText(r'-$1,234.50', textAlign: TextAlign.end),
    );
    final text = pumpText(tester);
    expect(text.textDirection, isNull);
    expect(text.textAlign, TextAlign.end);
  });

  testWidgets('keepRtlScript leaves Arabic or Hebrew text in the layout '
      'direction and forces everything else LTR', (tester) async {
    await pump(
      tester,
      TextDirection.rtl,
      const LtrText('شركة النور', keepRtlScript: true),
    );
    expect(pumpText(tester).textDirection, isNull);

    await pump(
      tester,
      TextDirection.rtl,
      const LtrText('INV-0042', keepRtlScript: true),
    );
    expect(pumpText(tester).textDirection, TextDirection.ltr);
    expect(pumpText(tester).textAlign, TextAlign.right);
  });
}
