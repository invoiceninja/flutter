import 'package:admin/data/services/activities_api.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';
import 'package:admin/domain/sync/mutation.dart';

/// The [MutationKind.addComment] dispatcher, identical across the ten entities
/// that can carry an activity note. Spread into `wireEntity`'s `customActions`.
///
/// [entity] is the plural wire name the endpoint expects (`'clients'`,
/// `'invoices'`, …) — the only thing that varied between the ten hand-copied
/// copies of this closure.
///
/// `POST /api/v1/activities/notes` returns no entity payload to apply locally:
/// the note lands in the record's activity feed and the optimistic row is
/// replaced on the next fetch. Fire-and-forget, so the handler returns `null`.
Map<MutationKind, CustomMutationHandler<TInner>> addCommentHandlers<TInner>(
  ActivitiesApi activitiesApi, {
  required String entity,
}) {
  return {
    MutationKind.addComment: ({required row, required payload}) async {
      await activitiesApi.addNote(
        entity: entity,
        entityId: payload['entity_id'] as String,
        notes: payload['notes'] as String,
        idempotencyKey: row.idempotencyKey,
      );
      return null;
    },
  };
}
