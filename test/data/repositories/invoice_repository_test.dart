import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';

import '_base_entity_repository_contract.dart';

/// Closes a standing coverage gap: invoices — the core entity of the app — had
/// five targeted repository tests (lock, mutation payload, side effects,
/// refresh-by-ids, payment schedule) but were never registered against the
/// shared `BaseEntityRepository` contract, so nothing verified the
/// offline-first invariants for them: tmp-id mint, idempotency key on the
/// enqueued row, `applyCreateResponse` tmp→real remap, `applyUpdateResponse`
/// clearing `is_dirty`, `applyDeleteResponse` hiding the row.
///
/// Mirrors `quote_repository_test.dart`, which closed the same gap for quotes.
/// The contract never touches the network — offline create/save/delete write
/// only to Drift and the outbox — so the API fake throws on every call.
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  runEntityRepositoryContract(
    EntityRepositoryContractFixture<Invoice, InvoiceApi>.build(
      entityType: 'invoice',
      updatedAtOf: (item) => item.updatedAt,
      buildRepo: (db) => InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: SettingsRepository(db: db),
      ),
      buildApiModel: ({required id, displayValue, updatedAt = 1700000000}) =>
          InvoiceApi(id: id, number: displayValue ?? id, updatedAt: updatedAt),
      fromApi: Invoice.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(number: displayValue),
      idOf: (i) => i.id,
      isDirtyOf: (i) => i.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as InvoiceRepository).create(
            companyId: companyId,
            draft: draft,
          ),
      save: (repo, {required companyId, required entity}) =>
          (repo as InvoiceRepository).save(
            companyId: companyId,
            invoice: entity,
          ),
      delete: (repo, {required companyId, required id}) =>
          repo.delete(companyId: companyId, id: id),
    ),
  );
}
