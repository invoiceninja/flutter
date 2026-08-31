import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

/// Covers the universal `BaseEntityRepository` contract via the shared
/// harness, plus entity-specific assertions on Decimal precision and the
/// `effectiveExchangeRate` sentinel.
class _ExpenseFixture
    extends EntityRepositoryContractFixture<Expense, ExpenseApi> {
  @override
  String get entityType => 'expense';

  @override
  ExpenseRepository buildRepo(AppDatabase db) =>
      ExpenseRepository(db: db, api: _FakeExpensesApi());

  @override
  ExpenseApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) => ExpenseApi(
    id: id,
    // `displayValue` doesn't map cleanly onto Expense; use `number` so the
    // edit-copy test has somewhere to roundtrip a value through the
    // mapper + outbox without colliding with the date / amount math.
    number: displayValue ?? id,
    updatedAt: updatedAt,
  );

  @override
  Expense fromApi(ExpenseApi api) => Expense.fromApi(api);

  @override
  Expense editCopy(Expense item, {required String displayValue}) =>
      item.copyWith(number: displayValue);

  @override
  String idOf(Expense item) => item.id;

  @override
  bool isDirtyOf(Expense item) => item.isDirty;

  @override
  DateTime Function(Expense item)? get updatedAtOf =>
      (item) => item.updatedAt;

  @override
  Future<SaveResult<Expense>> create(
    BaseEntityRepository<Expense, ExpenseApi> repo, {
    required String companyId,
    required Expense draft,
  }) => (repo as ExpenseRepository).create(companyId: companyId, draft: draft);

  @override
  Future<SaveResult<Expense>> save(
    BaseEntityRepository<Expense, ExpenseApi> repo, {
    required String companyId,
    required Expense entity,
  }) => (repo as ExpenseRepository).save(companyId: companyId, expense: entity);

  @override
  Future<void> delete(
    BaseEntityRepository<Expense, ExpenseApi> repo, {
    required String companyId,
    required String id,
  }) => (repo as ExpenseRepository).delete(companyId: companyId, id: id);
}

