import 'dart:typed_data';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/services/base_entity_api.dart';

/// `/api/v1/documents` — the company-wide Documents list, plus the operations
/// addressed by document id rather than by parent record. The per-entity
/// upload (`POST /<entity>/{id}/upload`) lives on each entity's api because
/// its URL is entity-scoped — see `ClientsApi.uploadDocument`.
///
/// `list` / `get` / `update` / `delete` are the inherited [BaseEntityApi]
/// calls. Two server facts shape how they may be used (`docs/documents-list.md`):
/// the documents table has no `is_deleted` column, so a list request must
/// never carry `status=archived|deleted`, `is_deleted` or
/// `without_deleted_clients` (`DocumentRepository.stateQueryParams` sends
/// none); and `PUT` accepts only `name` / `is_public`.
///
/// Delete is the inherited `DELETE /documents/{id}`, password-gated by
/// default. Never `/bulk`: its echo is the deleted rows — none — and its
/// `ids` existence check rejects a batch with one already-gone id.
class DocumentsApi extends BaseEntityApi<DocumentListApi, DocumentItemApi> {
  DocumentsApi(super.client);

  @override
  String get basePath => '/api/v1/documents';

  @override
  DocumentListApi parseList(Object json) =>
      DocumentListApi.fromJson(json as Map<String, dynamic>);

  @override
  DocumentItemApi parseItem(Object json) =>
      DocumentItemApi.fromJson(json as Map<String, dynamic>);

  /// `PUT /api/v1/documents/{id}` with `{is_public: bool}` — the visibility
  /// toggle on a record's Documents tab. Returns the updated document;
  /// callers patch the parent entity's `documents` array locally instead of
  /// refetching the whole entity.
  Future<DocumentApi?> setVisibility({
    required String id,
    required bool isPublic,
    required String idempotencyKey,
  }) async {
    final raw = await client.mutate(
      method: 'PUT',
      path: '$basePath/$id',
      idempotencyKey: idempotencyKey,
      body: {'is_public': isPublic},
    );
    // `{data: {...}}`, like every other PUT — but tolerate a body without it
    // (demo mode answers a mutation with nothing) rather than throw.
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return DocumentApi.fromJson(data);
    }
    return null;
  }

  /// `GET /api/v1/documents/{id}/download` — the file's own bytes.
  ///
  /// This is the route the server hands out as the document's `url`, and it
  /// sits behind `token_auth`: it answers only a request carrying
  /// `X-API-TOKEN`. Handing that url to a browser is what showed users
  /// `{"message":"Invalid token"}` — so every view or download fetches here,
  /// through the client, and never launches the url. See
  /// `docs/document-urls.md`.
  ///
  /// The server gates it on viewing the parent record (`DocumentPolicy::view`)
  /// and streams the file with no content type, hence
  /// `expectedContentType: null`. `readOnly: true` because a read must work in
  /// demo mode too.
  Future<Uint8List> download(String id) => client.getRaw(
    '$basePath/${Uri.encodeComponent(id)}/download',
    readOnly: true,
    expectedContentType: null,
  );

  /// `POST /api/v1/documents/bulk {action:'download', ids}` — server-side
  /// export: the server zips the documents and emails them to the user, so
  /// there's nothing to download client-side (parity with admin-portal +
  /// React; the caller toasts `exported_data`). The response is a document
  /// list we don't need, so this returns void.
  Future<void> bulkDownload({
    required List<String> ids,
    required String idempotencyKey,
  }) async {
    await client.mutate(
      method: 'POST',
      path: '$basePath/bulk',
      idempotencyKey: idempotencyKey,
      body: {'action': 'download', 'ids': ids},
    );
  }
}
