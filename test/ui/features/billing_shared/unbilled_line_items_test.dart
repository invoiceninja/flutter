import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';

Task _task({
  String id = 't1',
  String description = '',
  String number = '',
  String rate = '0',
  String timeLog = '',
  String invoiceId = '',
}) => Task.fromApi(
  TaskApi(
    id: id,
    description: description,
    number: number,
    rate: rate,
    timeLog: timeLog,
    invoiceId: invoiceId,
  ),
);

Expense _expense({
  String id = 'e1',
  String publicNotes = '',
  String number = '',
  String amount = '0',
  String taxName1 = '',
  Object taxRate1 = '0',
  String invoiceId = '',
  bool shouldBeInvoiced = false,
  bool usesInclusiveTaxes = false,
}) => Expense.fromApi(
  ExpenseApi(
    id: id,
    publicNotes: publicNotes,
    number: number,
    amount: amount,
    taxName1: taxName1,
    taxRate1: taxRate1,
    invoiceId: invoiceId,
    shouldBeInvoiced: shouldBeInvoiced,
    usesInclusiveTaxes: usesInclusiveTaxes,
  ),
);

Project _project({String taskRate = '0'}) =>
    Project.fromApi(ProjectApi(id: 'p1', name: 'P', taskRate: taskRate));

Company _company({double? defaultTaskRate}) => Company(
  id: 'co',
  settings: CompanySettingsApi(defaultTaskRate: defaultTaskRate),
);

GroupSetting _group({num? defaultTaskRate}) => GroupSetting(
  id: 'g1',
  name: 'G',
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime(2026),
  createdAt: DateTime(2026),
  archivedAt: null,
  isDeleted: false,
  settings: defaultTaskRate == null
      ? null
      : {'default_task_rate': defaultTaskRate},
);

// A stopped, billable, 1-hour entry.
const _stopped1h = '[[1700000000,1700003600,"",true]]';
// A still-running entry (no stop) — billable.
const _running = '[[1700000000,0,"",true]]';

