import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/domain/expense_invoice_line_item.dart';

void main() {
  // Run the produced line item through the invoice totals calculator with the
  // matching invoice-level inclusive flag, and return the invoice total. This
  // is the end-to-end check that matters: the invoice total must land on the
  // expense's (converted) gross regardless of inclusive mode or currency.
  Decimal invoiceTotalFor(Expense expense, {required bool invoiceInclusive}) {
    final item = expenseInvoiceLineItem(
      expense,
      invoiceInclusive: invoiceInclusive,
    );
    return computeTotals(
      BillingTotalsInput(
        lineItems: [item],
        discount: Decimal.zero,
        isAmountDiscount: true,
        usesInclusiveTaxes: invoiceInclusive,
      ),
      2,
    ).total;
  }

  group('expenseInvoiceLineItem', () {
    test('exclusive-tax expense → bills net + tax = expense gross', () {
      final expense = Expense.fromApi(
        const ExpenseApi(amount: '100', taxName1: 'GST', taxRate1: '10'),
      );
      // `invoiceExpense` seeds the new invoice exclusive (= the expense mode).
      final item = expenseInvoiceLineItem(expense, invoiceInclusive: false);
      expect(item.cost, Decimal.fromInt(100)); // net == amount for exclusive
      expect(item.taxRate1, Decimal.fromInt(10));
      expect(item.taxName1, 'GST');
      expect(
        invoiceTotalFor(expense, invoiceInclusive: false),
        Decimal.fromInt(110),
      );
    });

    test('inclusive-tax expense → no over-bill (total == gross, not 110)', () {
      final expense = Expense.fromApi(
        const ExpenseApi(
          amount: '100',
          taxName1: 'GST',
          taxRate1: '10',
          usesInclusiveTaxes: true,
        ),
      );
      // `invoiceExpense` seeds the new invoice inclusive (= the expense mode).
      final item = expenseInvoiceLineItem(expense, invoiceInclusive: true);
      expect(item.cost, Decimal.fromInt(100)); // gross == amount for inclusive
      // Pre-fix this billed 110 (tax added on top of an already-inclusive 100).
      expect(
        invoiceTotalFor(expense, invoiceInclusive: true),
        Decimal.fromInt(100),
      );
    });

    test('foreign-currency expense → billed in the invoice currency', () {
      final expense = Expense.fromApi(
        const ExpenseApi(
          amount: '100',
          taxName1: 'GST',
          taxRate1: '10',
          invoiceCurrencyId: '2',
          exchangeRate: '1.2',
          foreignAmount: '120',
        ),
      );
      final item = expenseInvoiceLineItem(expense, invoiceInclusive: false);
      expect(item.cost, Decimal.fromInt(120)); // net(100) × fx(1.2)
      // Converted gross = 110 × 1.2 = 132.
      expect(
        invoiceTotalFor(expense, invoiceInclusive: false),
        Decimal.fromInt(132),
      );
    });

    // L1: a by-amount expense must carry its tax as a derived line rate so the
    // invoice keeps a per-tax-name breakdown — not fold it silently into cost.
    Map<String, Decimal> breakdownFor(
      Expense expense, {
      required bool invoiceInclusive,
    }) {
      final item = expenseInvoiceLineItem(
        expense,
        invoiceInclusive: invoiceInclusive,
      );
      return computeTotals(
        BillingTotalsInput(
          lineItems: [item],
          discount: Decimal.zero,
          isAmountDiscount: true,
          usesInclusiveTaxes: invoiceInclusive,
        ),
        2,
      ).taxBreakdown;
    }

    test(
      'by-amount tax (exclusive invoice) → derived rate + tax breakdown',
      () {
        final expense = Expense.fromApi(
          const ExpenseApi(
            amount: '100',
            taxName1: 'GST',
            taxAmount1: '8',
            calculateTaxByAmount: true,
          ),
        );
        final item = expenseInvoiceLineItem(expense, invoiceInclusive: false);
        expect(item.cost, Decimal.fromInt(100)); // net base, tax added on top
        expect(item.taxName1, 'GST');
        expect(item.taxRate1, Decimal.fromInt(8)); // 8 / 100 * 100
        expect(
          invoiceTotalFor(expense, invoiceInclusive: false),
          Decimal.fromInt(108),
        );
        // The tax is attributed to its name, not dropped.
        expect(
          breakdownFor(expense, invoiceInclusive: false)['GST'],
          Decimal.fromInt(8),
        );
      },
    );

    test(
      'by-amount tax (inclusive invoice) → total stays gross, tax extracted',
      () {
        final expense = Expense.fromApi(
          const ExpenseApi(
            amount: '100',
            taxName1: 'GST',
            taxAmount1: '8',
            calculateTaxByAmount: true,
          ),
        );
        final item = expenseInvoiceLineItem(expense, invoiceInclusive: true);
        expect(item.cost, Decimal.fromInt(108)); // gross base
        expect(item.taxName1, 'GST');
        expect(item.taxRate1, Decimal.fromInt(8));
        expect(
          invoiceTotalFor(expense, invoiceInclusive: true),
          Decimal.fromInt(108),
        );
        expect(
          breakdownFor(expense, invoiceInclusive: true)['GST'],
          Decimal.fromInt(8),
        );
      },
    );
  });

  // invoiceninja/ui#3382 — the bulk Invoice / Add to invoice selection rule.
  group('isBulkBillableExpense', () {
    Expense e({
      String id = 'e1',
      bool shouldBeInvoiced = true,
      String invoiceId = '',
      bool deleted = false,
    }) => Expense.fromApi(
      ExpenseApi(
        id: id,
        shouldBeInvoiced: shouldBeInvoiced,
        invoiceId: invoiceId,
        isDeleted: deleted,
      ),
    );

    test('marked to be invoiced and not yet invoiced', () {
      expect(isBulkBillableExpense(e()), isTrue);
    });

    test('not when it is not marked to be invoiced', () {
      expect(isBulkBillableExpense(e(shouldBeInvoiced: false)), isFalse);
    });

    test('not when already invoiced, deleted, or unsynced', () {
      expect(isBulkBillableExpense(e(invoiceId: 'inv1')), isFalse);
      expect(isBulkBillableExpense(e(deleted: true)), isFalse);
      expect(isBulkBillableExpense(e(id: 'tmp_1')), isFalse);
    });
  });

  group('bulkBillableSelection', () {
    Expense e(String id, {String clientId = 'c1', String invoiceId = ''}) =>
        Expense.fromApi(
          ExpenseApi(
            id: id,
            clientId: clientId,
            shouldBeInvoiced: true,
            invoiceId: invoiceId,
          ),
        );

    test('keeps the billable rows; the rest are what the toast reports', () {
      final s = bulkBillableSelection([e('a'), e('b', invoiceId: 'inv1')]);
      expect(s.billable.map((x) => x.id), ['a']);
      expect(s.multipleClients, isFalse);
    });

    test('an invoiced row of another client does not block the rest', () {
      final s = bulkBillableSelection([
        e('a'),
        e('b', clientId: 'c2', invoiceId: 'inv1'),
      ]);
      expect(s.multipleClients, isFalse);
      expect(s.billable.map((x) => x.id), ['a']);
    });

    test('two clients among the billable rows can not share an invoice', () {
      expect(
        bulkBillableSelection([e('a'), e('b', clientId: 'c2')]).multipleClients,
        isTrue,
      );
    });
  });
}
