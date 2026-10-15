import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/domain/columns/ids/client_column_ids.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_invoice_picker.dart';

import '../../../_localization_helper.dart';

class _FakePaymentsApi implements PaymentsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeInvoices implements InvoiceRepository {
  _FakeInvoices(this.rows);
  final List<Invoice> rows;
  final List<String> fetches = [];

  @override
  Stream<List<Invoice>> watchRecent({
    required String companyId,
    required int limit,
    String? badgeModeId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    expect(badgeModeId, 'unpaid');
    return Stream.value(rows);
  }

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    fetches.add('all:${extraFilters['client_status']?.join()}');
    return false;
  }

  @override
  Future<UnpaidInvoicesFetch> ensureUnpaidForClientLoaded({
    required String companyId,
    required String clientId,
  }) async {
    fetches.add('client:$clientId');
    return UnpaidInvoicesFetch.complete;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeClients implements ClientRepository {
  _FakeClients(this.rows);
  final List<Client> rows;

  @override
  Stream<List<Client>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ClientFieldIds.name,
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
    String? badgeModeId,
  }) => Stream.value(rows);

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({required this.invoices, required this.clients});
  @override
  final InvoiceRepository invoices;
  @override
  final ClientRepository clients;
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Invoice _invoice(
  String id,
  String number,
  String clientId,
  String balance, {
  String status = '2',
}) => Invoice.fromApi(
  InvoiceApi(
    id: id,
    number: number,
    clientId: clientId,
    statusId: status,
    amount: double.parse(balance),
    balance: double.parse(balance),
  ),
);

void main() {
  late AppDatabase db;
  late _FakeInvoices invoices;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    invoices = _FakeInvoices([
      _invoice('i1', '0001', 'c1', '120'),
      _invoice('i2', '0002', 'c2', '80'),
      _invoice('i3', '0003', 'c1', '0'), // nothing left to pay
      _invoice('tmp_x', '', 'c1', '50'), // not on the server yet
    ]);
  });
  tearDown(() async => db.close());

  Future<PaymentEditViewModel> pump(
    WidgetTester tester, {
    Payment? draft,
  }) async {
    final vm = PaymentEditViewModel(
      repo: PaymentRepository(db: db, api: _FakePaymentsApi()),
      companyId: 'co',
      cloneFrom: draft,
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          invoices: invoices,
          clients: _FakeClients([
            Client.fromApi(
              const ClientApi(id: 'c1', name: 'Acme Ltd', currencyId: '3'),
            ),
            Client.fromApi(const ClientApi(id: 'c2', name: 'Globex')),
          ]),
        ),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: ListenableBuilder(
              listenable: vm,
              builder: (context, _) =>
                  PaymentInvoicePicker(vm: vm, formatter: null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every client\'s payable invoices, named by client', (
    tester,
  ) async {
    await pump(tester);
    await openPicker(tester);

    expect(find.text('#0001  ·  Acme Ltd  ·  120'), findsOneWidget);
    expect(find.text('#0002  ·  Globex  ·  80'), findsOneWidget);
    expect(find.textContaining('#0003'), findsNothing);
    expect(find.textContaining('Pending'), findsNothing);
    expect(invoices.fetches, ['all:unpaid']);
  });

  testWidgets('picking one fills the client, currency and allocation', (
    tester,
  ) async {
    final vm = await pump(tester);
    await openPicker(tester);
    await tester.tap(find.text('#0001  ·  Acme Ltd  ·  120'));
    await tester.pumpAndSettle();

    expect(vm.draft.clientId, 'c1');
    expect(vm.draft.currencyId, '3');
    expect(vm.draft.paymentables.single.invoiceId, 'i1');
    expect(vm.draft.amount, Decimal.parse('120'));
    // The picked client's own unpaid invoices are fetched next.
    expect(invoices.fetches.last, 'client:c1');
  });

  testWidgets('with a client chosen, only that client\'s invoices', (
    tester,
  ) async {
    await pump(tester, draft: emptyPayment().copyWith(clientId: 'c2'));
    await openPicker(tester);

    expect(find.textContaining('#0002'), findsOneWidget);
    expect(find.textContaining('#0001'), findsNothing);
    expect(invoices.fetches, ['client:c2']);
  });

  testWidgets('an invoice already allocated shows as the value', (
    tester,
  ) async {
    await pump(
      tester,
      draft: emptyPayment().copyWith(
        clientId: 'c1',
        paymentables: [
          Paymentable(
            invoiceId: 'i1',
            amount: Decimal.parse('120'),
            refunded: Decimal.zero,
          ),
        ],
      ),
    );
    expect(
      find.widgetWithText(TextField, '#0001  ·  Acme Ltd  ·  120'),
      findsOneWidget,
    );
  });
}
