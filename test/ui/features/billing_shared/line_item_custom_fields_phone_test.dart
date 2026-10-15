import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_custom_fields.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_card_list_mobile.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/utils/formatting.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// A customer on iOS: "custom fields of products are not recognized or
/// displayed in offers and invoices". The values were on the line — the
/// picker copies a product's custom values — but the phone card never showed
/// them and the edit dialog's four fields were gated on flags nothing set.
class _FakeServices implements Services {
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

const _definitions = {
  'product1': 'Color|Red,Blue',
  'product2': 'Warranty|switch',
  'product3': 'Serial|single_line_text',
  // product4 unconfigured — a value there must survive an edit untouched.
};

void main() {
  late List<LineItem> items;

  var config = LineItemColumnConfig(
    taxColumnCount: 0,
    customFields: lineItemCustomFields(_definitions, task: false),
  );

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: _FakeServices(),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: LineItemCardListMobile(
                  companyId: 'co',
                  items: items,
                  onChanged: (next) => setState(() => items = next),
                  newItemFactory: emptyLineItem,
                  config: config,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    config = LineItemColumnConfig(
      taxColumnCount: 0,
      customFields: lineItemCustomFields(_definitions, task: false),
    );
    items = [
      emptyLineItem().copyWith(
        productKey: 'Widget',
        cost: Decimal.fromInt(20),
        customValue1: 'Red',
        customValue2: 'yes',
        customValue4: 'keep me',
      ),
    ];
  });

  testWidgets('the card names the values under the item, labelled', (
    tester,
  ) async {
    await pump(tester);

    final summary = find.text('Color: Red · Warranty: Yes');
    expect(summary, findsOneWidget);
    // Above `cost × qty`: the values describe the item, the line below the
    // charge.
    expect(
      tester.getTopLeft(summary).dy,
      lessThan(tester.getTopLeft(find.textContaining(' × ')).dy),
    );
    // product4 has no definition, so its value is not shown.
    expect(find.textContaining('keep me'), findsNothing);
  });

  testWidgets('the dialog edits them by type, after Cost / Quantity', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Widget'));
    await tester.pumpAndSettle();

    // The company's labels, not "Custom Value 1".
    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Warranty'), findsOneWidget);
    expect(find.text('Serial'), findsOneWidget);
    expect(find.textContaining('Custom Value'), findsNothing);
    // Below Quantity, so a phone with the keyboard up keeps Quantity in view.
    expect(
      tester.getTopLeft(find.text('Quantity')).dy,
      lessThan(tester.getTopLeft(find.text('Color')).dy),
    );
    // Editing an existing line does not raise the keyboard over it.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Product'))
          .autofocus,
      isFalse,
    );

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    final serial = find.widgetWithText(TextField, 'Serial');
    await tester.ensureVisible(serial);
    await tester.enterText(serial, 'SN-1');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = items.single;
    expect(saved.customValue1, 'Red');
    expect(saved.customValue2, 'no');
    expect(saved.customValue3, 'SN-1');
    expect(
      saved.customValue4,
      'keep me',
      reason: 'a slot the company has no field for keeps its value',
    );
  });

  testWidgets('a dropdown pick and a typed date both reach the line', (
    tester,
  ) async {
    config = LineItemColumnConfig(
      taxColumnCount: 0,
      customFields: lineItemCustomFields(const {
        'product1': 'Color|Red,Blue',
        'product2': 'Shipped|date',
      }, task: false),
    );
    items = [emptyLineItem().copyWith(productKey: 'Widget')];
    await pump(tester);
    await tester.tap(find.text('Widget'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextField, 'Color'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blue').last);
    await tester.pumpAndSettle();

    // A date commits on blur, and on iOS / Android a tap on Save does not
    // blur a text field — the default test platform is Android, so this tap
    // is a touch that leaves the date field focused, as on a phone.
    final shipped = find.widgetWithText(TextField, 'Shipped');
    await tester.ensureVisible(shipped);
    await tester.enterText(shipped, '2026-05-14');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(items.single.customValue1, 'Blue');
    expect(items.single.customValue2, '2026-05-14');
  });

  testWidgets('Add Line starts at the Product field', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Line'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Product'))
          .autofocus,
      isTrue,
    );
  });
}
