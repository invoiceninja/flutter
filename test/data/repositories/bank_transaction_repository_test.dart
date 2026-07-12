import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/services/bank_transactions_api.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<BankTransaction, BankTransactionApi>.build(
      entityType: 'bank_transaction',
      buildRepo: (db) =>
          BankTransactionRepository(db: db, api: _FakeBankTransactionsApi()),
      buildApiModel:
          ({
            required String id,
            String? displayValue,
            int updatedAt = 1700000000,
          }) => BankTransactionApi(
            id: id,
            description: displayValue ?? id,
            baseType: kTransactionTypeDebit,
            statusId: kTransactionStatusUnmatched,
            updatedAt: updatedAt,
          ),
      fromApi: BankTransaction.fromApi,
      editCopy: (item, {required String displayValue}) =>
          item.copyWith(description: displayValue),
      idOf: (item) => item.id,
      isDirtyOf: (item) => item.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as BankTransactionRepository).create(
            companyId: companyId,
            draft: draft,
          ),
      save: (repo, {required companyId, required entity}) =>
          (repo as BankTransactionRepository).save(
            companyId: companyId,
            transaction: entity,
          ),
      delete: (repo, {required companyId, required id}) =>
          (repo as BankTransactionRepository).delete(
            companyId: companyId,
            id: id,
          ),
    ),
  );

  group('BankTransactionRepository — match action payload shapes', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    BankTransactionRepository makeRepo() =>
        BankTransactionRepository(db: db, api: _FakeBankTransactionsApi());

    test('matchToPayment payload carries invoice_ids CSV', () async {
      final repo = makeRepo();
      await repo.matchToPayment(
        companyId: 'co',
        transactionId: 'tx_1',
        invoiceIds: const ['inv_a', 'inv_b'],
      );
      final row = (await db.outboxDao.watchAll('co').first).firstWhere(
        (r) => r.mutationKind == MutationKind.matchToPayment.wireName,
      );
      expect(row.payload, contains('"invoice_ids":"inv_a,inv_b"'));
    });

    test('linkToPayment payload carries payment_id', () async {
      final repo = makeRepo();
      await repo.linkToPayment(
        companyId: 'co',
        transactionId: 'tx_1',
        paymentId: 'pay_x',
      );
      final row = (await db.outboxDao.watchAll('co').first).firstWhere(
        (r) => r.mutationKind == MutationKind.linkToPayment.wireName,
      );
      expect(row.payload, contains('"payment_id":"pay_x"'));
    });

    test(
      'matchToExpense payload carries vendor_id + ninja_category_id',
      () async {
        final repo = makeRepo();
        await repo.matchToExpense(
          companyId: 'co',
          transactionId: 'tx_1',
          vendorId: 'v1',
          categoryId: 'c1',
        );
        final row = (await db.outboxDao.watchAll('co').first).firstWhere(
          (r) => r.mutationKind == MutationKind.matchToExpense.wireName,
        );
        expect(row.payload, contains('"vendor_id":"v1"'));
        expect(row.payload, contains('"ninja_category_id":"c1"'));
      },
    );

    test('linkToExpense payload carries expense_id', () async {
      final repo = makeRepo();
      await repo.linkToExpense(
        companyId: 'co',
        transactionId: 'tx_1',
        expenseId: 'exp_x',
      );
      final row = (await db.outboxDao.watchAll('co').first).firstWhere(
        (r) => r.mutationKind == MutationKind.linkToExpense.wireName,
      );
      expect(row.payload, contains('"expense_id":"exp_x"'));
    });

    test('convertMatched payload carries ids array and uses the synthetic '
        'kBulkTransactionEntityId for the outbox row', () async {
      final repo = makeRepo();
      await repo.convertMatched(
        companyId: 'co',
        transactionIds: const ['tx_1', 'tx_2'],
      );
      final row = (await db.outboxDao.watchAll('co').first).firstWhere(
        (r) => r.mutationKind == MutationKind.convertMatched.wireName,
      );
      expect(row.payload, contains('"ids"'));
      // Bulk action — the row shouldn't pretend to point at the first
      // transaction; the full id list lives in the payload.
      expect(row.entityId, kBulkTransactionEntityId);
    });

    test(
      'unlinkTransactions uses the synthetic kBulkTransactionEntityId',
      () async {
        final repo = makeRepo();
        await repo.unlinkTransactions(
          companyId: 'co',
          transactionIds: const ['tx_1', 'tx_2', 'tx_3'],
        );
        final row = (await db.outboxDao.watchAll('co').first).firstWhere(
          (r) => r.mutationKind == MutationKind.unlinkTransaction.wireName,
        );
        expect(row.entityId, kBulkTransactionEntityId);
        expect(row.payload, contains('"ids"'));
      },
    );

    test('single-id convertMatched / unlink keep the transaction id on the '
        'outbox row so the Outbox screen renders meaningfully', () async {
      final repo = makeRepo();
      await repo.convertMatched(
        companyId: 'co',
        transactionIds: const ['tx_solo'],
      );
      await repo.unlinkTransactions(
        companyId: 'co',
        transactionIds: const ['tx_solo'],
      );
      final rows = await db.outboxDao.watchAll('co').first;
      final convert = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.convertMatched.wireName,
      );
      final unlink = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.unlinkTransaction.wireName,
      );
      expect(convert.entityId, 'tx_solo');
      expect(unlink.entityId, 'tx_solo');
    });

    test('linkedInvoiceIds / linkedExpenseIds parse CSV correctly', () {
      final domain = BankTransaction.fromApi(
        const BankTransactionApi(
          id: 'tx_1',
          invoiceIds: 'inv_a,inv_b,inv_c',
          expenseId: 'exp_a,exp_b',
        ),
      );
      expect(domain.linkedInvoiceIds, ['inv_a', 'inv_b', 'inv_c']);
      expect(domain.linkedExpenseIds, ['exp_a', 'exp_b']);

      final empty = BankTransaction.fromApi(
        const BankTransactionApi(id: 'tx_2'),
      );
      expect(empty.linkedInvoiceIds, isEmpty);
      expect(empty.linkedExpenseIds, isEmpty);
    });

    test('transaction_id wire value accepts int or string', () {
      final fromInt = BankTransaction.fromApi(
        const BankTransactionApi(id: 'tx_1', transactionId: 42),
      );
      expect(fromInt.transactionId, '42');

      final fromString = BankTransaction.fromApi(
        const BankTransactionApi(id: 'tx_2', transactionId: 'abc-123'),
      );
      expect(fromString.transactionId, 'abc-123');

      final fromZero = BankTransaction.fromApi(
        const BankTransactionApi(id: 'tx_3', transactionId: 0),
      );
      expect(fromZero.transactionId, '');
    });
  });

  group('BankTransactionRepository — local filter mirror (watchPage)', () {
    late AppDatabase db;
    late BankTransactionRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = BankTransactionRepository(db: db, api: _FakeBankTransactionsApi());
    });
    tearDown(() async {
      await db.close();
    });

    Future<void> seed(
      String id, {
      String statusId = kTransactionStatusUnmatched,
      String baseType = kTransactionTypeCredit,
      String date = '2026-03-15',
    }) => repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: BankTransactionApi(
        id: id,
        statusId: statusId,
        baseType: baseType,
        date: date,
      ),
    );

    Future<List<String>> idsOf(Stream<List<BankTransaction>> stream) async {
      final rows = await stream.first;
      return rows.map((t) => t.id).toList()..sort();
    }

    test('statusIds narrows to the matching statuses', () async {
      await seed('a', statusId: kTransactionStatusUnmatched);
      await seed('b', statusId: kTransactionStatusMatched);
      await seed('c', statusId: kTransactionStatusConverted);
      expect(
        await idsOf(
          repo.watchPage(
            companyId: 'co',
            statusIds: {kTransactionStatusMatched},
          ),
        ),
        ['b'],
      );
    });

    test('baseType narrows deposits vs withdrawals', () async {
      await seed('a', baseType: kTransactionTypeCredit);
      await seed('b', baseType: kTransactionTypeDebit);
      expect(
        await idsOf(
          repo.watchPage(companyId: 'co', baseType: kTransactionTypeCredit),
        ),
        ['a'],
      );
    });

    test('status + type AND together', () async {
      await seed(
        'a',
        statusId: kTransactionStatusMatched,
        baseType: kTransactionTypeCredit,
      );
      await seed(
        'b',
        statusId: kTransactionStatusMatched,
        baseType: kTransactionTypeDebit,
      );
      expect(
        await idsOf(
          repo.watchPage(
            companyId: 'co',
            statusIds: {kTransactionStatusMatched},
            baseType: kTransactionTypeDebit,
          ),
        ),
        ['b'],
      );
    });

    test('date window (between) narrows by the date column', () async {
      await seed('a', date: '2026-01-05');
      await seed('b', date: '2026-03-20');
      expect(
        await idsOf(
          repo.watchPage(
            companyId: 'co',
            dateStart: '2026-03-01',
            dateEnd: '2026-03-31',
          ),
        ),
        ['b'],
      );
    });

    test('date comparator (gte) narrows by the date column', () async {
      await seed('a', date: '2026-01-05');
      await seed('b', date: '2026-03-20');
      expect(
        await idsOf(
          repo.watchPage(
            companyId: 'co',
            dateOp: 'gte',
            dateValue: '2026-02-01',
          ),
        ),
        ['b'],
      );
    });

    test('no filters → all active rows', () async {
      await seed('a');
      await seed('b');
      expect(await idsOf(repo.watchPage(companyId: 'co')), ['a', 'b']);
    });
  });

  group('BankTransactionRepository — onRelatedEntitiesAffected refresh', () {
    late AppDatabase db;
    final calls = <({List<String> invoiceIds, List<String> clientIds})>[];

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      calls.clear();
    });
    tearDown(() async => db.close());

    BankTransactionRepository makeRepo() => BankTransactionRepository(
      db: db,
      api: _FakeBankTransactionsApi(),
      onRelatedEntitiesAffected: (companyId, byType) async {
        calls.add((
          invoiceIds: (byType[EntityType.invoice] ?? const {}).toList()..sort(),
          clientIds: (byType[EntityType.client] ?? const {}).toList(),
        ));
      },
    );

    test(
      'a matched transaction refreshes its invoices (no client id)',
      () async {
        await makeRepo().applyUpdateResponse(
          companyId: 'co',
          serverResponse: const BankTransactionApi(
            id: 'tx1',
            statusId: kTransactionStatusMatched,
            baseType: kTransactionTypeCredit,
            invoiceIds: 'inv_a,inv_b',
          ),
        );
        expect(calls, hasLength(1));
        expect(calls.single.invoiceIds, ['inv_a', 'inv_b']);
        expect(calls.single.clientIds, isEmpty);
      },
    );

    test('an expense match (no invoice_ids) fires nothing', () async {
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const BankTransactionApi(
          id: 'tx1',
          statusId: kTransactionStatusConverted,
          baseType: kTransactionTypeDebit,
          invoiceIds: '',
        ),
      );
      expect(calls, isEmpty);
    });

    test('unlink sources invoice ids from the existing row', () async {
      // Seed a matched tx (no-callback repo) so the seed doesn't record.
      await BankTransactionRepository(
        db: db,
        api: _FakeBankTransactionsApi(),
      ).applyUpdateResponse(
        companyId: 'co',
        serverResponse: const BankTransactionApi(
          id: 'tx1',
          statusId: kTransactionStatusMatched,
          baseType: kTransactionTypeCredit,
          invoiceIds: 'inv_z',
        ),
      );
      // The unlink response clears invoice_ids; the ids come from the old row.
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const BankTransactionApi(
          id: 'tx1',
          statusId: kTransactionStatusUnmatched,
          baseType: kTransactionTypeCredit,
          invoiceIds: '',
        ),
      );
      expect(calls.single.invoiceIds, ['inv_z']);
    });
  });

  group('BankTransactionRepository — refreshes payment + expense too', () {
    late AppDatabase db;
    final byType = <Map<EntityType, Set<String>>>[];
    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      byType.clear();
    });
    tearDown(() async => db.close());

    BankTransactionRepository makeRepo() => BankTransactionRepository(
      db: db,
      api: _FakeBankTransactionsApi(),
      onRelatedEntitiesAffected: (companyId, m) async {
        byType.add({for (final e in m.entries) e.key: e.value});
      },
    );

    test('a matched deposit with payment_id refreshes the payment', () async {
      await makeRepo().applyUpdateResponse(
        companyId: 'co',
        serverResponse: const BankTransactionApi(
          id: 'tx1',
          statusId: kTransactionStatusMatched,
          baseType: kTransactionTypeCredit,
          invoiceIds: 'inv_a',
          paymentId: 'pay_new',
        ),
      );
      expect(byType.single[EntityType.invoice], {'inv_a'});
      expect(byType.single[EntityType.payment], {'pay_new'});
    });

    test(
      'a converted withdrawal with expense_id refreshes the expense',
      () async {
        await makeRepo().applyUpdateResponse(
          companyId: 'co',
          serverResponse: const BankTransactionApi(
            id: 'tx2',
            statusId: kTransactionStatusConverted,
            baseType: kTransactionTypeDebit,
            expenseId: 'exp_new',
          ),
        );
        expect(byType.single[EntityType.expense], {'exp_new'});
        expect(byType.single.containsKey(EntityType.invoice), isFalse);
      },
    );
  });
}

class _FakeBankTransactionsApi implements BankTransactionsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
