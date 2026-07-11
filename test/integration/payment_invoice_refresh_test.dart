import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';

/// End-to-end regression guard for invoiceninja/flutter#7: adding a payment
/// must flip its invoice to Paid AND refresh its client's balance locally —
/// without a manual full resync — because a payment mutation now force-refetches
/// its affected invoice(s) + client through the injected
/// `onRelatedEntitiesAffected` callback, inside the outbox drain.
class _FakePaymentsApi implements PaymentsApi {
  _FakePaymentsApi(this.createResponse);
  final PaymentApi createResponse;

  @override
  Future<PaymentItemApi> create({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    bool requiresPassword = false,
    Map<String, String>? query,
  }) async => PaymentItemApi(data: createResponse);

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeInvoicesApi implements InvoicesApi {
  _FakeInvoicesApi({this.response, this.error});
  final InvoiceApi? response;
  final Object? error;
  int getCount = 0;

  @override
  Future<InvoiceItemApi> getWithSchedule(String id) async {
    getCount++;
    final err = error;
    if (err != null) throw err;
    return InvoiceItemApi(data: response!);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeClientsApi implements ClientsApi {
  _FakeClientsApi({this.response, this.error});
  final ClientApi? response;
  final Object? error;
  int getCount = 0;

  @override
  Future<ClientItemApi> get(String id) async {
    getCount++;
    final err = error;
    if (err != null) throw err;
    return ClientItemApi(data: response!);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // Server's payment-create response: allocated to inv1, for client cli_1.
  const paymentResponse = PaymentApi(
    id: 'pay_1',
    clientId: 'cli_1',
    paymentables: [PaymentableApi(id: 'pt1', invoiceId: 'inv1')],
  );

  ({
    SyncRepository sync,
    PaymentRepository payments,
    InvoiceRepository invoices,
    ClientRepository clients,
  })
  wire({
    required _FakeInvoicesApi invoicesApi,
    required _FakeClientsApi clientsApi,
  }) {
    final invoiceRepo = InvoiceRepository(
      db: db,
      api: invoicesApi,
      settings: SettingsRepository(db: db),
    );
    final clientRepo = ClientRepository(db: db, api: clientsApi);
    // Mirror the REAL DI closure (services_entity_wiring.dart's
    // refreshRelatedEntities): refresh the invoices, then their clients ∪ the
    // payment's own client.
    final paymentRepo = PaymentRepository(
      db: db,
      api: _FakePaymentsApi(paymentResponse),
      onRelatedEntitiesAffected: (companyId, invoiceIds, clientIds) async {
        final invoiceClients = await invoiceRepo.refreshByIds(
          companyId: companyId,
          ids: invoiceIds,
        );
        final allClients = <String>{...clientIds, ...invoiceClients};
        if (allClients.isNotEmpty) {
          await clientRepo.refreshByIds(companyId: companyId, ids: allClients);
        }
      },
    );
    final registry = EntityRegistry({
      EntityType.payment: EntityHandlers(
        type: EntityType.payment,
        wireName: 'payment',
        apiPath: '/api/v1/payments',
        routePath: '/payments',
        icon: Icons.payment,
        dispatcher: BaseEntitySyncDispatcher<PaymentItemApi, PaymentApi>(
          api: paymentRepo.api,
          repo: paymentRepo,
          dataOf: (item) => item.data,
        ),
      ),
    });
    return (
      sync: SyncRepository(db: db, registry: registry),
      payments: paymentRepo,
      invoices: invoiceRepo,
      clients: clientRepo,
    );
  }

  test(
    'payment create → drain flips the invoice to Paid AND refreshes the client',
    () async {
      final invoicesApi = _FakeInvoicesApi(
        response: const InvoiceApi(
          id: 'inv1',
          statusId: '4', // paid
          balance: '0',
          paidToDate: '100',
          clientId: 'cli_1',
          updatedAt: 1700000100,
        ),
      );
      final clientsApi = _FakeClientsApi(
        response: const ClientApi(
          id: 'cli_1',
          name: 'Acme',
          balance: '0', // outstanding cleared
          updatedAt: 1700000100,
        ),
      );
      final w = wire(invoicesApi: invoicesApi, clientsApi: clientsApi);

      // Seed an unpaid invoice + a client with an outstanding balance.
      await w.invoices.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const InvoiceApi(
          id: 'inv1',
          statusId: '2', // sent
          balance: '100',
          paidToDate: '0',
          clientId: 'cli_1',
          updatedAt: 1700000000,
        ),
      );
      await w.clients.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const ClientApi(
          id: 'cli_1',
          name: 'Acme',
          balance: '100',
          updatedAt: 1700000000,
        ),
      );

      await w.payments.create(
        companyId: 'co',
        draft: Payment.fromApi(const PaymentApi(id: '', clientId: 'cli_1')),
        sendEmail: false,
      );
      final successes = await w.sync.drainOnce(companyId: 'co');

      expect(successes, 1);
      expect(await w.sync.pendingCountFor('co'), 0);
      expect(invoicesApi.getCount, 1);
      expect(clientsApi.getCount, 1);

      // Invoice converged locally, no manual resync.
      final inv = await w.invoices.watch(companyId: 'co', id: 'inv1').first;
      expect(inv!.statusId, InvoiceStatus.paid);
      expect(inv.balance, Decimal.zero);

      // Client balance converged too.
      final cliRow = await db.clientDao
          .watchById(companyId: 'co', id: 'cli_1')
          .first;
      expect(cliRow!.balance, '0');
    },
  );

  test(
    'a failing invoice/client refetch does NOT break the payment mutation (the '
    'swallow is load-bearing)',
    () async {
      // Both side-effect refetches throw inside the drain.
      final invoicesApi = _FakeInvoicesApi(error: Exception('inv down'));
      final clientsApi = _FakeClientsApi(error: Exception('cli down'));
      final w = wire(invoicesApi: invoicesApi, clientsApi: clientsApi);

      await w.invoices.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const InvoiceApi(
          id: 'inv1',
          statusId: '2', // sent
          balance: '100',
          clientId: 'cli_1',
          updatedAt: 1700000000,
        ),
      );

      await w.payments.create(
        companyId: 'co',
        draft: Payment.fromApi(const PaymentApi(id: '', clientId: 'cli_1')),
        sendEmail: false,
      );
      final successes = await w.sync.drainOnce(companyId: 'co');

      // Payment still drained cleanly — the outbox row is gone (not parked as a
      // bogus conflict/dead), and the payment persisted.
      expect(successes, 1);
      expect(await w.sync.pendingCountFor('co'), 0);
      expect(invoicesApi.getCount, 1);
      expect(clientsApi.getCount, 1); // attempted via the payment's client id
      final pay = await db.paymentDao
          .watchById(companyId: 'co', id: 'pay_1')
          .first;
      expect(pay, isNotNull);

      // The invoice simply stays stale until the next full resync.
      final inv = await w.invoices.watch(companyId: 'co', id: 'inv1').first;
      expect(inv!.statusId, InvoiceStatus.sent);
    },
  );
}
