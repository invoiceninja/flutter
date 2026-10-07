import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/address_block.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

import '../../../_responsive_helper.dart';

/// `AddressBlock` shows an address as a reader meets one, and copies it whole.
void main() {
  const lines = ['12 Main Street', '10115 Berlin', 'Germany'];

  testWidgets('prints the lines as one block with a map link', (tester) async {
    await pumpAt(
      tester,
      400,
      const Material(child: AddressBlock(lines: lines)),
    );
    expect(find.text(lines.join('\n')), findsOneWidget);
    expect(find.widgetWithText(LinkText, 'View Map'), findsOneWidget);
  });

  testWidgets('no lines builds nothing', (tester) async {
    await pumpAt(tester, 400, const Material(child: AddressBlock(lines: [])));
    expect(tester.getSize(find.byType(AddressBlock)).height, 0);
    expect(find.text('View Map'), findsNothing);
  });

  testWidgets('on touch the map link is underlined at rest', (tester) async {
    // `flutter test` reports android: there is no hover to reveal a link.
    await pumpAt(
      tester,
      400,
      const Material(child: AddressBlock(lines: lines)),
    );
    final link = tester.widget<LinkText>(find.byType(LinkText));
    expect(link.underlineAtRest, isTrue);
  });
}
