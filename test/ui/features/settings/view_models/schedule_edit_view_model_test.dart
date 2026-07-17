import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/schedule_repository.dart';
import 'package:admin/data/services/schedules_api.dart';
import 'package:admin/ui/features/settings/view_models/schedule_edit_view_model.dart';
import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Save-gate + parameter-reset guards for the Schedules edit form. Mirrors the
/// canonical edit-VM test shape (`products/product_edit_view_model_test.dart`)
/// — exercises the VM logic without the Services/Provider scaffolding a full
/// screen pump needs. Covers the two pre-launch fixes:
///   A) email_report + a custom date range must require start/end (else 422).
///   B) switching report type must clear the prior report's parameters so
///      stale fields (template_id, client_id, a leftover `custom` range) don't
///      leak onto the wire.
class _FakeSchedulesApi implements SchedulesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late ScheduleRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db: db, api: _FakeSchedulesApi());
  });
  tearDown(() async {
    await db.close();
  });

  ScheduleEditViewModel newReportVm() {
    final vm = ScheduleEditViewModel(repo: repo, companyId: 'co');
    vm.setTemplate(kScheduleTemplateEmailReport);
    return vm;
  }

  group('canSave — email_report custom date range (finding A)', () {
    test('default (non-custom) range is saveable', () {
      final vm = newReportVm();
      expect(vm.draft.reportDateRange, 'last7_days');
      expect(vm.canSave, isTrue);
      vm.dispose();
    });

    test('custom range blocks save until both start and end are set', () {
      final vm = newReportVm();
      vm.setReportDateRange('custom');
      expect(vm.canSave, isFalse, reason: 'start + end empty would 422');

      vm.setReportStartDate('2026-06-01');
      expect(vm.canSave, isFalse, reason: 'end still empty');

      vm.setReportEndDate('2026-06-30');
      expect(vm.canSave, isTrue, reason: 'both set');
      vm.dispose();
    });

    test('custom range with end before start is not saveable', () {
      final vm = newReportVm();
      vm.setReportDateRange('custom');
      vm.setReportStartDate('2026-06-30');
      vm.setReportEndDate('2026-06-01');
      expect(vm.canSave, isFalse, reason: 'server requires end >= start');
      vm.dispose();
    });
  });

  group('setReportName resets stale parameters (finding B)', () {
    test('switching report clears the previous report-specific params', () {
      final vm = newReportVm();
      vm.setReportName('invoice');
      vm.setReportTemplateId('design-1');
      vm.setReportClientId('client-1');
      vm.setReportDateRange('custom');
      expect(vm.draft.reportTemplateId, 'design-1');
      expect(vm.draft.reportClientId, 'client-1');

      vm.setReportName('profitloss');

      expect(vm.draft.reportName, 'profitloss');
      expect(
        vm.draft.reportTemplateId,
        '',
        reason: 'stale template_id cleared',
      );
      expect(vm.draft.reportClientId, '', reason: 'stale client_id cleared');
      expect(
        vm.draft.reportDateRange,
        'last7_days',
        reason: 'stale custom range cleared (would otherwise 422)',
      );
      vm.dispose();
    });

    test('report switched to a fresh type is immediately saveable', () {
      final vm = newReportVm();
      vm.setReportName('profitloss');
      expect(vm.canSave, isTrue);
      vm.dispose();
    });

    test('re-selecting the same report keeps the configured params', () {
      final vm = newReportVm();
      vm.setReportName('invoice');
      vm.setReportTemplateId('design-1');
      vm.setReportClientId('client-1');
      // The dropdown fires onChanged on every tap, including re-selecting the
      // current report — that must NOT wipe the params the user just set.
      vm.setReportName('invoice');
      expect(vm.draft.reportTemplateId, 'design-1');
      expect(vm.draft.reportClientId, 'client-1');
      vm.dispose();
    });
  });

  group('canSave — payment_schedule amount-mode sum (finding #44)', () {
    ScheduleEditViewModel newPaymentScheduleVm() {
      final vm = ScheduleEditViewModel(repo: repo, companyId: 'co');
      vm.setTemplate(kScheduleTemplatePaymentSchedule);
      vm.setPaymentScheduleInvoiceId('inv-1');
      return vm;
    }

    // Amount-mode rows (isAmount=true) with strictly-ascending dates + positive
    // amounts, so only the sum-vs-invoice-total gate is under test.
    List<ScheduleParamsRow> amountRows(List<String> amounts) => [
      for (var i = 0; i < amounts.length; i++)
        ScheduleParamsRow(
          id: i,
          date: Date(2026, 6, i + 1),
          amount: Decimal.parse(amounts[i]),
          isAmount: true,
        ),
    ];

    test('amount rows that do NOT sum to the invoice total are not saveable '
        '(server 422s on sum != invoice.amount)', () {
      final vm = newPaymentScheduleVm();
      vm.setPaymentScheduleInvoiceAmount(Decimal.fromInt(100));
      vm.setPaymentScheduleRows(amountRows(['40', '40'])); // 80 != 100
      expect(vm.canSave, isFalse);
      vm.dispose();
    });

    test('amount rows that sum to the invoice total are saveable', () {
      final vm = newPaymentScheduleVm();
      vm.setPaymentScheduleInvoiceAmount(Decimal.fromInt(100));
      vm.setPaymentScheduleRows(amountRows(['40', '60'])); // 100 == 100
      expect(vm.canSave, isTrue);
      vm.dispose();
    });

    test(
      'sum equality is scale-insensitive (matches server BcMath::equal)',
      () {
        final vm = newPaymentScheduleVm();
        vm.setPaymentScheduleInvoiceAmount(Decimal.parse('100.00'));
        vm.setPaymentScheduleRows(amountRows(['99.5', '0.50'])); // 100.00
        expect(vm.canSave, isTrue);
        vm.dispose();
      },
    );

    test('when the invoice amount is unknown, Save is not over-blocked', () {
      final vm = newPaymentScheduleVm();
      // No setPaymentScheduleInvoiceAmount → amount unknown (edit / unloaded).
      vm.setPaymentScheduleRows(amountRows(['40', '40'])); // 80, uncheckable
      expect(vm.canSave, isTrue);
      vm.dispose();
    });
  });

  group('setRecordEntityType — reset on change, no-op on re-select', () {
    ScheduleEditViewModel newRecordVm() {
      final vm = ScheduleEditViewModel(repo: repo, companyId: 'co');
      vm.setTemplate(kScheduleTemplateEmailRecord);
      return vm;
    }

    test('re-selecting the same entity type keeps the chosen record', () {
      final vm = newRecordVm();
      expect(vm.draft.recordEntityType, 'invoice'); // default
      vm.setRecordEntityId('inv-1');
      // Same type — the DropdownButtonFormField re-fires onChanged, but
      // entity_id must survive.
      vm.setRecordEntityType('invoice');
      expect(vm.draft.recordEntityId, 'inv-1');
      vm.dispose();
    });

    test('switching entity type clears the now-invalid entity id', () {
      final vm = newRecordVm();
      vm.setRecordEntityId('inv-1');
      vm.setRecordEntityType('quote');
      expect(vm.draft.recordEntityId, '');
      vm.dispose();
    });
  });
}
