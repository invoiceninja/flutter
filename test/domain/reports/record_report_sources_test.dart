@TestOn('vm')
library;

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/services/company_switched_exception.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/reports/credit_items_source.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/record_report_source.dart';
import 'package:admin/domain/reports/recurring_expenses_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/transactions_source.dart';

/// Credit Items, Recurring Expenses and Transactions are built on the device
/// (`ReportDefinition.isLocal`), from records the app lists. These pin each
/// report's rows, the fetch that fills the device first, and the loop that
/// runs it.

final _now = DateTime(2026, 10, 18, 12);

final _usd = Currency(
  id: '1',
  name: 'US Dollar',
  code: 'USD',
  symbol: r'$',
  precision: 2,
  thousandSeparator: ',',
  decimalSeparator: '.',
  swapCurrencySymbol: false,
  exchangeRate: Decimal.one,
);

final _eur = Currency(
  id: '3',
  name: 'Euro',
  code: 'EUR',
  symbol: '€',
  precision: 2,
  thousandSeparator: '.',
  decimalSeparator: ',',
  swapCurrencySymbol: false,
  exchangeRate: Decimal.parse('0.9'),
);

ReportQuery _query({
  Date? start,
  Date? end,
  String status = '',
  Set<String> clientIds = const {},
  Set<String> vendorIds = const {},
  Set<String> categoryIds = const {},
  Set<String> productKeys = const {},
  Set<String> tagIds = const {},
  bool includeDeleted = false,
}) => ReportQuery(
  companyId: 'co',
  now: _now,
  label: (key) => key,
  start: start,
  end: end,
  status: status,
  clientIds: clientIds,
  vendorIds: vendorIds,
  categoryIds: categoryIds,
  productKeys: productKeys,
  tagIds: tagIds,
  includeDeleted: includeDeleted,
);

/// October 2026.
ReportQuery _october({
  String status = '',
  Set<String> clientIds = const {},
  Set<String> vendorIds = const {},
  Set<String> productKeys = const {},
  Set<String> tagIds = const {},
  bool includeDeleted = false,
}) => _query(
  start: Date(2026, 10, 1),
  end: Date(2026, 10, 31),
  status: status,
  clientIds: clientIds,
  vendorIds: vendorIds,
  productKeys: productKeys,
  tagIds: tagIds,
  includeDeleted: includeDeleted,
);

Credit _credit(
  String id, {
  String date = '2026-10-10',
  String clientId = 'c1',
  String status = '2',
  bool inclusive = false,
  String exchangeRate = '1',
  bool isDeleted = false,
  List<Map<String, dynamic>> items = const [],
  List<Map<String, dynamic>> tags = const [],
}) => Credit.fromApi(
  CreditApi.fromJson({
    'id': id,
    'number': 'CR-$id',
    'date': date,
    'client_id': clientId,
    'status_id': status,
    'uses_inclusive_taxes': inclusive,
    'exchange_rate': exchangeRate,
    'is_deleted': isDeleted,
    'line_items': items,
    'tags': tags,
  }),
);

Map<String, dynamic> _item({
  String productKey = 'widget',
  String notes = '',
  String cost = '50',
  String quantity = '2',
  String productCost = '0',
  String taxName = '',
  String taxRate = '0',
}) => {
  'product_key': productKey,
  'notes': notes,
  'cost': cost,
  'quantity': quantity,
  'product_cost': productCost,
  'tax_name1': taxName,
  'tax_rate1': taxRate,
};

Client _client(
  String id, {
  String name = 'Acme',
  String currencyId = '1',
  bool isDeleted = false,
  int archivedAt = 0,
}) => Client.fromApi(
  ClientApi.fromJson({
    'id': id,
    'name': name,
    'display_name': name,
    'number': 'N-$id',
    'currency_id': currencyId,
    'is_deleted': isDeleted,
    'archived_at': archivedAt,
    'contacts': [
      {'id': 'k1', 'email': 'billing@acme.test', 'is_primary': true},
    ],
  }),
);

