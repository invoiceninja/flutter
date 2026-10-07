import 'dart:typed_data';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/domain/email_template_names.dart';
import 'package:admin/utils/perf_trace.dart';

/// Generic API contract every entity-specific `*Api` implements (by extension
/// or by composition with [ApiClient]). The shape is uniform so the sync
/// engine, outbox dispatcher, and registry don't need entity-specific code
/// paths.
///
/// Concrete classes (`ClientApi`, `InvoiceApi`, etc.) supply the path and the
/// parsers that lift raw `Map<String, dynamic>` into typed list/item envelopes.
abstract class BaseEntityApi<TList, TItem> {
  BaseEntityApi(this.client);
  final ApiClient client;

  /// The collection path, e.g. `/api/v1/clients`.
  String get basePath;

  TList parseList(Object json);
  TItem parseItem(Object json);

  Future<({TList data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    final result = await client.getList(
      basePath,
      page: page,
      perPage: perPage,
      search: search,
      sinceUpdatedAt: sinceUpdatedAt,
      sinceId: sinceId,
      filters: filters,
    );
    return (
      data: traceSync(
        'page.parse',
        () => parseList(result.data as Object),
        args: {'path': basePath},
      ),
      cursorUpdatedAt: result.cursorUpdatedAt,
      cursorId: result.cursorId,
    );
  }

  /// How many records match [filters] on the server — see
  /// [ApiClient.getListTotal]. Reads nothing into the local database and
  /// touches no sync cursor; it is a number for a label, not a fetch.
  Future<int?> count({Map<String, String> filters = const {}}) =>
      client.getListTotal(basePath, filters: filters);

  Future<TItem> get(String id) async {
    final raw = await client.getOne('$basePath/$id');
    return parseItem(raw as Object);
  }

  Future<TItem> create({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    bool requiresPassword = false,
    Map<String, String>? query,
  }) async {
    final raw = await client.mutate(
      method: 'POST',
      path: basePath,
      query: query,
      idempotencyKey: idempotencyKey,
      body: payload,
      requiresPassword: requiresPassword,
    );
    return parseItem(raw as Object);
  }

  Future<TItem> update({
    required String id,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    bool requiresPassword = false,
    Map<String, String>? query,
  }) async {
    final raw = await client.mutate(
      method: 'PUT',
      path: '$basePath/$id',
      query: query,
      idempotencyKey: idempotencyKey,
      body: payload,
      requiresPassword: requiresPassword,
    );
    return parseItem(raw as Object);
  }

  Future<void> delete({
    required String id,
    required String idempotencyKey,
    bool requiresPassword = true,
  }) async {
    await client.mutate(
      method: 'DELETE',
      path: '$basePath/$id',
      idempotencyKey: idempotencyKey,
      requiresPassword: requiresPassword,
    );
  }

  /// Per-id POST action: `POST /api/v1/{basePath}/<id>/<action>`.
  ///
  /// Use this ONLY for routes the server genuinely registers as POST on the
  /// per-id path — today that is just `purge` (`POST /clients/{id}/purge`,
  /// password-gated). State transitions (mark_sent / mark_paid / archive /
  /// restore / cancel / auto_bill / …) must NOT use this: their per-id route
  /// (`/{id}/{action}`) is registered GET-only on the server, so a POST 404s
  /// and the outbox parks it as a bogus conflict. Use [bulkActionOne] for those.
  Future<TItem?> action({
    required String id,
    required String action,
    required String idempotencyKey,
    Map<String, dynamic>? payload,
    bool requiresPassword = false,
  }) async {
    final raw = await client.mutate(
      method: 'POST',
      path: '$basePath/$id/$action',
      idempotencyKey: idempotencyKey,
      body: payload,
      requiresPassword: requiresPassword,
    );
    return raw == null ? null : parseItem(raw as Object);
  }

  /// Bulk action: `POST /api/v1/{basePath}/bulk` with `{action, ids:[id]}`.
  ///
  /// This is how Invoice Ninja performs state transitions and lifecycle ops
  /// (mark_sent, mark_paid, auto_bill, cancel, archive, restore, email,
  /// template, clone_to_*). The per-id `/{id}/{action}` route is GET-only, so
  /// these can only be driven via `/bulk` (or the GET route) — `POST /{id}/
  /// {action}` 404s. Recurring invoices have ONLY a `/bulk` route, so this is
  /// the single uniform path that works for every billing document.
  ///
  /// The server replies with a list envelope of the affected entities; we send
  /// exactly one id, so the updated entity is `data.first` (or null when the
  /// action filtered it out / returned a `{message}` body, e.g. `template`).
  Future<TItem?> bulkActionOne({
    required String id,
    required String action,
    required String idempotencyKey,
    Map<String, dynamic>? extra,
    Map<String, String>? query,
    bool requiresPassword = false,
  }) async {
    final raw = await client.mutate(
      method: 'POST',
      path: '$basePath/bulk',
      query: query,
      idempotencyKey: idempotencyKey,
      body: {
        'action': action,
        'ids': [id],
        if (extra != null) ...extra,
      },
      requiresPassword: requiresPassword,
    );
    if (raw == null) return null;
    final data = (raw as Map<String, dynamic>)['data'];
    if (data is List && data.isNotEmpty) {
      return parseItem(<String, dynamic>{'data': data.first});
    }
    return null;
  }

  /// Synchronous merged-PDF "bulk print": `POST {basePath}/bulk`
  /// `{action:'bulk_print', ids}`. The server renders each document, merges the
  /// PDFs with FPDI, and streams back a single `application/pdf`. Valid for ≥1
  /// id on invoices/quotes/credits/purchase_orders.
  ///
  /// `readOnly: true` skips the demo-mode short-circuit (this is a read in
  /// effect — no server state mutates) and [ApiClient.postRaw]'s content-type
  /// guard turns a soft `200 + JSON` error envelope into a [ServerException]
  /// instead of handing garbage to the PDF renderer. Subject to the 60 s
  /// request timeout, so very large selections may time out.
  Future<Uint8List> bulkPrintPdf({required List<String> ids}) {
    return client.postRaw(
      '$basePath/bulk',
      readOnly: true,
      body: {'action': 'bulk_print', 'ids': ids},
    );
  }

  /// Async zip-and-email "bulk download": `POST {basePath}/bulk`
  /// `{action:'bulk_download', ids}`. The server dispatches a Zip job that
  /// emails the user a download link and returns `{message}` — **no bytes come
  /// back**, so this returns void (the caller toasts `exported_data`). Server
  /// count gating: invoices/credits require >1; quotes/purchase_orders accept
  /// ≥1. Mirrors `DocumentsApi.bulkDownload`.
  Future<void> bulkDownloadPdf({
    required List<String> ids,
    required String idempotencyKey,
  }) async {
    await client.mutate(
      method: 'POST',
      path: '$basePath/bulk',
      idempotencyKey: idempotencyKey,
      body: {'action': 'bulk_download', 'ids': ids},
    );
  }

  /// Send a billing document by email **now** via `POST /api/v1/emails` (the
  /// shared endpoint — there is no per-id `/{id}/email` route). [entity] is the
  /// short name the server expects (`invoice`, `quote`, `credit`,
  /// `recurring_invoice`, `purchase_order`); it transforms it to the model
  /// class internally. The server wants the full `email_template_<name>`
  /// settings key and replies with the refreshed entity (`itemResponse`).
  /// Scheduled (future) sends go through [scheduleEmailRecord], not here —
  /// `/emails` has no `send_at`.
  Future<TItem?> sendEmail({
    required String entity,
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
    required String idempotencyKey,
  }) async {
    // The server's "endless reminder" template setting is `reminder_endless`.
    final name = template == 'endless_reminder' ? 'reminder_endless' : template;
    final raw = await client.mutate(
      method: 'POST',
      path: '/api/v1/emails',
      idempotencyKey: idempotencyKey,
      body: {
        'entity': entity,
        'entity_id': id,
        // Shared wire-name mapping (handles the irregular `quote_reminder1` →
        // `email_quote_template_reminder1` key) — see [emailTemplateWireName].
        'template': emailTemplateWireName(name),
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
        if (ccEmail != null && ccEmail.isNotEmpty) 'cc_email': [ccEmail],
      },
    );
    return raw == null ? null : parseItem(raw as Object);
  }

  /// Schedule a future email send via `POST /api/v1/task_schedulers` with the
  /// `email_record` template (a one-time job, `frequency_id: 0`). This is the
  /// real server mechanism for scheduled sends — `/emails` has no `send_at`
  /// (React drives the identical task_scheduler). [sendAt] is any ISO-ish
  /// date/datetime; only its `Y-m-d` date part is used (`next_run` is
  /// date-only, must be ≥ today). [template] is the **bare** email template
  /// name (not the `email_template_` settings key). The response is a
  /// Scheduler, not the billing entity, so this returns void.
  Future<void> scheduleEmailRecord({
    required String entity,
    required String id,
    required String template,
    required String sendAt,
    required String idempotencyKey,
  }) async {
    final nextRun = sendAt.length >= 10 ? sendAt.substring(0, 10) : sendAt;
    final name = template == 'endless_reminder' ? 'reminder_endless' : template;
    await client.mutate(
      method: 'POST',
      path: '/api/v1/task_schedulers',
      idempotencyKey: idempotencyKey,
      body: {
        'template': 'email_record',
        'frequency_id': 0,
        'next_run': nextRun,
        'parameters': {'entity': entity, 'entity_id': id, 'template': name},
      },
    );
  }
}
