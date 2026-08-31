import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/services/credits_api.dart';

import '_base_entity_repository_contract.dart';

/// Closes a standing coverage gap: credits had only `credit_side_effects_test`
/// and were never registered against the shared `BaseEntityRepository`
/// contract, so the offline-first invariants (tmp-id mint, idempotency key,
/// `applyCreateResponse` remap, `is_dirty` clearing) went unverified.
///
/// Mirrors `quote_repository_test.dart`. The contract never touches the
/// network, so the API fake throws on every call.
class _FakeCreditsApi implements CreditsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<Credit, CreditApi>.build(
      entityType: 'credit',
      updatedAtOf: (item) => item.updatedAt,
      buildRepo: (db) => CreditRepository(db: db, api: _FakeCreditsApi()),
      buildApiModel: ({required id, displayValue, updatedAt = 1700000000}) =>
          CreditApi(id: id, number: displayValue ?? id, updatedAt: updatedAt),
      fromApi: Credit.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(number: displayValue),
      idOf: (c) => c.id,
      isDirtyOf: (c) => c.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as CreditRepository).create(companyId: companyId, draft: draft),
      save: (repo, {required companyId, required entity}) =>
          (repo as CreditRepository).save(companyId: companyId, credit: entity),
      delete: (repo, {required companyId, required id}) =>
          repo.delete(companyId: companyId, id: id),
    ),
  );
}
