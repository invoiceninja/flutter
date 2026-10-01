import 'dart:convert';
import 'dart:typed_data';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/base_entity_api.dart';
import 'package:admin/data/services/upload_source.dart';

/// Result of `POST /api/v1/einvoice/validateEntity`. [passes] is the
/// server's overall verdict; [messages] flattens the per-entity issue
/// arrays into readable lines (empty when valid).
typedef EInvoiceValidation = ({bool passes, List<String> messages});

/// Parse a `validateEntity` result. Two shapes reach here:
///
///  * **200, passes** (or e-invoicing not PEPPOL/VERIFACTU) — plural keys,
///    empty: `{passes:true, invoices:[], credits:[], recurring_invoices:[],
///    clients:[], companies:[]}`.
///  * **422, fails** — the Peppol `EntityLevel` checker's own map, with
///    SINGULAR keys: `{passes:false, invoice:[...], client:[...],
///    company:[...]}` (`credit` for a credit). Client/company issues are
///    `{field, label}`; invoice issues are XSD/stylesheet strings.
///
/// Only the plural shape was ever read, and the 422 was thrown away as a
/// generic error — so "Validate" said "An error occurred" exactly when there
/// was something to fix. Both key spellings are read; a map element yields its
/// `message` / `label` / `field`, else JSON. Pure + unit-tested.
EInvoiceValidation parseEInvoiceValidation(Object? raw) {
  if (raw is! Map) return (passes: false, messages: const <String>[]);
  final passes = raw['passes'] == true;
  final messages = <String>[];
  for (final group in const [
    'invoices',
    'invoice',
    'credits',
    'credit',
    'recurring_invoices',
    'clients',
    'client',
    'companies',
    'company',
  ]) {
    final list = raw[group];
    if (list is! List) continue;
    for (final e in list) {
      if (e is Map) {
        final m = e['message'] ?? e['label'] ?? e['field'];
        messages.add(m is String && m.isNotEmpty ? m : jsonEncode(e));
      } else if (e is String) {
        if (e.isNotEmpty) messages.add(e);
      } else {
        messages.add('$e');
      }
    }
  }
  return (passes: passes, messages: messages);
}

/// `POST /api/v1/einvoice/validateEntity` for [entity] (`invoices` /
/// `credits`). The server answers a FAILED check with **422** and the
/// checker's result as the body (`EInvoiceController::validateEntity`), so a
/// [ValidationException] carrying `passes` is a result, not an error. A 422
/// without it (an unknown id) still throws.
Future<EInvoiceValidation> validateEInvoiceEntity(
  ApiClient client, {
  required String entity,
  required String id,
}) async {
  try {
    final raw = await client.postJson(
      '/api/v1/einvoice/validateEntity',
      body: {'entity': entity, 'entity_id': id},
      readOnly: true,
    );
    return parseEInvoiceValidation(raw);
  } on ValidationException catch (e) {
    final body = e.body;
    if (body == null || !body.containsKey('passes')) rethrow;
    return parseEInvoiceValidation(body);
  }
}

/// Concrete API for `/api/v1/invoices`. The base class handles list/get/
/// create/update/delete/action; this subclass supplies the path, the
/// parsers, custom action endpoints (markSent / markPaid / email /
/// scheduleEmail / cloneTo / autoBill / cancel / runTemplate), and the
/// multipart document upload.
///
/// Named `InvoicesApi` (plural) to avoid collision with `InvoiceApi` (the
/// single-resource model class in `data/models/api/invoice_api_model.dart`).
class InvoicesApi extends BaseEntityApi<InvoiceListApi, InvoiceItemApi> {
  InvoicesApi(super.client);

  @override
  String get basePath => '/api/v1/invoices';

  @override
  InvoiceListApi parseList(Object json) =>
      InvoiceListApi.fromJson(json as Map<String, dynamic>);

  @override
  InvoiceItemApi parseItem(Object json) =>
      InvoiceItemApi.fromJson(json as Map<String, dynamic>);

