import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/base_entity_sync_dispatcher.dart';
import 'package:admin/domain/sync/mutation.dart';

/// Per-entity document mutation handlers for the sync dispatcher.
///
/// Returns the trio of [MutationKind.documentUpload],
/// [MutationKind.documentDelete], and [MutationKind.documentVisibility]
/// dispatchers — identical in shape across every document-bearing entity
/// (Client, Product, Project, and the upcoming Expense / Vendor / Invoice).
/// Spread into [wireEntity]'s `customActions` so entities with extra
/// non-document actions (Task's `reorder`, Client's `addComment`) merge in
/// one place.
///
/// The factory lives here rather than on [BaseEntityRepository] because the
/// three endpoints span two services: the entity-scoped upload
/// (`POST /<entity>/{id}/upload`) and the doc-scoped delete + visibility
/// (`DocumentsApi`). The dispatcher layer is where multi-service HTTP shape
/// belongs; repositories stay focused on Drift + outbox.
Map<MutationKind, CustomMutationHandler<TInner>>
documentMutationHandlers<TInner>({
  required DocumentsApi documentsApi,
  required Future<TInner> Function({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  })
  upload,
  required Future<void> Function({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  })
  applyChanged,
  required Future<void> Function({
    required String companyId,
    required String entityId,
    required String documentId,
  })
  applyDeleted,
}) {
  return {
    MutationKind.documentUpload: ({required row, required payload}) async {
      final entityId = payload['entity_id'] as String;
      final source = UploadSource.fromPayload(payload);
      // Source moved/deleted between enqueue and dispatch. Dead-letter LOUDLY
      // instead of returning null: a null return is treated as terminal
      // SUCCESS by the dispatcher, so the queued attachment would silently
      // vanish while the user's earlier "uploaded document" toast made them
      // believe it was saved. A 4xx ServerException marks the row dead with
      // this message + a DeadEvent so the failure surfaces (outbox + toast) and
      // the user can re-attach. Native local_path sources can go unreadable
      // across an app restart (macOS sandbox powerbox grant lost; iOS tmp copy
      // wiped); bytes sources are self-contained and never trip this.
      if (!await source.exists()) {
        throw const ServerException(
          400,
          'The attached file is no longer available on this device — reopen '
          'the record and attach it again.',
        );
      }
      return upload(
        entityId: entityId,
        source: source,
        idempotencyKey: row.idempotencyKey,
      );
    },
    MutationKind.documentDelete: ({required row, required payload}) async {
      final documentId = payload['document_id'] as String;
      final entityId = payload['entity_id'] as String;
      try {
        await documentsApi.delete(
          id: documentId,
          idempotencyKey: row.idempotencyKey,
          requiresPassword: true,
        );
      } on NotFoundException {
        // Already gone server-side (deleted from another device, or a retry
        // after a lost-success response) — the delete's goal is achieved. Fall
        // through to applyDeleted so the local documents[] entry is pruned and
        // the outbox row drains as success, instead of parking as a 404
        // conflict that mislabels the parent entity as "deleted on the server".
        // Mirrors the generic delete/purge NotFoundException handling.
      }
      await applyDeleted(
        companyId: row.companyId,
        entityId: entityId,
        documentId: documentId,
      );
      return null;
    },
    MutationKind.documentVisibility: ({required row, required payload}) async {
      final documentId = payload['document_id'] as String;
      final entityId = payload['entity_id'] as String;
      final isPublic = payload['is_public'] as bool;
      final updated = await documentsApi.setVisibility(
        id: documentId,
        isPublic: isPublic,
        idempotencyKey: row.idempotencyKey,
      );
      if (updated != null) {
        await applyChanged(
          companyId: row.companyId,
          entityId: entityId,
          document: updated,
        );
      }
      return null;
    },
  };
}
