import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_standing.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';

/// What the recurring expense's standing card draws, and what it leaves out.

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
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

RecurringExpense _recurring(Map<String, dynamic> json) =>
    RecurringExpense.fromApi(
      RecurringExpenseApi.fromJson({
        'id': 'r1',
        'currency_id': '1',
        'amount': '54.99',
        ...json,
      }),
    );

Future<void> _pump(
  WidgetTester tester,
  RecurringExpense recurring, {
  bool withFormatter = true,
}) => pumpAt(
  tester,
  500,
  RecurringExpenseDetailStanding(
    recurringExpense: recurring,
    formatter: withFormatter ? _formatter : null,
  ),
);

void main() {
  testWidgets('a running schedule: the amount, the next run, and that it is '
      'running', (tester) async {
    await _pump(
      tester,
      _recurring({
        'status_id': '2',
        'next_send_date': '2026-11-01',
        'last_sent_date': '2026-10-01',
      }),
    );

    expect(find.text(r'$54.99'), findsOneWidget);
    expect(find.text('NEXT SEND DATE'), findsOneWidget);
    // In the company's date format, not the wire's.
    expect(find.text('1/Nov/2026'), findsOneWidget);
    expect(find.text('2026-11-01'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('no next date draws no caption for one', (tester) async {
    await _pump(tester, _recurring({'status_id': '1'}));

    expect(find.text('NEXT SEND DATE'), findsNothing);
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('—'), findsNothing);
  });

  testWidgets('endless is the default and is not announced; a count is', (
    tester,
  ) async {
    await _pump(tester, _recurring({'remaining_cycles': -1}));
    expect(find.text('Remaining Cycles'), findsNothing);

    await _pump(tester, _recurring({'remaining_cycles': 3}));
    expect(find.text('Remaining Cycles'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a schedule that has run out says so, and that it is done', (
    tester,
  ) async {
    await _pump(tester, _recurring({'status_id': '2', 'remaining_cycles': 0}));

    expect(find.text('Remaining Cycles'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('tax is drawn only when there is some', (tester) async {
    await _pump(tester, _recurring(const {}));
    expect(find.text('Tax'), findsNothing);

    await _pump(
      tester,
      _recurring({'amount': '100', 'tax_name1': 'VAT', 'tax_rate1': '20'}),
    );
    expect(find.text('Tax'), findsOneWidget);
    expect(find.text(r'$20.00'), findsOneWidget);
  });

  testWidgets('until the formatter arrives the figures are blank — never a '
      'raw date or a bare number', (tester) async {
    await _pump(
      tester,
      _recurring({'next_send_date': '2026-11-01'}),
      withFormatter: false,
    );

    expect(find.text('NEXT SEND DATE'), findsOneWidget);
    expect(find.text('2026-11-01'), findsNothing);
    expect(find.textContaining('54.99'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
