import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// How a receipt read fills a New Expense: only blank, untouched fields,
/// never a vendor guessed or created (`docs/receipt-ocr.md`).
void main() {
  final today = Date.today();
  final blank = emptyExpense();

  Currency currency(String id, String code, String rate) => Currency(
    id: id,
    name: code,
    code: code,
    symbol: '',
    precision: 2,
    thousandSeparator: ',',
    decimalSeparator: '.',
    swapCurrencySymbol: false,
    exchangeRate: Decimal.parse(rate),
  );

  final currencies = {
    '1': currency('1', 'USD', '1'),
    '3': currency('3', 'EUR', '0.9'),
  };

  ReceiptFillContext ctx({
    int tiers = 2,
    List<({String name, Decimal rate})> rates = const [],
  }) => ReceiptFillContext(
    enabledTaxTiers: tiers,
    taxRates: rates,
    currencies: currencies,
    receiptNote: (n) => 'Receipt #$n',
  );

  ReceiptRead read({
    String? total,
    ReceiptConfidence totalConfidence = ReceiptConfidence.sure,
    Date? date,
    List<ReceiptTax> taxes = const [],
    String? vendorName,
    String? vendorId,
    String? vendorCurrencyId,
    String? currencyCode,
    String? number,
  }) => ReceiptRead(
    scan: ReceiptScan(
      total: total == null
          ? null
          : ReceiptField(Decimal.parse(total), totalConfidence),
      date: date == null ? null : ReceiptField(date, ReceiptConfidence.sure),
      taxes: taxes,
      vendorName: vendorName,
      currencyCode: currencyCode,
      receiptNumber: number,
    ),
    vendorId: vendorId,
    vendorCurrencyId: vendorCurrencyId,
  );

  ReceiptFillResult fill(
    ReceiptRead r, {
    Expense? draft,
    Expense? baseline,
    bool prefilled = false,
    ReceiptFillContext? context,
    bool follows = false,
    bool userChoseInclusive = false,
    Set<ReceiptFillField> busy = const {},
  }) => fillExpenseFromReceipt(
    draft: draft ?? blank,
    baseline: baseline ?? blank,
    prefilled: prefilled,
    read: r,
    ctx: context ?? ctx(),
    paymentDateFollowsDate: follows,
    userChoseInclusive: userChoseInclusive,
    busy: busy,
  );

  test('a blank form takes the amount, date, vendor and its currency', () {
    final r = fill(
      read(
        total: '14.23',
        date: const Date(2026, 10, 14),
        vendorId: 'v1',
        vendorCurrencyId: '3',
      ),
    );
    expect(r.draft.amount, Decimal.parse('14.23'));
    expect(r.draft.date, const Date(2026, 10, 14));
    expect(r.draft.vendorId, 'v1');
    expect(r.draft.currencyId, '3');
    expect(r.filled.keys, {
      ReceiptFillField.amount,
      ReceiptFillField.date,
      ReceiptFillField.vendor,
      ReceiptFillField.currency,
    });
  });

  test('a value the user typed, or a staged draft brought, is never '
      'replaced', () {
    final typed = blank.copyWith(
      amount: Decimal.parse('9.99'),
      vendorId: 'mine',
      currencyId: '1',
    );
    final r = fill(
      read(total: '14.23', vendorId: 'v1', currencyCode: 'EUR'),
      draft: typed,
    );
    expect(r.draft.amount, Decimal.parse('9.99'));
    expect(r.draft.vendorId, 'mine');
    expect(r.draft.currencyId, '1');
    expect(r.filled, isEmpty);
  });

  test("a clone's or a prefilled draft's date is the user's, not a "
      'default', () {
    final clone = blank.copyWith(date: const Date(2026, 1, 5));
    final r = fill(
      read(date: const Date(2026, 10, 14)),
      draft: clone,
      baseline: clone,
      prefilled: true,
    );
    expect(r.draft.date, const Date(2026, 1, 5));
    expect(r.filled.containsKey(ReceiptFillField.date), isFalse);
  });

  test('a field the user is typing in is left alone', () {
    final r = fill(
      read(total: '14.23', date: const Date(2026, 10, 14)),
      busy: {ReceiptFillField.date},
    );
    expect(r.draft.date, today);
    expect(r.draft.amount, Decimal.parse('14.23'));
  });

  test('a Mark-paid payment date follows a read date, as it follows the '
      "user's", () {
    final paid = blank.copyWith(paymentDate: today);
    final r = fill(
      read(date: const Date(2026, 10, 14)),
      draft: paid,
      baseline: paid,
      follows: true,
    );
    expect(r.draft.paymentDate, const Date(2026, 10, 14));
  });

  test("the receipt's own currency wins over the vendor's, and an invoice "
      'currency already picked gets a fresh rate', () {
    final billed = blank.copyWith(invoiceCurrencyId: '1');
    final r = fill(
      read(
        total: '10.00',
        vendorId: 'v1',
        vendorCurrencyId: '1',
        currencyCode: 'EUR',
      ),
      draft: billed,
      baseline: billed,
    );
    expect(r.draft.currencyId, '3');
    // USD 1 / EUR 0.9.
    expect(r.draft.exchangeRate.toDouble(), closeTo(1 / 0.9, 1e-6));
    expect(r.draft.foreignAmount.toDouble(), closeTo(10 / 0.9, 1e-6));
  });

  group('taxes', () {
    final vat = ReceiptTax(
      name: 'VAT',
      rate: Decimal.parse('19'),
      amount: Decimal.parse('3.80'),
    );

    test('a company that turned expense tax off gets none', () {
      final r = fill(read(taxes: [vat]), context: ctx(tiers: 0));
      expect(r.draft.taxAmount1, Decimal.zero);
      expect(r.draft.taxName1, '');
    });

    test("one of the company's own rates stays By rate, under its name", () {
      final r = fill(
        read(taxes: [vat]),
        context: ctx(rates: [(name: 'MwSt', rate: Decimal.parse('19'))]),
      );
      expect(r.draft.calculateTaxByAmount, isFalse);
      expect(r.draft.taxName1, 'MwSt');
      expect(r.draft.taxRate1, Decimal.parse('19'));
      expect(r.draft.usesInclusiveTaxes, isTrue);
    });

    test('otherwise By amount, one tier per printed tax, the rest summed '
        'into the last', () {
      final r = fill(
        read(
          taxes: [
            vat,
            ReceiptTax(
              name: 'VAT',
              rate: Decimal.parse('7'),
              amount: Decimal.parse('0.70'),
            ),
            ReceiptTax(name: 'GST', amount: Decimal.parse('1.00')),
          ],
        ),
        context: ctx(tiers: 2),
      );
      expect(r.draft.calculateTaxByAmount, isTrue);
      expect(r.draft.taxName1, 'VAT 19%');
      expect(r.draft.taxAmount1, Decimal.parse('3.80'));
      expect(r.draft.taxName2, 'VAT 7% + GST');
      expect(r.draft.taxAmount2, Decimal.parse('1.70'));
      expect(
        r.filled.keys,
        containsAll([ReceiptFillField.tax1, ReceiptFillField.tax2]),
      );
    });

    test("a company rate the printed tax doesn't add up to goes By amount, "
        'as printed', () {
      // Untaxed groceries: the rate covers only some lines, so By rate
      // would tax the whole 14.23.
      final rates = [(name: 'NY Sales', rate: Decimal.parse('8.625'))];
      final partial = fill(
        read(
          total: '14.23',
          taxes: [
            ReceiptTax(
              name: 'TAX',
              rate: Decimal.parse('8.625'),
              amount: Decimal.parse('0.56'),
            ),
          ],
        ),
        context: ctx(rates: rates),
      );
      expect(partial.draft.calculateTaxByAmount, isTrue);
      expect(partial.draft.taxName1, 'NY Sales');
      expect(partial.draft.taxAmount1, Decimal.parse('0.56'));

      // 19% of a 23.80 gross is 3.80: the rate holds, By rate it is.
      final whole = fill(
        read(total: '23.80', taxes: [vat]),
        context: ctx(rates: [(name: 'MwSt', rate: Decimal.parse('19'))]),
      );
      expect(whole.draft.calculateTaxByAmount, isFalse);
      expect(whole.draft.taxRate1, Decimal.parse('19'));
    });

    test('a net amount the user typed keeps the taxes exclusive', () {
      final typed = blank.copyWith(amount: Decimal.parse('20'));
      final r = fill(
        read(total: '23.80', taxes: [vat]),
        draft: typed,
      );
      expect(r.draft.amount, Decimal.parse('20'));
      expect(r.draft.taxAmount1, Decimal.parse('3.80'));
      expect(r.draft.usesInclusiveTaxes, isFalse);
    });

    test('an exclusive-tax choice the user made is kept', () {
      final r = fill(read(taxes: [vat]), userChoseInclusive: true);
      expect(r.draft.usesInclusiveTaxes, isFalse);
    });

    test('a tax already entered is left alone', () {
      final taxed = blank.copyWith(taxName1: 'Mine');
      final r = fill(read(taxes: [vat]), draft: taxed);
      expect(r.draft.taxName1, 'Mine');
    });
  });

  test("the receipt's number goes to the private notes, once — never the "
      "expense's own Number", () {
    final noted = blank.copyWith(privateNotes: 'Lunch with Acme');
    final r = fill(read(number: '4471-22'), draft: noted);
    expect(r.draft.privateNotes, 'Lunch with Acme\nReceipt #4471-22');
    expect(r.draft.number, '');
    expect(r.draft.transactionReference, '');

    final again = fill(read(number: '4471-22'), draft: r.draft);
    expect(again.draft.privateNotes, r.draft.privateNotes);
  });

  test('private notes the user is typing in are left alone', () {
    final r = fill(read(number: '4471'), busy: {ReceiptFillField.notes});
    expect(r.draft.privateNotes, '');
    expect(r.filled, isNot(contains(ReceiptFillField.notes)));
  });

  test('a guessed total is filled, and marked to check', () {
    final r = fill(
      read(total: '22.50', totalConfidence: ReceiptConfidence.check),
    );
    expect(r.filled[ReceiptFillField.amount], ReceiptConfidence.check);
  });
}
