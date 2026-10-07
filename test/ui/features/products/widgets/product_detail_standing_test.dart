import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/ui/features/products/widgets/detail/product_detail_standing.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';

/// The standing card's three reported problems, each about what a number
/// *means* — carried over from the KPI strip it replaced: Price / Cost read
/// as bare figures next to Quantity and Stock Quantity
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

Product _product({
  String price = '10',
  String cost = '4',
  num inStock = 0,
  num threshold = 0,
}) => Product.fromApi(
  ProductApi(
    id: 'p1',
    productKey: 'WIDGET',
    price: price,
    cost: cost,
    inStockQuantity: inStock,
    stockNotificationThreshold: threshold,
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required Product product,
  bool tracksInventory = false,
  int companyThreshold = 0,
  bool withFormatter = true,
  bool withCompany = true,
}) => pumpAt(
  tester,
  400,
  ProductDetailStanding(
    product: product,
    company: withCompany
        ? Company(
            id: 'co',
            trackInventory: tracksInventory,
            inventoryNotificationThreshold: companyThreshold,
          )
        : null,
    formatter: withFormatter ? _formatter : null,
  ),
);

void main() {
  testWidgets('price and cost carry the currency symbol', (tester) async {
    await _pump(tester, product: _product());

    expect(find.text(r'$10.00'), findsOneWidget);
    expect(find.text(r'$4.00'), findsOneWidget);
  });

  testWidgets('an unentered cost is not drawn at all — not as zero, not as a '
      'dash under the word', (tester) async {
    await _pump(tester, product: _product(cost: '0'));

    expect(find.text('COST'), findsNothing);
    expect(find.text('—'), findsNothing);
    expect(find.text(r'$0.00'), findsNothing);
  });

  testWidgets('a zero price is still a price', (tester) async {
    // Deliberately asymmetric with Cost: a free product is a real state.
    await _pump(tester, product: _product(price: '0'));

    expect(find.text('PRICE'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
  });

  testWidgets('stock is absent when inventory is not tracked', (tester) async {
    await _pump(tester, product: _product());

    expect(find.text('Stock quantity'), findsNothing);
    expect(find.text('Stock value'), findsNothing);
  });

  testWidgets('stock is shown when inventory is tracked, zero included', (
    tester,
  ) async {
    await _pump(tester, product: _product(), tracksInventory: true);

    expect(find.text('Stock quantity'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    // …and nothing in stock is out of stock.
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('a figure the product carries is never hidden', (tester) async {
    await _pump(tester, product: _product(inStock: 12));

    expect(find.text('Stock quantity'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    // Stock × price.
    expect(find.text('Stock value'), findsOneWidget);
    expect(find.text(r'$120.00'), findsOneWidget);
    // Nothing is watching it, so no call on whether it is enough.
    expect(find.text('Low stock'), findsNothing);
  });

  testWidgets('low stock is called against the product\'s own threshold, '
      'then the company\'s', (tester) async {
    // Its own threshold of five: three is low.
    await _pump(
      tester,
      product: _product(inStock: 3, threshold: 5),
      tracksInventory: true,
    );
    expect(find.text('Low stock'), findsOneWidget);

    // None of its own, the company's ten: still low.
    await _pump(
      tester,
      product: _product(inStock: 3),
      tracksInventory: true,
      companyThreshold: 10,
    );
    expect(find.text('Low stock'), findsOneWidget);

    // Neither: just the number.
    await _pump(tester, product: _product(inStock: 3), tracksInventory: true);
    expect(find.text('Low stock'), findsNothing);
    expect(find.text('Out of stock'), findsNothing);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a negative stock is shown, and is out of stock', (tester) async {
    // `!=`, never `>`: an anomalous negative is exactly the figure to see.
    await _pump(tester, product: _product(inStock: -2), tracksInventory: true);

    expect(find.text('-2'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);
  });

  testWidgets('until the formatter and the company arrive: blank money, no '
      'stock line, no bare numbers', (tester) async {
    await _pump(
      tester,
      product: _product(),
      withFormatter: false,
      withCompany: false,
    );

    expect(find.text('PRICE'), findsOneWidget);
    expect(find.textContaining('10'), findsNothing);
    expect(find.text('Stock quantity'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
