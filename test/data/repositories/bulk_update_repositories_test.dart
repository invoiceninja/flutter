// Bulk Update on tasks, expenses and recurring invoices: the local write has
// to show what the server's `bulkUpdate` will do, and the outbox row has to
// carry exactly the `column` + `new_value` the server reads.

import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/domain/sync/mutation.dart';

class _UnusedTasksApi implements TasksApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedExpensesApi implements ExpensesApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedRecurringApi implements RecurringInvoicesApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<List<Map<String, dynamic>>> queued() async {
    final rows = await db.outboxDao.pendingRowsForCompany('co');
    for (final r in rows) {
      expect(r.mutationKind, MutationKind.bulkUpdate.wireName);
    }
    return [
      for (final r in rows) jsonDecode(r.payload) as Map<String, dynamic>,
    ];
  }

  group('tasks', () {
    Task task({String invoiceId = '', String projectId = 'p0'}) => Task.fromApi(
      TaskApi(
        id: 't1',
        clientId: 'c0',
        projectId: projectId,
        invoiceId: invoiceId,
      ),
    );

    test('writes the column locally and queues it', () async {
      final repo = TaskRepository(db: db, api: _UnusedTasksApi());
      await repo.bulkUpdate(
        companyId: 'co',
        task: task(),
        column: 'status_id',
        newValue: 's9',
      );

      final local = await repo.watch(companyId: 'co', id: 't1').first;
      expect(local!.statusId, 's9');
      expect(local.isDirty, isTrue);
      expect(await queued(), [
        {'id': 't1', 'column': 'status_id', 'new_value': 's9'},
      ]);
    });

    test('an invoiced task is left alone, as the server leaves it', () async {
      final repo = TaskRepository(db: db, api: _UnusedTasksApi());
      await repo.bulkUpdate(
        companyId: 'co',
        task: task(invoiceId: 'inv1'),
        column: 'status_id',
        newValue: 's9',
      );

      expect(await repo.watch(companyId: 'co', id: 't1').first, isNull);
      expect(await queued(), isEmpty);
    });

    test('a new client drops the project; a project brings its client', () {
      final moved = taskWithBulkUpdate(task(), 'client_id', 'c2');
      expect(moved.clientId, 'c2');
      expect(moved.projectId, isEmpty);

      final onProject = taskWithBulkUpdate(
        task(),
        'project_id',
        'p2',
        projectClientId: 'c3',
      );
      expect(onProject.projectId, 'p2');
      expect(onProject.clientId, 'c3');

      expect(
        taskWithBulkUpdate(task(), 'assigned_user_id', 'u1').assignedUserId,
        'u1',
      );
    });
  });

  group('expenses', () {
    Expense expense() => Expense.fromApi(
      const ExpenseApi(id: 'e1', clientId: 'c0', projectId: 'p0'),
    );

    test('writes the column locally and queues it', () async {
      final repo = ExpenseRepository(db: db, api: _UnusedExpensesApi());
      await repo.bulkUpdate(
        companyId: 'co',
        expense: expense(),
        column: 'should_be_invoiced',
        newValue: '1',
      );

      final local = await repo.watch(companyId: 'co', id: 'e1').first;
      expect(local!.shouldBeInvoiced, isTrue);
      expect(await queued(), [
        {'id': 'e1', 'column': 'should_be_invoiced', 'new_value': '1'},
      ]);
    });

    test('a tax is name||rate, split into the name and rate slots', () {
      final taxed = expenseWithBulkUpdate(expense(), 'tax2', 'VAT||17.5');
      expect(taxed.taxName2, 'VAT');
      expect(taxed.taxRate2, Decimal.parse('17.5'));
    });

    test('client and project move together, as on the server', () {
      final moved = expenseWithBulkUpdate(expense(), 'client_id', 'c2');
      expect(moved.clientId, 'c2');
      expect(moved.projectId, isEmpty);

      final onProject = expenseWithBulkUpdate(
        expense(),
        'project_id',
        'p2',
        projectClientId: 'c3',
      );
      expect(onProject.projectId, 'p2');
      expect(onProject.clientId, 'c3');
    });
  });

  group('recurring invoices', () {
    RecurringInvoice recurring() => RecurringInvoice.fromApi(
      const RecurringInvoiceApi(id: 'r1', autoBill: 'off', remainingCycles: 5),
    );

    test(
      'auto_bill also sets the flag the edit form derives from it',
      () async {
        final repo = RecurringInvoiceRepository(
          db: db,
          api: _UnusedRecurringApi(),
        );
        await repo.bulkUpdate(
          companyId: 'co',
          recurringInvoice: recurring(),
          column: 'auto_bill',
          newValue: 'optout',
        );

        final local = await repo.watch(companyId: 'co', id: 'r1').first;
        expect(local!.autoBill, 'optout');
        expect(local.autoBillEnabled, isTrue);
        expect(await queued(), [
          {'id': 'r1', 'column': 'auto_bill', 'new_value': 'optout'},
          {'id': 'r1', 'column': 'auto_bill_enabled', 'new_value': '1'},
        ]);
      },
    );

    test('opt-in and off leave the flag off', () {
      for (final mode in ['optin', 'off']) {
        expect(
          recurringInvoiceWithBulkUpdate(
            recurring(),
            'auto_bill',
            mode,
          ).autoBillEnabled,
          isFalse,
          reason: mode,
        );
      }
    });

    test('remaining cycles and the rich-text fields', () {
      expect(
        recurringInvoiceWithBulkUpdate(
          recurring(),
          'remaining_cycles',
          '-1',
        ).remainingCycles,
        -1,
      );
      expect(
        recurringInvoiceWithBulkUpdate(
          recurring(),
          'terms',
          '<p>Net 30</p>',
        ).terms,
        '<p>Net 30</p>',
      );
    });
  });
}
