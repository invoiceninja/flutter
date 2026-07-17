import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';

final _log = Logger('CompanySyncDispatcher');

/// Shown when an offline-queued upload's local file is gone at drain time.
const _kUploadSourceGoneMessage =
    'The attached file is no longer available on this device — reopen the '
    'record and attach it again.';

/// Wires the company outbox rows to [CompaniesApi]. Settings + uploads go
/// through `update` (the `_action` field inside the payload steers between
/// the regular settings PUT and the two multipart upload paths); the
/// Danger Zone Delete-company flow goes through `delete`.
class CompanySyncDispatcher implements SyncDispatcher {
  CompanySyncDispatcher({
    required this.api,
    required this.repo,
    required this.documentsApi,
  });

  final CompaniesApi api;
  final CompanyRepository repo;

  /// Doc-scoped delete endpoint (`DELETE /documents/{id}`) — distinct from the
  /// entity-scoped upload on [CompaniesApi]. Mirrors `documentMutationHandlers`,
  /// where the delete also lives on [DocumentsApi].
  final DocumentsApi documentsApi;

  /// Decode the JSON payload defensively. A corrupt row would otherwise
  /// throw to the catch-all in `SyncRepository._attempt` and burn 5 retries
  /// before mark-dead.
  Map<String, dynamic> _decodePayload(OutboxRow row) {
    try {
      return jsonDecode(row.payload) as Map<String, dynamic>;
    } catch (e) {
      _log.severe('Corrupt company payload (row ${row.id}): $e');
      throw ValidationException('Corrupt outbox payload', const {
        'payload': ['Could not decode'],
      });
    }
  }

