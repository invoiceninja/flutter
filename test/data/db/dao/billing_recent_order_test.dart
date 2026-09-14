import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/db/dao/quote_dao.dart';

/// The ordering behind "most recent at the top" on the dashboard's Invoices &
/// Quotes panel (invoiceninja/flutter#155).
///
/// `date` is date-only, so every document a company issued today ties on it and
/// the `id` backstop — a hashid, ascending — decides. That silently returns an
/// arbitrary, effectively-oldest five. `tieBreakField` is what fixes it, and
/// each property below is one that the obvious implementation gets wrong.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  const co = 'co';

  Future<void> invoice(String id, {String date = '2026-09-14', int? created}) =>
      db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: id,
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          date: Value(date),
          createdAt: Value(created ?? 0),
        ),
      );

  Future<List<String>> recent({String? tieBreak, bool asc = false}) => db
      .invoiceDao
      .watchPage(
        companyId: co,
        offset: 0,
        limit: 10,
        sortField: InvoiceFieldIds.date,
        sortAscending: false,
        tieBreakField: tieBreak,
        tieBreakAscending: asc,
      )
      .first
      .then((r) => r.map((e) => e.id).toList());

  test('without a tie-break, same-date rows fall back to ascending id', () {
    // The default every existing caller keeps. Asserted so the new parameter
    // cannot quietly change the list screens' ordering.
    return (() async {
      await invoice('zzz', created: 300);
      await invoice('aaa', created: 100);
      expect(await recent(), ['aaa', 'zzz']);
    })();
  });

  test('created_at breaks a date tie, newest first', () async {
    await invoice('aaa', created: 100);
    await invoice('zzz', created: 300);
    // Without the tie-break this is ['aaa','zzz'] — the OLDER row first, which
    // is the bug on a panel whose premise is "most recent at the top".
    expect(await recent(tieBreak: InvoiceFieldIds.createdAt), ['zzz', 'aaa']);
  });

  test('an unsynced row (created_at == 0) LEADS, it does not trail', () async {
    // `created_at` defaults to 0 and an offline create stamps epoch 0 for it,
    // so a plain `created_at DESC` sorts the invoice the user just made to the
    // BOTTOM — and the panel's five-row window then drops it entirely.
    // `NULLIF(created_at, 0)` makes it null, and SQLite orders nulls first
    // under DESC.
    await invoice('synced', created: 500);
    await invoice('local', created: 0);
    expect(await recent(tieBreak: InvoiceFieldIds.createdAt), [
      'local',
      'synced',
    ]);
  });

  test('the primary key still wins over the tie-break', () async {
    await invoice('older-but-created-later', date: '2026-09-01', created: 900);
    await invoice('newer', date: '2026-09-14', created: 100);
    expect(await recent(tieBreak: InvoiceFieldIds.createdAt), [
      'newer',
      'older-but-created-later',
    ]);
  });

  test('id remains the final backstop, so the order is total', () async {
    // Rows can tie on BOTH keys — a bulk import shares a date and a
    // whole-second `created_at`. Without the `id` term the order would be
    // non-deterministic and `distinctRows()` could flap between emissions.
    await invoice('b', created: 100);
    await invoice('a', created: 100);
    await invoice('c', created: 100);
    expect(await recent(tieBreak: InvoiceFieldIds.createdAt), ['a', 'b', 'c']);
  });

  test('the tie-break carries its own direction', () async {
    await invoice('early', created: 100);
    await invoice('late', created: 300);
    expect(await recent(tieBreak: InvoiceFieldIds.createdAt, asc: true), [
      'early',
      'late',
    ]);
  });

  test('an unmapped tie-break throws at the call site, not in the stream', () {
    // Drift invokes the `orderBy` generators inside `orderBy()`, so this is
    // eager — which is what we want: a typo surfaces where it was written
    // rather than inside a stream nobody has listened to yet.
    expect(
      () => db.invoiceDao.watchPage(
        companyId: co,
        offset: 0,
        limit: 5,
        tieBreakField: 'not_a_column',
      ),
      throwsArgumentError,
    );
  });

  test('quotes order the same way — the merge relies on it', () async {
    // The panel merges two individually-correct top-Ns and truncates, which is
    // only the overall top-N if both halves use the SAME total order.
    Future<void> quote(String id, {int created = 0}) => db.quoteDao.upsert(
      QuotesCompanion.insert(
        id: id,
        companyId: co,
        updatedAt: 1,
        payload: '{}',
        date: const Value('2026-09-14'),
        createdAt: Value(created),
      ),
    );
    await quote('synced', created: 500);
    await quote('local');
    final rows = await db.quoteDao
        .watchPage(
          companyId: co,
          offset: 0,
          limit: 10,
          sortField: QuoteFieldIds.date,
          sortAscending: false,
          tieBreakField: QuoteFieldIds.createdAt,
        )
        .first;
    expect(rows.map((e) => e.id), ['local', 'synced']);
  });
}
