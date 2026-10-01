import 'dart:typed_data';

import 'package:admin/data/services/upload_source.dart';

import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/services/base_entity_api.dart';
import 'package:admin/data/services/invoices_api.dart'
    show EInvoiceValidation, validateEInvoiceEntity;

/// Concrete API for `/api/v1/credits`. Mirrors `QuotesApi` minus the
/// `approve`/`convertToInvoice`/`convertToProject` quote-only actions.
/// Credits share the full email/clone/PDF/upload surface every billing
/// doc has.
class CreditsApi extends BaseEntityApi<CreditListApi, CreditItemApi> {
  CreditsApi(super.client);

  @override
  String get basePath => '/api/v1/credits';

  @override
  CreditListApi parseList(Object json) =>
      CreditListApi.fromJson(json as Map<String, dynamic>);

  @override
  CreditItemApi parseItem(Object json) =>
      CreditItemApi.fromJson(json as Map<String, dynamic>);

  /// `POST /api/v1/einvoice/validateEntity` `{entity:'credits', entity_id}` —
  /// the e-invoice pre-flight, issues reported under `credit`. See
  /// [validateEInvoiceEntity].
  Future<EInvoiceValidation> validateEInvoice(String id) =>
      validateEInvoiceEntity(client, entity: 'credits', id: id);

  // State transitions / clones ride `POST /credits/bulk` ({action, ids:[id]})
  // — the per-id `/{id}/{action}` route is GET-only on the server.
  Future<CreditItemApi?> markSent({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'mark_sent',
    idempotencyKey: idempotencyKey,
  );

  /// `POST /credits/bulk {action:'mark_paid', ids:[id]}` — records a synthetic
  /// payment closing the credit. Surfaced only for negative credits (which
  /// behave like a receivable). Mirrors `InvoicesApi.markPaid`.
  Future<CreditItemApi?> markPaid({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'mark_paid',
    idempotencyKey: idempotencyKey,
  );

  Future<CreditItemApi?> email({
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) => sendEmail(
    entity: 'credit',
    id: id,
    template: template,
    subject: subject,
    body: body,
    ccEmail: ccEmail,
    idempotencyKey: idempotencyKey,
  );

  Future<CreditItemApi?> scheduleEmail({
    required String id,
    required String template,
    required String sendAt,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) async {
    await scheduleEmailRecord(
      entity: 'credit',
      id: id,
      template: template,
      sendAt: sendAt,
      idempotencyKey: idempotencyKey,
    );
    return null;
  }

  Future<CreditItemApi?> cloneTo({
    required String id,
    required String targetType,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'clone_to_$targetType',
    idempotencyKey: idempotencyKey,
  );

  Future<CreditItemApi?> runTemplate({
    required String id,
    required String templateId,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'template',
    idempotencyKey: idempotencyKey,
    extra: {'template_id': templateId},
  );

  /// Server-rendered PDF via `POST /api/v1/live_preview?entity=credit
  /// [&entity_id=<id>]` with the full credit entity (`Credit.toApiJson()`) as
  /// the body — see `InvoicesApi.downloadPdf` for why `/api/v1/preview` is
  /// wrong here.
  Future<Uint8List> downloadPdf({
    required Map<String, dynamic> entityJson,
    String? designId,
  }) {
    final id = (entityJson['id'] as String?) ?? '';
    final saved = id.isNotEmpty && !id.startsWith('tmp_');
    final path = StringBuffer('/api/v1/live_preview?entity=credit')
      ..write(saved ? '&entity_id=$id' : '');
    return client.postRaw(
      path.toString(),
      readOnly: true,
      body: {
        ...entityJson,
        if (designId != null && designId.isNotEmpty) 'design_id': designId,
      },
    );
  }

  Future<CreditApi> uploadDocument({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  }) async {
    final file = await source.toMultipartFile('documents[]');
    final raw = await client.uploadMultipart(
      path: '$basePath/$entityId/upload',
      // Server route is `Route::put('credits/{credit}/upload')`.
      fields: const {'_method': 'PUT'},
      files: [file],
      idempotencyKey: idempotencyKey,
    );
    return parseItem(raw as Object).data;
  }
}
