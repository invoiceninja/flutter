import 'dart:typed_data';

import 'package:admin/data/services/upload_source.dart';

import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/services/base_entity_api.dart';
import 'package:admin/data/services/stored_pdf.dart';

/// Concrete API for `/api/v1/purchase_orders`. Mirrors `QuotesApi` /
/// `CreditsApi` shape, vendor-centric. Adds PO-specific actions:
/// `expense` (convert PO → receipt → expense) and `add_to_inventory`
/// (Accepted → Received, recording stock). There is no admin `accept` —
/// a PO is accepted by the vendor via the portal (the server's `/bulk`
/// allow-list has no `accept`).
class PurchaseOrdersApi
    extends BaseEntityApi<PurchaseOrderListApi, PurchaseOrderItemApi> {
  PurchaseOrdersApi(super.client);

  @override
  String get basePath => '/api/v1/purchase_orders';

  @override
  PurchaseOrderListApi parseList(Object json) =>
      PurchaseOrderListApi.fromJson(json as Map<String, dynamic>);

  @override
  PurchaseOrderItemApi parseItem(Object json) =>
      PurchaseOrderItemApi.fromJson(json as Map<String, dynamic>);

  // State transitions ride `POST /purchase_orders/bulk` ({action, ids:[id]})
  // — the per-id `/{id}/{action}` route is GET-only on the server.
  Future<PurchaseOrderItemApi?> markSent({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'mark_sent',
    idempotencyKey: idempotencyKey,
  );

  Future<PurchaseOrderItemApi?> addToInventory({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'add_to_inventory',
    idempotencyKey: idempotencyKey,
  );

  Future<PurchaseOrderItemApi?> cancel({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(id: id, action: 'cancel', idempotencyKey: idempotencyKey);

  Future<PurchaseOrderItemApi?> expense({
    required String id,
    required String idempotencyKey,
  }) =>
      bulkActionOne(id: id, action: 'expense', idempotencyKey: idempotencyKey);

  Future<PurchaseOrderItemApi?> email({
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) => sendEmail(
    entity: 'purchase_order',
    id: id,
    template: template,
    subject: subject,
    body: body,
    ccEmail: ccEmail,
    idempotencyKey: idempotencyKey,
  );

  Future<PurchaseOrderItemApi?> scheduleEmail({
    required String id,
    required String template,
    required String sendAt,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) async {
    await scheduleEmailRecord(
      entity: 'purchase_order',
      id: id,
      template: template,
      sendAt: sendAt,
      idempotencyKey: idempotencyKey,
    );
    return null;
  }

  Future<PurchaseOrderItemApi?> runTemplate({
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
  /// (`fetchStoredPdf` — the only path that carries the vendor's DocuNinja
  /// signature), else the purchase-order sub-path
  /// `POST /api/v1/live_preview/purchase_order?entity=purchase_order
  /// [&entity_id=<id>]` (React + admin-portal both use this sub-path) with the
  /// full PO entity (`PurchaseOrder.toApiJson()`) as the body — see
  /// `InvoicesApi.downloadPdf` for why `/api/v1/preview` is wrong here.
  Future<Uint8List> downloadPdf({
    required Map<String, dynamic> entityJson,
    String? designId,
    String? storedPdfKey,
  }) {
    Future<Uint8List> livePreview() {
      final id = (entityJson['id'] as String?) ?? '';
      final saved = id.isNotEmpty && !id.startsWith('tmp_');
      final path = StringBuffer(
        '/api/v1/live_preview/purchase_order?entity=purchase_order',
      )..write(saved ? '&entity_id=$id' : '');
      return client.postRaw(
        path.toString(),
        readOnly: true,
        body: {
          ...entityJson,
          if (designId != null && designId.isNotEmpty) 'design_id': designId,
        },
      );
    }

    return fetchStoredPdf(
      client: client,
      entity: 'purchase_order',
      storedPdfKey: storedPdfKey,
      entityJson: entityJson,
      designId: designId,
      livePreview: livePreview,
    );
  }

  /// Authenticated download of the generated e-purchase-order XML (UBL /
  /// e-invoice). `GET /api/v1/purchase_order/{invitation_key}/
  /// download_e_purchase_order` is `token_auth`-gated (NOT a public portal
  /// route), so it rides the normal `ApiClient` headers (`X-API-Token`);
  /// `readOnly: true` keeps it demo-safe. Mirrors how React fetches the file
  /// as a blob rather than opening the URL — a bare browser launch sends no
  /// token header and 403s.
  Future<Uint8List> downloadEPurchaseOrder({required String invitationKey}) =>
      client.getRaw(
        '/api/v1/purchase_order/$invitationKey/download_e_purchase_order',
        readOnly: true,
        expectedContentType: 'application/xml',
      );

  Future<PurchaseOrderApi> uploadDocument({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  }) async {
    final file = await source.toMultipartFile('documents[]');
    final raw = await client.uploadMultipart(
      path: '$basePath/$entityId/upload',
      // Server route is `Route::put('purchase_orders/{purchase_order}/upload')`.
      fields: const {'_method': 'PUT'},
      files: [file],
      idempotencyKey: idempotencyKey,
    );
    return parseItem(raw as Object).data;
  }
}
