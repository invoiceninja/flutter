import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/base_entity_api.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';

/// Custom handler for an entity-specific mutation kind (e.g. `addComment`).
/// Returns the inner server-response DTO if the action produced an entity to
/// upsert, or null otherwise. The dispatcher routes the response through
/// `repo.applyUpdateResponse` when non-null, mirroring archive/restore.
typedef CustomMutationHandler<TInner> =
    Future<TInner?> Function({
      required OutboxRow row,
      required Map<String, dynamic> payload,
    });

/// Generic CRUD-list dispatcher. Drives every entity whose API extends
/// `BaseEntityApi<TList, TItem>` and whose repository extends
/// `BaseEntityRepository<TDomain, TInner>`. `TItem` is the envelope returned
/// by the server (`{ data: <entity> }`); `TInner` is the inner DTO the repo
/// upserts. The DI block passes `dataOf` as a one-liner tear-off, e.g.
/// `dataOf: (item) => item.data`.
///
/// Non-CRUD actions (e.g. `addComment` against `/api/v1/activities/notes`,
/// or future `send_email` / `mark_paid`) are wired via [customActions]: each
/// entity registers a `MutationKind -> handler` map that takes precedence
/// over the standard CRUD switch.
///
/// Non-standard flows (multipart uploads, settings-only PUT) keep their own
/// dispatcher — see `CompanySyncDispatcher` and `UserSettingsSyncDispatcher`.
class BaseEntitySyncDispatcher<TItem, TInner> implements SyncDispatcher {
  BaseEntitySyncDispatcher({
    required this.api,
    required this.repo,
    required this.dataOf,
    Map<MutationKind, CustomMutationHandler<TInner>>? customActions,
  }) : customActions = customActions ?? const {};

