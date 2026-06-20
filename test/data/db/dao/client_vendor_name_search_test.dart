import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// Regression coverage for local client/vendor-name search across the
/// billing-style list DAOs. The server's free-text `filter=` matches the
/// related client/vendor name, but the local Drift `watchPage` predicate used
/// to match only the entity's own columns — so the server's name matches got
/// filtered back out and e.g. searching invoices by client name showed
/// nothing. `clientNameMatchesFilter` / `vendorNameMatchesFilter`
/// (base_entity_dao.dart) now mirror the server, per its parity matrix.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ClientsCompanion client({required String id, required String name}) =>
      ClientsCompanion.insert(
        id: id,
        companyId: 'co',
        name: name,
        number: '',
        email: '',
        displayName: name,
        balance: '0',
        updatedAt: 1,
        payload: '{}',
      );

  VendorsCompanion vendor({required String id, required String name}) =>
      VendorsCompanion.insert(
        id: id,
        companyId: 'co',
        name: name,
        number: '',
        idNumber: '',
        vatNumber: '',
        city: '',
        countryId: '',
        currencyId: '',
        phone: '',
        displayName: name,
        updatedAt: 1,
        payload: '{}',
      );

  Future<List<String>> ids(Stream<List<dynamic>> stream) => stream.first.then(
    (rows) => rows.map((r) => r.id as String).toList()..sort(),
  );

  group('invoice search by client name', () {
    setUp(() async {
      await db.clientDao.upsert(client(id: 'c1', name: 'Acme Corp'));
      await db.clientDao.upsert(client(id: 'c2', name: 'Zenith LLC'));
      await db.vendorDao.upsert(vendor(id: 'v1', name: 'Globex'));
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'inv-acme',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          number: const Value('INV-1'),
          clientId: const Value('c1'),
        ),
      );
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'inv-zen',
          companyId: 'co',
          updatedAt: 2,
          payload: '{}',
          number: const Value('INV-2'),
          clientId: const Value('c2'),
        ),
      );
    });

    Future<List<String>> search(String term) => ids(
      db.invoiceDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    test('matches the related client name (the reported bug)', () async {
      expect(await search('acme'), ['inv-acme']);
      expect(await search('zenith'), ['inv-zen']);
    });

    test('own-column search still works', () async {
      expect(await search('INV-1'), ['inv-acme']);
    });

    test('does NOT match vendor name (server matches client only)', () async {
      expect(await search('globex'), isEmpty);
    });

    test('non-matching term returns nothing', () async {
      expect(await search('nobody'), isEmpty);
    });
  });

  test('purchase order search matches vendor name, not client', () async {
    await db.clientDao.upsert(client(id: 'c1', name: 'Acme Corp'));
    await db.vendorDao.upsert(vendor(id: 'v1', name: 'Globex'));
    await db.purchaseOrderDao.upsert(
      PurchaseOrdersCompanion.insert(
        id: 'po-glob',
        companyId: 'co',
        updatedAt: 1,
        payload: '{}',
        number: const Value('PO-1'),
        vendorId: const Value('v1'),
      ),
    );

    Future<List<String>> search(String term) => ids(
      db.purchaseOrderDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    expect(await search('globex'), ['po-glob']);
    expect(await search('PO-1'), ['po-glob']);
    expect(await search('acme'), isEmpty);
  });

  test('expense search matches both client and vendor name', () async {
    await db.clientDao.upsert(client(id: 'c1', name: 'Acme Corp'));
    await db.vendorDao.upsert(vendor(id: 'v1', name: 'Globex'));
    await db.expenseDao.upsert(
      ExpensesCompanion.insert(
        id: 'exp-client',
        companyId: 'co',
        updatedAt: 1,
        payload: '{}',
        clientId: const Value('c1'),
      ),
    );
    await db.expenseDao.upsert(
      ExpensesCompanion.insert(
        id: 'exp-vendor',
        companyId: 'co',
        updatedAt: 2,
        payload: '{}',
        vendorId: const Value('v1'),
      ),
    );

    Future<List<String>> search(String term) => ids(
      db.expenseDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    expect(await search('acme'), ['exp-client']);
    expect(await search('globex'), ['exp-vendor']);
  });
}
