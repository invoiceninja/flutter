import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/domain/entity_type.dart';

class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeTasksApi implements TasksApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  final calls = <Map<EntityType, Set<String>>>[];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calls.clear();
  });
  tearDown(() async => db.close());

  InvoiceRepository makeRepo({bool throwing = false}) => InvoiceRepository(
    db: db,
    api: _FakeInvoicesApi(),
    settings: SettingsRepository(db: db),
    onRelatedEntitiesAffected: (companyId, byType) async {
      calls.add({for (final e in byType.entries) e.key: e.value});
      if (throwing) throw StateError('boom');
    },
  );

  test(
    'billing tasks/expenses fires the client + task + expense refresh',
    () async {
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const InvoiceApi(
          id: 'inv1',
          clientId: 'c1',
          lineItems: [
            LineItemApi(taskId: 't1'),
            LineItemApi(taskId: 't2'),
            LineItemApi(expenseId: 'e1'),
            LineItemApi(
              productKey: 'Widget',
            ), // plain product line → no task/expense
          ],
        ),
      );
      expect(calls, hasLength(1));
      expect(calls.single[EntityType.client], {'c1'});
      expect(calls.single[EntityType.task], {'t1', 't2'});
      expect(calls.single[EntityType.expense], {'e1'});
    },
  );

  test('a plain invoice still refreshes its client (AR balance)', () async {
    await makeRepo().applyUpdateResponse(
      companyId: 'co',
      serverResponse: const InvoiceApi(id: 'inv1', clientId: 'c1'),
    );
    expect(calls.single[EntityType.client], {'c1'});
    expect(calls.single.containsKey(EntityType.task), isFalse);
    expect(calls.single.containsKey(EntityType.expense), isFalse);
  });

  test(
    'refreshes a task the save UN-linked (local invoice_id points here)',
    () async {
      // Seed a task already billed to inv1 (its invoice_id column == inv1).
      await TaskRepository(db: db, api: _FakeTasksApi()).applyUpdateResponse(
        companyId: 'co',
        serverResponse: const TaskApi(id: 't_old', invoiceId: 'inv1'),
      );
      // Save inv1 with NO line items → the server un-linked t_old. The local
      // invoice_id query catches it even though it's not in the response.
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const InvoiceApi(id: 'inv1', clientId: 'c1'),
      );
      expect(calls.single[EntityType.task], {'t_old'});
    },
  );

  test(
    'a throwing callback does not propagate out of applyUpdateResponse',
    () async {
      await expectLater(
        makeRepo(throwing: true).applyUpdateResponse(
          companyId: 'co',
          serverResponse: const InvoiceApi(id: 'inv1', clientId: 'c1'),
        ),
        completes,
      );
    },
  );
}
