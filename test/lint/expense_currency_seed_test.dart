import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seeding an expense's invoice currency from the picked client must also seed
/// the exchange rate.
///
/// Setting one without the other leaves the converted amount on whatever rate
/// the form already held, which is wrong the moment the client's currency
/// differs from the expense's. `RecurringExpenseEditIdentitySection` shipped
/// exactly that: its header says it "mirrors ExpenseEditIdentitySection" and it
/// had dropped the `crossCurrencyRate` half.
///
/// A source scan rather than a widget test because the section needs
/// `Services`, a live Drift stream and a router to pump, and a `pumpAndSettle`
/// over a real Drift watch times out (see the widget-test notes in
/// `docs/`). The invariant is textual and local, so scanning is enough.
void main() {
  test('every client picker that seeds invoiceCurrencyId also seeds the '
      'exchange rate', () {
    const files = [
      'lib/ui/features/expenses/widgets/edit/'
          'expense_edit_identity_section.dart',
      'lib/ui/features/recurring_expenses/widgets/edit/'
          'recurring_expense_edit_identity_section.dart',
    ];
    for (final path in files) {
      final src = File(path).readAsStringSync();
      if (!src.contains('setInvoiceCurrencyId(')) continue;
      expect(
        src.contains('crossCurrencyRate('),
        isTrue,
        reason:
            '$path seeds the invoice currency from the client but never the '
            'exchange rate, so the converted amount keeps a stale rate',
      );
      expect(
        src.contains('setExchangeRate('),
        isTrue,
        reason: '$path resolves a rate but never applies it',
      );
    }
  });
}