ReportLookups _creditLookups(List<Client> clients) => ReportLookups(
  names: {
    'client': {for (final c in clients) c.id: c.displayName},
  },
  extra: {
    'client': {for (final c in clients) c.id: c},
  },
  currencies: {'1': _usd, '3': _eur},
  companyCurrencyId: '1',
);

RecurringExpense _recurring(
  String id, {
  String nextSendDate = '2026-10-20',
  String vendorId = '',
  String categoryId = '',
  String statusId = '2',
  String lastSentDate = '2026-09-20',
  int remainingCycles = -1,
  String amount = '100',
  String currencyId = '',
  String frequencyId = '5',
  bool isDeleted = false,
}) => RecurringExpense.fromApi(
  RecurringExpenseApi.fromJson({
    'id': id,
    'number': 'RE-$id',
    'next_send_date': nextSendDate,
    'last_sent_date': lastSentDate,
    'vendor_id': vendorId,
    'category_id': categoryId,
    'status_id': statusId,
    'remaining_cycles': remainingCycles,
    'amount': amount,
    'currency_id': currencyId,
    'frequency_id': frequencyId,
    'is_deleted': isDeleted,
  }),
);

BankTransaction _tx(
  String id, {
  String date = '2026-10-05',
  String amount = '100',
  String baseType = 'CREDIT',
  String statusId = '1',
  String invoiceIds = '',
  String expenseId = '',
  String bankAccountId = '',
  bool isDeleted = false,
}) => BankTransaction.fromApi(
  BankTransactionApi(
    id: id,
    date: date,
    amount: amount,
    baseType: baseType,
    statusId: statusId,
    invoiceIds: invoiceIds,
    expenseId: expenseId,
    bankIntegrationId: bankAccountId,
    currencyId: '1',
    isDeleted: isDeleted,
  ),
);

int _col(ReportPreview p, String id) =>
    p.columns.indexWhere((c) => c.identifier == id);

ReportCell _cell(ReportPreview p, int row, String id) =>
    p.rows[row].cells[_col(p, id)];

Decimal? _money(ReportPreview p, int row, String id) =>
    (_cell(p, row, id) as ReportNumberCell).value;

String? _text(ReportPreview p, int row, String id) =>
    (_cell(p, row, id) as ReportStringCell).value;

