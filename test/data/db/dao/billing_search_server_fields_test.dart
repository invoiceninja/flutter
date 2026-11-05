import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// The server's billing-document search also LIKEs `date`, `amount` and
/// `balance` (`InvoiceFilters`, `CreditFilters`, `PurchaseOrderFilters`;
/// `RecurringInvoiceFilters` has no `balance`, `QuoteFilters` none of them).
/// The local search the lists render from left them out, so a document the
/// server found through a typed date or amount was fetched and then hidden —
/// the same bug as line items (invoiceninja/flutter#185).
///
/// MySQL renders a `decimal(20,6)` with six places, so the server matches
/// `150.00` against an amount of 150; the local text is `150`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<List<String>> ids(Stream<List<dynamic>> rows) =>
      rows.first.then((r) => r.map((e) => e.id as String).toList()..sort());

  group('invoices', () {
    setUp(() async {
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'a',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          date: const Value('2026-11-05'),
          amount: const Value('150'),
          balance: const Value('42.5'),
        ),
      );
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'b',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          date: const Value('2025-01-01'),
          amount: const Value('9'),
          balance: const Value('0'),
        ),
      );
    });

    Future<List<String>> search(String s) => ids(
      db.invoiceDao.watchPage(companyId: 'co', offset: 0, limit: 50, search: s),
    );

    test('a date', () async => expect(await search('2026-11'), ['a']));
    test('an amount, as the server renders it', () async {
      expect(await search('150'), ['a']);
      expect(await search('150.00'), ['a']);
    });
    test('a balance', () async => expect(await search('42.50'), ['a']));
  });

  group('credits', () {
    setUp(() async {
      await db.creditDao.upsert(
        CreditsCompanion.insert(
          id: 'a',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          date: const Value('2026-11-05'),
          amount: const Value('150'),
          balance: const Value('42.5'),
        ),
      );
    });

    Future<List<String>> search(String s) => ids(
      db.creditDao.watchPage(companyId: 'co', offset: 0, limit: 50, search: s),
    );

    test('date, amount and balance', () async {
      expect(await search('2026-11'), ['a']);
      expect(await search('150.00'), ['a']);
      expect(await search('42.50'), ['a']);
    });
  });

  group('purchase orders', () {
    setUp(() async {
      await db.purchaseOrderDao.upsert(
        PurchaseOrdersCompanion.insert(
          id: 'a',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          date: const Value('2026-11-05'),
          amount: const Value('150'),
          balance: const Value('42.5'),
        ),
      );
    });

    Future<List<String>> search(String s) => ids(
      db.purchaseOrderDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: s,
      ),
    );

    test('date, amount and balance', () async {
      expect(await search('2026-11'), ['a']);
      expect(await search('150.00'), ['a']);
      expect(await search('42.50'), ['a']);
    });
  });

  group('recurring invoices', () {
    setUp(() async {
      await db.recurringInvoiceDao.upsert(
        RecurringInvoicesCompanion.insert(
          id: 'a',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          date: const Value('2026-11-05'),
          amount: const Value('150'),
        ),
      );
    });

    Future<List<String>> search(String s) => ids(
      db.recurringInvoiceDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: s,
      ),
    );

    test('date and amount', () async {
      expect(await search('2026-11'), ['a']);
      expect(await search('150.00'), ['a']);
    });
  });

  // `payloadJsonLike` (the notes search) had no shape check, so a row whose
  // payload is not a JSON object made every search of the list throw
  // ("malformed JSON") instead of skipping that row.
  test('a payload that is not a JSON object never breaks the search', () async {
    for (final payload in ['', 'not json']) {
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'bad-${payload.length}',
          companyId: 'co',
          updatedAt: 1,
          payload: payload,
          number: const Value('INV-1'),
        ),
      );
    }
    final found = await ids(
      db.invoiceDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: 'INV-1',
      ),
    );
    expect(found, ['bad-0', 'bad-8']);
    // A term no cheaper field holds reaches the payload of every row.
    final none = await ids(
      db.invoiceDao.watchPage(
        companyId: 'co',
        offset: 0,
        limit: 50,
        search: 'zzz',
      ),
    );
    expect(none, isEmpty);
  });
}
