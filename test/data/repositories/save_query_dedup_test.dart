import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/domain/sync/mutation.dart';

class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeQuotesApi implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Regression: an offline SAVE-PARAM action (Mark Sent / Mark Paid / Approve /
/// Cancel / Auto-bill) used to be destroyed by the next ordinary Save.
///
/// From an edit screen those verbs are not their own `MutationKind` — they ride
/// in the same `update` row's payload under [kSaveQueryPayloadKey]. `save()`
/// calls `dedupPendingMutations(kind: update)` first, and that predicate keys
/// only on `(company, type, id, kind)`, so it cannot tell an action-bearing
/// save from a plain one: the newer plain row silently erased the older action
/// row. Offline, the user got no toast, no banner and no Outbox entry — the
/// edit synced and the invoice stayed a draft.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  InvoiceRepository invoices() => InvoiceRepository(
    db: db,
    api: _FakeInvoicesApi(),
    settings: SettingsRepository(db: db),
  );

  QuoteRepository quotes() => QuoteRepository(db: db, api: _FakeQuotesApi());

  Future<void> seedCompany() => db.companiesDao.upsertAll([
    CompaniesCompanion.insert(
      id: 'co',
      name: 'Acme',
      settings: jsonEncode(<String, dynamic>{}),
      permissions: '',
      accountId: 'acct',
      token: 'tok',
      updatedAt: 1700000000,
    ),
  ]);

  Future<List<OutboxRow>> outbox() =>
      db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);

  /// The `__save_query` map on the single surviving outbox row.
  Future<Map<String, dynamic>?> savedQuery() async {
    final rows = await outbox();
    expect(rows, hasLength(1), reason: 'dedup should leave exactly one row');
    final payload = jsonDecode(rows.single.payload) as Map<String, dynamic>;
    return payload[kSaveQueryPayloadKey] as Map<String, dynamic>?;
  }

  Invoice draftInvoice() =>
      Invoice.fromApi(const InvoiceApi(id: 'inv1', statusId: '1'));

  group('re-sending a failed create', () {
    test('carries the action of an update queued behind it', () async {
      // The update waited for the create to land; the re-create replaces it,
      // so its Mark Sent rides on the create instead of being lost.
      await seedCompany();
      final repo = invoices();
      final first = await repo.create(
        companyId: 'co',
        draft: Invoice.fromApi(const InvoiceApi(id: '', statusId: '1')),
      );
      await db.outboxDao.markDead(id: first.outboxRowId, error: 'bad');
      await repo.save(
        companyId: 'co',
        invoice: first.entity,
        extraQuery: const {'mark_sent': 'true'},
      );

      await repo.create(
        companyId: 'co',
        draft: first.entity,
        existingTempId: first.entity.id,
      );

      final rows = await outbox();
      expect(rows.single.mutationKind, MutationKind.create.wireName);
      expect(await savedQuery(), {'mark_sent': 'true'});
    });
  });

  test('a re-create takes the failed updates of its record with their '
      'action — the failed create stays until it lands', () async {
    await seedCompany();
    final repo = invoices();
    final first = await repo.create(
      companyId: 'co',
      draft: Invoice.fromApi(const InvoiceApi(id: '', statusId: '1')),
    );
    final edit = await repo.save(
      companyId: 'co',
      invoice: first.entity,
      extraQuery: const {'mark_sent': 'true'},
    );
    await db.outboxDao.markDead(id: first.outboxRowId, error: 'bad');
    await db.outboxDao.markDead(id: edit.outboxRowId, error: 'bad');

    await repo.create(
      companyId: 'co',
      draft: first.entity,
      existingTempId: first.entity.id,
    );

    expect(await savedQuery(), {'mark_sent': 'true'});
    expect(await db.outboxDao.byId(edit.outboxRowId), isNull);
    expect(await db.outboxDao.byId(first.outboxRowId), isNotNull);
  });

  group('re-sending a create that failed with an action', () {
    Future<(InvoiceRepository, String)> failedCreate() async {
      await seedCompany();
      final repo = invoices();
      final first = await repo.create(
        companyId: 'co',
        draft: Invoice.fromApi(const InvoiceApi(id: '', statusId: '1')),
        extraQuery: const {'paid': 'true'},
      );
      await db.outboxDao.markDead(id: first.outboxRowId, error: 'taken');
      return (repo, first.entity.id);
    }

    test('a plain re-save keeps the action of the failed create', () async {
      // Offline "Save & Mark Paid", rejected for a taken number, fixed and
      // re-saved with a plain Save. The failed create is deleted once the
      // re-create lands, so it must not take the action with it.
      final (repo, tmpId) = await failedCreate();
      await repo.create(
        companyId: 'co',
        draft: Invoice.fromApi(InvoiceApi(id: tmpId, statusId: '1')),
        existingTempId: tmpId,
      );
      expect(await savedQuery(), {'paid': 'true'});
    });

    test('an action on the re-save replaces it', () async {
      final (repo, tmpId) = await failedCreate();
      await repo.create(
        companyId: 'co',
        draft: Invoice.fromApi(InvoiceApi(id: tmpId, statusId: '1')),
        existingTempId: tmpId,
        extraQuery: const {'mark_sent': 'true'},
      );
      expect(await savedQuery(), {'mark_sent': 'true'});
    });
  });

  group('a superseding save carries the earlier action forward', () {
    test('offline Mark Sent then a plain Save keeps mark_sent', () async {
      await seedCompany();
      final repo = invoices();

      // 1. Mark Sent from the edit screen — a save-param save.
      await repo.save(
        companyId: 'co',
        invoice: draftInvoice(),
        extraQuery: const {'mark_sent': 'true'},
      );
      expect(await savedQuery(), {'mark_sent': 'true'});

      // 2. Still offline: reopen, fix a typo, plain Save. Pre-fix this deleted
      //    row 1 outright and the invoice stayed a draft forever.
      await repo.save(
        companyId: 'co',
        invoice: draftInvoice().copyWith(publicNotes: 'typo fixed'),
      );
      expect(await savedQuery(), {'mark_sent': 'true'});
    });

    test(
      // A second ACTION is the user's latest intent and replaces the first —
      // deliberately NOT a union. Merging by key only disambiguates the same
      // verb; contradictory actions live under different keys, so a union keeps
      // both. `canMarkPaid` and `canCancel` are true together on a sent unpaid
      // invoice and neither flips the local status, so offline a union would
      // drain as `?cancel=true&paid=true` — cancelling the invoice AND
      // recording a payment, with the outcome decided by server param ordering.
      'a second action replaces the first rather than unioning',
      () async {
        await seedCompany();
        final repo = invoices();
        await repo.save(
          companyId: 'co',
          invoice: draftInvoice(),
          extraQuery: const {'cancel': 'true'},
        );
        await repo.save(
          companyId: 'co',
          invoice: draftInvoice(),
          extraQuery: const {'paid': 'true'},
        );

        final query = await savedQuery();
        expect(query, {'paid': 'true'});
        expect(
          query!.containsKey('cancel'),
          isFalse,
          reason: 'cancel + paid must never travel together',
        );
      },
    );

    test('the newer value wins on a key collision', () async {
      await seedCompany();
      final repo = invoices();
      await repo.save(
        companyId: 'co',
        invoice: draftInvoice(),
        extraQuery: const {'cancel': 'true'},
      );
      await repo.save(
        companyId: 'co',
        invoice: draftInvoice(),
        extraQuery: const {'cancel': 'false'},
      );
      expect(await savedQuery(), {'cancel': 'false'});
    });

    test('a plain save chain never grows an empty save-query key', () async {
      await seedCompany();
      final repo = invoices();
      await repo.save(companyId: 'co', invoice: draftInvoice());
      await repo.save(companyId: 'co', invoice: draftInvoice());
      expect(await savedQuery(), isNull);
    });

    // The salvage lives on BaseEntityRepository, so every billing repo that
    // folds an action into its save inherits it — quote stands in for the
    // credit / purchase-order / recurring-invoice copies of the same shape.
    test(
      'quotes inherit the same salvage (approve then a plain save)',
      () async {
        await seedCompany();
        final repo = quotes();
        final quote = Quote.fromApi(const QuoteApi(id: 'q1', statusId: '1'));
        await repo.save(
          companyId: 'co',
          quote: quote,
          extraQuery: const {'approve': 'true'},
        );
        await repo.save(companyId: 'co', quote: quote);
        expect(await savedQuery(), {'approve': 'true'});
      },
    );
  });

  group('a save replaces the failed update it re-sends', () {
    Future<List<OutboxRow>> allRows() => db.select(db.outbox).get();

    Future<int> rawRow({
      required String kind,
      required String state,
      required Map<String, dynamic> payload,
      String key = 'raw',
    }) => db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co',
        entityType: 'invoice',
        entityId: 'inv1',
        mutationKind: kind,
        payload: jsonEncode(payload),
        idempotencyKey: key,
        createdAt: 0,
        nextAttemptAt: 0,
        state: Value(state),
      ),
    );

    test('a plain re-save of a failed "Mark Paid" keeps paid, and leaves one '
        'row — even after it fails again', () async {
      // "Save & Mark Paid" rejected for a taken number, fixed, re-saved with
      // a plain Save: it landed without `paid`, and the cleanup of the failed
      // row then deleted the only record of the action.
      await seedCompany();
      final repo = invoices();
      final first = await repo.save(
        companyId: 'co',
        invoice: draftInvoice(),
        extraQuery: const {'paid': 'true'},
      );
      await db.outboxDao.markDead(id: first.outboxRowId, error: 'taken');

      final second = await repo.save(companyId: 'co', invoice: draftInvoice());
      expect(await savedQuery(), {'paid': 'true'});
      expect(await allRows(), hasLength(1), reason: 'the failed row is gone');

      await db.outboxDao.markDead(id: second.outboxRowId, error: 'taken');
      await repo.save(companyId: 'co', invoice: draftInvoice());
      expect(await savedQuery(), {'paid': 'true'});
      expect(await allRows(), hasLength(1));
    });

    test('the newest action wins across failed and queued saves', () async {
      await seedCompany();
      final repo = invoices();
      final failed = await repo.save(
        companyId: 'co',
        invoice: draftInvoice(),
        extraQuery: const {'paid': 'true'},
      );
      await db.outboxDao.markDead(id: failed.outboxRowId, error: 'taken');
      await rawRow(
        kind: 'update',
        state: 'pending',
        payload: {
          'id': 'inv1',
          kSaveQueryPayloadKey: {'cancel': 'true'},
        },
      );

      await repo.save(companyId: 'co', invoice: draftInvoice());

      expect(await savedQuery(), {'cancel': 'true'});
    });

    test('a failed create under the real id is not carried, and stays for '
        'the form to supersede', () async {
      await seedCompany();
      final repo = invoices();
      final create = await rawRow(
        kind: 'create',
        state: 'dead',
        payload: {
          'id': 'inv1',
          kSaveQueryPayloadKey: {'paid': 'true'},
        },
      );

      await repo.save(companyId: 'co', invoice: draftInvoice());

      expect(await savedQuery(), isNull);
      expect(await db.outboxDao.byId(create), isNotNull);
    });

    test('a save that may already have gone through is neither carried nor '
        'replaced — it waits for the user', () async {
      await seedCompany();
      final repo = invoices();
      final held = await rawRow(
        kind: 'update',
        state: 'unconfirmed',
        payload: {
          'id': 'inv1',
          kSaveQueryPayloadKey: {'paid': 'true'},
        },
      );

      await repo.save(companyId: 'co', invoice: draftInvoice());

      expect(await savedQuery(), isNull);
      expect((await db.outboxDao.byId(held))?.state, 'unconfirmed');
    });

    test('a failed row carrying an `_action` is no save of the record, and '
        'is left alone', () async {
      await seedCompany();
      final repo = invoices();
      final action = await rawRow(
        kind: 'update',
        state: 'dead',
        payload: {
          '_action': 'upload_document',
          kSaveQueryPayloadKey: {'paid': 'true'},
        },
      );

      await repo.save(companyId: 'co', invoice: draftInvoice());

      expect(await savedQuery(), isNull);
      expect(await db.outboxDao.byId(action), isNotNull);
    });
  });
}
