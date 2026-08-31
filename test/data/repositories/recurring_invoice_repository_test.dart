import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';

import '_base_entity_repository_contract.dart';

/// Closes a standing coverage gap: recurring invoices were reachable only
/// through `subscription_related_lists_test` and the edit-VM test, and were
/// never registered against the shared `BaseEntityRepository` contract, so the
/// offline-first invariants (tmp-id mint, idempotency key,
/// `applyCreateResponse` remap, `is_dirty` clearing) went unverified.
///
/// Mirrors `quote_repository_test.dart`. The contract never touches the
/// network, so the API fake throws on every call.
class _FakeRecurringInvoicesApi implements RecurringInvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<
      RecurringInvoice,
      RecurringInvoiceApi
    >.build(
      // Matches `RecurringInvoiceRepository.entityTypeName`, which overrides
      // the base `EntityType.name` — the outbox stores the snake_case spelling.
      entityType: 'recurring_invoice',
      updatedAtOf: (item) => item.updatedAt,
      buildRepo: (db) =>
          RecurringInvoiceRepository(db: db, api: _FakeRecurringInvoicesApi()),
      buildApiModel: ({required id, displayValue, updatedAt = 1700000000}) =>
          RecurringInvoiceApi(
            id: id,
            number: displayValue ?? id,
            updatedAt: updatedAt,
          ),
      fromApi: RecurringInvoice.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(number: displayValue),
      idOf: (r) => r.id,
      isDirtyOf: (r) => r.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as RecurringInvoiceRepository).create(
            companyId: companyId,
            draft: draft,
          ),
      save: (repo, {required companyId, required entity}) =>
          (repo as RecurringInvoiceRepository).save(
            companyId: companyId,
            recurringInvoice: entity,
          ),
      delete: (repo, {required companyId, required id}) =>
          repo.delete(companyId: companyId, id: id),
    ),
  );
}
