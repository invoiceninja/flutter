import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_standing.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';

/// What the expense's standing card draws, and — as much the point — what it
/// leaves out. Each case is a figure that used to be a dashed cell.

Currency _currency(String id, String symbol) => Currency(
  id: id,
  name: id,
  code: id,
  symbol: symbol,
  precision: 2,
  thousandSeparator: ',',
  decimalSeparator: '.',
  swapCurrencySymbol: false,
  exchangeRate: Decimal.one,
);

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
  currencies: {'1': _currency('1', r'$'), '3': _currency('3', '€')},
  countries: const {},
  dateFormats: const {},
);

Expense _expense(Map<String, dynamic> json) => Expense.fromApi(
  ExpenseApi.fromJson({'id': 'e1', 'currency_id': '1', ...json}),
);

Future<void> _pump(
  WidgetTester tester,
  Expense expense, {
  Formatter? formatter,
  bool withFormatter = true,
}) => pumpAt(
  tester,
  500,
  ExpenseDetailStanding(
    expense: expense,
    formatter: withFormatter ? (formatter ?? _formatter) : null,
  ),
);

void main() {
  testWidgets('no tax: the amount and the status, and nothing labelled '
      'nothing', (tester) async {
    await _pump(tester, _expense({'amount': '42.50'}));

    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.text(r'$42.50'), findsOneWidget);
    expect(find.text('Logged'), findsOneWidget);
    expect(find.text('GROSS AMOUNT'), findsNothing);
    expect(find.text('NET AMOUNT'), findsNothing);
    expect(find.text('Tax'), findsNothing);
    expect(find.text('Converted Amount'), findsNothing);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('a zero amount is still the amount', (tester) async {
    await _pump(tester, _expense({'amount': '0'}));

    expect(find.text(r'$0.00'), findsOneWidget);
  });

  testWidgets('tax on top: the gross beside the amount, and the tax', (
    tester,
  ) async {
    await _pump(
      tester,
      _expense({'amount': '100', 'tax_name1': 'VAT', 'tax_rate1': '20'}),
    );

    expect(find.text(r'$100.00'), findsOneWidget);
    expect(find.text('GROSS AMOUNT'), findsOneWidget);
    expect(find.text(r'$120.00'), findsOneWidget);
    expect(find.text('Tax'), findsOneWidget);
    expect(find.text(r'$20.00'), findsOneWidget);
    expect(find.text('NET AMOUNT'), findsNothing);
  });

  testWidgets('tax included: the net beside the amount instead', (
    tester,
  ) async {
    await _pump(
      tester,
      _expense({
        'amount': '120',
        'tax_name1': 'VAT',
        'tax_rate1': '20',
        'uses_inclusive_taxes': true,
      }),
    );

    expect(find.text(r'$120.00'), findsOneWidget);
    expect(find.text('NET AMOUNT'), findsOneWidget);
    expect(find.text(r'$100.00'), findsOneWidget);
    expect(find.text(r'$20.00'), findsOneWidget);
    expect(find.text('GROSS AMOUNT'), findsNothing);
  });

  testWidgets('a converted amount is in the currency it will be invoiced in', (
    tester,
  ) async {
    await _pump(
      tester,
      _expense({
        'amount': '100',
        'invoice_currency_id': '3',
        'exchange_rate': '0.5',
      }),
    );

    expect(find.text('Converted Amount'), findsOneWidget);
    expect(find.text('€50.00'), findsOneWidget);
  });

  testWidgets('an invoice currency at a rate of one converts nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      _expense({
        'amount': '100',
        'invoice_currency_id': '3',
        'exchange_rate': '1',
      }),
    );

    expect(find.text('Converted Amount'), findsNothing);
  });

  testWidgets('the status is the list\'s own word for it', (tester) async {
    await _pump(tester, _expense({'amount': '10', 'should_be_invoiced': true}));
    expect(find.text('Pending'), findsOneWidget);

    await _pump(tester, _expense({'amount': '10', 'invoice_id': 'i1'}));
    expect(find.text('Invoiced'), findsOneWidget);

    await _pump(
      tester,
      _expense({'amount': '10', 'payment_date': '2026-10-05'}),
    );
    expect(find.text('Paid'), findsOneWidget);
  });

  testWidgets('until the formatter arrives the figure is blank — never a '
      'bare number with no currency', (tester) async {
    await _pump(tester, _expense({'amount': '42.50'}), withFormatter: false);

    expect(find.text('AMOUNT'), findsOneWidget);
    expect(find.textContaining('42.5'), findsNothing);
    // The status does not wait for it.
    expect(find.text('Logged'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
