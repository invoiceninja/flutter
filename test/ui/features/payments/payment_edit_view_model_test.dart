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
}
