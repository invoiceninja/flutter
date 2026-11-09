// An optional quote line is one the client may choose to include when
// approving; until then it counts toward nothing — subtotal, taxes, discount
// or total. `BillingDocTotals.totalsInput` is the one place every total is
// built from, so the exclusion lives there.

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/domain/billing/billing_doc_totals.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';

LineItem _line(int cost, {bool optional = false}) => emptyLineItem().copyWith(
  notes: 'Line $cost',
  cost: Decimal.fromInt(cost),
  quantity: Decimal.one,
  taxName1: 'VAT',
  taxRate1: Decimal.fromInt(10),
  isOptional: optional,
);

void main() {
  test('an optional line adds nothing to subtotal, tax or total', () {
    final quote = emptyQuote().copyWith(
      lineItems: [_line(100), _line(50, optional: true)],
    );
    final totals = computeTotals(quote.totalsInput, 2);

    expect(totals.subtotal, Decimal.fromInt(100));
    expect(totals.taxAmount, Decimal.fromInt(10));
    expect(totals.total, Decimal.fromInt(110));
  });

  test('a percent discount applies to the lines that count', () {
    final quote = emptyQuote().copyWith(
      lineItems: [_line(200), _line(1000, optional: true)],
      discount: Decimal.fromInt(10),
      isAmountDiscount: false,
    );
    final totals = computeTotals(quote.totalsInput, 2);

    expect(totals.subtotal, Decimal.fromInt(200));
    // 200 less 10% is 180, and the line's VAT is taken on that discounted
    // base: 180 + 18. With the optional line counted it would be 1080 + 108.
    expect(totals.total, Decimal.fromInt(198));
  });

  test('ticking it off again counts it', () {
    final optional = _line(50, optional: true);
    final quote = emptyQuote().copyWith(
      lineItems: [_line(100), optional.copyWith(isOptional: false)],
    );
    expect(computeTotals(quote.totalsInput, 2).subtotal, Decimal.fromInt(150));
  });
}
