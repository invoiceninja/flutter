// The local database — what a list does on every filter change and scroll,
// what a page of server data costs to store, and what saving an edit costs.
// A real in-memory SQLite (the engine the app ships), seeded with 5,000
// invoices and 2,000 clients through the same repository code a sync uses.
//
// docs/performance-tracking.md. Run through `dart tools/perf/main.dart run`.

import 'package:drift/drift.dart'
    show ApplyInterceptor, DatabaseConnection, QueryExecutor, QueryInterceptor;
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/db/dao/expense_dao.dart' show ExpenseFieldIds;
import 'package:admin/data/db/dao/payment_dao.dart' show PaymentFieldIds;
import 'package:admin/data/db/dao/product_dao.dart' show ProductFieldIds;
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/bank_transactions_api.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/payments_api.dart';
import 'package:admin/data/services/products_api.dart';
import 'package:admin/domain/columns/ids/bank_transaction_column_ids.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

import '../../test/ui/features/shell/_shell_test_helpers.dart';
import '../workloads.dart';
import '_perf.dart';

const _co = 'co';
const _invoiceCount = 5000;
const _clientCount = 2000;

/// Rows per entity for the lists seeded through a refresh delta.
const _rowsPerList = 5000;

// Every call fails: these repositories are only written through
// `applyRefreshDelta` and read back, never fetched for.
class _NoExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoPaymentsApi implements PaymentsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoProductsApi implements ProductsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _NoBankTransactionsApi implements BankTransactionsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _pageSize = 50;