void main() {
  group('buildCreditItemsPreview', () {
    test('a row per line item, each carrying its credit', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit(
            'a',
            items: [
              _item(productKey: 'widget'),
              _item(productKey: 'gadget', cost: '10', quantity: '1'),
            ],
          ),
        ],
        query: _october(),
        lookups: _creditLookups([_client('c1')]),
      );
      expect(p.rows, hasLength(2));
      expect(_text(p, 0, 'item.product_key'), 'widget');
      expect(_text(p, 1, 'item.product_key'), 'gadget');
      for (final row in p.rows) {
        // Each line opens its credit, and is counted under it.
        expect(row.recordWire, 'credit');
        expect(row.recordId, 'a');
        expect(row.currencyId, '1');
      }
      expect(_text(p, 0, 'credit.number'), 'CR-a');
      expect(_text(p, 0, 'client.name'), 'Acme');
      expect(_text(p, 0, 'client.currency_id'), 'USD');
      expect(_text(p, 0, 'contact.email'), 'billing@acme.test');
    });

    test('exclusive tax: the line total is net, the gross adds the tax', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit(
            'a',
            items: [
              _item(
                cost: '50',
                quantity: '2',
                taxName: 'VAT',
                taxRate: '10',
                productCost: '30',
              ),
            ],
          ),
        ],
        query: _october(),
        lookups: _creditLookups([_client('c1')]),
      );
      expect(_money(p, 0, 'item.line_total'), Decimal.parse('100'));
      expect(_money(p, 0, 'item.tax_amount'), Decimal.parse('10'));
      expect(_money(p, 0, 'item.net_total'), Decimal.parse('100'));
      expect(_money(p, 0, 'item.gross_line_total'), Decimal.parse('110'));
      // Net less two units at their product cost.
      expect(_money(p, 0, 'item.profit'), Decimal.parse('40'));
      expect(_money(p, 0, 'item.markup'), Decimal.parse('66.67'));
      expect(_text(p, 0, 'item.tax_names'), 'VAT');
      expect(_text(p, 0, 'item.tax_rates'), '10%');
    });

    test('inclusive tax: the line total is gross, the net backs it out', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit(
            'a',
            inclusive: true,
            items: [
              _item(cost: '110', quantity: '1', taxName: 'VAT', taxRate: '10'),
            ],
          ),
        ],
        query: _october(),
        lookups: _creditLookups([_client('c1')]),
      );
      expect(_money(p, 0, 'item.line_total'), Decimal.parse('110'));
      expect(_money(p, 0, 'item.tax_amount'), Decimal.parse('10'));
      expect(_money(p, 0, 'item.net_total'), Decimal.parse('100'));
      expect(_money(p, 0, 'item.gross_line_total'), Decimal.parse('110'));
    });

    test('a credit in another currency: its lines in its own, profit in the '
        "company's", () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit(
            'a',
            exchangeRate: '2',
            items: [_item(cost: '100', quantity: '1', productCost: '30')],
          ),
        ],
        query: _october(),
        lookups: _creditLookups([_client('c1', currencyId: '3')]),
      );
      expect(p.rows.single.currencyId, '3');
      expect(_text(p, 0, 'client.currency_id'), 'EUR');
      final profit = _cell(p, 0, 'item.profit') as ReportNumberCell;
      // 100 EUR at 2 per dollar is 50 dollars, less 30 of cost.
      expect(profit.value, Decimal.parse('20'));
      expect(profit.currencyId, '1');
      expect(
        (_cell(p, 0, 'item.product_cost') as ReportNumberCell).currencyId,
        '1',
      );
    });

    test("the credit's filters: range, status, client, tags, deleted", () {
      final credits = [
        _credit('in', items: [_item()]),
        _credit('september', date: '2026-09-30', items: [_item()]),
        _credit('draft', status: '1', items: [_item()]),
        _credit('other', clientId: 'c2', items: [_item()]),
        _credit(
          'tagged',
          items: [_item()],
          tags: [
            {'id': 't1', 'name': 'x'},
          ],
        ),
        _credit('deleted', isDeleted: true, items: [_item()]),
      ];
      final lookups = _creditLookups([_client('c1'), _client('c2')]);
      List<String?> ids(ReportQuery q) => [
        for (final r in buildCreditItemsPreview(
          credits: credits,
          query: q,
          lookups: lookups,
        ).rows)
          r.recordId,
      ];
      expect(ids(_october()), ['draft', 'in', 'other', 'tagged']);
      // All time, oldest credit first.
      expect(ids(_query()), ['september', 'draft', 'in', 'other', 'tagged']);
      expect(ids(_october(status: 'draft')), ['draft']);
      expect(ids(_october(clientIds: {'c2'})), ['other']);
      expect(ids(_october(tagIds: {'t1'})), ['tagged']);
      expect(ids(_october(includeDeleted: true)), contains('deleted'));
    });

    test('a deleted client drops its credits; an archived one keeps them', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit('a', items: [_item()]),
          _credit('b', clientId: 'c2', items: [_item()]),
        ],
        query: _october(),
        lookups: _creditLookups([
          _client('c1', isDeleted: true),
          _client('c2', archivedAt: 1760000000),
        ]),
      );
      expect(p.rows.map((r) => r.recordId), ['b']);
    });

    test('the product filter keeps only the lines of that product', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit(
            'a',
            items: [
              _item(productKey: 'widget'),
              _item(productKey: 'gadget'),
            ],
          ),
        ],
        query: _october(productKeys: {'gadget'}),
        lookups: _creditLookups([_client('c1')]),
      );
      expect(p.rows, hasLength(1));
      expect(_text(p, 0, 'item.product_key'), 'gadget');
    });

    test('an unknown client reads as a dash, never an id', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit('a', clientId: 'c9', items: [_item()]),
        ],
        query: _october(),
        lookups: _creditLookups(const []),
      );
      expect(_text(p, 0, 'client.name'), '—');
      // No client: the company's currency.
      expect(p.rows.single.currencyId, '1');
    });

    test('a credit not yet on the server is not a link', () {
      final p = buildCreditItemsPreview(
        credits: [
          _credit('tmp_x', items: [_item()]),
        ],
        query: _october(),
        lookups: _creditLookups([_client('c1')]),
      );
      expect(p.rows.single.recordId, isNull);
    });

    test('a line figure is summed; a unit price, rate or markup never', () {
      // The credit's own columns are strings and dates; were one an amount,
      // `lineItemPrefix` would count it once per credit.
      final p = buildCreditItemsPreview(credits: const [], query: _october());
      ReportAggregation of(String id) =>
          p.columns[_col(p, id)].effectiveAggregation;
      expect(of('item.line_total'), ReportAggregation.sum);
      expect(of('item.quantity'), ReportAggregation.sum);
      expect(of('item.profit'), ReportAggregation.sum);
      expect(of('item.cost'), ReportAggregation.none);
      expect(of('item.discount'), ReportAggregation.none);
      expect(of('item.markup'), ReportAggregation.none);
    });

    test('fetches the credits dated in the range, of undeleted clients', () {
      expect(creditItemsFetchFilters(_october()), {
        'filter_deleted_clients': {'true'},
        'date_range': {'2026-10-01,2026-10-31'},
      });
      expect(creditItemsFetchFilters(_query()), {
        'filter_deleted_clients': {'true'},
      });
    });
  });

  group('buildRecurringExpensesPreview', () {
    final lookups = ReportLookups(
      names: const {
        'vendor': {'v1': 'Hosting Co'},
        'category': {'k1': 'Software'},
      },
      currencies: {'1': _usd, '3': _eur},
      companyCurrencyId: '1',
    );

    test('a row per recurring expense whose next run is in the range', () {
      final p = buildRecurringExpensesPreview(
        recurringExpenses: [
          _recurring('late', nextSendDate: '2026-11-02'),
          _recurring('soon', nextSendDate: '2026-10-20'),
          _recurring('first', nextSendDate: '2026-10-01'),
        ],
        query: _october(),
        lookups: lookups,
      );
      expect(p.rows.map((r) => r.recordId), ['first', 'soon']);
      expect(p.rows.first.recordWire, 'recurring_expense');
    });

    test('names, frequency, an endless schedule and a gross amount', () {
      final p = buildRecurringExpensesPreview(
        recurringExpenses: [
          _recurring('a', vendorId: 'v1', categoryId: 'k1', currencyId: '3'),
        ],
        query: _query(),
        lookups: lookups,
      );
      expect(_text(p, 0, 'vendor.name'), 'Hosting Co');
      expect(_text(p, 0, 'recurring_expense.category_id'), 'Software');
      expect(_text(p, 0, 'recurring_expense.frequency_id'), 'freq_monthly');
      final cycles =
          _cell(p, 0, 'recurring_expense.remaining_cycles') as ReportNumberCell;
      expect(cycles.value, isNull);
      expect(cycles.displayValue, 'endless');
      expect(_money(p, 0, 'recurring_expense.amount'), Decimal.parse('100'));
      expect(p.rows.single.currencyId, '3');
      expect(_text(p, 0, 'recurring_expense.currency_id'), 'EUR');
      expect(
        p
            .columns[_col(p, 'recurring_expense.remaining_cycles')]
            .effectiveAggregation,
        ReportAggregation.none,
      );
    });

    test('the status is the one the list shows, Pending included', () {
      final pending = _recurring('p', lastSentDate: '');
      final paused = _recurring('z', statusId: '3');
      List<String?> ids(String status) => [
        for (final r in buildRecurringExpensesPreview(
          recurringExpenses: [pending, paused],
          query: _query(status: status),
          lookups: lookups,
        ).rows)
          r.recordId,
      ];
      expect(ids('pending'), ['p']);
      expect(ids('paused'), ['z']);
      expect(ids(''), hasLength(2));
    });

    test('vendor filter and deleted rows', () {
      final p = buildRecurringExpensesPreview(
        recurringExpenses: [
          _recurring('a', vendorId: 'v1'),
          _recurring('b', vendorId: 'v2'),
          _recurring('c', vendorId: 'v1', isDeleted: true),
        ],
        query: _query(vendorIds: {'v1'}),
        lookups: lookups,
      );
      expect(p.rows.map((r) => r.recordId), ['a']);
    });

    test('fetches by the next send date the API returns', () {
      expect(recurringExpensesFetchFilters(_october()), {
        'date_range': {'next_send_date_client,2026-10-01,2026-10-31'},
      });
      expect(recurringExpensesFetchFilters(_query()), isEmpty);
    });
  });

  group('buildTransactionsPreview', () {
    final lookups = ReportLookups(
      names: const {
        'invoice': {'i1': 'INV-1', 'i2': 'INV-2'},
        'expense': {'e1': 'EXP-1'},
        'bank_account': {'b1': 'Checking'},
      },
      currencies: {'1': _usd},
      companyCurrencyId: '1',
    );

    test('money in is a deposit, money out a withdrawal', () {
      final p = buildTransactionsPreview(
        transactions: [
          _tx('in', amount: '100', baseType: 'CREDIT'),
          _tx('out', date: '2026-10-06', amount: '40', baseType: 'DEBIT'),
        ],
        query: _october(),
        lookups: lookups,
      );
      expect(_money(p, 0, 'bank_transaction.deposit'), Decimal.parse('100'));
      expect(_money(p, 0, 'bank_transaction.withdrawal'), isNull);
      expect(_money(p, 1, 'bank_transaction.deposit'), isNull);
      expect(_money(p, 1, 'bank_transaction.withdrawal'), Decimal.parse('40'));
      expect(p.rows.first.recordWire, 'bank_transaction');
      expect(p.rows.first.currencyId, '1');
      // Unsigned in both directions: never totalled.
      expect(
        p.columns[_col(p, 'bank_transaction.amount')].effectiveAggregation,
        ReportAggregation.none,
      );
    });

    test('linked records read as their numbers', () {
      final p = buildTransactionsPreview(
        transactions: [
          _tx(
            'a',
            statusId: '2',
            invoiceIds: 'i1,i2',
            expenseId: 'e1',
            bankAccountId: 'b1',
          ),
        ],
        query: _october(),
        lookups: lookups,
      );
      expect(_text(p, 0, 'bank_transaction.invoices'), 'INV-1, INV-2');
      expect(_text(p, 0, 'bank_transaction.expense_number'), 'EXP-1');
      expect(_text(p, 0, 'bank_account.name'), 'Checking');
      expect(_text(p, 0, 'bank_transaction.status'), 'matched');
    });

    test('range, status and deleted rows', () {
      final txs = [
        _tx('a'),
        _tx('b', statusId: '3'),
        _tx('c', date: '2026-09-30'),
        _tx('d', isDeleted: true),
      ];
      List<String?> ids(ReportQuery q) => [
        for (final r in buildTransactionsPreview(
          transactions: txs,
          query: q,
          lookups: lookups,
        ).rows)
          r.recordId,
      ];
      expect(ids(_october()), ['a', 'b']);
      expect(ids(_october(status: 'converted')), ['b']);
      expect(ids(_query()), ['c', 'a', 'b']);
      expect(ids(_october(includeDeleted: true)), ['a', 'b', 'd']);
    });

    test('fetches the transactions dated in the range', () {
      expect(transactionsFetchFilters(_october()), {
        'date_range': {'2026-10-01,2026-10-31'},
      });
      expect(transactionsFetchFilters(_query()), isEmpty);
    });
  });

  group('every header of a report built on the device is its own', () {
    test('each column has a label key and a type', () {
      for (final p in [
        buildCreditItemsPreview(credits: const [], query: _query()),
        buildRecurringExpensesPreview(
          recurringExpenses: const [],
          query: _query(),
        ),
        buildTransactionsPreview(transactions: const [], query: _query()),
      ]) {
        expect(
          p.columns.map((c) => c.identifier).toSet(),
          hasLength(p.columns.length),
        );
        for (final c in p.columns) {
          expect(c.displayLabel, isNotEmpty, reason: c.identifier);
        }
      }
    });
  });

  group('RecordReportSource.refresh', () {
    RecordReportSource<String> source({
      required List<int> pages,
      List<Map<String, Set<String>>>? filters,
      List<Set<EntityState>>? states,
      int pagesBeforeEnd = 2,
      Object? failure,
      Map<String, Set<String>> Function()? missing,
      Future<void> Function(Map<String, Set<String>>)? hydrate,
      List<String> records = const ['r1'],
    }) => RecordReportSource<String>(
      name: 'test',
      fetchPage: (companyId, page, s, f) async {
        pages.add(page);
        filters?.add(f);
        states?.add(s);
        if (failure != null) throw failure;
        return page < pagesBeforeEnd;
      },
      fetchFilters: (q) => {
        'date_range': {'${q.start?.toIso()},${q.end?.toIso()}'},
      },
      readRecords: (q, s) async => records,
      readLookups: (companyId, records) async => const ReportLookups(),
      build: (records, q, lookups) => ReportPreview(
        columns: const [],
        rows: [for (final _ in records) const ReportRow(cells: [])],
      ),
      namesToFetch: missing == null ? null : (r, q, l) => missing(),
      hydrateNames: hydrate == null ? null : (c, ids) => hydrate(ids),
    );

    test(
      'pages until the server says no more, then reads the device',
      () async {
        final pages = <int>[];
        final filters = <Map<String, Set<String>>>[];
        final states = <Set<EntityState>>[];
        final p = await source(
          pages: pages,
          filters: filters,
          states: states,
          pagesBeforeEnd: 3,
        ).refresh(_october());
        expect(pages, [1, 2, 3]);
        expect(filters.first, {
          'date_range': {'2026-10-01,2026-10-31'},
        });
        expect(states.first, {EntityState.active, EntityState.archived});
        expect(p.rows, hasLength(1));
      },
    );

    test('deleted records are fetched only when asked for', () async {
      final states = <Set<EntityState>>[];
      await source(
        pages: [],
        states: states,
      ).refresh(_october(includeDeleted: true));
      expect(states.first, contains(EntityState.deleted));
    });

    test('a cancelled refresh spends no request', () async {
      final pages = <int>[];
      await expectLater(
        source(pages: pages).refresh(_october(), isCancelled: () => true),
        throwsA(
          isA<ReportError>().having(
            (e) => e.kind,
            'kind',
            ReportErrorKind.cancelled,
          ),
        ),
      );
      expect(pages, isEmpty);
    });

    test('a company switched mid-fetch is a cancel, not a failure', () async {
      await expectLater(
        source(
          pages: [],
          failure: const CompanySwitchedException(
            expected: 'co',
            active: 'other',
            entityType: 'credit',
          ),
        ).refresh(_october()),
        throwsA(
          isA<ReportError>().having(
            (e) => e.kind,
            'kind',
            ReportErrorKind.cancelled,
          ),
        ),
      );
    });

    test(
      'a server that never stops is an error, not a quiet partial',
      () async {
        final pages = <int>[];
        await expectLater(
          source(pages: pages, pagesBeforeEnd: 1 << 30).refresh(_october()),
          throwsA(isA<ReportError>()),
        );
        expect(pages.length, kRecordReportMaxPages);
      },
    );

    test(
      'fetches the names the rows lack, capped, and never fails on them',
      () async {
        Map<String, Set<String>>? asked;
        await source(
          pages: [],
          missing: () => {
            'client': {for (var i = 0; i < 300; i++) 'c$i'},
            'vendor': const {},
          },
          hydrate: (ids) async {
            asked = ids;
            throw StateError('offline');
          },
        ).refresh(_october());
        expect(asked!.keys, ['client']);
        expect(asked!['client'], hasLength(kRecordReportMaxNameFetches));
      },
    );

    test('reading from the device alone fetches nothing', () async {
      final pages = <int>[];
      var hydrated = false;
      final p = await source(
        pages: pages,
        missing: () => {
          'client': {'c1'},
        },
        hydrate: (_) async => hydrated = true,
      ).fromDevice(_october());
      expect(pages, isEmpty);
      expect(hydrated, isFalse);
      expect(p.rows, hasLength(1));
    });
  });

  group('creditItemsReportSource', () {
    test('sweeps narrowed, keeps archived clients, resolves offline ids, '
        'and fetches the clients it cannot name', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.idRemapDao.remember(
        entityType: 'client',
        tempId: 'tmp_c',
        realId: 'c1',
        now: 0,
      );
      final credits = _Credits([
        _credit('a', clientId: 'tmp_c', items: [_item()]),
      ]);
      final clients = _Clients();
      final source = creditItemsReportSource(
        credits: credits,
        clients: clients,
        idRemap: db.idRemapDao,
        currencies: () => {'1': _usd},
        companyCurrencyId: () async => '1',
      );
      final p = await source.refresh(_october(includeDeleted: true));

      final page = credits.pages.single;
      expect(page.namedArguments[#ignoreCursor], isTrue);
      expect(page.namedArguments[#excludeDeletedClients], isFalse);
      expect(page.namedArguments[#extraFilters], {
        'filter_deleted_clients': {'true'},
        'date_range': {'2026-10-01,2026-10-31'},
      });
      expect(page.namedArguments[#states], {
        EntityState.active,
        EntityState.archived,
        EntityState.deleted,
      });
      // The device is read with the range, every row of it.
      final read = credits.reads.single;
      expect(read.namedArguments[#extraFilters], {
        'date_range': {'date,2026-10-01,2026-10-31'},
      });
      expect(read.namedArguments[#loadedPages], kRecordReportAllPages);
      // The offline id is looked up — and fetched — as the real one.
      expect(clients.lookedUp.first, ['c1']);
      expect(clients.refetched, ['c1']);
      expect(p.rows, hasLength(1));
    });
  });
}

class _Credits implements CreditRepository {
  _Credits(this.held);
  final List<Credit> held;
  final List<Invocation> pages = [];
  final List<Invocation> reads = [];

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #ensurePageLoaded) {
      pages.add(i);
      return Future<bool>.value(false);
    }
    if (i.memberName == #watchPage) {
      reads.add(i);
      return Stream<List<Credit>>.value(held);
    }
    return super.noSuchMethod(i);
  }
}

class _Clients implements ClientRepository {
  final List<List<String>> lookedUp = [];
  final List<String> refetched = [];

  @override
  dynamic noSuchMethod(Invocation i) {
    final ids = i.namedArguments[#ids] as Iterable<String>?;
    if (i.memberName == #getByIds) {
      lookedUp.add([...?ids]);
      return Future.value(const <Client>[]);
    }
    if (i.memberName == #ensureLoaded) {
      refetched.add(i.namedArguments[#id] as String);
      return Future.value(EnsureLoadedOutcome.fetched);
    }
    return super.noSuchMethod(i);
  }
}
