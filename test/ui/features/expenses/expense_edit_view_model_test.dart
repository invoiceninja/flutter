import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// First dedicated coverage for `ExpenseEditViewModel` — expenses were one of
/// three feature areas with no `test/ui/features/<name>/` directory, and the VM
/// appeared only incidentally in the shared locale-parse sweep.
///
/// The interesting logic is the **three-way currency conversion** between
/// `amount`, `exchangeRate` and `foreignAmount` (React `AdditionalInfo`
/// parity): editing the amount or the rate recomputes the foreign amount, but
/// editing the foreign amount back-computes the rate instead. Getting the
/// direction wrong silently books an expense at the wrong converted value.
///
/// Comma-decimal parsing is threaded through `useCommaAsDecimalPlace` per the
/// project-wide convention.
class _FakeExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late ExpenseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
  });
  tearDown(() async => db.close());

  ExpenseEditViewModel createVm({bool commaDecimal = false}) =>
      ExpenseEditViewModel(
        repo: repo,
        companyId: 'co',
        useCommaAsDecimalPlace: commaDecimal,
      );

  ExpenseEditViewModel editVm(Expense existing) =>
      ExpenseEditViewModel(repo: repo, companyId: 'co', existing: existing);

  Future<int> pendingOutboxCount() async {
    final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);
    return rows.length;
  }

  group('save', () {
    test('a create enqueues exactly one outbox row', () async {
      final vm = createVm()
        ..setVendorId('v1')
        ..setAmount('50');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });

    test('an edit of an existing expense enqueues an update', () async {
      final existing = Expense.fromApi(
        const ExpenseApi(id: 'e1', vendorId: 'v1', updatedAt: 1700000000),
      );
      final vm = editVm(existing)..setAmount('75');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });
  });

  group('amount parsing', () {
    test('a dot-decimal amount', () {
      final vm = createVm()..setAmount('12.34');

      expect(vm.draft.amount, Decimal.parse('12.34'));
    });

    test('a comma-decimal amount when the locale uses commas', () {
      final vm = createVm(commaDecimal: true)..setAmount('12,34');

      expect(vm.draft.amount, Decimal.parse('12.34'));
    });

    test('unparseable input falls back to zero rather than throwing', () {
      final vm = createVm()..setAmount('not a number');

      expect(vm.draft.amount, Decimal.zero);
    });
  });

  group('currency conversion', () {
    test('setting an invoice currency recomputes the foreign amount from the '
        'current rate', () {
      final vm = createVm()
        ..setAmount('100')
        ..setExchangeRate('2')
        ..setInvoiceCurrencyId('2');

      expect(vm.draft.foreignAmount, Decimal.parse('200'));
    });

    test('clearing the invoice currency resets rate to 1 and foreign to 0', () {
      final vm = createVm()
        ..setAmount('100')
        ..setInvoiceCurrencyId('2')
        ..setExchangeRate('2');
      expect(vm.draft.foreignAmount, Decimal.parse('200'));

      vm.setInvoiceCurrencyId('');

      expect(vm.draft.invoiceCurrencyId, isEmpty);
      expect(vm.draft.exchangeRate, Decimal.one);
      expect(vm.draft.foreignAmount, Decimal.zero);
    });

    test('editing the amount keeps the foreign amount in step', () {
      final vm = createVm()
        ..setInvoiceCurrencyId('2')
        ..setExchangeRate('1.5')
        ..setAmount('200');

      expect(vm.draft.foreignAmount, Decimal.parse('300'));
    });

    test(
      'the foreign amount is left alone when no invoice currency is set',
      () {
        // Seed a non-zero foreign amount first, otherwise "left alone" and
        // "recomputed to zero" are indistinguishable — the field's default is
        // already zero.
        final vm = createVm()
          ..setInvoiceCurrencyId('2')
          ..setAmount('50')
          ..setExchangeRate('3');
        expect(vm.draft.foreignAmount, Decimal.parse('150'));

        // Clearing the currency resets it; from there, editing amount/rate
        // must NOT start recomputing again.
        vm.setInvoiceCurrencyId('');
        vm
          ..setExchangeRate('2')
          ..setAmount('100');

        expect(vm.draft.foreignAmount, Decimal.zero);
      },
    );

    test('editing the foreign amount back-computes the rate (the opposite '
        'direction)', () {
      final vm = createVm()
        ..setAmount('100')
        ..setInvoiceCurrencyId('2')
        ..setForeignAmount('250');

      expect(vm.draft.exchangeRate, Decimal.parse('2.5'));
      expect(vm.draft.foreignAmount, Decimal.parse('250'));
    });

    test('a back-computed rate that does not terminate is capped at 10 dp', () {
      final vm = createVm()
        ..setAmount('3')
        ..setInvoiceCurrencyId('2')
        ..setForeignAmount('1');

      expect(vm.draft.exchangeRate, Decimal.parse('0.3333333333'));
    });

    test('a zero amount leaves the rate untouched (no division by zero)', () {
      final vm = createVm()
        ..setExchangeRate('2')
        ..setForeignAmount('50');

      expect(vm.draft.exchangeRate, Decimal.parse('2'));
    });

    test('a zero exchange rate falls back to 1', () {
      // parseDecimal(zeroIsNull: true) → null → the `?? Decimal.one` default,
      // so a cleared rate field can never zero out the conversion.
      final vm = createVm()..setExchangeRate('0');

      expect(vm.draft.exchangeRate, Decimal.one);
    });

    test('comma-decimal rates parse too', () {
      final vm = createVm(commaDecimal: true)
        ..setAmount('100')
        ..setInvoiceCurrencyId('2')
        ..setExchangeRate('1,5');

      expect(vm.draft.exchangeRate, Decimal.parse('1.5'));
      expect(vm.draft.foreignAmount, Decimal.parse('150'));
    });
  });

  group('draftIsNonEmpty drives the discard prompt', () {
    test('a fresh create is empty', () {
      expect(createVm().draftIsNonEmpty(), isFalse);
    });

    test('a non-zero amount marks it dirty', () {
      expect((createVm()..setAmount('1')).draftIsNonEmpty(), isTrue);
    });

    test('a picked vendor marks it dirty', () {
      expect((createVm()..setVendorId('v1')).draftIsNonEmpty(), isTrue);
    });

    test('an amount typed then cleared reads as empty again', () {
      final vm = createVm()..setAmount('10');
      expect(vm.draftIsNonEmpty(), isTrue);

      vm.setAmount('');

      expect(vm.draftIsNonEmpty(), isFalse);
    });

    // The hand-kept field list this replaced had none of these three, so a
    // new expense holding only them left without the Discard prompt.
    test('a typed number, a picked assignee or a changed date marks it '
        'dirty', () {
      expect((createVm()..setNumber('EXP-9')).draftIsNonEmpty(), isTrue);
      expect((createVm()..setAssignedUserId('u1')).draftIsNonEmpty(), isTrue);
      expect(
        (createVm()..setDate(Date(2020, 3, 14))).draftIsNonEmpty(),
        isTrue,
      );
    });

    test('a form opened on a staged draft is dirty from the start', () {
      final vm = ExpenseEditViewModel(
        repo: repo,
        companyId: 'co',
        cloneFrom: emptyExpense().copyWith(vendorId: 'v1'),
      );
      expect(vm.draftIsNonEmpty(), isTrue);
    });
  });

  test('resetToEmpty clears the draft', () {
    final vm = createVm()
      ..setVendorId('v1')
      ..setAmount('99');

    vm.resetToEmpty();

    expect(vm.draftIsNonEmpty(), isFalse);
    expect(vm.draft.amount, Decimal.zero);
  });

  // A new expense takes the company's Expense Settings (React `Create.tsx`,
  // admin-portal's `ExpenseEntity` constructor). The server applies none of
  // them to a manual create, so without this every one of those toggles was
  // inert.
  group('the company Expense Settings defaults', () {
    const everything = Company(
      expenseInclusiveTaxes: true,
      calculateExpenseTaxByAmount: true,
      markExpensesInvoiceable: true,
      invoiceExpenseDocuments: true,
    );

    test('seed an untouched new expense without dirtying it', () {
      final vm = createVm()..seedCompanyDefaults(everything);
      expect(vm.draft.usesInclusiveTaxes, isTrue);
      expect(vm.draft.calculateTaxByAmount, isTrue);
      expect(vm.draft.shouldBeInvoiced, isTrue);
      expect(vm.draft.invoiceDocuments, isTrue);
      expect(vm.draft.paymentDate, isNull);
      expect(vm.isDirty, isFalse);
    });

    test('never over a switch the user touched', () {
      final vm = createVm()
        ..setUsesInclusiveTaxes(false)
        ..setShouldBeInvoiced(true)
        ..seedCompanyDefaults(const Company(expenseInclusiveTaxes: true));
      expect(vm.draft.usesInclusiveTaxes, isFalse);
      // The company says "not invoiceable"; the user already said yes.
      expect(vm.draft.shouldBeInvoiced, isTrue);
    });

    test('the inclusive mode never once an amount was typed in the other '
        'mode', () {
      final vm = createVm()
        ..setAmount('120')
        ..seedCompanyDefaults(const Company(expenseInclusiveTaxes: true));
      expect(vm.draft.usesInclusiveTaxes, isFalse);
    });

    test('tax-by-amount never once a tax was entered by rate', () {
      final vm = createVm()
        ..setTaxRate1('10')
        ..seedCompanyDefaults(const Company(calculateExpenseTaxByAmount: true));
      expect(vm.draft.calculateTaxByAmount, isFalse);
    });

    test('are a no-op on an existing expense', () {
      final existing = Expense.fromApi(
        const ExpenseApi(id: 'e1', updatedAt: 1700000000),
      );
      final vm = editVm(existing)
        ..seedCompanyDefaults(
          const Company(markExpensesInvoiceable: true, markExpensesPaid: true),
        );
      expect(vm.draft.shouldBeInvoiced, isFalse);
      expect(vm.draft.paymentDate, isNull);
      expect(vm.isDirty, isFalse);
    });

    test('mark paid fills the payment date from the expense date and the '
        'default payment type, still clean', () {
      final vm = createVm()
        ..seedCompanyDefaults(
          const Company(
            markExpensesPaid: true,
            settings: CompanySettings(defaultExpensePaymentTypeId: '4'),
          ),
        );
      expect(vm.draft.paymentDate, vm.draft.date);
      expect(vm.draft.paymentTypeId, '4');
      expect(vm.isDirty, isFalse);
    });

    test("'0' is the server's \"no default payment type\"", () {
      final vm = createVm()
        ..seedCompanyDefaults(
          const Company(
            markExpensesPaid: true,
            settings: CompanySettings(defaultExpensePaymentTypeId: '0'),
          ),
        );
      expect(vm.draft.paymentDate, isNotNull);
      expect(vm.draft.paymentTypeId, isEmpty);
    });

    test('a seeded payment date follows the expense date', () {
      final vm = createVm()
        ..seedCompanyDefaults(const Company(markExpensesPaid: true))
        ..setDate(Date(2026, 9, 1));
      expect(vm.draft.paymentDate, Date(2026, 9, 1));
    });

    test('survive a discard, including the payment date following', () {
      final vm = createVm()
        ..seedCompanyDefaults(
          const Company(expenseInclusiveTaxes: true, markExpensesPaid: true),
        )
        ..setUsesInclusiveTaxes(false)
        ..unmarkPaid()
        ..resetToEmpty();
      expect(vm.draft.usesInclusiveTaxes, isTrue);
      expect(vm.draft.paymentDate, isNotNull);
      expect(vm.isDirty, isFalse);

      vm.setDate(Date(2026, 9, 1));
      expect(vm.draft.paymentDate, Date(2026, 9, 1));
    });
  });

  // A receipt back-dated to last week was paid last week far more often than
  // today, so "Mark paid" takes the expense's date — and keeps following it
  // until the user sets the payment date themselves.
  group('mark paid', () {
    test('takes the expense date, not today', () {
      final vm = createVm()
        ..setDate(Date(2026, 9, 1))
        ..markPaid();
      expect(vm.draft.paymentDate, Date(2026, 9, 1));
    });

    test('falls back to today when the expense has no date', () {
      final vm = createVm()
        ..setDate(null)
        ..markPaid();
      expect(vm.draft.paymentDate, Date.today());
    });

    test('fills the default payment type, never over a picked one', () {
      expect(
        (createVm()..markPaid(defaultPaymentTypeId: '4')).draft.paymentTypeId,
        '4',
      );
      expect(
        (createVm()
              ..setPaymentTypeId('2')
              ..markPaid(defaultPaymentTypeId: '4'))
            .draft
            .paymentTypeId,
        '2',
      );
    });

    test('the payment date follows the expense date until the user edits '
        'it', () {
      final vm = createVm()
        ..markPaid()
        ..setDate(Date(2026, 8, 3));
      expect(vm.draft.paymentDate, Date(2026, 8, 3));

      vm
        ..setPaymentDate(Date(2026, 8, 10))
        ..setDate(Date(2026, 8, 1));
      expect(vm.draft.paymentDate, Date(2026, 8, 10));
    });

    test("an existing expense's stored payment date never follows", () {
      final existing = Expense.fromApi(
        const ExpenseApi(
          id: 'e1',
          date: '2026-08-03',
          paymentDate: '2026-08-03',
          updatedAt: 1700000000,
        ),
      );
      final vm = editVm(existing)..setDate(Date(2026, 8, 1));
      expect(vm.draft.paymentDate, Date(2026, 8, 3));

      // Nor after a discard restores the stored record.
      vm
        ..resetToEmpty()
        ..setDate(Date(2026, 8, 1));
      expect(vm.draft.paymentDate, Date(2026, 8, 3));
    });

    test('unmark clears the whole triple, and a date change after it sets '
        'no payment date', () {
      final vm = createVm()
        ..markPaid(defaultPaymentTypeId: '4')
        ..setTransactionReference('REF-1')
        ..unmarkPaid()
        ..setDate(Date(2026, 8, 1));
      expect(vm.draft.paymentDate, isNull);
      expect(vm.draft.paymentTypeId, isEmpty);
      expect(vm.draft.transactionReference, isEmpty);
    });
  });
}