  /// `POST /api/v1/invoices/bulk {action:'mark_sent', ids:[id]}` — Draft →
  /// Sent. (The per-id `/{id}/mark_sent` route is GET-only server-side, so
  /// the action must ride the bulk endpoint.) Server returns the affected
  /// invoices; [bulkActionOne] unwraps the single updated invoice.
  Future<InvoiceItemApi?> markSent({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'mark_sent',
    idempotencyKey: idempotencyKey,
  );

  /// `POST /api/v1/invoices/bulk {action:'mark_paid', ids:[id]}` — records a
  /// synthetic payment for the outstanding balance.
  Future<InvoiceItemApi?> markPaid({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'mark_paid',
    idempotencyKey: idempotencyKey,
  );

  /// `POST /api/v1/emails` — send the invoice using a named template
  /// (`invoice`, `reminder1..3`, `endless_reminder`, `custom1..3`). Optional
  /// subject/body/cc override the company default for this send only.
  ///
  /// There is **no** per-id `/{id}/email` route; email is sent via the
  /// dedicated `/emails` endpoint (admin-portal parity), which is the only one
  /// that carries the subject/body/cc overrides. The server expects the full
  /// `email_template_<name>` settings key and replies with the refreshed
  /// entity (`itemResponse`), so the dispatcher upserts the updated invoice.
  Future<InvoiceItemApi?> email({
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) => sendEmail(
    entity: 'invoice',
    id: id,
    template: template,
    subject: subject,
    body: body,
    ccEmail: ccEmail,
    idempotencyKey: idempotencyKey,
  );

  /// Schedule this invoice's email for a future date via a `email_record`
  /// task_scheduler (`scheduleEmailRecord`). Custom subject/body/cc don't apply
  /// to a scheduled send (the scheduler emails the named template), so they're
  /// accepted for call-site parity but ignored. Returns null — the response is
  /// a Scheduler, not the invoice.
  Future<InvoiceItemApi?> scheduleEmail({
    required String id,
    required String template,
    required String sendAt,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) async {
    await scheduleEmailRecord(
      entity: 'invoice',
      id: id,
      template: template,
      sendAt: sendAt,
      idempotencyKey: idempotencyKey,
    );
    return null;
  }

  /// `POST /api/v1/invoices/bulk {action:'clone_to_<target>', ids:[id]}`.
  /// Only `invoice` and `quote` are server-side actions (`InvoiceController::
  /// performAction`); `credit` / `recurring_invoice` / `purchase_order` are
  /// NOT — those are produced client-side by pre-filling the target's create
  /// screen (see invoice_actions). The bulk response returns the *source*
  /// list, so the handler ignores it; the new entity lands on the next sync.
  Future<InvoiceItemApi?> cloneTo({
    required String id,
    required String targetType,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'clone_to_$targetType',
    idempotencyKey: idempotencyKey,
  );

  /// `POST /api/v1/invoices/bulk {action:'auto_bill', ids:[id]}` — charge the
  /// stored payment token on the client. Server returns the updated invoice
  /// (status flips to Partial / Paid on success).
  Future<InvoiceItemApi?> autoBill({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'auto_bill',
    idempotencyKey: idempotencyKey,
  );

  /// `POST /api/v1/invoices/bulk {action:'cancel', ids:[id]}` — mark a sent
  /// invoice as cancelled. Server returns the updated invoice.
  Future<InvoiceItemApi?> cancel({
    required String id,
    required String idempotencyKey,
  }) => bulkActionOne(id: id, action: 'cancel', idempotencyKey: idempotencyKey);

  /// `POST /api/v1/invoices/bulk {action:'template', ids:[id], template_id}` —
  /// apply a design/email template. The server dispatches an async job and
  /// returns a `{message}` (no entity), so [bulkActionOne] yields null.
  Future<InvoiceItemApi?> runTemplate({
    required String id,
    required String templateId,
    required String idempotencyKey,
  }) => bulkActionOne(
    id: id,
    action: 'template',
    idempotencyKey: idempotencyKey,
    extra: {'template_id': templateId},
  );

  /// Fetch a server-rendered PDF for this invoice.
  ///
  /// Two endpoints, picked by [deliveryNote]:
  ///
  /// * Normal layout — `POST /api/v1/live_preview?entity=invoice[&entity_id=<id>]`,
  ///   body = the **full invoice entity** (`Invoice.toApiJson()` — the same
  ///   shape the save/outbox path sends), exactly as React and admin-portal do.
  ///   The server resolves the design from the entity's `design_id`. (The old
  ///   `/api/v1/preview` is the design-editor endpoint and rejects an entity
  ///   body with "Invalid custom design object".) `entity_id` is sent only for
  ///   a saved invoice. Optional [designId] overrides the design.
  ///
  /// * Delivery note (`deliveryNote: true` **and** saved id) —
  ///   `GET /api/v1/invoices/{id}/delivery_note[?design_id=<id>]`. This is the
  ///   only path that actually renders the delivery-note layout: `live_preview`
  ///   ignores a `delivery_note` body field (it hardcodes the PDF type to
  ///   `product`). Matches React (`useGeneratePdfUrl.ts`) and admin-portal
  ///   (`lib/ui/invoice/invoice_pdf.dart`). Requires a real id — for unsaved
  ///   drafts the UI hides the toggle, but if called we fall through to the
  ///   live-preview path so the caller still gets a PDF instead of a 404.
  ///
  /// `readOnly: true` on both wire calls skips the demo-mode short-circuit
  /// and the outbox (reads in effect).
  Future<Uint8List> downloadPdf({
    required Map<String, dynamic> entityJson,
    String? designId,
    bool deliveryNote = false,
  }) {
    final id = (entityJson['id'] as String?) ?? '';
    final saved = id.isNotEmpty && !id.startsWith('tmp_');

    if (deliveryNote && saved) {
      final qs = (designId != null && designId.isNotEmpty)
          ? '?design_id=$designId'
          : '';
      return client.getRaw(
        '/api/v1/invoices/$id/delivery_note$qs',
        readOnly: true,
      );
    }

    final path = StringBuffer('/api/v1/live_preview?entity=invoice')
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

  /// `POST /api/v1/einvoice/peppol/send` `{entity:'invoice', entity_id}` —
  /// transmit the invoice via the configured e-invoice channel
  /// (PEPPOL / Verifactu-AEAT). React parity (`Verifactu.tsx`). The
  /// server owns the transmission; caller re-fetches the invoice after.
  Future<void> sendEInvoice({
    required String id,
    required String idempotencyKey,
  }) async {
    await client.mutate(
      method: 'POST',
      path: '/api/v1/einvoice/peppol/send',
      idempotencyKey: idempotencyKey,
      body: {'entity': 'invoice', 'entity_id': id},
    );
  }

  /// `POST /api/v1/einvoice/validateEntity` `{entity:'invoices',
  /// entity_id}` — pre-flight validation (no transmission). `readOnly` —
  /// it validates, it doesn't submit. See [validateEInvoiceEntity].
  Future<EInvoiceValidation> validateEInvoice(String id) =>
      validateEInvoiceEntity(client, entity: 'invoices', id: id);

  /// `GET /api/v1/invoices/{id}?show_schedule=true` — the only fetch that
  /// embeds the read-only `invoice.schedule[]` payment-schedule projection
  /// (probe-verified: absent on plain/list GETs). Used by the detail
  /// fetch + the payment-schedule custom-action re-fetch.
  Future<InvoiceItemApi> getWithSchedule(String id) async {
    final raw = await client.getOne('$basePath/$id?show_schedule=true');
    return parseItem(raw as Object);
  }

  /// `POST /api/v1/invoices/{id}/payment_schedule?show_schedule=true` —
  /// number-of-payments flow (server expands frequency + cycles into
  /// installments). Body mirrors React: `{template, next_run,
  /// remaining_cycles, frequency_id, parameters:{invoice_id, auto_bill,
  /// schedule:[]}}`. Returns the refreshed invoice (schedule embedded).
  Future<InvoiceApi> createPaymentSchedule({
    required String id,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    final raw = await client.mutate(
      method: 'POST',
      path: '$basePath/$id/payment_schedule?show_schedule=true',
      idempotencyKey: idempotencyKey,
      body: body,
    );
    return parseItem(raw as Object).data;
  }

  /// `POST /api/v1/task_schedulers` — custom-rows flow (caller supplies the
  /// explicit `parameters.schedule[]` rows). The Schedule resource itself
  /// is returned/ignored; the caller re-fetches the invoice afterwards.
  Future<void> createCustomPaymentSchedule({
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    await client.mutate(
      method: 'POST',
      path: '/api/v1/task_schedulers',
      idempotencyKey: idempotencyKey,
      body: body,
    );
  }

  /// `DELETE /api/v1/invoices/{id}/payment_schedule` — clears the invoice's
  /// payment schedule (React's remove flow).
  Future<void> deletePaymentSchedule({
    required String id,
    required String idempotencyKey,
  }) async {
    await client.mutate(
      method: 'DELETE',
      path: '$basePath/$id/payment_schedule',
      idempotencyKey: idempotencyKey,
    );
  }

  /// Upload a document attachment to an invoice. Returns the refreshed
  /// invoice envelope with the new document in its `documents` array.
  /// Mirrors `ClientsApi.uploadDocument` — same multipart field name.
  Future<InvoiceApi> uploadDocument({
    required String entityId,
    required UploadSource source,
    required String idempotencyKey,
  }) async {
    final file = await source.toMultipartFile('documents[]');
    final raw = await client.uploadMultipart(
      path: '$basePath/$entityId/upload',
      // Server route is `Route::put('invoices/{invoice}/upload')` — the
      // multipart POST must spoof PUT via `_method`, else it 404s.
      fields: const {'_method': 'PUT'},
      files: [file],
      idempotencyKey: idempotencyKey,
    );
    return parseItem(raw as Object).data;
  }
}
