import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/_search_fold.dart';

/// invoiceninja/flutter#185: the server's search on all five billing documents
/// matches line items' `notes` and `product_key`, while the local search the
/// lists render from left them out — so a document found through a line item
/// was fetched and then hidden. `lineItemSearchMatches` puts them back.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  String withItems(List<Object?> items) => jsonEncode({'line_items': items});

  group('lineItemSearchMatches', () {
    Future<bool> matches(String payload, String search) async {
      final expr = lineItemSearchMatches(
        payload: Variable.withString(payload),
        search: search,
      );
      final row = await db.selectExpressions([expr]).getSingle();
      return row.read(expr) ?? false;
    }

    test("matches an item's description and its product key", () async {
      final p = withItems([
        {'product_key': 'SKU-42', 'notes': 'Window replacement'},
      ]);
      expect(await matches(p, 'window'), isTrue);
      expect(await matches(p, 'sku-4'), isTrue);
      expect(await matches(p, 'door'), isFalse);
    });

    test('folds case and accents like every local search', () async {
      final p = withItems([
        {'notes': 'MÜLLER Straße'},
        {'notes': 'Müller decomposed'},
      ]);
      expect(await matches(p, 'muller'), isTrue);
      expect(await matches(p, 'strasse'), isTrue);
      expect(
        await matches(
          withItems([
            {'notes': 'plain'},
          ]),
          'PLAIN',
        ),
        isTrue,
      );
    });

    test('never matches across two items or two fields', () async {
      final items = withItems([
        {'notes': 'alpha'},
        {'notes': 'beta'},
      ]);
      expect(await matches(items, 'alphabeta'), isFalse);
      expect(await matches(items, 'alpha beta'), isFalse);
      final fields = withItems([
        {'product_key': 'SKU1', 'notes': 'Widget'},
      ]);
      expect(await matches(fields, 'SKU1Widget'), isFalse);
      expect(await matches(fields, 'Widget SKU1'), isFalse);
    });

    test('only notes and product_key, and only inside line_items', () async {
      final p = jsonEncode({
        'product_key': 'TOPLEVEL',
        'line_items': [
          {'custom_value1': 'custom', 'tax_name1': 'VAT', 'notes': 'n'},
        ],
      });
      expect(await matches(p, 'custom'), isFalse);
      expect(await matches(p, 'VAT'), isFalse);
      expect(await matches(p, 'TOPLEVEL'), isFalse);
    });

    test('any other shape matches nothing, and never throws', () async {
      for (final p in [
        '',
        'not json',
        '[1,2]',
        '{}',
        '{"line_items":null}',
        '{"line_items":"window"}',
        withItems([1, 'window', null]),
        withItems([
          {'notes': null},
        ]),
      ]) {
        expect(await matches(p, 'window'), isFalse, reason: p);
      }
    });

    test('a numeric product key matches as text', () async {
      expect(
        await matches(
          withItems([
            {'product_key': 12345},
          ]),
          '234',
        ),
        isTrue,
      );
    });

    test('quotes and wildcards are literals', () async {
      final p = withItems([
        {'notes': '500 units'},
      ]);
      expect(await matches(p, "x' OR '1'='1"), isFalse);
      expect(await matches(p, '50%'), isFalse);
      expect(
        await matches(
          withItems([
            {'notes': '50% off'},
          ]),
          '50%',
        ),
        isTrue,
      );
    });
  });

  // Every billing list, through its own `watchPage(search:)`.
  final daos =
      <
        ({
          String name,
          Future<void> Function(
            String id,
            String payload, {
            String company,
            String number,
            String poNumber,
            String custom1,
          })
          insert,
          Future<List<String>> Function(String search) search,
        })
      >[
        (
          name: 'invoices',
          insert:
              (
                id,
                payload, {
                company = 'co',
                number = '',
                poNumber = '',
                custom1 = '',
              }) => db.invoiceDao.upsert(
                InvoicesCompanion.insert(
                  id: id,
                  companyId: company,
                  updatedAt: 1,
                  payload: payload,
                  number: Value(number),
                  poNumber: Value(poNumber),
                  customValue1: Value(custom1),
                ),
              ),
          search: (s) => db.invoiceDao
              .watchPage(companyId: 'co', offset: 0, limit: 50, search: s)
              .first
              .then((r) => r.map((e) => e.id).toList()..sort()),
        ),
        (
          name: 'quotes',
          insert:
              (
                id,
                payload, {
                company = 'co',
                number = '',
                poNumber = '',
                custom1 = '',
              }) => db.quoteDao.upsert(
                QuotesCompanion.insert(
                  id: id,
                  companyId: company,
                  updatedAt: 1,
                  payload: payload,
                  number: Value(number),
                  poNumber: Value(poNumber),
                  customValue1: Value(custom1),
                ),
              ),
          search: (s) => db.quoteDao
              .watchPage(companyId: 'co', offset: 0, limit: 50, search: s)
              .first
              .then((r) => r.map((e) => e.id).toList()..sort()),
        ),
        (
          name: 'credits',
          insert:
              (
                id,
                payload, {
                company = 'co',
                number = '',
                poNumber = '',
                custom1 = '',
              }) => db.creditDao.upsert(
                CreditsCompanion.insert(
                  id: id,
                  companyId: company,
                  updatedAt: 1,
                  payload: payload,
                  number: Value(number),
                  poNumber: Value(poNumber),
                  customValue1: Value(custom1),
                ),
              ),
          search: (s) => db.creditDao
              .watchPage(companyId: 'co', offset: 0, limit: 50, search: s)
              .first
              .then((r) => r.map((e) => e.id).toList()..sort()),
        ),
        (
          name: 'recurring invoices',
          insert:
              (
                id,
                payload, {
                company = 'co',
                number = '',
                poNumber = '',
                custom1 = '',
              }) => db.recurringInvoiceDao.upsert(
                RecurringInvoicesCompanion.insert(
                  id: id,
                  companyId: company,
                  updatedAt: 1,
                  payload: payload,
                  number: Value(number),
                  poNumber: Value(poNumber),
                  customValue1: Value(custom1),
                ),
              ),
          search: (s) => db.recurringInvoiceDao
              .watchPage(companyId: 'co', offset: 0, limit: 50, search: s)
              .first
              .then((r) => r.map((e) => e.id).toList()..sort()),
        ),
        (
          name: 'purchase orders',
          insert:
              (
                id,
                payload, {
                company = 'co',
                number = '',
                poNumber = '',
                custom1 = '',
              }) => db.purchaseOrderDao.upsert(
                PurchaseOrdersCompanion.insert(
                  id: id,
                  companyId: company,
                  updatedAt: 1,
                  payload: payload,
                  number: Value(number),
                  poNumber: Value(poNumber),
                  customValue1: Value(custom1),
                ),
              ),
          search: (s) => db.purchaseOrderDao
              .watchPage(companyId: 'co', offset: 0, limit: 50, search: s)
              .first
              .then((r) => r.map((e) => e.id).toList()..sort()),
        ),
      ];

  for (final dao in daos) {
    group('the ${dao.name} list', () {
      setUp(() async {
        await dao.insert(
          'a',
          withItems([
            {'product_key': 'GLASS-9', 'notes': 'Replaced the Fenster'},
          ]),
        );
        await dao.insert('b', withItems([]));
        await dao.insert('c', '{}');
        await dao.insert('d', '{"line_items":null}');
        await dao.insert(
          'e',
          withItems([
            {'notes': 'Wäsche'},
          ]),
          number: 'INV-77',
          poNumber: 'PO-55',
          custom1: 'Blue',
        );
        await dao.insert(
          'other-company',
          withItems([
            {'notes': 'Replaced the Fenster'},
          ]),
          company: 'co2',
        );
      });

      test('finds a document by a line item description', () async {
        expect(await dao.search('fenster'), ['a']);
      });

      test('finds a document by a line item product key', () async {
        expect(await dao.search('glass-9'), ['a']);
      });

      test('folds accents in line items', () async {
        expect(await dao.search('wasche'), ['e']);
      });

      test('a term in no field matches nothing', () async {
        expect(await dao.search('nothing-here'), isEmpty);
      });

      test('the fields it already searched still match', () async {
        expect(await dao.search('INV-77'), ['e']);
        expect(await dao.search('PO-55'), ['e']);
        expect(await dao.search('blue'), ['e']);
      });
    });
  }
}
