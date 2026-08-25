import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/domain/columns/product_columns.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/utils/formatting.dart';

import '../../_localization_helper.dart';

/// The Description column is the surface invoiceninja/flutter#93 reported, and
/// the only place the `FormatterScope` → `expandDatePlaceholders` wiring is
/// exercised end to end. The regression it guards: the column used to pass
/// `settings.locale` straight into `DateFormat`, and that field is `''` for
/// `CompanyFormatSettings.fallback` and for any unrecognised `language_id` —
/// which threw `Invalid locale ""` on precisely the rows carrying a keyword.
void main() {
  setUpAll(initializeDateFormatting);

  Product product(String notes) => Product(
    id: 'p1',
    productKey: 'HOSTING',
    notes: notes,
    cost: Decimal.zero,
    price: Decimal.zero,
    quantity: Decimal.zero,
    maxQuantity: Decimal.zero,
    productImage: '',
    inStockQuantity: Decimal.zero,
    stockNotification: false,
    stockNotificationThreshold: Decimal.zero,
    taxName1: '',
    taxRate1: Decimal.zero,
    taxName2: '',
    taxRate2: Decimal.zero,
    taxName3: '',
    taxRate3: Decimal.zero,
    taxId: '',
    customValue1: '',
    customValue2: '',
    customValue3: '',
    customValue4: '',
    updatedAt: DateTime.utc(2026, 8, 15, 12),
    createdAt: DateTime.utc(2026, 8, 15, 12),
    archivedAt: null,
    isDeleted: false,
  );

  final column = kAllProductColumns.firstWhere(
    (c) => c.labelKey == 'description',
  );

  Future<void> pumpCell(
    WidgetTester tester,
    Product p, {
    Formatter? formatter,
  }) async {
    Widget cell(BuildContext context) => column.cellBuilder(p, context);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => formatter == null
                ? cell(context)
                : FormatterScope(
                    formatter: formatter,
                    child: Builder(builder: cell),
                  ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Formatter fallbackFormatter() => Formatter(
    settings: CompanyFormatSettings.fallback,
    currencies: const {},
    countries: const {},
    dateFormats: const {},
  );

  testWidgets('renders the dates a reserved keyword becomes', (tester) async {
    await pumpCell(
      tester,
      product('Hosting [MONTHYEAR|MONTHYEAR+12]'),
      formatter: fallbackFormatter(),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Hosting '), findsOneWidget);
    expect(find.textContaining('[MONTHYEAR'), findsNothing);
    expect(find.textContaining(' to '), findsOneWidget);
  });

  testWidgets('the empty-locale fallback formatter does not throw', (
    tester,
  ) async {
    // `CompanyFormatSettings.fallback.locale` is `''` — the shipped code fed
    // that straight to `DateFormat` and threw.
    expect(CompanyFormatSettings.fallback.locale, '');

    await pumpCell(
      tester,
      product(':MONTH_AFTER retainer'),
      formatter: fallbackFormatter(),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining(':MONTH_AFTER'), findsNothing);
    expect(find.textContaining('retainer'), findsOneWidget);
  });

  testWidgets('renders with no FormatterScope in the tree', (tester) async {
    await pumpCell(tester, product('Hosting [MONTHYEAR|MONTHYEAR+12]'));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('[MONTHYEAR'), findsNothing);
  });

  testWidgets('valueBuilder keeps the raw token for sort / copy / export', (
    tester,
  ) async {
    const raw = 'Hosting [MONTHYEAR|MONTHYEAR+12]';
    expect(column.valueBuilder!(product(raw)), raw);
  });

  testWidgets('a description with no keyword is untouched', (tester) async {
    await pumpCell(
      tester,
      product('Annual hosting plan'),
      formatter: fallbackFormatter(),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Annual hosting plan'), findsOneWidget);
  });
}
