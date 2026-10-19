import 'dart:typed_data';

import 'package:admin/data/services/upload_source.dart';

import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/models/domain/recurring_schedule_date.dart';
import 'package:admin/data/services/base_entity_api.dart';

/// Concrete API for `/api/v1/recurring_invoices`. Mirrors `InvoicesApi`
/// minus the invoice-only actions (mark_paid / auto_bill / cancel) and
/// adds the recurring-specific `start` / `stop` lifecycle actions.
class RecurringInvoicesApi
    extends BaseEntityApi<RecurringInvoiceListApi, RecurringInvoiceItemApi> {
  RecurringInvoicesApi(super.client);

  @override
  String get basePath => '/api/v1/recurring_invoices';

  @override
  RecurringInvoiceListApi parseList(Object json) =>
      RecurringInvoiceListApi.fromJson(json as Map<String, dynamic>);

  @override
  RecurringInvoiceItemApi parseItem(Object json) =>
      RecurringInvoiceItemApi.fromJson(json as Map<String, dynamic>);

  // Recurring lifecycle actions ride `POST /recurring_invoices/bulk`
  // ({action, ids:[id]}) — start / stop / update_prices / increase_prices /
  // template — there is no per-id `/{id}/{action}` route. (send_now is the
  // exception: it rides a normal update as `?send_now=true`; see
  // RecurringInvoiceRepository.sendNow. mark_sent is not a recurring action.)
  Future<RecurringInvoiceItemApi?> start({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(id: id, action: 'start', idempotencyKey: idempotencyKey);

  Future<RecurringInvoiceItemApi?> stop({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(id: id, action: 'stop', idempotencyKey: idempotencyKey);

  Future<RecurringInvoiceItemApi?> cloneTo({
    required String id,
    required String targetType,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'clone_to_$targetType',
    idempotencyKey: idempotencyKey,
  );

  Future<RecurringInvoiceItemApi?> runTemplate({
    required String id,
    required String templateId,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'template',
    idempotencyKey: idempotencyKey,
    extra: {'template_id': templateId},
  );

  Future<RecurringInvoiceItemApi?> updatePrices({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'update_prices',
    idempotencyKey: idempotencyKey,
  );

  Future<RecurringInvoiceItemApi?> increasePrices({
    required String id,
    required String percentageIncrease,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'increase_prices',
    idempotencyKey: idempotencyKey,
    extra: {'percentage_increase': num.tryParse(percentageIncrease) ?? 0},
  );

  /// The server-computed upcoming schedule (send + due dates) for a saved
  /// recurring invoice: `GET /api/v1/recurring_invoices/{id}?show_dates=true`.
  /// The transformer leaves `recurring_dates` empty unless `show_dates=true`,
  /// and computes each due date from the client's payment terms — richer than
  /// the client-side frequency preview. Read-only / on-demand (no outbox, no
  /// Drift, not part of the normal payload). Returns `[]` for an unsaved id.
  Future<List<RecurringScheduleDate>> fetchSchedule({
    required String id,
  }) async {
    if (id.isEmpty || id.startsWith('tmp_')) return const [];
    final raw = await client.getOneWithQuery(
      '$basePath/$id',
      query: const {'show_dates': 'true'},
    );
    if (raw is! Map) return const [];
    final data = raw['data'];
    if (data is! Map) return const [];
    final dates = data['recurring_dates'];
    if (dates is! List) return const [];
    return dates
        .whereType<Map<String, dynamic>>()
        .map(RecurringScheduleDate.fromJson)
        .toList(growable: false);
  }

  /// Server-rendered PDF via `POST /api/v1/live_preview?entity=recurring_invoice
  /// [&entity_id=<id>]` with the full entity (`RecurringInvoice.toApiJson()`)
  /// as the body — see `InvoicesApi.downloadPdf` for why `/api/v1/preview` is
  /// wrong here.
  Future<Uint8List> downloadPdf({
    required Map<String, dynamic> entityJson,
    String? designId,
  }) {
    final id = (entityJson['id'] as String?) ?? '';
    final saved = id.isNotEmpty && !id.startsWith('tmp_');
    final path = StringBuffer('/api/v1/live_preview?entity=recurring_invoice')
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

  Future<RecurringInvoiceApi> uploadDocument({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  }) async {
    final file = await source.toMultipartFile('documents[]');
    final raw = await client.uploadMultipart(
      path: '$basePath/$entityId/upload',
      // Server route is PUT `recurring_invoices/{recurring_invoice}/upload`.
      fields: const {'_method': 'PUT'},
      files: [file],
      idempotencyKey: idempotencyKey,
    );
    return parseItem(raw as Object).data;
  }
}
