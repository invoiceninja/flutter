import 'dart:typed_data';

import 'package:admin/data/services/upload_source.dart';

import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/services/base_entity_api.dart';
import 'package:admin/data/services/stored_pdf.dart';

/// Concrete API for `/api/v1/quotes`. Mirrors `InvoicesApi` — same custom
/// actions where they apply (markSent / email / scheduleEmail / cloneTo /
/// cancel / runTemplate / uploadDocument), plus quote-specific
/// `approve` / `convertToInvoice` / `convertToProject`.
///
/// Quotes have **no** mark-paid / auto-bill (those are payment-side
/// actions only relevant to invoices). Cancel is supported on the server
/// for quotes but rarely used in practice.
class QuotesApi extends BaseEntityApi<QuoteListApi, QuoteItemApi> {
  QuotesApi(super.client);

  @override
  String get basePath => '/api/v1/quotes';

  @override
  QuoteListApi parseList(Object json) =>
      QuoteListApi.fromJson(json as Map<String, dynamic>);

  @override
  QuoteItemApi parseItem(Object json) =>
      QuoteItemApi.fromJson(json as Map<String, dynamic>);

  // State transitions / conversions / clones ride `POST /quotes/bulk`
  // ({action, ids:[id]}) — the per-id `/{id}/{action}` route is GET-only.
  Future<QuoteItemApi?> markSent({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'mark_sent',
    idempotencyKey: idempotencyKey,
  );

  Future<QuoteItemApi?> approve({
    required String id,
    required String idempotencyKey,
  }) =>
      bulkActionOne(id: id, action: 'approve', idempotencyKey: idempotencyKey);

  Future<QuoteItemApi?> convertToInvoice({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'convert_to_invoice',
    idempotencyKey: idempotencyKey,
  );

  Future<QuoteItemApi?> convertToProject({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'convert_to_project',
    idempotencyKey: idempotencyKey,
  );

  Future<QuoteItemApi?> email({
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) => sendEmail(
    entity: 'quote',
    id: id,
    template: template,
    subject: subject,
    body: body,
    ccEmail: ccEmail,
    idempotencyKey: idempotencyKey,
  );

  Future<QuoteItemApi?> scheduleEmail({
    required String id,
    required String template,
    required String sendAt,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) async {
    // The scheduled `email_record` job runs through
    // `Quote/SendEmail::resolveTemplateString`, whose match arms are the BARE
    // names `quote | reminder1 | custom1..3` (it maps `reminder1` →
    // `email_quote_template_reminder1` itself). The composer carries the
    // canonical `quote_reminder1` key, so strip the `quote_` infix here —
    // otherwise the unknown token falls to `default` and silently sends the
    // INITIAL quote template. (Immediate `/emails` sends differ: they want the
    // full settings key — see [emailTemplateWireName].)
    final scheduledName = template == 'quote_reminder1'
        ? 'reminder1'
        : template;
    await scheduleEmailRecord(
      entity: 'quote',
      id: id,
      template: scheduledName,
      sendAt: sendAt,
      idempotencyKey: idempotencyKey,
    );
    return null;
  }

  Future<QuoteItemApi?> cloneTo({
    required String id,
    required String targetType,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'clone_to_$targetType',
    idempotencyKey: idempotencyKey,
  );

  Future<QuoteItemApi?> cancel({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(id: id, action: 'cancel', idempotencyKey: idempotencyKey);

  Future<QuoteItemApi?> runTemplate({
    required String id,
    required String templateId,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'template',
    idempotencyKey: idempotencyKey,
    extra: {'template_id': templateId},
  );

  /// Server-rendered PDF: the stored render when [storedPdfKey] allows it
  /// (`fetchStoredPdf` — the only path that carries the client's signature
  /// once a quote is approved through DocuNinja), else
  /// `POST /api/v1/live_preview?entity=quote[&entity_id=<id>]` with the full
  /// quote entity (`Quote.toApiJson()`) as the body — see
  /// `InvoicesApi.downloadPdf` for why `/api/v1/preview` is wrong here.
  Future<Uint8List> downloadPdf({
    required Map<String, dynamic> entityJson,
    String? designId,
    String? storedPdfKey,
  }) {
    final stored = fetchStoredPdf(
      client: client,
      entity: 'quote',
      storedPdfKey: storedPdfKey,
      entityJson: entityJson,
      designId: designId,
    );
    if (stored != null) return stored;
    final id = (entityJson['id'] as String?) ?? '';
    final saved = id.isNotEmpty && !id.startsWith('tmp_');
    final path = StringBuffer('/api/v1/live_preview?entity=quote')
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

  Future<QuoteApi> uploadDocument({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  }) async {
    final file = await source.toMultipartFile('documents[]');
    final raw = await client.uploadMultipart(
      path: '$basePath/$entityId/upload',
      // Server route is `Route::put('quotes/{quote}/upload')` — the multipart
      // POST must spoof PUT via `_method`, else it 404s. (Matches companies.)
      fields: const {'_method': 'PUT'},
      files: [file],
      idempotencyKey: idempotencyKey,
    );
    return parseItem(raw as Object).data;
  }
}
