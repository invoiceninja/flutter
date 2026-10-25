import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';

/// A text line is what the server prints as a row of text: it blanks the
/// money columns only when both quantity and cost are 0
/// (`MakesInvoiceValues::transformLineItems`).
void main() {
  test('a fresh text line is text-only, and a fresh line is not', () {
    expect(textLineItem().isTextOnly, isTrue);
    expect(textLineItem().quantity, Decimal.zero);
    expect(emptyLineItem().isTextOnly, isFalse, reason: 'quantity 1');
  });

  test('a product, a price or a quantity makes it a line item', () {
    final text = textLineItem().copyWith(notes: 'x');
    expect(text.isTextOnly, isTrue);
    expect(text.copyWith(productKey: 'SC2').isTextOnly, isFalse);
    expect(text.copyWith(cost: Decimal.one).isTextOnly, isFalse);
    expect(text.copyWith(quantity: Decimal.one).isTextOnly, isFalse);
  });

  test('a task or expense line is never one', () {
    final text = textLineItem().copyWith(notes: 'x');
    expect(text.copyWith(typeId: LineItemType.task).isTextOnly, isFalse);
    expect(text.copyWith(taskId: 't1').isTextOnly, isFalse);
    expect(text.copyWith(expenseId: 'e1').isTextOnly, isFalse);
  });
}
