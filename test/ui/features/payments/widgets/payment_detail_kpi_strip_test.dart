import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_kpi_strip.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_responsive_helper.dart';

/// Recording a payment against an invoice lands the user on this strip, and it
/// used to open with the word "Refunded" over an unconditional `$0.00` — read
/// as an alarm for the split second before the eye reached the value
/// (invoiceninja/flutter#113). The pair now appears only once a refund exists.
///
/// A real formatter, because a null one falls back to `Decimal.toString()` and
/// would quietly hollow out every assertion about a rendered amount.
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

Payment _payment({String refunded = '0'}) => Payment.fromApi(
  PaymentApi(
    id: 'p1',
    number: '0001',
    currencyId: '1',
    amount: '500',
    applied: '500',
    refunded: refunded,
    updatedAt: 1,
  ),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Payment payment, {
    double width = 500,
  }) => pumpAt(
    tester,
    width,
    PaymentDetailKpiStrip(payment: payment, formatter: _formatter),
  );

  group('the refund pair', () {
    testWidgets('is absent on a payment that has never been refunded', (
      tester,
    ) async {
      await pump(tester, _payment());

      // `_KpiCell` upper-cases every label.
      expect(find.text('REFUNDED'), findsNothing);
      expect(find.text('REFUNDABLE'), findsNothing);
      // ...and nothing else quietly took its place.
      expect(find.text(r'$0.00'), findsNothing);
    });

    testWidgets('leaves Amount and Applied behind', (tester) async {
      await pump(tester, _payment());

      expect(find.text('AMOUNT'), findsOneWidget);
      expect(find.text('APPLIED'), findsOneWidget);
      expect(find.text(r'$500.00'), findsNWidgets(2));
    });

    testWidgets('returns once a refund is recorded', (tester) async {
      await pump(tester, _payment(refunded: '100'));

      expect(find.text('REFUNDED'), findsOneWidget);
      expect(find.text('REFUNDABLE'), findsOneWidget);
      expect(find.text(r'$100.00'), findsOneWidget);
      // refundable = amount - refunded
      expect(find.text(r'$400.00'), findsOneWidget);
    });

    testWidgets('renders for a negative refunded figure too', (tester) async {
      // Pins `!= zero` rather than `> zero`: an anomalous negative is exactly
      // the number a user needs to see, not one to hide behind a tidy strip.
      await pump(tester, _payment(refunded: '-25'));

      expect(find.text('REFUNDED'), findsOneWidget);
      expect(find.text('REFUNDABLE'), findsOneWidget);
    });
  });

  group('layout survives the shorter cell list', () {
    // The grid used to hard-index `cells[0..3]`, so a two-cell strip threw a
    // RangeError below the 1100 px branch — which, thanks to the 820 px
    // `CenteredFormColumn` cap on the detail body, is the only branch that
    // ever renders in production.
    for (final width in <double>[500, 1200]) {
      for (final refunded in const <String>['0', '100']) {
        testWidgets('at ${width}px with refunded=$refunded', (tester) async {
          await pump(tester, _payment(refunded: refunded), width: width);

          expectNoOverflow(tester);
          expect(find.text('AMOUNT'), findsOneWidget);
        });
      }
    }
  });
}
