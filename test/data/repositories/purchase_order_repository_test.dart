import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/services/purchase_orders_api.dart';

import '_base_entity_repository_contract.dart';

/// Closes a standing coverage gap: purchase orders had action-gating and
/// convert/merge tests but were never registered against the shared
/// `BaseEntityRepository` contract, so the offline-first invariants (tmp-id
/// mint, idempotency key, `applyCreateResponse` remap, `is_dirty` clearing)
/// went unverified.
///
/// Mirrors `quote_repository_test.dart`. The contract never touches the
/// network, so the API fake throws on every call.
class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<PurchaseOrder, PurchaseOrderApi>.build(
      // Matches `PurchaseOrderRepository.entityTypeName`, which overrides the
      // base `EntityType.name` — the outbox stores the snake_case spelling.
      entityType: 'purchase_order',
      updatedAtOf: (item) => item.updatedAt,
      buildRepo: (db) =>
          PurchaseOrderRepository(db: db, api: _FakePurchaseOrdersApi()),
      buildApiModel: ({required id, displayValue, updatedAt = 1700000000}) =>
          PurchaseOrderApi(
            id: id,
            number: displayValue ?? id,
            updatedAt: updatedAt,
          ),
      fromApi: PurchaseOrder.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(number: displayValue),
      idOf: (p) => p.id,
      isDirtyOf: (p) => p.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as PurchaseOrderRepository).create(
            companyId: companyId,
            draft: draft,
          ),
      save: (repo, {required companyId, required entity}) =>
          (repo as PurchaseOrderRepository).save(
            companyId: companyId,
            purchaseOrder: entity,
          ),
      delete: (repo, {required companyId, required id}) =>
          repo.delete(companyId: companyId, id: id),
    ),
  );
}
