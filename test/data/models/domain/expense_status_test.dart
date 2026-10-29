import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/domain/expense_status.dart';

Expense _expense({
  String paymentDate = '',
  String paymentTypeId = '',
  String transactionReference = '',
  String invoiceId = '',
  bool shouldBeInvoiced = false,
}) => Expense.fromApi(
  ExpenseApi(
    id: '1',
    paymentDate: paymentDate,
    paymentTypeId: paymentTypeId,
    transactionReference: transactionReference,
    invoiceId: invoiceId,
    shouldBeInvoiced: shouldBeInvoiced,
  ),
);

void main() {
  group('Expense.calculatedStatusId', () {
    test('no payment field is Logged', () {
      expect(_expense().calculatedStatusId, kExpenseStatusLogged);
    });

    test('a payment type alone is Paid — a recurring expense copy carries '
        'payment_type_id but no payment_date', () {
      final e = _expense(paymentTypeId: '1');
      expect(e.calculatedStatusId, kExpenseStatusPaid);
      // The list filter stays on the server's definition of paid.
      expect(e.isPaid, isFalse);
    });

    test('a payment date or a transaction reference is Paid', () {
      expect(
        _expense(paymentDate: '2026-10-01').calculatedStatusId,
        kExpenseStatusPaid,
      );
      expect(
        _expense(transactionReference: 'abc').calculatedStatusId,
        kExpenseStatusPaid,
      );
    });

    test('Invoiced and Pending still win over a payment type', () {
      expect(
        _expense(paymentTypeId: '1', invoiceId: 'x').calculatedStatusId,
        kExpenseStatusInvoiced,
      );
      expect(
        _expense(paymentTypeId: '1', shouldBeInvoiced: true).calculatedStatusId,
        kExpenseStatusPending,
      );
    });
  });
}