void main() {
  group('taskToLineItem', () {
    test('maps rate→cost, billable hours→quantity, type=task, taskId set', () {
      // 5400s = 1.5h billable.
      final li = taskToLineItem(
        _task(
          description: 'Design work',
          rate: '150',
          timeLog: '[[1700000000,1700005400,"",true]]',
        ),
      );
      expect(li.cost, Decimal.parse('150'));
      expect(li.quantity, Decimal.parse('1.5'));
      expect(li.notes, 'Design work');
      expect(li.typeId, LineItemType.task);
      expect(li.taskId, 't1');
      expect(li.expenseId, isNull);
    });

    test('a rate-0 task uses the GROUP default_task_rate over the company '
        'rate (the group tier of the cascade — #7/#38)', () {
      final li = taskToLineItem(
        _task(rate: '0', timeLog: _stopped1h),
        group: _group(defaultTaskRate: 75),
        company: _company(defaultTaskRate: 50),
      );
      expect(li.cost, Decimal.parse('75'));
    });

    test('no logged time falls back to quantity 1 (editable default)', () {
      final li = taskToLineItem(_task(rate: '90'));
      expect(li.quantity, Decimal.one);
    });

    test('non-billable entries are excluded from hours', () {
      final li = taskToLineItem(
        _task(timeLog: '[[1700000000,1700003600,"",false]]'),
      );
      expect(li.quantity, Decimal.one); // 0 billable → fallback 1
    });

    test('description falls back to #number then empty', () {
      expect(taskToLineItem(_task(number: '7')).notes, '#7');
      expect(taskToLineItem(_task()).notes, '');
    });
  });

  group('expenseToLineItem', () {
    test('maps amount→cost, qty 1, tax pass-through, expenseId set', () {
      final li = expenseToLineItem(
        _expense(
          publicNotes: 'Flights',
          amount: '420.50',
          taxName1: 'VAT',
          taxRate1: '20',
        ),
        invoiceInclusive: false,
      );
      expect(li.cost, Decimal.parse('420.50'));
      expect(li.quantity, Decimal.one);
      expect(li.notes, 'Flights');
      expect(li.taxName1, 'VAT');
      expect(li.taxRate1, Decimal.parse('20'));
      expect(li.expenseId, 'e1');
      expect(li.taskId, isNull);
      expect(li.typeId, LineItemType.standard);
    });

    test('inclusive-tax expense bills NET onto an exclusive doc and GROSS '
        'onto an inclusive doc (line total lands on the gross either way)', () {
      // 120.00 receipt containing 20% VAT: net 100, gross 120.
      final inclusiveExpense = _expense(
        amount: '120',
        taxName1: 'VAT',
        taxRate1: '20',
        usesInclusiveTaxes: true,
      );
      final ontoExclusive = expenseToLineItem(
        inclusiveExpense,
        invoiceInclusive: false,
      );
      expect(
        ontoExclusive.cost,
        Decimal.parse('100'),
        reason:
            'the exclusive doc adds 20% back on top → total 120, '
            'not 120 + 20% = 144 (the pre-fix overbilling)',
      );
      expect(ontoExclusive.taxRate1, Decimal.parse('20'));

      final ontoInclusive = expenseToLineItem(
        inclusiveExpense,
        invoiceInclusive: true,
      );
      expect(ontoInclusive.cost, Decimal.parse('120'));
    });

    test('notes fall back to #number then empty', () {
      expect(
        expenseToLineItem(
          _expense(number: '99'),
          invoiceInclusive: false,
        ).notes,
        '#99',
      );
      expect(expenseToLineItem(_expense(), invoiceInclusive: false).notes, '');
    });
  });

  group('taskBillableHours', () {
    test('rounds to 3 decimals', () {
      // 3661s ≈ 1.0169h → 1.017
      final h = taskBillableHours(
        _task(timeLog: '[[1700000000,1700003661,"",true]]'),
      );
      expect(h, Decimal.parse('1.017'));
    });
  });

  group('projectInvoiceLineItems', () {
    test('includes pending expenses first, then stopped+uninvoiced tasks', () {
      final items = projectInvoiceLineItems(
        tasks: [
          _task(id: 't_ok', rate: '100', timeLog: _stopped1h), // ✓ include
          _task(
            id: 't_inv',
            rate: '100',
            timeLog: _stopped1h,
            invoiceId: 'i1',
          ), // invoiced
          _task(id: 't_run', rate: '100', timeLog: _running), // running
          _task(id: 't_zero', rate: '100'), // no logged time
          _task(id: 'tmp_t', rate: '100', timeLog: _stopped1h), // unsynced
        ],
        invoiceInclusive: false,
        expenses: [
          _expense(
            id: 'e_ok',
            amount: '50',
            shouldBeInvoiced: true,
          ), // ✓ include
          _expense(
            id: 'e_inv',
            amount: '50',
            shouldBeInvoiced: true,
            invoiceId: 'i2',
          ), // invoiced
          _expense(id: 'e_nb', amount: '50'), // not should_be_invoiced
          _expense(
            id: 'tmp_e',
            amount: '50',
            shouldBeInvoiced: true,
          ), // unsynced
        ],
      );

      expect(items.length, 2);
      // Expenses come first (mirrors admin-portal ordering), then tasks.
      expect(items[0].expenseId, 'e_ok');
      expect(items[1].taskId, 't_ok');
    });

    test('returns empty when nothing is billable', () {
      final items = projectInvoiceLineItems(
        tasks: [
          _task(id: 't_run', timeLog: _running),
          _task(id: 't_zero'),
        ],
        invoiceInclusive: false,
        expenses: [_expense(id: 'e_nb')],
      );
      expect(items, isEmpty);
    });

    test('rate-0 task inherits the project→company cascade when project + '
        r'company are passed (the bulk-invoice $0 fix)', () {
      // project.taskRate wins over the company default for a rate-0 task.
      final viaProject = projectInvoiceLineItems(
        tasks: [_task(id: 't1', rate: '0', timeLog: _stopped1h)],
        expenses: const [],
        invoiceInclusive: false,
        project: _project(taskRate: '90'),
        company: _company(defaultTaskRate: 75),
      );
      expect(viaProject.single.cost, Decimal.parse('90'));

      // project.taskRate 0 → falls through to company default_task_rate.
      final viaCompany = projectInvoiceLineItems(
        tasks: [_task(id: 't1', rate: '0', timeLog: _stopped1h)],
        expenses: const [],
        invoiceInclusive: false,
        project: _project(taskRate: '0'),
        company: _company(defaultTaskRate: 75),
      );
      expect(viaCompany.single.cost, Decimal.parse('75'));
    });

    test('without project/company a rate-0 task bills at 0 (old bulk-path '
        'behavior — the regression Fix 3 addresses)', () {
      final noCascade = projectInvoiceLineItems(
        tasks: [_task(id: 't1', rate: '0', timeLog: _stopped1h)],
        expenses: const [],
        invoiceInclusive: false,
      );
      expect(noCascade.single.cost, Decimal.zero);
    });
  });
}
