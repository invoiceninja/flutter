import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/ui/features/dashboard/helpers/converted_hint.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// flutter#22: the dashboard told a GBP-only company its untouched GBP totals
/// were "Converted to GBP". The caption may only appear when the company
/// genuinely trades in a second currency — i.e. when the server's `currencies`
/// map (which always carries the company currency) holds more than the base.
Currency _currency(String id, String code, String symbol) => Currency(
  id: id,
  name: code,
  code: code,
  symbol: symbol,
  precision: 2,
  thousandSeparator: ',',
  decimalSeparator: '.',
  swapCurrencySymbol: false,
  exchangeRate: Decimal.one,
);

/// Company base currency is GBP (`'2'`), matching the issue report.
Formatter _formatter({Map<String, Currency>? currencies}) => Formatter(
  settings: CompanyFormatSettings.fallback.copyWith(currencyId: '2'),
  currencies:
      currencies ??
      {'2': _currency('2', 'GBP', '£'), '3': _currency('3', 'EUR', '€')},
  countries: const {
    '840': Country(
      id: '840',
      name: 'United States',
      iso2: 'US',
      iso3: 'USA',
      swapCurrencySymbol: false,
      thousandSeparator: '',
      decimalSeparator: '',
      swapPostalCode: false,
    ),
  },
  dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
);

DashboardTotals _totals(Map<String, String> currencies) =>
    DashboardTotals.fromJson({'currencies': currencies});

/// Pumps a throwaway tree just to get a localized `BuildContext`, and returns
/// what `convertedToBaseCaption` produced.
Future<String?> _caption(
  WidgetTester tester, {
  required int selectedCurrencyId,
  required DashboardTotals? totals,
  Formatter? formatter,
}) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Builder(
        builder: (context) {
          result = convertedToBaseCaption(
            context,
            selectedCurrencyId: selectedCurrencyId,
            totals: totals,
            formatter: formatter ?? _formatter(),
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('single-currency company gets no caption (flutter#22)', (
    tester,
  ) async {
    expect(
      await _caption(
        tester,
        selectedCurrencyId: kDashboardCurrencyAll,
        totals: _totals(const {'2': 'GBP - British Pound'}),
      ),
      isNull,
    );
  });

  testWidgets('multi-currency company under "All currencies" is flagged', (
    tester,
  ) async {
    expect(
      await _caption(
        tester,
        selectedCurrencyId: kDashboardCurrencyAll,
        totals: _totals(const {'2': 'GBP - British Pound', '3': 'EUR - Euro'}),
      ),
      // Also guards the `:currency` interpolation and the `_app_pending.json`
      // key that carries this string.
      'Converted to GBP',
    );
  });

  testWidgets('a specific currency renders native amounts — no caption', (
    tester,
  ) async {
    expect(
      await _caption(
        tester,
        selectedCurrencyId: 3,
        totals: _totals(const {'2': 'GBP - British Pound', '3': 'EUR - Euro'}),
      ),
      isNull,
    );
  });

  testWidgets('no caption while totals are still loading', (tester) async {
    expect(
      await _caption(
        tester,
        selectedCurrencyId: kDashboardCurrencyAll,
        totals: null,
      ),
      isNull,
    );
  });

  testWidgets('no caption when the base currency code cannot be resolved', (
    tester,
  ) async {
    expect(
      await _caption(
        tester,
        selectedCurrencyId: kDashboardCurrencyAll,
        totals: _totals(const {'2': 'GBP - British Pound', '3': 'EUR - Euro'}),
        formatter: _formatter(currencies: {'3': _currency('3', 'EUR', '€')}),
      ),
      isNull,
    );
  });
}
