import 'dart:typed_data';

import 'package:admin/data/services/upload_source.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/base_entity_api.dart';

/// Concrete API for `/api/v1/clients`. The base class handles list/get/create/
/// update/delete/action; this subclass only supplies the path and the
/// parsers that lift `Map<String, dynamic>` into typed envelopes.
///
/// Named `ClientsApi` (plural) to avoid collision with `ClientApi` (the
/// single-resource model class in `data/models/api/client_api_model.dart`).
class ClientsApi extends BaseEntityApi<ClientListApi, ClientItemApi> {
  ClientsApi(super.client);

  @override
  String get basePath => '/api/v1/clients';

  @override
  ClientListApi parseList(Object json) =>
      ClientListApi.fromJson(json as Map<String, dynamic>);

  @override
  ClientItemApi parseItem(Object json) =>
      ClientItemApi.fromJson(json as Map<String, dynamic>);

  /// Fetch the client statement PDF. Returns raw bytes; the caller hands them
  /// to `PdfPreview`. The endpoint is `POST /api/v1/client_statement` but is a
  /// server-side read (no mutation) — flagged [readOnly] so demo builds work
  /// and no outbox row is created.
  Future<Uint8List> getStatement({
    required String clientId,
    required Date startDate,
    required Date endDate,
    required String status,
    required bool showPayments,
    required bool showCredits,
    required bool showAging,
  }) {
    return client.postRaw(
      '/api/v1/client_statement',
      readOnly: true,
      body: {
        'client_id': clientId,
        'start_date': startDate.toIso(),
        'end_date': endDate.toIso(),
        'show_payments_table': showPayments,
        'show_credits_table': showCredits,
        'show_aging_table': showAging,
        'status': status,
      },
    );
  }

  /// Upload a document attachment to a client. Returns the refreshed client
  /// envelope with the new document in its `documents` array. Mirrors the
  /// `CompaniesApi.uploadDocument` shape — same multipart field name.
  Future<ClientApi> uploadDocument({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  }) async {
    final file = await source.toMultipartFile('documents[]');
    final raw = await client.uploadMultipart(
      path: '$basePath/$entityId/upload',
      fields: const {'_method': 'PUT'},
      files: [file],
      idempotencyKey: idempotencyKey,
    );
    return parseItem(raw as Object).data;
  }

  /// Merge two clients: absorb [mergeFromId] into [mergeIntoId] (the
  /// survivor). `POST /api/v1/clients/{into}/{from}/merge`, no body.
  /// Password-gated server-side (412) — `client.mutate` injects
  /// `X-API-PASSWORD-BASE64` from the cache (or raises
  /// `PasswordRequiredException`, which the sync gate turns into the
  /// ConfirmPasswordSheet). Returns the surviving client envelope.
  Future<ClientApi> merge({
    required String mergeIntoId,
    required String mergeFromId,
    required String idempotencyKey,
    bool requiresPassword = true,
  }) async {
    final raw = await client.mutate(
      method: 'POST',
      path: '$basePath/$mergeIntoId/$mergeFromId/merge',
      idempotencyKey: idempotencyKey,
      requiresPassword: requiresPassword,
    );
    return parseItem(raw as Object).data;
  }

  /// `POST /clients/{id}/check_vat` — queue a VIES lookup of the client's
  /// *saved* VAT number (`CheckVat` job, server 5.13.45). The verdict lands
  /// in the server's cache for [vatStatus] to read, and the job writes
  /// `has_valid_vat_number` itself.
  ///
  /// Direct, not through the outbox: it's a check the user runs and reads
  /// the answer to straight away, like the mailer check — queued, a result
  /// would arrive with nobody waiting for it.
  Future<void> checkVat(String id) =>
      client.postJson('$basePath/$id/check_vat');

  /// `GET /clients/{id}/vat_status` — `pending`, `valid`, `invalid` or
  /// `unavailable` (VIES gave no verdict), or null once the cached result has
  /// expired or been read: the server forgets a verdict on the first read
  /// that isn't `pending`.
  Future<String?> vatStatus(String id) async {
    final raw = await client.getOne('$basePath/$id/vat_status');
    final message = raw is Map<String, dynamic> ? raw['message'] : null;
    return message is String ? message : null;
  }

  /// `POST /clients/{id}/peppol_discovery` — whether the client can be found
  /// on the PEPPOL network, so an e-invoice can reach it (hosted, 5.13.45).
  /// Null when the reply isn't the boolean it should be. Read-only.
  Future<bool?> peppolDiscovery(String id) async {
    final raw = await client.postJson(
      '$basePath/$id/peppol_discovery',
      readOnly: true,
    );
    final message = raw is Map<String, dynamic> ? raw['message'] : null;
    return message is bool ? message : null;
  }
}
