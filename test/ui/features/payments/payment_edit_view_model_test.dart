import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

class _FakePaymentsApi implements PaymentsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late PaymentRepository repo;
  const companyId = 'co_1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PaymentRepository(db: db, api: _FakePaymentsApi());
  });
  tearDown(() async {
    await db.close();
  });

  PaymentEditViewModel vmFor({
    Payment? existing,
    bool enableApplyingPayments = true,
  }) => PaymentEditViewModel(
    repo: repo,
    companyId: companyId,
    existing: existing,
    enableApplyingPayments: enableApplyingPayments,
  );

  Paymentable inv(String id, num amount) => Paymentable(
    invoiceId: id,
    amount: Decimal.parse(amount.toString()),
    refunded: Decimal.zero,
  );

  Paymentable cre(String id, num amount) => Paymentable(
    creditId: id,
    amount: Decimal.parse(amount.toString()),
    refunded: Decimal.zero,
  );

  group('PaymentEditViewModel — allocation totals', () {
    test('creditAllocatedTotal sums only credit-keyed paymentables', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 100), inv('i2', 50), cre('c1', 25)]);
      expect(vm.invoiceAllocatedTotal, Decimal.parse('150'));
      expect(vm.creditAllocatedTotal, Decimal.parse('25'));
      expect(vm.allocatedTotal, Decimal.parse('175'));
    });
  });

  group('PaymentEditViewModel — validateForSave', () {
    test('credit total > invoice total returns credit_payment_error', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 50), cre('c1', 100)]);
      expect(vm.validateForSave(), kPaymentValidationCreditExceedsInvoice);
    });

    test('enableApplyingPayments=false + empty allocations on create returns '
        'please_select_an_invoice_or_credit', () {
      final vm = vmFor(enableApplyingPayments: false);
      expect(vm.validateForSave(), kPaymentValidationMissingAllocations);
    });

    test('enableApplyingPayments=true allows save with zero allocations', () {
      final vm = vmFor(enableApplyingPayments: true);
      expect(vm.validateForSave(), isNull);
    });

    test('enableApplyingPayments=false + at least one allocation passes', () {
      final vm = vmFor(enableApplyingPayments: false);
      vm.replacePaymentables([inv('i1', 25)]);
      expect(vm.validateForSave(), isNull);
    });
  });

  group('PaymentEditViewModel — _amountDirty + auto-sync', () {
    test('replacePaymentables auto-syncs draft.amount while user has not '
        'touched the amount field', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 100), cre('c1', 30)]);
      expect(vm.draft.amount, Decimal.parse('70'));
    });

    test('setAmount flips _amountDirty so auto-sync stops', () {
      final vm = vmFor();
      vm.setAmount('250');
      expect(vm.isAmountDirty, true);
      vm.replacePaymentables([inv('i1', 100)]);
      expect(
        vm.draft.amount,
        Decimal.parse('250'),
        reason: 'manual amount must survive a paymentables update',
      );
    });

    test('clone-from with a nonzero amount initializes _amountDirty=true so '
        'the cloned amount survives the first paymentables update (B3)', () {
      final clone = (
        existing: null,
        cloneFrom: emptyPayment().copyWith(
          clientId: 'c_clone',
          amount: Decimal.parse('500'),
        ),
      );
      final vm = PaymentEditViewModel(
        repo: repo,
        companyId: companyId,
        cloneFrom: clone.cloneFrom,
      );
      expect(vm.isAmountDirty, true);
      vm.replacePaymentables([inv('i1', 100)]);
      expect(
        vm.draft.amount,
        Decimal.parse('500'),
        reason: 'cloned amount must not be auto-overwritten',
      );
    });
  });

  group('PaymentEditViewModel — setClientId + replaceClientAndClear', () {
    test('setClientId with the same value does not notify or mutate', () {
      final vm = vmFor();
      vm.setClientId('c_42');
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);
      vm.setClientId('c_42');
      expect(notifyCount, 0);
    });

    test('replaceClientAndClearPaymentables drops the allocations list', () {
      final vm = vmFor();
      vm.setClientId('c_1');
      vm.replacePaymentables([inv('i1', 100)]);
      expect(vm.draft.paymentables, hasLength(1));
      vm.replaceClientAndClearPaymentables('c_2');
      expect(vm.draft.clientId, 'c_2');
      expect(vm.draft.paymentables, isEmpty);
    });
  });

  group('PaymentEditViewModel — startFromInvoice', () {
    test('fills the client, its currency and the amount from no client', () {
      final vm = vmFor();
      vm.startFromInvoice(
        clientId: 'c_1',
        clientCurrencyId: '3',
        allocation: inv('i1', 120),
      );
      expect(vm.draft.clientId, 'c_1');
      expect(vm.draft.currencyId, '3');
      expect(vm.draft.paymentables.single.invoiceId, 'i1');
      expect(vm.draft.amount, Decimal.parse('120'));
    });

    test('a currency already chosen is kept', () {
      final vm = vmFor();
      vm.setCurrencyId('2');
      vm.startFromInvoice(
        clientId: 'c_1',
        clientCurrencyId: '3',
        allocation: inv('i1', 120),
      );
      expect(vm.draft.currencyId, '2');
    });

    test('the same client keeps its credits and replaces the invoice', () {
      final vm = vmFor();
      vm.setClientId('c_1');
      vm.replacePaymentables([inv('i1', 100), cre('cr1', 25)]);
      vm.startFromInvoice(
        clientId: 'c_1',
        clientCurrencyId: '',
        allocation: inv('i2', 60),
      );
      expect(
        vm.draft.paymentables
            .map((p) => p.invoiceId)
            .where((id) => id.isNotEmpty),
        ['i2'],
      );
      expect(
        vm.draft.paymentables.where((p) => p.creditId == 'cr1'),
        hasLength(1),
      );
      expect(vm.draft.amount, Decimal.parse('35'));
    });

    test('a different client drops the last client\'s allocations', () {
      final vm = vmFor();
      vm.setClientId('c_1');
      vm.replacePaymentables([inv('i1', 100), cre('cr1', 25)]);
      vm.startFromInvoice(
        clientId: 'c_2',
        clientCurrencyId: '',
        allocation: inv('i9', 40),
      );
      expect(vm.draft.clientId, 'c_2');
      expect(vm.draft.paymentables.single.invoiceId, 'i9');
      expect(vm.draft.amount, Decimal.parse('40'));
    });

    test('clearInvoiceAllocations keeps credits', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 100), cre('cr1', 25)]);
      vm.clearInvoiceAllocations();
      expect(vm.draft.paymentables.single.creditId, 'cr1');
    });
  });

  group('PaymentEditViewModel — performSave validation throw', () {
    test('save() returns null and surfaces translated message on '
        'ValidationException', () async {
      final vm = PaymentEditViewModel(
        repo: repo,
        companyId: companyId,
        enableApplyingPayments: false,
        translate: (key) => '[$key]',
      );
      final result = await vm.save();
      expect(result, isNull);
      expect(vm.submitError, '[please_select_an_invoice_or_credit]');
    });

    test(
      'translate fallback (identity) returns the raw key in submitError',
      () async {
        final vm = vmFor(enableApplyingPayments: false);
        final result = await vm.save();
        expect(result, isNull);
        expect(vm.submitError, 'please_select_an_invoice_or_credit');
      },
    );
  });

  // Regression: picking a SECOND invoice used to auto-fill 0.00, because the
  // edit layout handed `draft.amount` to the allocation section's headroom cap
  // and that value auto-syncs to the allocation total — so headroom was always
  // exactly zero after the first pick. `autoFillCap` is the seam that keeps the
  // two apart; the layout must read it instead of `draft.amount`.
  group('autoFillCap', () {
    test(
      'is zero while the amount auto-syncs, so nothing caps the next pick',
      () {
        final vm = vmFor();
        expect(vm.isAmountDirty, isFalse);
        expect(vm.autoFillCap, Decimal.zero);

        // Pick invoice #1 (balance 100) — the amount follows the allocation.
        vm.replacePaymentables([inv('i1', 100)]);
        expect(vm.draft.amount, Decimal.parse('100'));
        expect(vm.isAmountDirty, isFalse);

        // The bug: `draft.amount` is now 100 and the allocated total is also 100,
        // so a cap built from it leaves no headroom. `autoFillCap` stays zero.
        expect(vm.allocatedTotal, Decimal.parse('100'));
        expect(vm.autoFillCap, Decimal.zero);

        // With no cap the second invoice keeps its own balance, and the payment
        // grows to cover both.
        vm.replacePaymentables([inv('i1', 100), inv('i2', 50)]);
        expect(vm.draft.amount, Decimal.parse('150'));
      },
    );

    test('becomes the typed amount once the user fixes it', () {
      final vm = vmFor();
      vm.setAmount('120');
      expect(vm.isAmountDirty, isTrue);
      expect(vm.autoFillCap, Decimal.parse('120'));

      // A user-fixed amount must still cap: the allocations no longer drive it.
      vm.replacePaymentables([inv('i1', 100)]);
      expect(vm.draft.amount, Decimal.parse('120'));
      expect(vm.autoFillCap, Decimal.parse('120'));
    });

    test('an existing payment starts capped (amount is user-meaningful)', () {
      final vm = vmFor(
        existing: emptyPayment().copyWith(
          id: 'p1',
          amount: Decimal.parse('75'),
        ),
      );
      expect(vm.isAmountDirty, isTrue);
      expect(vm.autoFillCap, Decimal.parse('75'));
    });
  });

  // Beta report: pick a $1,250 invoice, type 625 as the amount, Save — the
  // invoice stayed allocated 1,250 and the server rejected the save with
  // "Amounts do not balance correctly".
  group('PaymentEditViewModel — invoice allocations follow the amount', () {
    Decimal d(String v) => Decimal.parse(v);
    List<String> amounts(PaymentEditViewModel vm) =>
        vm.draft.paymentables.map((p) => p.amount.toString()).toList();

    test('a partial amount on one invoice allocates that amount', () {
      final vm = vmFor();
      vm.startFromInvoice(
        clientId: 'c_1',
        clientCurrencyId: '1',
        allocation: inv('i1', 1250),
        openAmount: d('1250'),
      );
      vm.setAmount('625');
      expect(amounts(vm), ['625']);
      expect(vm.allocationRemainder, Decimal.zero);
      expect(vm.validateForSave(), isNull);
    });

    test('typing digit by digit grows back, capped at the open amount', () {
      final vm = vmFor();
      vm.startFromInvoice(
        clientId: 'c_1',
        clientCurrencyId: '1',
        allocation: inv('i1', 1250),
        openAmount: d('1250'),
      );
      for (final typed in ['6', '62', '625']) {
        vm.setAmount(typed);
      }
      expect(amounts(vm), ['625']);
      vm.setAmount('2000');
      // The excess stays unapplied — never an overpaid invoice.
      expect(amounts(vm), ['1250']);
      expect(vm.allocationRemainder, d('750'));
    });

    test('several invoices fill in order; credits pay invoices too', () {
      final vm = vmFor();
      vm.noteInvoiceOpenAmounts({'i1': d('100'), 'i2': d('200')});
      vm.replacePaymentables([inv('i1', 100), inv('i2', 200), cre('c1', 50)]);
      vm.setAmount('120');
      // 120 paid + 50 credit = 170 over the invoices.
      expect(amounts(vm), ['100', '70', '50']);
    });

    // Review: an emptied field parses to zero, which the server reads as
    // "derive the amount from the allocations" — and toApiJson drops
    // zero-amount rows, so zeroing them saved an unapplied $0 payment.
    test('an emptied, zero or negative amount leaves the allocations', () {
      final vm = vmFor();
      vm.startFromInvoice(
        clientId: 'c_1',
        clientCurrencyId: '1',
        allocation: inv('i1', 1250),
        openAmount: d('1250'),
      );
      for (final typed in ['', '0', '-', '-5']) {
        vm.setAmount(typed);
        expect(amounts(vm), ['1250'], reason: 'typed "$typed"');
      }
      vm.setAmount('');
      expect(vm.validateForSave(), isNull);
      vm.setAmount('625');
      expect(amounts(vm), ['625']);
    });

    test('a credit changed after the amount re-spreads the invoices', () {
      final vm = vmFor();
      vm.noteInvoiceOpenAmounts({'i1': d('100'), 'i2': d('200')});
      vm.replacePaymentables([inv('i1', 100), inv('i2', 200), cre('c1', 50)]);
      vm.setAmount('120');
      expect(amounts(vm), ['100', '70', '50']);
      vm.replacePaymentables([inv('i1', 100), inv('i2', 70), cre('c1', 20)]);
      expect(amounts(vm), ['100', '40', '20']);
      vm.replacePaymentables([inv('i1', 100), inv('i2', 40)]);
      expect(amounts(vm), ['100', '20']);
      expect(vm.validateForSave(), isNull);
    });

    test('a client change hands the lead back to the amount', () {
      final vm = vmFor();
      vm.noteInvoiceOpenAmounts({'i1': d('100'), 'i9': d('1250')});
      vm.replacePaymentables([inv('i1', 100)]);
      vm.replacePaymentables([inv('i1', 40)]); // typed
      vm.replaceClientAndClearPaymentables('c_2');
      vm.replacePaymentables([inv('i9', 1250)]);
      vm.setAmount('625');
      expect(amounts(vm), ['625']);
    });

    test('a discarded draft hands the lead back too', () {
      final vm = vmFor();
      vm.noteInvoiceOpenAmounts({'i1': d('100')});
      vm.replacePaymentables([inv('i1', 100)]);
      vm.replacePaymentables([inv('i1', 40)]); // typed
      vm.resetToEmpty();
      vm.replacePaymentables([inv('i1', 100)]);
      vm.setAmount('30');
      expect(amounts(vm), ['30']);
    });

    test('an allocation the user typed is left alone', () {
      final vm = vmFor();
      vm.noteInvoiceOpenAmounts({'i1': d('100'), 'i2': d('200')});
      vm.replacePaymentables([inv('i1', 100), inv('i2', 200)]);
      vm.replacePaymentables([inv('i1', 40), inv('i2', 200)]);
      vm.setAmount('100');
      expect(amounts(vm), ['40', '200']);
    });

    test('adding or removing an invoice is not a typed allocation', () {
      final vm = vmFor();
      vm.noteInvoiceOpenAmounts({'i1': d('100'), 'i2': d('200')});
      vm.replacePaymentables([inv('i1', 100)]);
      vm.replacePaymentables([inv('i1', 100), inv('i2', 200)]);
      vm.replacePaymentables([inv('i2', 200)]);
      vm.setAmount('150');
      expect(amounts(vm), ['150']);
    });

    test('an invoice with no known open amount turns the follow off', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 1250)]);
      vm.setAmount('625');
      expect(amounts(vm), ['1250']);
      expect(vm.validateForSave(), kPaymentValidationAmountsDoNotBalance);
    });

    test('an existing payment\'s allocations never follow', () {
      final vm = vmFor(
        existing: emptyPayment().copyWith(
          id: 'p1',
          amount: d('100'),
          paymentables: [inv('i1', 100)],
        ),
      );
      vm.noteInvoiceOpenAmounts({'i1': d('100')});
      vm.setAmount('50');
      expect(amounts(vm), ['100']);
    });
  });

  group('PaymentEditViewModel — validateForSave balance rule', () {
    test('invoices over amount + credits are refused before the server', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 100), cre('c1', 30)]);
      vm.setAmount('60');
      expect(vm.validateForSave(), kPaymentValidationAmountsDoNotBalance);
      vm.setAmount('70');
      expect(vm.validateForSave(), isNull);
    });

    test('compares at two decimals, as the server does', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 100)]);
      vm.setAmount('99.999');
      expect(vm.validateForSave(), isNull);
      vm.setAmount('99.99');
      expect(vm.validateForSave(), kPaymentValidationAmountsDoNotBalance);
    });

    test('a zero amount is derived by the server, so it passes', () {
      final vm = vmFor();
      vm.replacePaymentables([inv('i1', 100)]);
      vm.setAmount('0');
      expect(vm.validateForSave(), isNull);
    });
  });

  // Beta feedback: the converted amount was read-only, so a user holding the
  // bank's settled figure had to work the rate out by hand. React and v1 both
  // take the converted amount and set the rate from it.
  group('PaymentEditViewModel — setConvertedAmount', () {
    test('sets the rate that turns the amount into it', () {
      final vm = vmFor()..setAmount('300');
      vm.setConvertedAmount('265.50');
      expect(vm.draft.exchangeRate, Decimal.parse('0.885'));
      expect(vm.draft.amount, Decimal.parse('300'));
    });

    test('rounds the rate to the six places the server keeps', () {
      final vm = vmFor()..setAmount('3');
      vm.setConvertedAmount('1');
      expect(vm.draft.exchangeRate, Decimal.parse('0.333333'));
    });

    test('a comma locale reads a comma as the decimal point', () {
      final vm = PaymentEditViewModel(
        repo: repo,
        companyId: companyId,
        useCommaAsDecimalPlace: true,
      )..setAmount('200');
      vm.setConvertedAmount('250,50');
      expect(vm.draft.exchangeRate, Decimal.parse('1.2525'));
    });

    test('a blank or zero entry, or no amount, leaves the rate alone', () {
      final vm = vmFor()
        ..setAmount('100')
        ..setExchangeRate('1.5');
      vm.setConvertedAmount('');
      vm.setConvertedAmount('0');
      expect(vm.draft.exchangeRate, Decimal.parse('1.5'));

      final empty = vmFor()..setConvertedAmount('50');
      expect(empty.draft.exchangeRate, Decimal.one);
    });
  });
}