  final BaseEntityApi<dynamic, TItem> api;
  final BaseEntityRepository<dynamic, TInner> repo;
  final TInner Function(TItem item) dataOf;
  final Map<MutationKind, CustomMutationHandler<TInner>> customActions;

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) => repo.deleteLocalById(companyId: companyId, id: id);

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => repo.clearLocalDirty(companyId: companyId, id: id);

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    // SAVE-PARAM actions ride inside the create/update payload under a
    // reserved key. Strip it out of the JSON body and promote it to the
    // request's query string so the server performs the action as part of
    // the same save round-trip (no temp-id gap). Reserved key, so removing
    // it unconditionally is safe for every dispatch path.
    final rawSaveQuery = payload.remove(kSaveQueryPayloadKey);
    final Map<String, String>? saveQuery = rawSaveQuery is Map
        ? rawSaveQuery.map((k, v) => MapEntry(k.toString(), v.toString()))
        : null;
    final custom = customActions[kind];
    if (custom != null) {
      final response = await custom(row: row, payload: payload);
      if (response != null) {
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: response,
        );
      }
      return;
    }
    switch (kind) {
      case MutationKind.create:
        final response = await api.create(
          payload: payload,
          idempotencyKey: row.idempotencyKey,
          query: saveQuery,
        );
        await repo.applyCreateResponse(
          companyId: row.companyId,
          tempId: row.entityId,
          serverResponse: dataOf(response),
        );
      case MutationKind.update:
        final response = await api.update(
          id: row.entityId,
          payload: payload,
          idempotencyKey: row.idempotencyKey,
          query: saveQuery,
        );
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: dataOf(response),
        );
      case MutationKind.delete:
        try {
          await api.delete(
            id: row.entityId,
            idempotencyKey: row.idempotencyKey,
            requiresPassword: row.requiresPassword,
          );
        } on NotFoundException {
          // Already gone server-side — a delete whose target no longer exists
          // has achieved its goal. Fall through to applyDeleteResponse so the
          // local row is marked deleted and the outbox row drains as success,
          // instead of parking as a conflict that offers a nonsensical
          // "recreate".
        }
        await repo.applyDeleteResponse(
          companyId: row.companyId,
          id: row.entityId,
        );
      case MutationKind.archive:
        final response = await api.bulkActionOne(
          id: row.entityId,
          action: 'archive',
          idempotencyKey: row.idempotencyKey,
        );
        if (response != null) {
          await repo.applyUpdateResponse(
            companyId: row.companyId,
            serverResponse: dataOf(response),
          );
        } else {
          // The bulk action drained successfully but returned no entity (the
          // server's re-query found zero rows for the id — e.g. it was purged
          // elsewhere). The optimistic flip left the local row is_dirty=true;
          // without reconciliation it stays dirty forever and every /refresh
          // skips it (stale "unsynced" badge). Clear the flag. (L8)
          await repo.clearLocalDirty(
            companyId: row.companyId,
            id: row.entityId,
          );
        }
      case MutationKind.restore:
        final response = await api.bulkActionOne(
          id: row.entityId,
          action: 'restore',
          idempotencyKey: row.idempotencyKey,
        );
        if (response != null) {
          await repo.applyUpdateResponse(
            companyId: row.companyId,
            serverResponse: dataOf(response),
          );
        } else {
          // See archive: clear the optimistic dirty flag when the bulk action
          // returns no entity, so the row isn't refresh-skipped forever. (L8)
          await repo.clearLocalDirty(
            companyId: row.companyId,
            id: row.entityId,
          );
        }
      case MutationKind.purge:
        // POST /<entity>/:id/purge — password-gated server-side, so the
        // outbox row's `requiresPassword` flag is honored. The server's
        // response (if any) is irrelevant: the entity is gone. We ignore
        // it and let `applyPurgeResponse` drop the local row.
        try {
          await api.action(
            id: row.entityId,
            action: 'purge',
            idempotencyKey: row.idempotencyKey,
            requiresPassword: row.requiresPassword,
          );
        } on NotFoundException {
          // Already gone server-side — purge's goal is "entity removed", which
          // is already true. Fall through to applyPurgeResponse (idempotent
          // success) rather than parking as a conflict.
        }
        await repo.applyPurgeResponse(
          companyId: row.companyId,
          id: row.entityId,
        );
      case MutationKind.addComment:
      case MutationKind.documentUpload:
      case MutationKind.documentDelete:
      case MutationKind.documentVisibility:
      case MutationKind.reorder:
      case MutationKind.start:
      case MutationKind.stop:
      case MutationKind.markSent:
      case MutationKind.sendEInvoice:
      case MutationKind.markPaid:
      case MutationKind.emailEntity:
      case MutationKind.scheduleEmail:
      case MutationKind.cloneToInvoice:
      case MutationKind.cloneToQuote:
      case MutationKind.cloneToCredit:
      case MutationKind.cloneToRecurring:
      case MutationKind.cloneToPurchaseOrder:
      case MutationKind.autoBill:
      case MutationKind.cancelEntity:
      case MutationKind.runTemplate:
      case MutationKind.updatePrices:
      case MutationKind.increasePrices:
      case MutationKind.approve:
      case MutationKind.convertToInvoice:
      case MutationKind.convertToProject:
      case MutationKind.acceptOrder:
      case MutationKind.convertToExpense:
      case MutationKind.addToInventory:
      case MutationKind.sendNow:
      // Bank-integration kinds — routed via custom dispatchers on the
      // BankAccount / BankTransaction repos (not this generic base).
      // Reaching here means a non-bank repo wired one of these by
      // mistake, same configuration-error story as the PEPPOL kinds.
      case MutationKind.refreshAccounts:
      case MutationKind.matchToPayment:
      case MutationKind.linkToPayment:
      case MutationKind.matchToExpense:
      case MutationKind.linkToExpense:
      case MutationKind.convertMatched:
      case MutationKind.unlinkTransaction:
      case MutationKind.inviteUser:
      case MutationKind.detachFromCompany:
      // Payment-only kinds — wired via `customActions` on the Payment
      // dispatcher. Reaching here means a non-Payment repo wired one in.
      case MutationKind.refundPayment:
      case MutationKind.applyPayment:
      // Multi-entity — wired via `reactivateEmailHandlers` in
      // `customActions` on the Client + the five billing-doc dispatchers.
      case MutationKind.reactivateEmail:
      // Wired via `bulkUpdateHandler` in `customActions` on the Client, Task,
      // Expense and Recurring Invoice dispatchers.
      case MutationKind.bulkUpdate:
      // Client-only — wired via `customActions` on the Client dispatcher.
      case MutationKind.merge:
      case MutationKind.locationCreate:
      case MutationKind.locationUpdate:
      case MutationKind.locationDelete:
      // Client + group settings — Invoice Design "update all records" retro-
      // apply, wired via `customActions` on the Client + GroupSetting
      // dispatchers (company scope fires it inline from CompanySyncDispatcher).
      case MutationKind.setDefaultDesign:
      // Invoice-only — wired via `customActions` on the Invoice dispatcher.
      case MutationKind.paymentScheduleCreate:
      case MutationKind.paymentScheduleCreateCustom:
      case MutationKind.paymentScheduleDelete:
      // E-Invoice / PEPPOL kinds are company-only — handled by
      // `CompanySyncDispatcher`, not this generic dispatcher. Reaching
      // here means a non-company repo wired one into its outbox, which
      // is always a configuration error.
      case MutationKind.uploadEInvoiceCertificate:
      case MutationKind.peppolSetup:
      case MutationKind.peppolUpdate:
      case MutationKind.peppolDisconnect:
      case MutationKind.peppolAddTaxIdentifier:
      case MutationKind.peppolRemoveTaxIdentifier:
      case MutationKind.eInvoicePaymentMeans:
      case MutationKind.regenerateEInvoiceToken:
        // Non-CRUD action. Reaching here means the entity wired this kind
        // into the outbox without registering a [customActions] handler —
        // a configuration error, not a runtime condition.
        throw StateError(
          'No customActions handler registered for ${kind.wireName} on '
          '${row.entityType}',
        );
    }
  }
}
