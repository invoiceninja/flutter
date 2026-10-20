import 'dart:convert';

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

  ClientsCompanion client({
    required String id,
    required String name,
    String idNumber = '',
    String customValue1 = '',
    String payload = '{}',
  }) => ClientsCompanion.insert(
    id: id,
    companyId: 'co',
    name: name,
    number: '',
    email: '',
    displayName: name,
    balance: '0',
    updatedAt: 1,
    payload: payload,
    idNumber: Value(idNumber),
    customValue1: Value(customValue1),
  );

  VendorsCompanion vendor({
    required String id,
    required String name,
    String idNumber = '',
    String customValue1 = '',
    String payload = '{}',
  }) => VendorsCompanion.insert(
    id: id,
    companyId: 'co',
    name: name,
    number: '',
    idNumber: idNumber,
    vatNumber: '',
    city: '',
    countryId: '',
    currencyId: '',
    phone: '',
    displayName: name,
    updatedAt: 1,
    payload: payload,
    customValue1: Value(customValue1),
  );

  ExpenseCategoriesCompanion category({
    required String id,
    required String name,
  }) => ExpenseCategoriesCompanion.insert(
    id: id,
    companyId: 'co',
    updatedAt: 1,
    payload: '{}',
    name: Value(name),
  );

  ProjectsCompanion project({required String id, required String name}) =>
      ProjectsCompanion.insert(
        id: id,
        companyId: 'co',
        updatedAt: 1,
        payload: '{}',
        name: Value(name),
      );

  TasksCompanion taskRow({
    required String id,
    String number = '',
    String description = '',
    String clientId = '',
    String projectId = '',
    String customValue1 = '',
  }) => TasksCompanion.insert(
    id: id,
    companyId: 'co',
    updatedAt: 1,
    payload: '{}',
    taskNumber: Value(number),
    description: Value(description),
    clientId: Value(clientId),
    projectId: Value(projectId),
    customValue1: Value(customValue1),
  );

  Future<List<String>> ids(Stream<List<dynamic>> stream) => stream.first.then(
    (rows) => rows.map((r) => r.id as String).toList()..sort(),
  );

  group('invoice search mirrors the server field set', () {
    setUp(() async {
      await db.clientDao.upsert(client(id: 'c1', name: 'Acme Corp'));
      await db.clientDao.upsert(client(id: 'c2', name: 'Zenith LLC'));
      await db.vendorDao.upsert(vendor(id: 'v1', name: 'Globex'));
      await db.projectDao.upsert(project(id: 'p1', name: 'Apollo Redesign'));
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
      // Matches ONLY via a custom field value (server matches custom_value1-4).
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'inv-cf',
          companyId: 'co',
          updatedAt: 3,
          payload: '{}',
          number: const Value('INV-3'),
          customValue1: const Value('urgent-flag'),
        ),
      );
      // Matches ONLY via the related project name (server matches project.name).
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'inv-proj',
          companyId: 'co',
          updatedAt: 4,
          payload: '{}',
          number: const Value('INV-4'),
          projectId: const Value('p1'),
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

    test('matches a custom field value', () async {
      expect(await search('urgent-flag'), ['inv-cf']);
    });

    test('matches the related project name', () async {
      expect(await search('apollo'), ['inv-proj']);
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

  test('client search matches id_number and custom fields', () async {
    await db.clientDao.upsert(
      client(id: 'c-id', name: 'Acme Corp', idNumber: 'REG-9981'),
    );
    await db.clientDao.upsert(
      client(id: 'c-cf', name: 'Zenith LLC', customValue1: 'vip-account'),
    );

    Future<List<String>> search(String term) => ids(
      db.clientDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    expect(await search('REG-9981'), ['c-id']);
    expect(await search('vip-account'), ['c-cf']);
    expect(await search('acme'), ['c-id']);
  });

  test('vendor search matches id_number and custom fields', () async {
    await db.vendorDao.upsert(
      vendor(id: 'v-id', name: 'Globex', idNumber: 'VREG-42'),
    );
    await db.vendorDao.upsert(
      vendor(id: 'v-cf', name: 'Initech', customValue1: 'preferred'),
    );

    Future<List<String>> search(String term) => ids(
      db.vendorDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    expect(await search('VREG-42'), ['v-id']);
    expect(await search('preferred'), ['v-cf']);
    expect(await search('globex'), ['v-id']);
  });

  test('product search matches custom fields', () async {
    await db.productDao.upsert(
      ProductsCompanion.insert(
        id: 'prod-cf',
        companyId: 'co',
        updatedAt: 1,
        payload: '{}',
        productKey: 'WIDGET-1',
        notes: '',
        price: '0',
        cost: '0',
        quantity: '0',
        customValue1: const Value('clearance'),
      ),
    );

    Future<List<String>> search(String term) => ids(
      db.productDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    expect(await search('clearance'), ['prod-cf']);
    expect(await search('WIDGET-1'), ['prod-cf']);
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

  test(
    'expense search matches client, vendor, category and custom fields',
    () async {
      await db.clientDao.upsert(client(id: 'c1', name: 'Acme Corp'));
      await db.vendorDao.upsert(vendor(id: 'v1', name: 'Globex'));
      await db.expenseCategoryDao.upsert(category(id: 'cat1', name: 'Travel'));
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
      // Matches ONLY via the related category name (server matches category.name).
      await db.expenseDao.upsert(
        ExpensesCompanion.insert(
          id: 'exp-cat',
          companyId: 'co',
          updatedAt: 3,
          payload: '{}',
          categoryId: const Value('cat1'),
        ),
      );
      // Matches ONLY via a custom field value.
      await db.expenseDao.upsert(
        ExpensesCompanion.insert(
          id: 'exp-cf',
          companyId: 'co',
          updatedAt: 4,
          payload: '{}',
          customValue1: const Value('reimbursable'),
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
      expect(await search('travel'), ['exp-cat']);
      expect(await search('reimbursable'), ['exp-cf']);
    },
  );

  group('task search mirrors the server field set', () {
    setUp(() async {
      await db.clientDao.upsert(client(id: 'c1', name: 'Acme Corp'));
      await db.projectDao.upsert(project(id: 'p1', name: 'Apollo Redesign'));
      // Matches ONLY via project name — the server matches `project.name`, and
      // the local watch used to filter that match back out (the reported bug).
      await db.taskDao.upsert(
        taskRow(id: 't-proj', number: 'T-1', projectId: 'p1'),
      );
      // Matches ONLY via a custom field value.
      await db.taskDao.upsert(
        taskRow(id: 't-cf', number: 'T-2', customValue1: 'urgent-flag'),
      );
      // Matches on its own number / description columns.
      await db.taskDao.upsert(
        taskRow(id: 't-own', number: 'T-3', description: 'Fix the login bug'),
      );
      // Matches on the related client name.
      await db.taskDao.upsert(
        taskRow(id: 't-client', number: 'T-4', clientId: 'c1'),
      );
    });

    Future<List<String>> search(String term) => ids(
      db.taskDao.watchPage(companyId: 'co', offset: 0, limit: 50, search: term),
    );

    test('matches the related project name (the reported bug)', () async {
      expect(await search('apollo'), ['t-proj']);
    });

    test('matches a custom field value', () async {
      expect(await search('urgent-flag'), ['t-cf']);
    });

    test('own number / description columns still match', () async {
      expect(await search('T-3'), ['t-own']);
      expect(await search('login'), ['t-own']);
    });

    test('matches the related client name', () async {
      expect(await search('acme'), ['t-client']);
    });

    test('non-matching term returns nothing', () async {
      expect(await search('nobody'), isEmpty);
    });
  });

  // SQLite folds case for ASCII only, so these all failed before
  // `searchLike` — the reported "searching for Müller doesn't always work".
  group('umlauts and contacts match like the server', () {
    String contacts(List<Map<String, String>> list) =>
        jsonEncode({'contacts': list});

    setUp(() async {
      await db.clientDao.upsert(client(id: 'c-ue', name: 'Überseehandel'));
      await db.clientDao.upsert(client(id: 'c-mu', name: 'Hans Müller'));
      await db.clientDao.upsert(
        client(
          id: 'c-contact',
          name: 'Acme Corp',
          payload: contacts([
            {
              'first_name': 'Jürgen',
              'last_name': 'Schmidt',
              'email': 'js@example.com',
              'phone': '+49 30 1234',
            },
          ]),
        ),
      );
      await db.clientDao.upsert(
        client(id: 'c-bad', name: 'Broken', payload: 'not json'),
      );
      await db.vendorDao.upsert(
        vendor(
          id: 'v-contact',
          name: 'Globex',
          payload: contacts([
            {'first_name': 'Jörg', 'last_name': 'Öztürk', 'email': ''},
          ]),
        ),
      );
      await db.clientDao.upsert(client(id: 'c-oe', name: 'Österreich AG'));
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'inv-oe',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          number: const Value('INV-1'),
          clientId: const Value('c-oe'),
        ),
      );
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'inv-contact',
          companyId: 'co',
          updatedAt: 2,
          payload: '{}',
          number: const Value('INV-2'),
          clientId: const Value('c-contact'),
        ),
      );
      await db.expenseDao.upsert(
        ExpensesCompanion.insert(
          id: 'exp-contact',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          clientId: const Value('c-contact'),
        ),
      );
    });

    Future<List<String>> clientsFor(String term) => ids(
      db.clientDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: term,
      ),
    );

    test('a capital umlaut matches either case', () async {
      expect(await clientsFor('über'), ['c-ue']);
      expect(await clientsFor('ÜBER'), ['c-ue']);
      expect(await clientsFor('uber'), ['c-ue']);
    });

    test('mü, MÜ and mu all find Müller', () async {
      expect(await clientsFor('mü'), ['c-mu']);
      expect(await clientsFor('MÜ'), ['c-mu']);
      expect(await clientsFor('mull'), ['c-mu']);
    });

    test('every word must match, in any order', () async {
      expect(await clientsFor('müller hans'), ['c-mu']);
      expect(await clientsFor('müller acme'), isEmpty);
    });

    test('a client is found through a contact', () async {
      expect(await clientsFor('jurgen'), ['c-contact']);
      expect(await clientsFor('schmidt'), ['c-contact']);
      expect(await clientsFor('js@example'), ['c-contact']);
      expect(await clientsFor('30 1234'), ['c-contact']);
    });

    test('a payload that is not JSON does not break the search', () async {
      expect(await clientsFor('broken'), ['c-bad']);
    });

    test('a vendor is found through a contact', () async {
      final found = await ids(
        db.vendorDao.watchPage(
          companyId: 'co',
          offset: 0,
          limit: 50,
          search: 'ozturk',
        ),
      );
      expect(found, ['v-contact']);
    });

    test('an invoice is found through its client name and contacts', () async {
      Future<List<String>> invoicesFor(String term) => ids(
        db.invoiceDao.watchPage(
          companyId: 'co',
          offset: 0,
          limit: 50,
          search: term,
        ),
      );
      expect(await invoicesFor('österreich'), ['inv-oe']);
      expect(await invoicesFor('OSTERREICH'), ['inv-oe']);
      expect(await invoicesFor('jürgen'), ['inv-contact']);
    });

    test(
      'an expense does not match client contacts (server: name only)',
      () async {
        final found = await ids(
          db.expenseDao.watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            search: 'jürgen',
          ),
        );
        expect(found, isEmpty);
      },
    );
  });
}
