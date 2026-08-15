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

Project _namedProject({required String id, required String name}) =>
    Project.fromApi(ProjectApi(id: id, name: name));

Company _company({double? defaultTaskRate}) => Company(
  id: 'co',
  settings: CompanySettingsApi(defaultTaskRate: defaultTaskRate),
);

/// A company that shows the project on task lines. [header] false is the
/// "Project Location = Service" branch (name → `product_key`).
Company _headerCompany({bool header = true}) => Company(
  id: 'co',
  markdownEnabled: true,
  invoiceTaskProject: true,
  invoiceTaskProjectHeader: header,
  settings: const CompanySettingsApi(),
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

  // The forum #23511 mechanism: several projects' tasks on one invoice, told
  // apart by a header on the first line of each project's run.
  group('tasksToLineItems', () {
    Task at(String id, String projectId, int startEpoch) => Task.fromApi(
      TaskApi(
        id: id,
        description: id,
        projectId: projectId,
        timeLog: '[[$startEpoch,${startEpoch + 3600},"",true]]',
      ),
    );

    final projects = {
      'pA': _namedProject(id: 'pA', name: 'Alpha'),
      'pB': _namedProject(id: 'pB', name: 'Beta'),
    };

    test('clusters by project and heads each run exactly once', () {
      final items = tasksToLineItems(
        // Deliberately interleaved on input.
        [
          at('a1', 'pA', 1700000000),
          at('b1', 'pB', 1700100000),
          at('a2', 'pA', 1700200000),
        ],
        projectsById: projects,
        company: _headerCompany(),
      );
      expect(items.map((i) => i.taskId), ['a1', 'a2', 'b1']);
      expect(
        items[0].notes,
        startsWith('<div class="project-header">Alpha</div>\n'),
      );
      expect(items[1].notes, isNot(contains('project-header')));
      expect(
        items[2].notes,
        startsWith('<div class="project-header">Beta</div>\n'),
      );
    });

    test('orders the clusters by project NAME, not by hashed id — the picker '
        'groups by name, and the two must agree', () {
      // Ids sort Alpha *after* Beta; names sort it before.
      final byName = {
        'zzz': _namedProject(id: 'zzz', name: 'Alpha'),
        'aaa': _namedProject(id: 'aaa', name: 'Beta'),
      };
      final items = tasksToLineItems(
        [at('b1', 'aaa', 1700000000), at('a1', 'zzz', 1700100000)],
        projectsById: byName,
        company: _headerCompany(),
      );
      expect(items.map((i) => i.taskId), ['a1', 'b1']);
      expect(
        items[0].notes,
        startsWith('<div class="project-header">Alpha</div>\n'),
      );
      expect(
        items[1].notes,
        startsWith('<div class="project-header">Beta</div>\n'),
      );
    });

    test('project-less tasks sort last, matching the picker\'s "No project" '
        'group', () {
      final items = tasksToLineItems(
        [at('none', '', 1700000000), at('a1', 'pA', 1700100000)],
        projectsById: projects,
        company: _headerCompany(),
      );
      expect(items.map((i) => i.taskId), ['a1', 'none']);
    });

    test('sorts chronologically within a project', () {
      final items = tasksToLineItems(
        [at('late', 'pA', 1700200000), at('early', 'pA', 1700000000)],
        projectsById: projects,
        company: _headerCompany(),
      );
      expect(items.map((i) => i.taskId), ['early', 'late']);
      // The header rides the first line after sorting, not the first on input.
      expect(
        items[0].notes,
        startsWith('<div class="project-header">Alpha</div>\n'),
      );
    });

    test('alreadyHeadedProjectIds suppresses a repeat header — appending more '
        'of a project already on the invoice must not print it twice', () {
      final items = tasksToLineItems(
        [at('a1', 'pA', 1700000000), at('b1', 'pB', 1700100000)],
        projectsById: projects,
        company: _headerCompany(),
        alreadyHeadedProjectIds: const {'pA'},
      );
      expect(items[0].notes, isNot(contains('project-header')));
      // Beta is new to the invoice, so it still gets its header.
      expect(
        items[1].notes,
        startsWith('<div class="project-header">Beta</div>\n'),
      );
    });

    test(
      'no headers at all when invoice_task_project is off (the default)',
      () {
        final items = tasksToLineItems(
          [at('a1', 'pA', 1700000000), at('b1', 'pB', 1700100000)],
          projectsById: projects,
          company: _company(),
        );
        expect(items.every((i) => !i.notes.contains('project-header')), isTrue);
      },
    );

    test('Project Location = Service puts the name in product_key, not the '
        'notes', () {
      final items = tasksToLineItems(
        [at('a1', 'pA', 1700000000)],
        projectsById: projects,
        company: _headerCompany(header: false),
      );
      expect(items.single.productKey, 'Alpha');
      expect(items.single.notes, isNot(contains('Alpha')));
    });

    test('a product custom field labelled "Project" suppresses the header — it '
        'already shows the project', () {
      final items = tasksToLineItems(
        [at('a1', 'pA', 1700000000)],
        projectsById: projects,
        company: _headerCompany().copyWith(
          customFields: const {'product1': 'Project'},
        ),
        projectFieldLabel: 'Project',
      );
      expect(items.single.notes, isNot(contains('project-header')));
    });

    test('fallbackProject covers tasks whose own project_id is blank — the '
        'single-project callers already know the project', () {
      final items = tasksToLineItems(
        [at('a1', '', 1700000000)],
        fallbackProject: projects['pA'],
        company: _headerCompany(),
      );
      expect(
        items.single.notes,
        startsWith('<div class="project-header">Alpha</div>\n'),
      );
    });

    test('task custom values ride onto the line item', () {
      final items = tasksToLineItems([
        Task.fromApi(
          TaskApi(id: 't1', customValue1: 'CV1', customValue4: 'CV4'),
        ),
      ]);
      expect(items.single.customValue1, 'CV1');
      expect(items.single.customValue4, 'CV4');
    });
  });

  group('projectInvoiceLineItems', () {
    test('excluded ids are dropped so appending twice cannot double-bill', () {
      final items = projectInvoiceLineItems(
        tasks: [
          _task(id: 't_new', rate: '100', timeLog: _stopped1h),
          _task(id: 't_already', rate: '100', timeLog: _stopped1h),
        ],
        expenses: [
          _expense(id: 'e_new', amount: '50', shouldBeInvoiced: true),
          _expense(id: 'e_already', amount: '50', shouldBeInvoiced: true),
        ],
        invoiceInclusive: false,
        excludedTaskIds: const {'t_already'},
        excludedExpenseIds: const {'e_already'},
      );
      expect(items.map((i) => i.expenseId ?? i.taskId), ['e_new', 't_new']);
    });

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
