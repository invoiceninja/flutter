import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/services/recurring_expenses_api.dart';
import 'package:admin/domain/recurring_expense_status.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

/// Covers the universal `BaseEntityRepository` contract plus the
/// recurring-only `start` / `stop` mutation kinds and the
/// `calculatedStatusId` derivation.
class _RecurringExpenseFixture
    extends
        EntityRepositoryContractFixture<RecurringExpense, RecurringExpenseApi> {
  @override
  String get entityType => 'recurring_expense';

  @override
  RecurringExpenseRepository buildRepo(AppDatabase db) =>
      RecurringExpenseRepository(db: db, api: _FakeRecurringExpensesApi());

  @override
  RecurringExpenseApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) => RecurringExpenseApi(
    id: id,
    number: displayValue ?? id,
    updatedAt: updatedAt,
  );

  @override
  RecurringExpense fromApi(RecurringExpenseApi api) =>
      RecurringExpense.fromApi(api);

  @override
  RecurringExpense editCopy(
    RecurringExpense item, {
    required String displayValue,
  }) => item.copyWith(number: displayValue);

  @override
  String idOf(RecurringExpense item) => item.id;

  @override
  bool isDirtyOf(RecurringExpense item) => item.isDirty;

  @override
  DateTime Function(RecurringExpense item)? get updatedAtOf =>
      (item) => item.updatedAt;

  @override
  Future<SaveResult<RecurringExpense>> create(
    BaseEntityRepository<RecurringExpense, RecurringExpenseApi> repo, {
    required String companyId,
    required RecurringExpense draft,
  }) => (repo as RecurringExpenseRepository).create(
    companyId: companyId,
    draft: draft,
  );

  @override
  Future<SaveResult<RecurringExpense>> save(
    BaseEntityRepository<RecurringExpense, RecurringExpenseApi> repo, {
    required String companyId,
    required RecurringExpense entity,
  }) => (repo as RecurringExpenseRepository).save(
    companyId: companyId,
    recurringExpense: entity,
  );

  @override
  Future<void> delete(
    BaseEntityRepository<RecurringExpense, RecurringExpenseApi> repo, {
    required String companyId,
    required String id,
  }) =>
      (repo as RecurringExpenseRepository).delete(companyId: companyId, id: id);
}

void main() {
  runEntityRepositoryContract(_RecurringExpenseFixture());

  group('RecurringExpenseRepository — entity-specific', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    RecurringExpenseRepository makeRepo() =>
        RecurringExpenseRepository(db: db, api: _FakeRecurringExpensesApi());

    test('start(...) enqueues a MutationKind.start row carrying the full '
        'entity body (parity with admin-portal + React)', () async {
      final repo = makeRepo();
      // Seed a synced row so start() can serialize the full entity.
      await repo.save(
        companyId: 'co',
        recurringExpense: RecurringExpense.fromApi(
          RecurringExpenseApi(
            id: 're_1',
            number: 'RE-1',
            updatedAt: 1700000000,
          ),
        ),
      );
      await repo.start(companyId: 'co', id: 're_1');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      final startRow = pending.singleWhere(
        (r) => r.mutationKind == MutationKind.start.wireName,
      );
      expect(startRow.entityType, 'recurring_expense');
      expect(startRow.entityId, 're_1');
      final payload = jsonDecode(startRow.payload) as Map<String, dynamic>;
      // Full entity body, not just {'id': ...}.
      expect(payload['id'], 're_1');
      expect(payload.containsKey('frequency_id'), isTrue);
      expect(payload.containsKey('amount'), isTrue);
    });

    test('stop(...) enqueues a MutationKind.stop row carrying the full '
        'entity body', () async {
      final repo = makeRepo();
      await repo.save(
        companyId: 'co',
        recurringExpense: RecurringExpense.fromApi(
          RecurringExpenseApi(
            id: 're_2',
            number: 'RE-2',
            updatedAt: 1700000000,
          ),
        ),
      );
      await repo.stop(companyId: 'co', id: 're_2');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      final stopRow = pending.singleWhere(
        (r) => r.mutationKind == MutationKind.stop.wireName,
      );
      expect(stopRow.entityType, 'recurring_expense');
      expect(stopRow.entityId, 're_2');
      final payload = jsonDecode(stopRow.payload) as Map<String, dynamic>;
      expect(payload['id'], 're_2');
      expect(payload.containsKey('frequency_id'), isTrue);
      expect(payload.containsKey('amount'), isTrue);
    });

    test('start(...) falls back to a bare {id} body when the row is not '
        'cached', () async {
      final repo = makeRepo();
      await repo.start(companyId: 'co', id: 're_x');

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload, {'id': 're_x'});
    });

    test('start(...) on an unsynced (tmp) row keeps the tmp id in the payload '
        'so the drain remap can rewrite it to the real id', () async {
      final repo = makeRepo();
      // Created offline → tmp_ id, create not yet synced.
      final created = await repo.create(
        companyId: 'co',
        draft: RecurringExpense.fromApi(
          RecurringExpenseApi(id: '', number: 'RE-3', updatedAt: 1700000000),
        ),
      );
      final tmpId = created.entity.id;
      expect(tmpId, startsWith('tmp_'));

      await repo.start(companyId: 'co', id: tmpId);

      final pending = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 1 << 60,
      );
      final startRow = pending.singleWhere(
        (r) => r.mutationKind == MutationKind.start.wireName,
      );
      final payload = jsonDecode(startRow.payload) as Map<String, dynamic>;
      // The id MUST be present (preserveTempId) so rewriteTempIdInPayloads can
      // swap it to the real id before dispatch — otherwise payload['id'] is
      // null and the handler throws on every drain.
      expect(payload['id'], tmpId);
    });

    test('calculatedStatusId — Active + null lastSentDate → -1 (Pending); '
        'remainingCycles == 0 → 4 (Completed)', () {
      // Active + null lastSentDate → Pending.
      const activeNoSendApi = RecurringExpenseApi(
        id: 're_a',
        statusId: kRecurringExpenseStatusActive,
        remainingCycles: 5,
        // lastSentDate omitted → '' → Date.tryParse → null.
      );
      final activeNoSend = RecurringExpense.fromApi(activeNoSendApi);
      expect(activeNoSend.lastSentDate, isNull);
      expect(activeNoSend.calculatedStatusId, kRecurringExpenseStatusPending);

      // remainingCycles == 0 → Completed, regardless of statusId.
      const noCyclesApi = RecurringExpenseApi(
        id: 're_b',
        statusId: kRecurringExpenseStatusActive,
        remainingCycles: 0,
      );
      final noCycles = RecurringExpense.fromApi(noCyclesApi);
      expect(noCycles.calculatedStatusId, kRecurringExpenseStatusCompleted);
    });
  });
}

class _FakeRecurringExpensesApi implements RecurringExpensesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
