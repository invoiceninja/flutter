import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';

class _NoopApi implements RecurringInvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late RecurringInvoiceRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecurringInvoiceRepository(db: db, api: _NoopApi());
  });
  tearDown(() async {
    await db.close();
  });

  RecurringInvoiceEditViewModel buildVm() => RecurringInvoiceEditViewModel(
    repo: repo,
    companyId: 'co',
    clientRequiredMessage: 'client required',
    crossClientLineItemsMessage: 'cross client',
  );

  group('a new recurring invoice', () {
    test('is not dirty until the user changes something — its default '
        'frequency is not input', () {
      // It used to be: the monthly default passed `frequencyId.isNotEmpty`,
      // so leaving an untouched new form always asked to discard changes.
      final vm = buildVm();
      expect(vm.draft.frequencyId, kDefaultRecurringFrequencyId);
      expect(vm.isDirty, isFalse);
    });

    test(
      'a different frequency is input, and choosing monthly again is not',
      () {
        final vm = buildVm();
        vm.setFrequencyId('1');
        expect(vm.isDirty, isTrue);
        vm.setFrequencyId(kDefaultRecurringFrequencyId);
        expect(vm.isDirty, isFalse);
      },
    );

    // Measured against the new form's own defaults, so the schedule counts
    // as input the way the frequency does: leaving a form holding only a
    // next send date used to drop it without asking.
    for (final (label, edit)
        in <(String, void Function(RecurringInvoiceEditViewModel))>[
          (
            'a next send date',
            (vm) => vm.setNextSendDate(const Date(2026, 10, 1)),
          ),
          ('a remaining-cycles count', (vm) => vm.setRemainingCycles(12)),
          ('a due-date choice', (vm) => vm.setDueDateDays('15')),
          ('an auto-bill choice', (vm) => vm.setAutoBill('always')),
        ]) {
      test('$label is input', () {
        final vm = buildVm();
        edit(vm);
        expect(vm.isDirty, isTrue);
      });
    }
  });

  // The recurring server derives `auto_bill_enabled` from `auto_bill`
  // (Store/UpdateRecurringInvoiceRequest::setAutoBillFlag: always/optout →
  // true) and overwrites it on save — there is no separate toggle. The VM
  // mirrors that derivation locally so the optimistic Drift copy is correct.
  group('setAutoBill derives autoBillEnabled', () {
    test('always → enabled', () {
      final vm = buildVm();
      vm.setAutoBill('always');
      expect(vm.draft.autoBill, 'always');
      expect(vm.draft.autoBillEnabled, isTrue);
      vm.dispose();
    });

    test('optout → enabled', () {
      final vm = buildVm();
      vm.setAutoBill('optout');
      expect(vm.draft.autoBillEnabled, isTrue);
      vm.dispose();
    });

    test('optin → disabled', () {
      final vm = buildVm();
      vm.setAutoBill('optin');
      expect(vm.draft.autoBillEnabled, isFalse);
      vm.dispose();
    });

    test('off → disabled', () {
      final vm = buildVm();
      vm.setAutoBill('always'); // flip on first…
      vm.setAutoBill('off'); // …then off must clear it
      expect(vm.draft.autoBillEnabled, isFalse);
      vm.dispose();
    });
  });
}
