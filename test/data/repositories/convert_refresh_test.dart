import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/domain/entity_type.dart';

class _FakeQuotesApi implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
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

  Future<void> spy(
    String companyId,
    Map<EntityType, Set<String>> byType,
  ) async {
    calls.add({for (final e in byType.entries) e.key: e.value});
  }

  group('QuoteRepository — convert side-effect', () {
    QuoteRepository makeRepo() => QuoteRepository(
      db: db,
      api: _FakeQuotesApi(),
      onRelatedEntitiesAffected: spy,
    );

    test(
      'a converted quote (invoice_id set) refreshes the new invoice',
      () async {
        await makeRepo().applyUpdateResponse(
          companyId: 'co',
          serverResponse: const QuoteApi(id: 'q1', invoiceId: 'inv_new'),
        );
        expect(calls.single[EntityType.invoice], {'inv_new'});
      },
    );

    test(
      'a converted-to-project quote (project_id set) refreshes it',
      () async {
        await makeRepo().applyUpdateResponse(
          companyId: 'co',
          serverResponse: const QuoteApi(id: 'q1', projectId: 'proj_new'),
        );
        expect(calls.single[EntityType.project], {'proj_new'});
      },
    );

    test('a normal quote edit (no invoice_id) fires nothing', () async {
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const QuoteApi(id: 'q1'),
      );
      expect(calls, isEmpty);
    });
  });

  group('PurchaseOrderRepository — convert side-effect', () {
    PurchaseOrderRepository makeRepo() => PurchaseOrderRepository(
      db: db,
      api: _FakePurchaseOrdersApi(),
      onRelatedEntitiesAffected: spy,
    );

    test('a PO converted to expense (expense_id set) refreshes it', () async {
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const PurchaseOrderApi(id: 'po1', expenseId: 'exp_new'),
      );
      expect(calls.single[EntityType.expense], {'exp_new'});
    });

    test('a normal PO edit (no expense_id) fires nothing', () async {
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const PurchaseOrderApi(id: 'po1'),
      );
      expect(calls, isEmpty);
    });
  });
}