/// Serves pre-parsed pages, the way the network would after `page.parse`.
class _InvoicePages implements InvoicesApi {
  _InvoicePages(this.rows);
  final List<InvoiceApi> rows;

  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = _pageSize,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    final start = ((page - 1) * perPage).clamp(0, rows.length);
    final end = (start + perPage).clamp(0, rows.length);
    final slice = rows.sublist(start, end);
    return (
      data: InvoiceListApi(data: slice),
      cursorUpdatedAt: slice.isEmpty ? null : slice.last.updatedAt,
      cursorId: slice.isEmpty ? null : slice.last.id,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _ClientPages implements ClientsApi {
  _ClientPages(this.rows);
  final List<ClientApi> rows;

  @override
  Future<({ClientListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = _pageSize,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    final start = ((page - 1) * perPage).clamp(0, rows.length);
    final end = (start + perPage).clamp(0, rows.length);
    final slice = rows.sublist(start, end);
    return (
      data: ClientListApi(data: slice),
      cursorUpdatedAt: slice.isEmpty ? null : slice.last.updatedAt,
      cursorId: slice.isEmpty ? null : slice.last.id,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Counts the SELECTs that reach SQLite, so a read benchmark can prove each
/// sample ran its query rather than being answered from a cached stream.
class _SelectCounter extends QueryInterceptor {
  int count = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    count++;
    return executor.runSelect(statement, args);
  }
}

final _selects = _SelectCounter();

/// Runs [read], failing unless it executed SQL. Drift keeps a cancelled
/// query stream alive until the event loop turns, and a re-listen before
/// then replays the last result — so a loop of `.first` reads can measure
/// row mapping alone while looking like a query.
Future<T> _query<T>(Future<T> Function() read) async {
  final before = _selects.count;
  final result = await read();
  if (_selects.count == before) {
    throw StateError('no SQL ran: the read was served from a cached stream');
  }
  return result;
}

void main() {
  perfCalibration();

  late AppDatabase db;
  late InvoiceRepository invoices;
  late ClientRepository clients;
  late ExpenseRepository expenses;
  late PaymentRepository payments;
  late ProductRepository products;
  late BankTransactionRepository transactions;

  setUpAll(() async {
    // Streams close synchronously, so each `.first` below runs its query:
    // with drift's default a re-listen inside the same event-loop turn
    // replays the cancelled stream's last result instead (see [_query]).
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory().interceptWith(_selects),
        closeStreamsSynchronously: true,
      ),
    );
    invoices = InvoiceRepository(
      db: db,
      api: _InvoicePages([
        for (var i = 0; i < _invoiceCount; i++)
          InvoiceApi.fromJson(invoiceJson(i, clients: _clientCount)),
      ]),
      settings: SettingsRepository(db: db),
    );
    clients = ClientRepository(
      db: db,
      api: _ClientPages([
        for (var i = 0; i < _clientCount; i++)
          ClientApi.fromJson(clientJson(i)),
      ]),
    );
    for (var page = 1; page <= _invoiceCount ~/ _pageSize; page++) {
      await invoices.ensurePageLoaded(
        companyId: _co,
        page: page,
        ignoreCursor: true,
      );
    }
    for (var page = 1; page <= _clientCount ~/ _pageSize; page++) {
      await clients.ensurePageLoaded(
        companyId: _co,
        page: page,
        ignoreCursor: true,
      );
    }
    // Four more lists, each with its own default sort, written the way a
    // `/refresh` delta writes them.
    expenses = ExpenseRepository(db: db, api: _NoExpensesApi());
    payments = PaymentRepository(db: db, api: _NoPaymentsApi());
    products = ProductRepository(db: db, api: _NoProductsApi());
    transactions = BankTransactionRepository(
      db: db,
      api: _NoBankTransactionsApi(),
    );
    await expenses.applyRefreshDelta(
      companyId: _co,
      bundle: [
        for (var i = 0; i < _rowsPerList; i++)
          ExpenseApi.fromJson(expenseJson(i)),
      ],
    );
    await payments.applyRefreshDelta(
      companyId: _co,
      bundle: [
        for (var i = 0; i < _rowsPerList; i++)
          PaymentApi.fromJson(paymentJson(i)),
      ],
    );
    await products.applyRefreshDelta(
      companyId: _co,
      bundle: [
        for (var i = 0; i < _rowsPerList; i++)
          ProductApi.fromJson(productJson(i)),
      ],
    );
    await transactions.applyRefreshDelta(
      companyId: _co,
      bundle: [
        for (var i = 0; i < _rowsPerList; i++)
          BankTransactionApi.fromJson(bankTransactionJson(i)),
      ],
    );
    for (final (name, count) in [
      ('expenses', db.expenseDao.watchBadgeCount(companyId: _co)),
      ('payments', db.paymentDao.watchBadgeCount(companyId: _co)),
      ('products', db.productDao.watchBadgeCount(companyId: _co)),
      ('transactions', db.bankTransactionDao.watchBadgeCount(companyId: _co)),
    ]) {
      expect(await count.first, _rowsPerList, reason: '$name did not seed');
    }

    // A benchmark over an empty table measures nothing and passes anyway.
    expect(
      await db.invoiceDao.watchBadgeCount(companyId: _co).first,
      _invoiceCount,
    );
    expect(
      await db.clientDao.watchBadgeCount(companyId: _co).first,
      _clientCount,
    );
  });
  tearDownAll(() => db.close());

  benchmark(
    'invoices.page_write',
    title: 'Invoices — store one page of 50 from the server (refresh)',
    // Page 7 re-delivers rows already stored, which is what a refresh is.
    run: () =>
        invoices.ensurePageLoaded(companyId: _co, page: 7, ignoreCursor: true),
  );

  benchmark(
    'invoices.list_first_page',
    title: 'Invoices list — first page of 50 of 5,000, default sort',
    batch: 2,
    run: () => _query(() async {
      final rows = await invoices.watchPage(companyId: _co).first;
      return _expectRows(rows, _pageSize);
    }),
  );

  // The same read with nothing decoded yet — a page seen for the first time,
  // or a list reopened after logout. Every other list read finds its rows in
  // `decodeRow`'s cache after warm-up, so without this a slower `fromApi`
  // would go unseen.
  benchmark(
    'invoices.list_first_page_cold',
    title: 'Invoices list — first page of 50, every row decoded afresh',
    run: () => _query(() async {
      final rows = await invoices.watchPage(companyId: _co).first;
      return _expectRows(rows, _pageSize);
    }),
    reset: () => invoices.clearPeekCache(),
  );

  benchmark(
    'invoices.list_deep_scroll',
    title: 'Invoices list — re-reading 10 loaded pages (500 rows)',
    run: () => _query(() async {
      final rows = await invoices
          .watchPage(companyId: _co, loadedPages: 10)
          .first;
      return _expectRows(rows, _pageSize * 10);
    }),
  );

  benchmark(
    'invoices.list_search',
    title: 'Invoices list — free-text search across 5,000',
    batch: 2,
    run: () => _query(() async {
      final rows = await invoices
          .watchPage(companyId: _co, search: 'Region 3')
          .first;
      return _expectSome(rows);
    }),
  );

  benchmark(
    'invoices.list_status_tab',
    title: 'Invoices list — the Overdue status tab',
    batch: 2,
    run: () => _query(() async {
      final rows = await invoices
          .watchPage(companyId: _co, badgeModeId: 'overdue')
          .first;
      return _expectSome(rows);
    }),
  );

  benchmark(
    'invoices.badge_counts',
    title: 'Invoices — every sidebar / status-tab count',
    run: () async {
      var total = 0;
      // `none` is a constant 0 with no query behind it.
      for (final mode in kInvoiceBadgeModes) {
        if (mode.id == kBadgeModeNone) continue;
        total += await _query(
          () => db.invoiceDao
              .watchBadgeCount(companyId: _co, modeId: mode.id)
              .first,
        );
      }
      return total;
    },
  );

  var edit = 0;
  late List<Invoice> editable;
  benchmark(
    'invoices.save_edit',
    title: 'Invoices — save an edit offline (row + outbox entry)',
    setUp: () async {
      editable = await invoices.watchPage(companyId: _co, loadedPages: 4).first;
      _expectRows(editable, _pageSize * 4);
    },
    run: () {
      // A different invoice every time: a second edit of the same one merges
      // into its pending outbox row, which is a different (cheaper) path.
      final invoice = editable[edit++ % editable.length];
      return invoices.save(
        companyId: _co,
        invoice: invoice.copyWith(privateNotes: 'edit $edit'),
      );
    },
    // Each save queued its own row — a save that queued nothing is no save.
    reset: () async => expect(
      await db.outboxDao.pendingCountForCompany(_co),
      edit,
      reason: 'a save did not reach the outbox',
    ),
    samples: 20,
  );

  benchmark(
    'clients.list_first_page',
    title: 'Clients list — first page of 50 of 2,000, sorted by name',
    batch: 2,
    run: () => _query(() async {
      final rows = await clients.watchPage(companyId: _co).first;
      return _expectRows(rows, _pageSize);
    }),
  );

  benchmark(
    'clients.list_search',
    title: 'Clients list — free-text search across 2,000',
    batch: 2,
    run: () => _query(() async {
      final rows = await clients
          .watchPage(companyId: _co, search: 'byrne')
          .first;
      return _expectSome(rows);
    }),
  );

  // An unaccented word finding an accented name (`García`): the fold's slow
  // path, on every row whose name or contact holds a non-ASCII letter.
  benchmark(
    'clients.list_search_folded',
    title: 'Clients list — accent-folded search across 2,000',
    batch: 2,
    run: () => _query(() async {
      final rows = await clients
          .watchPage(companyId: _co, search: 'garcia')
          .first;
      return _expectSome(rows);
    }),
  );

  // Every list's first page on the sort the app opens it with — the class
  // of cost `invoices.list_first_page` was: a default order no index serves
  // makes SQLite sort the whole table to return fifty rows.
  benchmark(
    'expenses.list_first_page',
    title: 'Expenses list — first page of 50 of 5,000, newest date first',
    batch: 2,
    run: () => _query(() async {
      final rows = await expenses
          .watchPage(
            companyId: _co,
            sortField: ExpenseFieldIds.date,
            sortAscending: false,
          )
          .first;
      return _expectRows(rows, _pageSize);
    }),
  );

  benchmark(
    'payments.list_first_page',
    title: 'Payments list — first page of 50 of 5,000, newest date first',
    batch: 2,
    run: () => _query(() async {
      final rows = await payments
          .watchPage(
            companyId: _co,
            sortField: PaymentFieldIds.date,
            sortAscending: false,
          )
          .first;
      return _expectRows(rows, _pageSize);
    }),
  );

  benchmark(
    'products.list_first_page',
    title: 'Products list — first page of 50 of 5,000, by product key',
    batch: 2,
    run: () => _query(() async {
      final rows = await products
          .watchPage(
            companyId: _co,
            sortField: ProductFieldIds.productKey,
            sortAscending: true,
          )
          .first;
      return _expectRows(rows, _pageSize);
    }),
  );

  benchmark(
    'transactions.list_first_page',
    title: 'Bank transactions list — first page of 50 of 5,000, newest first',
    batch: 2,
    run: () => _query(() async {
      final rows = await transactions
          .watchPage(
            companyId: _co,
            sortField: BankTransactionFieldIds.date,
            sortAscending: false,
          )
          .first;
      return _expectRows(rows, _pageSize);
    }),
  );

  // Coming back online with edits made offline: the outbox drain, through the
  // real sync engine and the real `Services` graph, against a server that
  // answers each update with the saved invoice. What is timed is this app's
  // side of it — building each request, parsing the reply, applying it.
  const drainCompany = 'co1';
  const drainBatch = 25;
  ShellFixture? online;
  var batch = 0;
  late List<Invoice> drainable;
  Future<void> queueEdits() async {
    final services = online!.services;
    // A sample that drained by failing — every edit dead — would time the
    // failure path and pass. Prove the last batch landed before the next.
    if (batch > 0) {
      Future<int> count(String sql) async =>
          (await services.db.customSelect(sql).getSingle()).data['c'] as int;
      expect(
        await count("SELECT COUNT(*) AS c FROM outbox WHERE state = 'dead'"),
        0,
        reason: 'an edit was rejected instead of sent',
      );
      expect(
        await count('SELECT COUNT(*) AS c FROM invoices WHERE is_dirty = 1'),
        0,
        reason: 'a reply was not applied',
      );
    }
    services.sync.holdDrains();
    try {
      for (var i = 0; i < drainBatch; i++) {
        final invoice = drainable[(batch * drainBatch + i) % drainable.length];
        await services.invoices.save(
          companyId: drainCompany,
          invoice: invoice.copyWith(privateNotes: 'offline edit $batch'),
        );
      }
    } finally {
      services.sync.releaseDrains();
    }
    batch++;
    expect(
      await services.sync.pendingCountFor(drainCompany),
      drainBatch,
      reason: 'the edits were not queued',
    );
  }

  benchmark(
    'sync.outbox_drain',
    title: 'Back online — send 25 queued invoice edits and apply the replies',
    setUp: () async {
      var stamp = 1800000000;
      online = await buildFixture(
        companies: const [FakeCompany(id: drainCompany, name: 'Acme Ltd')],
        currentCompanyId: drainCompany,
        httpClient: MockClient((request) async {
          final match = RegExp(
            r'/api/v1/invoices/([^/?]+)$',
          ).firstMatch(request.url.path);
          if (request.method != 'PUT' || match == null) {
            throw http.ClientException('offline (benchmark)');
          }
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {...sent, 'id': match.group(1), 'updated_at': ++stamp},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final services = online!.services;
      for (var i = 0; i < 200; i++) {
        await services.invoices.applyUpdateResponse(
          companyId: drainCompany,
          serverResponse: InvoiceApi.fromJson(invoiceJson(i)),
        );
      }
      drainable = await services.invoices
          .watchPage(companyId: drainCompany, loadedPages: 4)
          .first;
      expect(drainable, hasLength(200));
      await queueEdits();
    },
    run: () async {
      final services = online!.services;
      while (await services.sync.pendingCountFor(drainCompany) > 0) {
        final sent = await services.sync.drainOnce(companyId: drainCompany);
        if (sent == 0) throw StateError('the drain sent nothing');
      }
      return batch;
    },
    reset: queueEdits,
    tearDown: () async {
      final fixture = online;
      online = null;
      fixture?.services.refreshScheduler.dispose();
      await fixture?.dispose();
    },
    warmup: 2,
    samples: 10,
  );

  // What a `/refresh` after a day away writes: 200 changed invoices, each
  // newer than the stored copy, applied upsert-only.
  // Built before any timing: generating and typing the bundles is
  // `sync.refresh_delta_parse`'s work, not this one's.
  const deltaRounds = 3 + 10;
  late List<List<InvoiceApi>> deltas;
  var round = 0;
  benchmark(
    'sync.refresh_delta_apply',
    title: 'Delta /refresh — store 200 changed invoices',
    setUp: () => deltas = [
      for (var r = 0; r < deltaRounds; r++)
        [
          for (var i = 0; i < 200; i++)
            InvoiceApi.fromJson({
              ...invoiceJson(i, clients: _clientCount),
              // Newer every round, or the upsert skips rows it already has.
              'updated_at': 1800000000 + r * 1000 + i,
            }),
        ],
    ],
    run: () =>
        invoices.applyRefreshDelta(companyId: _co, bundle: deltas[round++]),
    // The round's rows landed: the last one stored carries its stamp.
    reset: () async {
      final stored = await db.invoiceDao
          .watchById(companyId: _co, id: 'inv_199')
          .first;
      expect(
        stored?.updatedAt,
        1800000000 + (round - 1) * 1000 + 199,
        reason: 'the delta was not stored',
      );
    },
    samples: deltaRounds - 3,
  );
}

int _expectRows(List<Object?> rows, int count) {
  if (rows.length != count) {
    throw StateError('expected $count rows, got ${rows.length}');
  }
  return rows.length;
}

int _expectSome(List<Object?> rows) {
  if (rows.isEmpty) throw StateError('the query matched nothing');
  return rows.length;
}