void main() {
  runEntityRepositoryContract(_ExpenseFixture());

  group('ExpenseRepository — entity-specific', () {
    test('ExpenseApi → Expense round-trip preserves Decimal precision on '
        'amount, taxAmount1..3, taxRate1..3, and exchangeRate', () {
      const api = ExpenseApi(
        id: 'e_1',
        amount: '123.4567',
        exchangeRate: '0.876543',
        taxAmount1: '11.1111',
        taxAmount2: '22.2222',
        taxAmount3: '33.3333',
        taxRate1: '5.250',
        taxRate2: '7.125',
        taxRate3: '1.5',
      );
      final domain = Expense.fromApi(api);
      expect(domain.amount, Decimal.parse('123.4567'));
      expect(domain.exchangeRate, Decimal.parse('0.876543'));
      expect(domain.taxAmount1, Decimal.parse('11.1111'));
      expect(domain.taxAmount2, Decimal.parse('22.2222'));
      expect(domain.taxAmount3, Decimal.parse('33.3333'));
      expect(domain.taxRate1, Decimal.parse('5.250'));
      expect(domain.taxRate2, Decimal.parse('7.125'));
      expect(domain.taxRate3, Decimal.parse('1.5'));
    });

    test(
      'effectiveExchangeRate returns Decimal.one when stored exchangeRate is '
      'zero — the legacy "no conversion" sentinel from admin-portal',
      () {
        const zeroApi = ExpenseApi(id: 'e_2', exchangeRate: '0');
        final zero = Expense.fromApi(zeroApi);
        expect(zero.exchangeRate, Decimal.zero);
        expect(zero.effectiveExchangeRate, Decimal.one);

        // Sanity: a real exchange rate is returned unchanged.
        const realApi = ExpenseApi(id: 'e_3', exchangeRate: '1.25');
        final real = Expense.fromApi(realApi);
        expect(real.effectiveExchangeRate, Decimal.parse('1.25'));
      },
    );
  });

  // Sanity-check the in-memory DB harness still composes cleanly so future
  // entity-specific DB tests have a slot to drop into.
  group('ExpenseRepository — DB smoke', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('repo can be constructed against an in-memory DB', () {
      final repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
      expect(repo.entityTypeName, 'expense');
    });

    test('runTemplate enqueues MutationKind.runTemplate with id + '
        'template_id', () async {
      final repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
      await repo.runTemplate(companyId: 'co', id: 'e_99', templateId: 'tmpl_7');
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.runTemplate.wireName,
      );
      expect(row.entityId, 'e_99');
      expect(row.payload, contains('tmpl_7'));
    });
  });

  // The expense status filter (`client_status`) is applied as a local Drift
  // predicate over the denormalized invoice_id / should_be_invoiced / is_paid
  // columns. Mirrors admin-portal `Expense.matchesStatuses`, including the
  // intentional paid/logged overlap (paid-but-not-invoiced is both).
  group('ExpenseRepository — status filter', () {
    const co = 'co';
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    Future<void> seed(ExpenseRepository repo) async {
      await repo.create(
        companyId: co,
        draft: Expense.fromApi(const ExpenseApi(id: 'tmp_l', number: 'L')),
      );
      await repo.create(
        companyId: co,
        draft: Expense.fromApi(
          const ExpenseApi(id: 'tmp_p', number: 'P', shouldBeInvoiced: true),
        ),
      );
      await repo.create(
        companyId: co,
        draft: Expense.fromApi(
          const ExpenseApi(id: 'tmp_i', number: 'I', invoiceId: 'inv_1'),
        ),
      );
      await repo.create(
        companyId: co,
        draft: Expense.fromApi(
          const ExpenseApi(id: 'tmp_d', number: 'D', paymentDate: '2026-06-01'),
        ),
      );
    }

    Future<Set<String>> numbersFor(
      ExpenseRepository repo,
      Set<String> statuses,
    ) async {
      final rows = await repo
          .watchPage(companyId: co, extraFilters: {'client_status': statuses})
          .first;
      return rows.map((e) => e.number).toSet();
    }

    test('each status narrows to the matching expenses', () async {
      final repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
      await seed(repo);

      expect(await numbersFor(repo, {'invoiced'}), {'I'});
      expect(await numbersFor(repo, {'pending'}), {'P'});
      expect(await numbersFor(repo, {'paid'}), {'D'});
      // Logged = not-invoiced & not-should-be-invoiced — also matches the
      // paid-but-not-invoiced row (admin-portal overlap).
      expect(await numbersFor(repo, {'logged'}), {'L', 'D'});
      // Unpaid = is_paid false → everything except the paid row.
      expect(await numbersFor(repo, {'unpaid'}), {'L', 'P', 'I'});
    });

    test('multiple statuses union (OR)', () async {
      final repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
      await seed(repo);
      expect(await numbersFor(repo, {'invoiced', 'paid'}), {'I', 'D'});
    });

    test('payment_type_id alone is not paid (server-aligned)', () async {
      // The server's `client_status` filter keys paid/unpaid on payment_date /
      // transaction_reference only — a payment type with no date/reference is
      // NOT paid. (Diverges from admin-portal, which counted the type too.)
      final repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
      await repo.create(
        companyId: co,
        draft: Expense.fromApi(
          const ExpenseApi(id: 'tmp_t', number: 'T', paymentTypeId: 'pt1'),
        ),
      );
      expect(await numbersFor(repo, {'paid'}), <String>{});
      expect(await numbersFor(repo, {'unpaid'}), {'T'});
      expect(await numbersFor(repo, {'logged'}), {'T'});
    });

    test('empty status set returns all', () async {
      final repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
      await seed(repo);
      final all = await repo.watchPage(companyId: co).first;
      expect(all.map((e) => e.number).toSet(), {'L', 'P', 'I', 'D'});
    });
  });
}

class _FakeExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
