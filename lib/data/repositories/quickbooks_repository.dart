import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/request_scope.dart';
import 'package:admin/domain/quickbooks/quickbooks_invoice.dart';

/// Thin wrapper around the QuickBooks integration endpoints. The repository
/// has no local state — `company.quickbooks` is the source of truth and is
/// kept fresh by `_persistAndActivate` / `applyUpdateResponse`. The methods
/// here are the side-effects the Account Management → Integrations →
/// QuickBooks screen and an invoice's QuickBooks tab fire.
///
/// **Not through the outbox** (an accepted exception, CLAUDE.md § Strict
/// rules): every call is a synchronous UI flow — an OAuth handshake, or an
/// invoice action whose answer the tab is waiting to show — and none of them
/// edits a record's fields; a queued, offline-delivered "check this invoice
/// against QuickBooks" would answer a question nobody is still asking.
class QuickbooksRepository {
  QuickbooksRepository({
    required ApiClient apiClient,
    required AuthRepository auth,
    Future<void> Function(String companyId, String invoiceId)? refreshInvoice,
  }) : _api = apiClient,
       _auth = auth,
       _refreshInvoice = refreshInvoice;

  final ApiClient _api;
  final AuthRepository _auth;

  /// Re-fetches one invoice through the ordinary GET, dirty-preserving —
  /// `InvoiceRepository.refreshByIds` in production.
  final Future<void> Function(String companyId, String invoiceId)?
  _refreshInvoice;

  /// `POST /api/v1/quickbooks/action` for one invoice.
  ///
  /// [QuickbooksInvoiceAction.checkRecord] answers synchronously with a check
  /// report, which is returned. Its `data` is **not** applied: the server
  /// builds it with `InvoiceTransformer::transform()` directly, which skips
  /// the transformer's default includes, so it carries no `invitations` or
  /// `documents` — written back, it would empty the local invitations and the
  /// next save would PUT `invitations: []`, dropping the chosen contacts. The
  /// invoice is re-fetched through the ordinary GET instead
  /// (`InvoiceRepository.refreshByIds`, dirty-preserving), so its new `sync`
  /// state shows.
  ///
  /// The `force_*` actions return 204 and run after the response; the same
  /// re-fetch picks up anything already done, and the rest reaches the app
  /// through the next `/refresh` delta — pushed straight away on hosted,
  /// where the server announces it on the user's realtime channel. Returns
  /// null for those.
  Future<QuickbooksInvoiceCheck?> invoiceAction({
    required String companyId,
    required String invoiceId,
    required QuickbooksInvoiceAction action,
  }) async {
    final raw = await RequestScope(companyId).run(
      () => _api.postJson(
        '/api/v1/quickbooks/action',
        body: {'entity': 'invoice', 'id': invoiceId, 'action': action.wire},
      ),
    );
    final refresh = _refreshInvoice;
    if (refresh != null) {
      await RequestScope(companyId).run(() => refresh(companyId, invoiceId));
    }
    if (action != QuickbooksInvoiceAction.checkRecord) return null;
    if (raw is! Map) {
      throw const FormatException('quickbooks/action returned no body');
    }
    final meta = raw['meta'];
    final check = meta is Map ? meta['quickbooks_check'] : null;
    if (check is! Map<String, dynamic>) {
      throw const FormatException('quickbooks/action returned no check');
    }
    return QuickbooksInvoiceCheck.fromJson(check);
  }

  /// Mint a short-lived "one time token" the server hands the Intuit OAuth
  /// authorize endpoint, and build the URL the user opens to complete the
  /// connect flow. The hosted page redirects back to the Invoice Ninja
  /// server with the OAuth code; the server stores the tokens on
  /// `company.quickbooks` and the next `/refresh` propagates them locally.
  ///
  /// Mirrors React `useQuickbooksConnect`:
  ///   `POST /api/v1/one_time_token { context: 'quickbooks' }` →
  ///   `{ data: { hash: '<token>' } }` →
  ///   `GET {baseUrl}/quickbooks/authorize/<token>` (launched externally).
  ///
  /// Returns the URL to launch via `url_launcher`. Throws on transport /
  /// HTTP failure so the caller can toast.
  Future<Uri> buildAuthorizeUrl() async {
    final raw = await _api.postJson(
      '/api/v1/one_time_token',
      body: const {'context': 'quickbooks'},
    );
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Unexpected /one_time_token response shape: ${raw.runtimeType}',
      );
    }
    // Server response shape: `{ data: { hash: '<token>' } }`. Tolerate a
    // top-level `hash` for older builds.
    String? token;
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      token = data['hash'] as String?;
    }
    token ??= raw['hash'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('one_time_token response missing hash');
    }
    final baseUrl = _auth.session.value?.baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('cannot build QuickBooks authorize URL without baseUrl');
    }
    return Uri.parse(baseUrl).resolve('/quickbooks/authorize/$token');
  }

  /// Disconnect the integration server-side. Mirrors React
  /// `useQuickbooksDisconnect`: `POST /api/v1/quickbooks/disconnect`.
  ///
  /// On success, refresh the session so `company.quickbooks` flips back to
  /// `null` everywhere the UI reads from (incl. the local Drift row that
  /// drives `CompanyRepository.watchCompany`).
  Future<void> disconnect() async {
    await _api.postJson('/api/v1/quickbooks/disconnect', body: const {});
    // Low-frequency, user-initiated integration toggle — force a full
    // snapshot so `company.quickbooks` is unambiguously authoritative.
    await _auth.refresh(fullSync: true);
  }

  /// Re-authorize an expired connection. Mirrors React
  /// `useQuickbooksReconnect`: `POST /api/v1/quickbooks/reconnect_url {}` →
  /// `{ data: { reconnect_url: '<url>' } }`. The caller launches the URL;
  /// the hosted page redirects back like the initial connect. Tolerant
  /// parse (nested `data` or flat) matching [buildAuthorizeUrl].
  Future<Uri> reconnectUrl() async {
    final raw = await _api.postJson(
      '/api/v1/quickbooks/reconnect_url',
      body: const {},
    );
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Unexpected /quickbooks/reconnect_url response shape: '
        '${raw.runtimeType}',
      );
    }
    String? url;
    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      url = data['reconnect_url'] as String?;
    }
    url ??= raw['reconnect_url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('reconnect_url response missing reconnect_url');
    }
    return Uri.parse(url);
  }

  /// Trigger a one-shot import of QuickBooks entities into Invoice Ninja.
  /// Mirrors React `QuickBooksImportTab`: `POST /api/v1/quickbooks/sync`
  /// with the per-entity booleans. The server runs the import async; the
  /// next `/refresh` (or a manual "Refresh status") reflects results.
  Future<void> triggerImport({
    required bool client,
    required bool product,
    required bool invoice,
  }) async {
    await _api.postJson(
      '/api/v1/quickbooks/sync',
      body: {'client': client, 'product': product, 'invoice': invoice},
    );
  }
}