  // No offline create-with-tmp-id flow → a discarded ghost create can
  // never route here. See SyncDispatcher.deleteLocalRecord.
  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  // Company is a single-row, settings-only entity with no offline
  // create/discard flow → nothing to reconcile.
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    if (kind == MutationKind.delete) {
      final payload = _decodePayload(row);
      await api.deleteWithBody(
        id: row.entityId,
        body: payload,
        idempotencyKey: row.idempotencyKey,
      );
      return;
    }
    // Document delete — doc-scoped endpoint, password-gated. Prune the local
    // `documents` column only after the server confirms (the page's mount
    // refresh would otherwise re-add a not-yet-drained delete).
    if (kind == MutationKind.documentDelete) {
      final payload = _decodePayload(row);
      final documentId = payload['document_id'] as String;
      await documentsApi.delete(
        id: documentId,
        idempotencyKey: row.idempotencyKey,
        requiresPassword: true,
      );
      await repo.removeDocumentLocally(
        companyId: row.companyId,
        documentId: documentId,
      );
      return;
    }
    // E-Invoice / PEPPOL custom actions — each routes to its own endpoint;
    // server returns the refreshed company envelope so we apply it back
    // into Drift the same way the standard settings PUT does.
    if (await _dispatchEInvoice(row, kind)) return;
    if (kind != MutationKind.update) {
      _log.warning('Unexpected mutation kind for company: $kind — skipping.');
      return;
    }
    final payload = _decodePayload(row);
    final action = payload['_action'];
    // The Email Settings page's "Sync send time to existing entities"
    // checkbox stashes a one-shot bool under this control key; pop it
    // before serializing so it doesn't leak into the company PUT body,
    // and pass it as a query param on the canonical settings PUT below.
    final syncSendTime = payload.remove('_sync_send_time');
    // The Invoice Design page's "Update all records" toggles stash a list of
    // `{design_id, entity}` directives here; pop it before serializing so it
    // can't leak into the company PUT body, then fire a `/designs/set/default`
    // POST per entry once the settings land (see below).
    final designUpdates = payload.remove('_design_updates');
    if (action == 'upload_logo') {
      final source = UploadSource.fromPayload(payload);
      if (!await source.exists()) {
        // Dead-letter LOUDLY rather than draining as silent success — the file
        // vanished (native local_path unreadable after restart), so returning
        // would lose the upload while the user believes it saved.
        _log.warning(
          'Logo upload failed: source ${source.fileName} no longer exists.',
        );
        throw const ServerException(400, _kUploadSourceGoneMessage);
      }
      final response = await api.uploadLogo(
        companyId: row.entityId,
        source: source,
        idempotencyKey: row.idempotencyKey,
      );
      await repo.applyUpdateResponse(
        companyId: row.companyId,
        serverResponse: response.data,
      );
      return;
    }
    if (action == 'upload_document') {
      final source = UploadSource.fromPayload(payload);
      if (!await source.exists()) {
        _log.warning(
          'Document upload failed: source ${source.fileName} '
          'no longer exists.',
        );
        throw const ServerException(400, _kUploadSourceGoneMessage);
      }
      final response = await api.uploadDocument(
        companyId: row.entityId,
        source: source,
        idempotencyKey: row.idempotencyKey,
      );
      await repo.applyUpdateResponse(
        companyId: row.companyId,
        serverResponse: response.data,
      );
      return;
    }
    if (action == 'remove_e_invoice_certificate') {
      // The server removes the certificate only when the request *carries*
      // the `e_invoice_certificate` key (then it nulls cert + passphrase and
      // sets enable_e_invoice — CompanyController::update). A normal company
      // PUT never sends that key, so removal is its own PUT with an explicit
      // null. Body is just that key — not the full company — so unrelated
      // columns aren't clobbered.
      final response = await api.update(
        id: row.entityId,
        payload: const {'e_invoice_certificate': null},
        idempotencyKey: row.idempotencyKey,
      );
      await repo.applyUpdateResponse(
        companyId: row.companyId,
        serverResponse: response.data,
      );
      return;
    }
    final response = await api.update(
      id: row.entityId,
      payload: payload,
      idempotencyKey: row.idempotencyKey,
      query: syncSendTime is bool
          ? {'sync_send_time': syncSendTime.toString()}
          : null,
    );
    await repo.applyUpdateResponse(
      companyId: row.companyId,
      serverResponse: response.data,
    );
    // "Update all records": retroactively stamp changed designs onto existing
    // entities. Fired after the settings PUT lands so the new default is
    // already persisted. Each POST gets a per-entity idempotency key derived
    // from the row's, so a retry of this row re-fires them idempotently (and
    // the redundant PUT above dedupes on its own key). At company scope here;
    // the VM only attaches directives when editing the company settings.
    if (designUpdates is List) {
      for (final update in designUpdates) {
        if (update is! Map) continue;
        final designId = update['design_id'];
        final entity = update['entity'];
        if (designId is! String || entity is! String) continue;
        // Best-effort: a set/default failure must NOT fail the settings save —
        // the PUT above already succeeded and applied. The server 400s on a
        // design id it doesn't know; letting that throw here would retry the
        // whole row and eventually mark the (already-applied) settings change
        // dead. Catch per-entity so one failure doesn't block the rest.
        // (Deliberately swallows transient errors too, unlike the dedicated
        // client/group-scope handler in services_design_handlers.dart — the
        // retro-apply here shares its outbox row with the settings PUT, so
        // failing the row would misreport the already-applied save.)
        try {
          await api.setDefaultDesign(
            designId: designId,
            entity: entity,
            settingsLevel: 'company',
            idempotencyKey: '${row.idempotencyKey}:set_default:$entity',
          );
        } catch (e) {
          _log.warning(
            'set/default failed (design=$designId entity=$entity, company '
            '${row.companyId}) — settings save unaffected, retro-apply skipped.',
            e,
          );
        }
      }
    }
  }

  /// E-Invoice / PEPPOL branch table. Returns true when [kind] was handled
  /// so the caller can short-circuit. Each branch reads its row's payload,
  /// fires the matching API call with the outbox idempotency key, and
  /// applies the server response back to Drift.
  Future<bool> _dispatchEInvoice(OutboxRow row, MutationKind kind) async {
    switch (kind) {
      case MutationKind.uploadEInvoiceCertificate:
        final payload = _decodePayload(row);
        final source = UploadSource.fromPayload(payload);
        if (!await source.exists()) {
          _log.warning(
            'Cert upload failed: source ${source.fileName} '
            'no longer exists.',
          );
          throw const ServerException(400, _kUploadSourceGoneMessage);
        }
        final response = await api.uploadEInvoiceCertificate(
          companyId: row.entityId,
          source: source,
          idempotencyKey: row.idempotencyKey,
        );
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: response.data,
        );
        return true;
      case MutationKind.peppolSetup:
        final payload = _decodePayload(row);
        final response = await api.peppolSetup(
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: response.data,
        );
        return true;
      case MutationKind.peppolUpdate:
        final payload = _decodePayload(row);
        final response = await api.peppolUpdatePreferences(
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: response.data,
        );
        return true;
      case MutationKind.peppolDisconnect:
        final payload = _decodePayload(row);
        final response = await api.peppolDisconnect(
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: response.data,
        );
        return true;
      case MutationKind.peppolAddTaxIdentifier:
        final payload = _decodePayload(row);
        final raw = await api.peppolAddTaxIdentifier(
          country: payload['country'] as String,
          vatNumber: payload['vat_number'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        await _applyResponseIfCompany(row.companyId, raw);
        return true;
      case MutationKind.peppolRemoveTaxIdentifier:
        final payload = _decodePayload(row);
        final raw = await api.peppolRemoveTaxIdentifier(
          country: payload['country'] as String,
          vatNumber: payload['vat_number'] as String,
          idempotencyKey: row.idempotencyKey,
        );
        await _applyResponseIfCompany(row.companyId, raw);
        return true;
      case MutationKind.eInvoicePaymentMeans:
        final payload = _decodePayload(row);
        final raw = await api.saveEInvoicePaymentMeans(
          payload: payload,
          idempotencyKey: row.idempotencyKey,
        );
        await _applyResponseIfCompany(row.companyId, raw);
        return true;
      case MutationKind.regenerateEInvoiceToken:
        final response = await api.regenerateEInvoiceToken(
          idempotencyKey: row.idempotencyKey,
        );
        await repo.applyUpdateResponse(
          companyId: row.companyId,
          serverResponse: response.data,
        );
        return true;
      // Not an e-invoice kind — let the caller continue.
      // ignore: no_default_cases
      default:
        return false;
    }
  }

  /// Lenient apply for the three PEPPOL endpoints whose response shape
  /// isn't guaranteed to be a wrapped company envelope —
  /// `peppolAddTaxIdentifier`, `peppolRemoveTaxIdentifier`, and
  /// `eInvoicePaymentMeans`. If the response carries `{data: company}`
  /// we apply it; otherwise we log and skip and let the next `/auth/me`
  /// or company refresh resync the local row.
  Future<void> _applyResponseIfCompany(String companyId, dynamic raw) async {
    if (raw is! Map<String, dynamic>) return;
    final data = raw['data'];
    if (data is! Map<String, dynamic>) return;
    try {
      final company = CompanyApi.fromJson(data);
      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: company,
      );
    } catch (e, st) {
      _log.warning(
        'PEPPOL response did not parse as CompanyApi for $companyId — '
        'skipping local apply',
        e,
        st,
      );
    }
  }
}
