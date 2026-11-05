// The phone line-item editor picks a line's taxes from the company's tax
// rates, as the desktop table's tax cells and the document's Taxes card do.
// It was the one surface left typing a saved rate by hand (beta feedback:
// "NYS Sales Tax 8.75%" was nowhere to be picked).

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_edit_dialog.dart';

import '../../../_localization_helper.dart';

TaxRate _rate(String id, String name, double rate) => TaxRate(
  id: id,
  name: name,
  rate: rate,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  archivedAt: null,
  isDeleted: false,
);

final _rates = [
  _rate('r2', 'County Tax', 4),
  _rate('r1', 'NYS Sales Tax', 8.75),
];

void main() {
  /// Opens the dialog and returns a getter for what it resolved with.
  Future<LineItem? Function()> open(
    WidgetTester tester, {
    LineItem? initial,
    Stream<List<TaxRate>>? taxRates,
  }) async {
    LineItem? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showLineItemEditDialog(
                  context,
                  initial: initial ?? emptyLineItem(),
                  config: const LineItemColumnConfig(taxColumnCount: 1),
                  taxRates: taxRates,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Finder picker() => find.byType(SearchableDropdownField<TaxRate>);

  testWidgets('a picked rate is saved on the line', (tester) async {
    final result = await open(tester, taxRates: Stream.value(_rates));
    expect(picker(), findsOneWidget);

    await tester.tap(picker());
    await tester.pumpAndSettle();
    await tester.tap(find.text('NYS Sales Tax (8.75%)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result()?.taxName1, 'NYS Sales Tax');
    expect(result()?.taxRate1, Decimal.parse('8.75'));
  });

  testWidgets('a line\'s stored tax shows and survives an untouched save', (
    tester,
  ) async {
    final result = await open(
      tester,
      initial: emptyLineItem().copyWith(
        taxName1: 'County Tax',
        taxRate1: Decimal.fromInt(4),
      ),
      taxRates: Stream.value(_rates),
    );
    expect(find.text('County Tax (4%)'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result()?.taxName1, 'County Tax');
    expect(result()?.taxRate1, Decimal.fromInt(4));
  });

  testWidgets('a company with no rates keeps the freeform pair', (
    tester,
  ) async {
    await open(tester, taxRates: Stream.value(const <TaxRate>[]));
    expect(picker(), findsNothing);
    expect(find.text('Tax Name 1'), findsOneWidget);
  });

  testWidgets('no stream keeps the freeform pair', (tester) async {
    await open(tester);
    expect(picker(), findsNothing);
    expect(find.text('Tax Name 1'), findsOneWidget);
  });
}
