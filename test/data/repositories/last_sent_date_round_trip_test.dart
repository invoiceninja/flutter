import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `last_sent_date` is server-stamped and read-only — `toApiJson` leaves it
/// off the wire and so out of a locally saved payload — so it lives in its own
/// Drift column (v18), which the Last Sent Date list column reads and sorts
/// by. A local edit-save must keep it, or a sent document reads back as never
/// sent until the server's echo lands (never, offline).
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeQuotesApi implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('invoice', () {
    late InvoiceRepository repo;
    setUp(
      () => repo = InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: SettingsRepository(db: db),
      ),
    );

    Future<void> seed(String id, String lastSent) => repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: InvoiceApi(
        id: id,
        number: id,
        statusId: '2',
        updatedAt: 1700000000,
        lastSentDate: lastSent,
      ),
    );

    test('keeps last_sent_date across a local edit', () async {
      await seed('inv1', '2026-10-01');
      final stored = await repo.watch(companyId: 'co', id: 'inv1').first;
      expect(stored!.lastSentDate?.toIso(), '2026-10-01');

      await repo.save(
        companyId: 'co',
        invoice: stored.copyWith(number: 'INV-RENAMED'),
      );
      final edited = await repo.watch(companyId: 'co', id: 'inv1').first;
      expect(edited!.number, 'INV-RENAMED');
      expect(edited.lastSentDate?.toIso(), '2026-10-01');
    });

    test('sorts by last_sent_date, never-sent last under DESC', () async {
      await seed('a', '2026-09-01');
      await seed('never', '');
      await seed('b', '2026-10-01');

      final rows = await db.invoiceDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 10,
            sortField: InvoiceFieldIds.lastSentDate,
          )
          .first;
      expect(rows.map((r) => r.id), ['b', 'a', 'never']);
    });
  });

  group('quote', () {
    late QuoteRepository repo;
    setUp(() => repo = QuoteRepository(db: db, api: _FakeQuotesApi()));

    Future<void> seed(String id, String lastSent) => repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: QuoteApi(
        id: id,
        number: id,
        statusId: '2',
        updatedAt: 1700000000,
        lastSentDate: lastSent,
      ),
    );

    test('keeps last_sent_date across a local edit', () async {
      await seed('q1', '2026-10-01');
      final stored = await repo.watch(companyId: 'co', id: 'q1').first;
      expect(stored!.lastSentDate?.toIso(), '2026-10-01');

      await repo.save(
        companyId: 'co',
        quote: stored.copyWith(number: 'Q-RENAMED'),
      );
      final edited = await repo.watch(companyId: 'co', id: 'q1').first;
      expect(edited!.number, 'Q-RENAMED');
      expect(edited.lastSentDate?.toIso(), '2026-10-01');
    });

    test('sorts by last_sent_date, never-sent last under DESC', () async {
      await seed('a', '2026-09-01');
      await seed('never', '');
      await seed('b', '2026-10-01');

      final rows = await db.quoteDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 10,
            sortField: QuoteFieldIds.lastSentDate,
          )
          .first;
      expect(rows.map((r) => r.id), ['b', 'a', 'never']);
    });
  });
}
