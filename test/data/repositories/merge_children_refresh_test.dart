import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/domain/entity_type.dart';

class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakePaymentsApi implements PaymentsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeQuotesApi implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeVendorsApi implements VendorsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test(
    'childIdsForClient groups the client\'s local children by type',
    () async {
      final invoices = InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: SettingsRepository(db: db),
      );
      // inv1 belongs to the absorbed client; inv2 to the survivor (excluded).
      await invoices.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const InvoiceApi(id: 'inv1', clientId: 'absorbed'),
      );
      await invoices.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const InvoiceApi(id: 'inv2', clientId: 'survivor'),
      );
      await PaymentRepository(
        db: db,
        api: _FakePaymentsApi(),
      ).applyUpdateResponse(
        companyId: 'co',
        serverResponse: const PaymentApi(id: 'pay1', clientId: 'absorbed'),
      );
      await QuoteRepository(db: db, api: _FakeQuotesApi()).applyUpdateResponse(
        companyId: 'co',
        serverResponse: const QuoteApi(id: 'q1', clientId: 'absorbed'),
      );

      final repo = ClientRepository(db: db, api: _FakeClientsApi());
      final result = await repo.childIdsForClient(
        companyId: 'co',
        clientId: 'absorbed',
      );

      expect(result[EntityType.invoice], {'inv1'}); // inv2 excluded
      expect(result[EntityType.payment], {'pay1'});
      expect(result[EntityType.quote], {'q1'});
      // No credits/tasks/etc. were seeded → absent, not empty sets.
      expect(result.containsKey(EntityType.credit), isFalse);
    },
  );

  test(
    'childIdsForVendor groups the vendor\'s local children by type',
    () async {
      await ExpenseRepository(
        db: db,
        api: _FakeExpensesApi(),
      ).applyUpdateResponse(
        companyId: 'co',
        serverResponse: const ExpenseApi(id: 'exp1', vendorId: 'absorbed'),
      );
      await PurchaseOrderRepository(
        db: db,
        api: _FakePurchaseOrdersApi(),
      ).applyUpdateResponse(
        companyId: 'co',
        serverResponse: const PurchaseOrderApi(id: 'po1', vendorId: 'absorbed'),
      );

      final repo = VendorRepository(db: db, api: _FakeVendorsApi());
      final result = await repo.childIdsForVendor(
        companyId: 'co',
        vendorId: 'absorbed',
      );

      expect(result[EntityType.expense], {'exp1'});
      expect(result[EntityType.purchaseOrder], {'po1'});
    },
  );
}
