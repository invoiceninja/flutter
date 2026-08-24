import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/ui/features/products/widgets/detail/product_detail_kpi_strip.dart';
import 'package:admin/utils/formatting.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../_localization_helper.dart';

/// The strip's three reported problems, all about what a number *means*:
/// Price / Cost read as bare figures next to Quantity and Stock Quantity
/// (invoiceninja/flutter#90), an unentered Cost claimed the product costs
/// nothing (#92), and Stock Quantity sat there dashed on companies that don't
/// track inventory at all (#91).
final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'X',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
  currencies: {
    '1': Currency(
      id: '1',
      name: 'US Dollar',
      code: 'USD',
      symbol: r'$',
      precision: 2,
      thousandSeparator: ',',
      decimalSeparator: '.',
      swapCurrencySymbol: false,
      exchangeRate: Decimal.one,
    ),
  },
  countries: const {},
  dateFormats: const {},
);

class _FakeCompanyRepo implements CompanyRepository {
  _FakeCompanyRepo(this.company);
  final Company company;

  @override
  Stream<Company?> watchCompany(String companyId) => Stream.value(company);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.company);
  @override
  final CompanyRepository company;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Product product,
    required bool tracksInventory,
  }) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          _FakeCompanyRepo(Company(id: 'co', trackInventory: tracksInventory)),
        ),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: ProductDetailKpiStrip(
                product: product,
                companyId: 'co',
                formatter: _formatter,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Product product({String price = '10', String cost = '4', num inStock = 0}) =>
      Product.fromApi(
        ProductApi(
          id: 'p1',
          productKey: 'WIDGET',
          price: price,
          cost: cost,
          inStockQuantity: inStock,
        ),
      );

  testWidgets('price and cost carry the currency symbol', (tester) async {
    await pump(tester, product: product(), tracksInventory: false);

    expect(find.text(r'$10.00'), findsOneWidget);
    expect(find.text(r'$4.00'), findsOneWidget);
  });

  testWidgets('an unentered cost reads as blank, not as zero', (tester) async {
    await pump(tester, product: product(cost: '0'), tracksInventory: false);

    expect(find.text('—'), findsOneWidget);
    expect(find.text(r'$0.00'), findsNothing);
  });

  testWidgets('a zero price is still a price', (tester) async {
    // Deliberately asymmetric with Cost: a free product is a real state.
    await pump(tester, product: product(price: '0'), tracksInventory: false);

    expect(find.text(r'$0.00'), findsOneWidget);
  });

  testWidgets('stock quantity is absent when inventory is not tracked', (
    tester,
  ) async {
    await pump(tester, product: product(), tracksInventory: false);

    expect(find.text('STOCK QUANTITY'), findsNothing);
  });

  testWidgets('stock quantity appears when inventory is tracked', (
    tester,
  ) async {
    await pump(tester, product: product(inStock: 7), tracksInventory: true);

    expect(find.text('STOCK QUANTITY'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('an untracked product that still holds stock keeps the cell', (
    tester,
  ) async {
    // Never hide a figure the product actually has, whatever the company flag.
    await pump(tester, product: product(inStock: 3), tracksInventory: false);

    expect(find.text('STOCK QUANTITY'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
