import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/domain/sync/mutation.dart';

/// Append a user comment to a record's activity stream.
///
/// Hits `/api/v1/activities/notes` via the outbox; the dispatcher's
/// `customActions` map (registered in `services_entity_wiring.dart`) calls the
/// `ActivitiesApi`. The pending outbox row is what drives the optimistic
/// "syncing…" entry in the Comments card and Activity tab.
///
/// Mixed into the twelve repositories whose entity can carry a comment — every
/// entity `StoreNoteRequest` accepts except bank transactions. The first ten
/// each carried a byte-identical copy of this method, differing only in the
/// name of the id parameter (`clientId`, `quoteId`, `recurringExpenseId`, …),
/// which is now uniformly `entityId` — so `call_note_sink.dart`'s switch differs
/// only in the repository it dispatches to. Task and Project joined later.
///
/// Deliberately a mixin rather than a method on [BaseEntityRepository]: only
/// these twelve wire the `addComment` dispatch handler, so the base would offer
/// every repository a mutation whose drain has no handler.
mixin EntityCommentMutations<TDomain, TApi>
    on BaseEntityRepository<TDomain, TApi> {
  Future<void> addComment({
    required String companyId,
    required String entityId,
    required String text,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: entityId,
    kind: MutationKind.addComment,
    payload: {'entity_id': entityId, 'notes': text.trim()},
  );
}
