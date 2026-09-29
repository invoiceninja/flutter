import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/services/recurring_expenses_api.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';

/// First coverage for `RecurringExpenseEditViewModel` — recurring expenses were
/// one of three feature areas with no `test/ui/features/<name>/` directory.
///
/// It shares the expense VM's three-way currency conversion (covered in
/// `expense_edit_view_model_test.dart`); what is unique here is the **schedule**:
/// `setEndlessCycles` encodes "run forever" as `remainingCycles == -1`, which is
/// the server's sentinel — writing `0` instead would mean "already finished" and
/// silently stop the schedule.
class _FakeRecurringExpensesApi implements RecurringExpensesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late RecurringExpenseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecurringExpenseRepository(db: db, api: _FakeRecurringExpensesApi());
  });
  tearDown(() async => db.close());

  RecurringExpenseEditViewModel createVm({bool commaDecimal = false}) =>
      RecurringExpenseEditViewModel(
        repo: repo,
        companyId: 'co',
        useCommaAsDecimalPlace: commaDecimal,
      );

  Future<int> pendingOutboxCount() async {
    final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);
    return rows.length;
  }

  group('save', () {
    test('a create enqueues exactly one outbox row', () async {
      final vm = createVm()
        ..setVendorId('v1')
        ..setAmount('50')
        ..setFrequencyId(kRecurringFrequencyMonthly);

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });

    test('an edit enqueues an update', () async {
      final existing = RecurringExpense.fromApi(
        const RecurringExpenseApi(
          id: 're1',
          vendorId: 'v1',
          updatedAt: 1700000000,
        ),
      );
      final vm = RecurringExpenseEditViewModel(
        repo: repo,
        companyId: 'co',
        existing: existing,
      )..setAmount('75');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });
  });

  group('schedule', () {
    test('endless cycles is the -1 sentinel, not 0', () {
      final vm = createVm()..setEndlessCycles(true);

      expect(
        vm.draft.remainingCycles,
        -1,
        reason: '0 would mean "already finished" and stop the schedule',
      );
    });

    test('turning endless off drops back to a single remaining cycle', () {
      final vm = createVm()
        ..setEndlessCycles(true)
        ..setEndlessCycles(false);

      expect(vm.draft.remainingCycles, 1);
    });

    test('an explicit cycle count is preserved', () {
      final vm = createVm()..setRemainingCycles(12);

      expect(vm.draft.remainingCycles, 12);
    });

    test('the frequency id round-trips', () {
      final vm = createVm()..setFrequencyId(kRecurringFrequencySixMonths);

      expect(vm.draft.frequencyId, kRecurringFrequencySixMonths);
    });
  });

  group('amount + conversion mirror the one-off expense VM', () {
    test('comma-decimal amounts parse', () {
      final vm = createVm(commaDecimal: true)..setAmount('12,34');

      expect(vm.draft.amount, Decimal.parse('12.34'));
    });

    test('setting an invoice currency recomputes the foreign amount', () {
      final vm = createVm()
        ..setAmount('100')
        ..setExchangeRate('2')
        ..setInvoiceCurrencyId('2');

      expect(vm.draft.foreignAmount, Decimal.parse('200'));
    });

    test('clearing the invoice currency resets the conversion', () {
      final vm = createVm()
        ..setAmount('100')
        ..setInvoiceCurrencyId('2')
        ..setExchangeRate('2')
        ..setInvoiceCurrencyId('');

      expect(vm.draft.exchangeRate, Decimal.one);
      expect(vm.draft.foreignAmount, Decimal.zero);
    });
  });

  group('draftIsNonEmpty drives the discard prompt', () {
    test('a fresh create is empty', () {
      expect(createVm().draftIsNonEmpty(), isFalse);
    });

    test('an amount or a vendor marks it dirty', () {
      expect((createVm()..setAmount('1')).draftIsNonEmpty(), isTrue);
      expect((createVm()..setVendorId('v1')).draftIsNonEmpty(), isTrue);
    });

    // Dirty is "differs from the untouched form" (the billing view models'
    // rule). The schedule defaults are in that baseline, so an untouched form
    // stays clean — but a frequency the user picked is their input, as it is
    // on a recurring invoice. The old hand-kept list excluded it outright.
    test('the seeded schedule is clean; a picked frequency is input', () {
      expect(createVm().draftIsNonEmpty(), isFalse);
      expect(
        (createVm()..setFrequencyId(kRecurringFrequencyWeekly))
            .draftIsNonEmpty(),
        isTrue,
      );
    });

    test('a typed number or a picked assignee marks it dirty', () {
      expect((createVm()..setNumber('R-9')).draftIsNonEmpty(), isTrue);
      expect((createVm()..setAssignedUserId('u1')).draftIsNonEmpty(), isTrue);
    });

    test('a form opened on a staged draft is dirty from the start', () {
      final vm = RecurringExpenseEditViewModel(
        repo: repo,
        companyId: 'co',
        cloneFrom: emptyRecurringExpense().copyWith(vendorId: 'v1'),
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

  // A new recurring expense takes the company's Expense Settings, minus
  // "mark paid" — the server applies that itself to every expense the cron
  // generates.
  group('the company Expense Settings defaults', () {
    test('seed an untouched new record without dirtying it', () {
      final vm = createVm()
        ..seedCompanyDefaults(
          const Company(
            expenseInclusiveTaxes: true,
            calculateExpenseTaxByAmount: true,
            markExpensesInvoiceable: true,
            invoiceExpenseDocuments: true,
            markExpensesPaid: true,
          ),
        );
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
        ..setInvoiceDocuments(true)
        ..seedCompanyDefaults(const Company(expenseInclusiveTaxes: true));
      expect(vm.draft.usesInclusiveTaxes, isFalse);
      expect(vm.draft.invoiceDocuments, isTrue);
    });

    test('the inclusive mode never once an amount was typed in the other '
        'mode', () {
      final vm = createVm()
        ..setAmount('120')
        ..seedCompanyDefaults(const Company(expenseInclusiveTaxes: true));
      expect(vm.draft.usesInclusiveTaxes, isFalse);
    });

    test('survive a discard', () {
      final vm = createVm()
        ..seedCompanyDefaults(const Company(expenseInclusiveTaxes: true))
        ..setUsesInclusiveTaxes(false)
        ..resetToEmpty();
      expect(vm.draft.usesInclusiveTaxes, isTrue);
      expect(vm.isDirty, isFalse);
    });
  });
}
