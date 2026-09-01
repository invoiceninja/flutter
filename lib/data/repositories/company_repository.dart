import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/auth/auth_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('CompanyRepository');

/// Source of truth for the active company row. Companies are loaded into the
/// `companies` Drift table by [AuthRepository] at login; this repo provides
/// the typed watch stream the settings UI binds to, plus the outbox-backed
/// update path.
///
/// Unlike most entities there is no create/delete/archive flow — a company's
/// lifecycle is managed at the account level. Logo + document uploads still
/// go through the outbox so they survive offline.
/// Outbox `entity_type` for company mutations. The `companies` table has no
/// `is_dirty` column, so a pending row of this type IS the dirty marker —
/// `AuthRepository._persistAndActivate` consults it before letting a delta
/// `/refresh` overwrite the locally-edited row. Mirrors [kUserSettingsWireName].
const String kCompanyWireName = 'company';

class CompanyRepository extends BaseEntityRepository<Company, CompanyApi> {
  CompanyRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onSettingsWritten,
  }) : super(
         entityType: EntityType.company,
         // `documentDelete` is password-gated server-side — the outbox row
         // gets `requiresPassword=true` so the sync engine fires
         // `ConfirmPasswordSheet` before draining (mirrors every other
         // document-bearing entity, see mutation.dart).
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.documentDelete,
         },
       );

  final CompaniesApi api;

  /// Invoked with the company id after [updateCompany] commits new settings to
  /// Drift. Wired to `Services.invalidateFormatter` so the memoized per-company
  /// [Formatter] is dropped — otherwise a Date Format / currency / decimal
  /// separator change is invisible until logout/restart. Repo stays free of a
  /// `Services` import; the cache invalidation is injected, like [onEnqueued].
  final void Function(String companyId)? onSettingsWritten;

  /// Company ids whose canonical `GET /companies/{id}` succeeded this session.
  /// The Account-Management tabs (Enabled Modules / Security / Overview) and
  /// the Analytics page PUT the WHOLE company row, so they gate their controls
  /// on this set: a toggle shouldn't ship table defaults for a row the server
  /// has never filled in.
  ///
  /// This used to be load-bearing — the login/refresh envelope omitted ~29
  /// top-level columns (SMTP / expense / task-invoicing / payment conversion),
  /// so the cached row held defaults for them until [refresh] backfilled it
  /// (issue #29). The envelope now carries all of them and the full-sync path
  /// prunes instead of wiping, so this is a backstop for a company row that
  /// genuinely predates any server read, not the routine case.
  final ValueNotifier<Set<String>> _canonicalFetched = ValueNotifier(
    const <String>{},
  );

  /// Listenable view of [isCanonicalFetched] — the gating widgets rebuild on it.
  ValueListenable<Set<String>> get canonicalFetched => _canonicalFetched;

  /// Whether the canonical company for [companyId] has been fetched this
  /// session (see [_canonicalFetched]).
  bool isCanonicalFetched(String companyId) =>
      _canonicalFetched.value.contains(companyId);

  /// Drop [companyId] from the canonical-fetched set so the Account-Management
  /// / Analytics controls re-lock. Called after a FULL-sync re-seed (force
  /// resync, danger-zone refresh) re-writes the companies row from the
  /// login/refresh envelope. That envelope now carries every top-level column,
  /// so the row is no longer degraded by the re-seed — this is kept as a
  /// conservative re-lock, matching the fresh-session state where nothing has
  /// been canonically fetched yet.
  void markCanonicalStale(String companyId) {
    if (!_canonicalFetched.value.contains(companyId)) return;
    _canonicalFetched.value = {..._canonicalFetched.value}..remove(companyId);
  }

  @override
  String get entityTypeName => kCompanyWireName;

  /// Enqueue a Danger-Zone delete. Returns the outbox row id so the caller
  /// can poll for the row's terminal state after the drain.
  Future<int> deleteCompany({
    required String companyId,
    required String cancellationMessage,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.delete,
      payload: {'cancellation_message': cancellationMessage},
    );
  }

  /// Watch the active company. Decodes the `settings` JSON blob on every
  /// emission; the UI binds to this directly.
  ///
  /// Company is a settings-only entity — there is no separate `(companyId, id)`
  /// tuple, the company *is* the row keyed by `companyId`, and the generic
  /// `watch` machinery's tmp-id remap doesn't apply. It still routes through
  /// [BaseEntityRepository.watch] with the id doubled, because that is what
  /// mirrors emissions into the first-frame seed cache: without it every
  /// company-gated widget in the detail pane (custom-field cards, surcharge
  /// rows, the e-invoice actions) has `initialData: null` on every row click
  /// and materialises a frame late, shifting the layout.
  Stream<Company?> watchCompany(String companyId) =>
      watch(companyId: companyId, id: companyId);

  /// Only ever called by [watchCompany] via the base's [watch].
  ///
  /// Reads by `companyId`, NOT by `id`: the assert is stripped in release, and
  /// reading by a mismatched `id` would file another company's row under
  /// `_lastSeen['$companyId/$id']` — a cross-company leak. Degrading to the
  /// documented invariant is the safe direction.
  @override
  Stream<Company?> watchByRealId({
    required String companyId,
    required String id,
  }) {
    assert(
      id == companyId,
      'CompanyRepository is settings-only: the company IS the row keyed by '
      'companyId, so there is no separate id. Use watchCompany(companyId).',
    );
    return db.companiesDao.watchById(companyId).map(_fromRow);
  }

  Future<Company?> get(String companyId) async {
    final row = await db.companiesDao.byId(companyId);
    return _fromRow(row);
  }

  /// Persist a settings change. Writes the new settings JSON to Drift
  /// (optimistic) and enqueues a `PUT /companies/{id}` outbox row.
  ///
  /// [extraOutboxPayload] piggybacks one-shot control keys onto the outbox
  /// payload **without** touching the Drift snapshot. The dispatcher pops
  /// these before serializing the PUT body (today that's
  /// `_sync_send_time`, set by Email Settings's inline "Apply to existing"
  /// checkbox; the dispatcher converts it to `?sync_send_time=true|false`).
  /// Mirrors the `_action` precedent for `upload_logo` / `upload_document`.
  Future<void> updateCompany({
    required Company draft,
    Map<String, dynamic>? extraOutboxPayload,
  }) async {
    final body = draft.toApiJson()..removeWhere(_isMaskedSmtpCredential);
    final outboxPayload = extraOutboxPayload == null
        ? body
        : <String, dynamic>{...body, ...extraOutboxPayload};
    // Merge raw + typed exactly as `toApiJson` does so the on-disk row
    // matches what we POST. Without this, fields the model doesn't cover
    // would disappear from the local cache after each save.
    final mergedSettings = <String, dynamic>{
      ...draft.rawSettings,
      ...draft.settings.toJson(),
    };
    await db.transaction(() async {
      await (db.update(
        db.companies,
      )..where((c) => c.id.equals(draft.id))).write(
        CompaniesCompanion(
          displayName: Value(
            draft.displayName.isNotEmpty ? draft.displayName : null,
          ),
          name: Value(
            draft.name.isNotEmpty ? draft.name : draft.settings.name ?? '',
          ),
          settings: Value(jsonEncode(mergedSettings)),
          customFields: Value(jsonEncode(draft.customFields)),
          sizeId: Value(draft.sizeId),
          industryId: Value(draft.industryId),
          firstMonthOfYear: Value(draft.firstMonthOfYear),
          firstDayOfWeek: Value(draft.firstDayOfWeek),
          useCommaAsDecimalPlace: Value(draft.useCommaAsDecimalPlace),
          legalEntityId: Value(draft.legalEntityId),
          hasEInvoiceCertificate: Value(draft.hasEInvoiceCertificate),
          eInvoiceCertificatePassphrase: Value(
            draft.eInvoiceCertificatePassphrase,
          ),
          hasEInvoiceCertificatePassphrase: Value(
            draft.hasEInvoiceCertificatePassphrase,
          ),
          enabledModules: Value(draft.enabledModules),
          googleAnalyticsKey: Value(draft.googleAnalyticsKey),
          matomoId: Value(draft.matomoId),
          matomoUrl: Value(draft.matomoUrl),
          sessionTimeout: Value(draft.sessionTimeout),
          defaultPasswordTimeout: Value(draft.defaultPasswordTimeout),
          oauthPasswordRequired: Value(draft.oauthPasswordRequired),
          isDisabled: Value(draft.isDisabled),
          markdownEnabled: Value(draft.markdownEnabled),
          markdownEmailEnabled: Value(draft.markdownEmailEnabled),
          reportIncludeDrafts: Value(draft.reportIncludeDrafts),
          reportIncludeDeleted: Value(draft.reportIncludeDeleted),
          enableApplyingPayments: Value(draft.enableApplyingPayments),
          convertPaymentCurrency: Value(draft.convertPaymentCurrency),
          quickbooksJson: Value(
            draft.quickbooks == null ? null : jsonEncode(draft.quickbooks),
          ),
          enabledTaxRates: Value(draft.enabledTaxRates),
          enabledItemTaxRates: Value(draft.enabledItemTaxRates),
          enabledExpenseTaxRates: Value(draft.enabledExpenseTaxRates),
          calculateTaxes: Value(draft.calculateTaxes),
          taxDataJson: Value(
            draft.taxData == null ? null : jsonEncode(draft.taxData!.toJson()),
          ),
          // Round-trip the e-invoice blob the draft loaded from Drift so a
          // settings save doesn't drop the Payment Means seed.
          eInvoiceJson: Value(
            draft.eInvoice == null ? null : jsonEncode(draft.eInvoice),
          ),
          customSurchargeTaxes1: Value(draft.customSurchargeTaxes1),
          customSurchargeTaxes2: Value(draft.customSurchargeTaxes2),
          customSurchargeTaxes3: Value(draft.customSurchargeTaxes3),
          customSurchargeTaxes4: Value(draft.customSurchargeTaxes4),
          trackInventory: Value(draft.trackInventory),
          stockNotification: Value(draft.stockNotification),
          inventoryNotificationThreshold: Value(
            draft.inventoryNotificationThreshold,
          ),
          enableProductDiscount: Value(draft.enableProductDiscount),
          enableProductCost: Value(draft.enableProductCost),
          enableProductQuantity: Value(draft.enableProductQuantity),
          defaultQuantity: Value(draft.defaultQuantity),
          showProductDetails: Value(draft.showProductDetails),
          fillProducts: Value(draft.fillProducts),
          updateProducts: Value(draft.updateProducts),
          convertProducts: Value(draft.convertProducts),
          convertRateToClient: Value(draft.convertRateToClient),
          stopOnUnpaidRecurring: Value(draft.stopOnUnpaidRecurring),
          useQuoteTermsOnConversion: Value(draft.useQuoteTermsOnConversion),
          autoStartTasks: Value(draft.autoStartTasks),
          showTaskEndDate: Value(draft.showTaskEndDate),
          showTasksTable: Value(draft.showTasksTable),
          invoiceTaskDatelog: Value(draft.invoiceTaskDatelog),
          invoiceTaskTimelog: Value(draft.invoiceTaskTimelog),
          invoiceTaskHours: Value(draft.invoiceTaskHours),
          invoiceTaskItemDescription: Value(draft.invoiceTaskItemDescription),
          invoiceTaskProject: Value(draft.invoiceTaskProject),
          invoiceTaskProjectHeader: Value(draft.invoiceTaskProjectHeader),
          invoiceTaskLock: Value(draft.invoiceTaskLock),
          invoiceTaskDocuments: Value(draft.invoiceTaskDocuments),
          markExpensesInvoiceable: Value(draft.markExpensesInvoiceable),
          markExpensesPaid: Value(draft.markExpensesPaid),
          convertExpenseCurrency: Value(draft.convertExpenseCurrency),
          invoiceExpenseDocuments: Value(draft.invoiceExpenseDocuments),
          notifyVendorWhenPaid: Value(draft.notifyVendorWhenPaid),
          calculateExpenseTaxByAmount: Value(draft.calculateExpenseTaxByAmount),
          expenseInclusiveTaxes: Value(draft.expenseInclusiveTaxes),
          expenseMailboxActive: Value(draft.expenseMailboxActive),
          expenseMailbox: Value(draft.expenseMailbox),
          inboundMailboxAllowCompanyUsers: Value(
            draft.inboundMailboxAllowCompanyUsers,
          ),
          inboundMailboxAllowVendors: Value(draft.inboundMailboxAllowVendors),
          inboundMailboxAllowClients: Value(draft.inboundMailboxAllowClients),
          inboundMailboxWhitelist: Value(draft.inboundMailboxWhitelist),
          inboundMailboxBlacklist: Value(draft.inboundMailboxBlacklist),
          inboundMailboxAllowUnknown: Value(draft.inboundMailboxAllowUnknown),
          smtpHost: Value(draft.smtpHost),
          smtpPort: Value(draft.smtpPort),
          smtpEncryption: Value(draft.smtpEncryption),
          smtpUsername: Value(draft.smtpUsername),
          smtpPassword: Value(draft.smtpPassword),
          smtpLocalDomain: Value(draft.smtpLocalDomain),
          smtpVerifyPeer: Value(draft.smtpVerifyPeer),
          subdomain: Value(draft.subdomain),
          portalDomain: Value(draft.portalDomain),
          portalMode: Value(draft.portalMode),
          clientCanRegister: Value(draft.clientCanRegister),
          companyKey: Value(draft.companyKey),
          clientRegistrationFields: Value(
            _encodeRegistrationFields(draft.clientRegistrationFields),
          ),
          updatedAt: Value(_nowSeconds()),
        ),
      );
      await enqueueMutation(
        companyId: draft.id,
        entityId: draft.id,
        kind: MutationKind.update,
        payload: outboxPayload,
      );
    });
    // Settings JSON (date_format_id, currency, decimal separator, …) just
    // changed on disk; drop the stale memoized Formatter for this company.
    onSettingsWritten?.call(draft.id);
  }

  /// Enqueue a logo upload. The dispatcher reads the file from `localPath` at
  /// send-time so the upload survives the app being killed between save and
  /// network availability.
  Future<void> uploadLogo({
    required String companyId,
    required UploadSource source,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.update,
      payload: {'_action': 'upload_logo', ...source.toPayload()},
    );
  }

  /// Enqueue a document upload (multipart).
  Future<void> uploadDocument({
    required String companyId,
    required UploadSource source,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.update,
      payload: {'_action': 'upload_document', ...source.toPayload()},
    );
  }

  /// Enqueue a company document delete (`DELETE /documents/{id}`).
  /// Password-gated — the outbox row carries `requiresPassword=true` (see
  /// `requiresPasswordFor`), so the sync engine prompts before draining. The
  /// local list is pruned by the dispatcher *after* the server confirms (via
  /// [removeDocumentLocally]) rather than optimistically — the Company
  /// Details page's mount `refresh()` would otherwise re-add a not-yet-drained
  /// delete.
  Future<void> deleteDocument({
    required String companyId,
    required String documentId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.documentDelete,
      payload: {'document_id': documentId},
    );
  }

  /// Drop a single document from the local `documents` column. Operates on the
  /// raw JSON list so every stored field round-trips (not just the typed
  /// subset). No-op when the row, column, or matching id is absent.
  Future<void> removeDocumentLocally({
    required String companyId,
    required String documentId,
  }) async {
    final row = await db.companiesDao.byId(companyId);
    final raw = row?.documents;
    if (raw == null || raw.isEmpty) return;
    final List<dynamic> decoded;
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return;
      decoded = parsed;
    } catch (_) {
      return;
    }
    final filtered = decoded
        .where((e) => !(e is Map && e['id']?.toString() == documentId))
        .toList();
    if (filtered.length == decoded.length) return; // id not present
    await (db.update(db.companies)..where((c) => c.id.equals(companyId))).write(
      CompaniesCompanion(documents: Value(jsonEncode(filtered))),
    );
  }

  // ── E-Invoice / PEPPOL enqueue helpers ────────────────────────────
  // Each returns as soon as the outbox row is written. The dispatcher
  // drains under the hood with the row's idempotency key — same retry
  // semantics as any other outbox row.

  /// Enqueue a digital certificate upload. The dispatcher reads the file
  /// from [localPath] at send-time so the upload survives an app kill
  /// between save and network availability.
  Future<void> enqueueEInvoiceCertificateUpload({
    required String companyId,
    required UploadSource source,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.uploadEInvoiceCertificate,
      payload: {...source.toPayload()},
    );
  }

  /// Enqueue a digital certificate **removal**. A plain company PUT only
  /// carries the read-only `has_e_invoice_certificate` flag (not in the
  /// server's `$fillable`, ignored on write); the server removes the cert
  /// only when the request *carries* the `e_invoice_certificate` key (it
  /// then nulls the cert + passphrase — CompanyController::update). So
  /// removal goes through the `_action` seam (like `upload_logo`) and the
  /// dispatcher PUTs `{e_invoice_certificate: null}`. Optimistically flips
  /// the local flag so the upload dropzone reappears at once and survives an
  /// app restart before the outbox drains.
  Future<void> enqueueEInvoiceCertificateRemoval({
    required String companyId,
  }) async {
    await db.transaction(() async {
      await (db.update(
        db.companies,
      )..where((c) => c.id.equals(companyId))).write(
        CompaniesCompanion(
          hasEInvoiceCertificate: const Value(false),
          updatedAt: Value(_nowSeconds()),
        ),
      );
      await enqueueMutation(
        companyId: companyId,
        entityId: companyId,
        kind: MutationKind.update,
        payload: {'_action': 'remove_e_invoice_certificate'},
      );
    });
  }

  /// Enqueue the PEPPOL onboarding setup. [payload] mirrors React
  /// `peppol/Onboarding.tsx`: `party_name`, `line1`, `line2`, `city`,
  /// `county`, `zip`, `country`, one of `vat_number` / `id_number`,
  /// `acts_as_sender`, `acts_as_receiver`, `classification`, `tenant_id`.
  Future<void> enqueuePeppolSetup({
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.peppolSetup,
      payload: payload,
    );
  }

  /// Singapore PEPPOL onboarding — a **deliberate, direct (non-outbox)**
  /// request. Unlike EU ([enqueuePeppolSetup]), the Singapore response
  /// carries a `corppass_url` the caller must launch into the browser
  /// immediately for interactive government auth (mirrors React). An
  /// interactive gov-auth redirect can't be meaningfully offline-queued, so
  /// this bypasses the outbox by design (precedent: the OAuth setup
  /// launchers). The EU outbox path is untouched.
  ///
  /// Applies the returned company envelope to Drift via the same
  /// [applyUpdateResponse] tail the dispatcher uses (so an immediate /
  /// no-redirect response still lands `legalEntityId` locally). Returns the
  /// `corppass_url` when present (else null → registration was immediate).
  Future<String?> peppolSetupDirect({
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    final result = await api.peppolSetupWithRedirect(
      payload: payload,
      idempotencyKey: uuid.v4(),
    );
    await applyUpdateResponse(
      companyId: companyId,
      serverResponse: result.company.data,
    );
    final url = result.corppassUrl;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// Enqueue a PEPPOL preferences update (`acts_as_sender` /
  /// `acts_as_receiver`).
  Future<void> enqueuePeppolUpdate({
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.peppolUpdate,
      payload: payload,
    );
  }

  /// Enqueue a PEPPOL disconnect. [payload] carries `company_key`,
  /// `legal_entity_id`, `tax_data`, `e_invoicing_token` — the four fields
  /// the server needs to revoke the binding.
  Future<void> enqueuePeppolDisconnect({
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.peppolDisconnect,
      payload: payload,
    );
  }

  /// Add an additional per-country VAT identifier.
  Future<void> enqueuePeppolAddTaxIdentifier({
    required String companyId,
    required String country,
    required String vatNumber,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.peppolAddTaxIdentifier,
      payload: {'country': country, 'vat_number': vatNumber},
    );
  }

  /// Remove an additional per-country VAT identifier.
  Future<void> enqueuePeppolRemoveTaxIdentifier({
    required String companyId,
    required String country,
    required String vatNumber,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.peppolRemoveTaxIdentifier,
      payload: {'country': country, 'vat_number': vatNumber},
    );
  }

  /// Save the payment-means configuration.
  Future<void> enqueueEInvoicePaymentMeans({
    required String companyId,
    required Map<String, dynamic> payload,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.eInvoicePaymentMeans,
      payload: payload,
    );
  }

  /// Regenerate the e-invoicing token.
  Future<void> enqueueRegenerateEInvoiceToken({
    required String companyId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: companyId,
      kind: MutationKind.regenerateEInvoiceToken,
      payload: const <String, dynamic>{},
    );
  }

  /// Live fetch of the PEPPOL credit quota. Out-of-outbox; the
  /// Preferences card calls this on mount. Returns `null` on network
  /// error or when the response shape isn't recognized — callers treat
  /// `null` as "unknown" rather than zero.
  Future<int?> fetchEInvoiceQuota() async {
    try {
      final raw = await api.getEInvoiceQuota();
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is Map) {
        for (final key in ['quota', 'credits', 'data']) {
          final v = raw[key];
          if (v is int) return v;
          if (v is num) return v.toInt();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Live fetch of the PEPPOL token health-check. Out-of-outbox.
  /// Returns `true` when the token is valid, `false` when it should be
  /// regenerated, `null` on network error or unknown response.
  Future<bool?> fetchEInvoiceHealthCheck() async {
    try {
      final raw = await api.getEInvoiceHealthCheck();
      if (raw is bool) return raw;
      if (raw is Map) {
        for (final key in ['healthy', 'health', 'status', 'data']) {
          final v = raw[key];
          if (v is bool) return v;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Pull the canonical company from `GET /api/v1/companies/{id}` and upsert
  /// it into Drift. Used by the Company Details page on mount so the form
  /// always shows live server state — the login-time settings blob is a
  /// snapshot that can be stale or missing fields the server fills in
  /// elsewhere. Errors are swallowed (logged only): the page still renders
  /// from the cached row.
  Future<void> refresh(String companyId) async {
    if (companyId.isEmpty) return;
    try {
      final response = await api.get(companyId);
      await applyUpdateResponse(
        companyId: companyId,
        serverResponse: response.data,
      );
      // Canonical row is now in Drift — release the Account-Management /
      // Analytics control gate for this company (see [_canonicalFetched]).
      if (!_canonicalFetched.value.contains(companyId)) {
        _canonicalFetched.value = {..._canonicalFetched.value, companyId};
      }
    } on UnauthorizedException catch (e, st) {
      // A background refresh can race a company-switch / logout. A stale-
      // credential 401 says nothing about the live session (ApiClient already
      // discarded it) — keep it out of the WARNING+ diagnostics log. A genuine
      // session-expired 401 still surfaces.
      if (e.isStaleCredential) {
        _log.fine('refresh($companyId) skipped: stale-credential 401');
      } else {
        _log.warning('refresh($companyId) failed', e, st);
      }
    } catch (e, st) {
      _log.warning('refresh($companyId) failed', e, st);
    }
  }

  /// Apply the canonical company body returned by the server after a
  /// successful update. The login envelope already wrote the row at login
  /// time; this refreshes the settings blob and the top-level company
  /// fields the Details tab edits.
  ///
  /// `companyId` is part of the standard repository contract; for company
  /// it always equals `serverResponse.id`.
  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required CompanyApi serverResponse,
  }) async {
    await (db.update(
      db.companies,
    )..where((c) => c.id.equals(serverResponse.id))).write(
      CompaniesCompanion(
        settings: Value(jsonEncode(serverResponse.settings)),
        // Keep the dedicated logo_url column in sync with the freshly-applied
        // settings. `_onCompaniesChanged` / `restore` prefer this column over
        // the settings blob, so without this a logo upload (Invoice Ninja
        // returns a new logo URL) leaves the picker avatar on the old logo
        // even though the Logo tab preview — which reads settings — updates.
        logoUrl: Value(companyLogoUrl(serverResponse.settings)),
        customFields: Value(jsonEncode(serverResponse.customFields)),
        sizeId: Value(serverResponse.sizeId),
        industryId: Value(serverResponse.industryId),
        firstMonthOfYear: Value(serverResponse.firstMonthOfYear),
        firstDayOfWeek: Value(serverResponse.firstDayOfWeek),
        useCommaAsDecimalPlace: Value(serverResponse.useCommaAsDecimalPlace),
        legalEntityId: Value(serverResponse.legalEntityId),
        hasEInvoiceCertificate: Value(serverResponse.hasEInvoiceCertificate),
        eInvoiceCertificatePassphrase: Value(
          serverResponse.eInvoiceCertificatePassphrase,
        ),
        hasEInvoiceCertificatePassphrase: Value(
          serverResponse.hasEInvoiceCertificatePassphrase,
        ),
        enabledModules: Value(serverResponse.enabledModules),
        googleAnalyticsKey: Value(serverResponse.googleAnalyticsKey),
        matomoId: Value(serverResponse.matomoId),
        matomoUrl: Value(serverResponse.matomoUrl),
        sessionTimeout: Value(serverResponse.sessionTimeout),
        defaultPasswordTimeout: Value(serverResponse.defaultPasswordTimeout),
        oauthPasswordRequired: Value(serverResponse.oauthPasswordRequired),
        isDisabled: Value(serverResponse.isDisabled),
        markdownEnabled: Value(serverResponse.markdownEnabled),
        markdownEmailEnabled: Value(serverResponse.markdownEmailEnabled),
        reportIncludeDrafts: Value(serverResponse.reportIncludeDrafts),
        reportIncludeDeleted: Value(serverResponse.reportIncludeDeleted),
        enableApplyingPayments: Value(serverResponse.enableApplyingPayments),
        convertPaymentCurrency: Value(serverResponse.convertPaymentCurrency),
        quickbooksJson: Value(
          serverResponse.quickbooks == null
              ? null
              : jsonEncode(serverResponse.quickbooks),
        ),
        enabledTaxRates: Value(serverResponse.enabledTaxRates),
        enabledItemTaxRates: Value(serverResponse.enabledItemTaxRates),
        enabledExpenseTaxRates: Value(serverResponse.enabledExpenseTaxRates),
        calculateTaxes: Value(serverResponse.calculateTaxes),
        taxDataJson: Value(
          serverResponse.taxData == null
              ? null
              : jsonEncode(serverResponse.taxData!.toJson()),
        ),
        // Preserve the existing blob when the response omits `e_invoice` (a
        // plain company PUT echoes settings but not the derived e-invoice
        // config) — `Value.absent()` leaves the column untouched. Only a
        // response that actually carries it (e.g. /refresh) overwrites.
        eInvoiceJson: serverResponse.eInvoice == null
            ? const Value.absent()
            : Value(jsonEncode(serverResponse.eInvoice)),
        customSurchargeTaxes1: Value(serverResponse.customSurchargeTaxes1),
        customSurchargeTaxes2: Value(serverResponse.customSurchargeTaxes2),
        customSurchargeTaxes3: Value(serverResponse.customSurchargeTaxes3),
        customSurchargeTaxes4: Value(serverResponse.customSurchargeTaxes4),
        trackInventory: Value(serverResponse.trackInventory),
        stockNotification: Value(serverResponse.stockNotification),
        inventoryNotificationThreshold: Value(
          serverResponse.inventoryNotificationThreshold,
        ),
        enableProductDiscount: Value(serverResponse.enableProductDiscount),
        enableProductCost: Value(serverResponse.enableProductCost),
        enableProductQuantity: Value(serverResponse.enableProductQuantity),
        defaultQuantity: Value(serverResponse.defaultQuantity),
        showProductDetails: Value(serverResponse.showProductDetails),
        fillProducts: Value(serverResponse.fillProducts),
        updateProducts: Value(serverResponse.updateProducts),
        convertProducts: Value(serverResponse.convertProducts),
        convertRateToClient: Value(serverResponse.convertRateToClient),
        stopOnUnpaidRecurring: Value(serverResponse.stopOnUnpaidRecurring),
        useQuoteTermsOnConversion: Value(
          serverResponse.useQuoteTermsOnConversion,
        ),
        autoStartTasks: Value(serverResponse.autoStartTasks),
        showTaskEndDate: Value(serverResponse.showTaskEndDate),
        showTasksTable: Value(serverResponse.showTasksTable),
        invoiceTaskDatelog: Value(serverResponse.invoiceTaskDatelog),
        invoiceTaskTimelog: Value(serverResponse.invoiceTaskTimelog),
        invoiceTaskHours: Value(serverResponse.invoiceTaskHours),
        invoiceTaskItemDescription: Value(
          serverResponse.invoiceTaskItemDescription,
        ),
        invoiceTaskProject: Value(serverResponse.invoiceTaskProject),
        invoiceTaskProjectHeader: Value(
          serverResponse.invoiceTaskProjectHeader,
        ),
        invoiceTaskLock: Value(serverResponse.invoiceTaskLock),
        invoiceTaskDocuments: Value(serverResponse.invoiceTaskDocuments),
        markExpensesInvoiceable: Value(serverResponse.markExpensesInvoiceable),
        markExpensesPaid: Value(serverResponse.markExpensesPaid),
        convertExpenseCurrency: Value(serverResponse.convertExpenseCurrency),
        invoiceExpenseDocuments: Value(serverResponse.invoiceExpenseDocuments),
        notifyVendorWhenPaid: Value(serverResponse.notifyVendorWhenPaid),
        calculateExpenseTaxByAmount: Value(
          serverResponse.calculateExpenseTaxByAmount,
        ),
        expenseInclusiveTaxes: Value(serverResponse.expenseInclusiveTaxes),
        expenseMailboxActive: Value(serverResponse.expenseMailboxActive),
        expenseMailbox: Value(serverResponse.expenseMailbox),
        inboundMailboxAllowCompanyUsers: Value(
          serverResponse.inboundMailboxAllowCompanyUsers,
        ),
        inboundMailboxAllowVendors: Value(
          serverResponse.inboundMailboxAllowVendors,
        ),
        inboundMailboxAllowClients: Value(
          serverResponse.inboundMailboxAllowClients,
        ),
        inboundMailboxWhitelist: Value(serverResponse.inboundMailboxWhitelist),
        inboundMailboxBlacklist: Value(serverResponse.inboundMailboxBlacklist),
        inboundMailboxAllowUnknown: Value(
          serverResponse.inboundMailboxAllowUnknown,
        ),
        smtpHost: Value(serverResponse.smtpHost),
        smtpPort: Value(serverResponse.smtpPort),
        smtpEncryption: Value(serverResponse.smtpEncryption),
        smtpUsername: Value(serverResponse.smtpUsername),
        smtpPassword: Value(serverResponse.smtpPassword),
        smtpLocalDomain: Value(serverResponse.smtpLocalDomain),
        smtpVerifyPeer: Value(serverResponse.smtpVerifyPeer),
        subdomain: Value(serverResponse.subdomain),
        portalDomain: Value(serverResponse.portalDomain),
        portalMode: Value(serverResponse.portalMode),
        clientCanRegister: Value(serverResponse.clientCanRegister),
        companyKey: Value(serverResponse.companyKey),
        clientRegistrationFields: Value(
          _encodeRegistrationFields(serverResponse.clientRegistrationFields),
        ),
        documents: Value(
          jsonEncode(serverResponse.documents.map((d) => d.toJson()).toList()),
        ),
        name: Value(
          serverResponse.name.isNotEmpty
              ? serverResponse.name
              : (serverResponse.settings['name'] as String? ?? ''),
        ),
        updatedAt: Value(
          serverResponse.updatedAt > 0
              ? serverResponse.updatedAt
              : _nowSeconds(),
        ),
      ),
    );
  }

  Company? _fromRow(CompanyRow? row) {
    if (row == null) return null;
    final raw = _decodeSettingsMap(row.settings);
    // The generated `_$$CompanySettingsApiImplFromJson` uses ~200 bare type
    // casts (`as bool?`, `as int?`, ...). Invoice Ninja sometimes ships a
    // legacy field as `0`/`1` where we model it as `bool`; a single mismatch
    // throws a `TypeError` and would otherwise wedge `CompanyDetailsViewModel`
    // on its spinner forever. Falling back to empty typed settings keeps
    // the UI alive — `rawSettings` is still the unmodified server map, so
    // the next save merges every original key back into the PUT body.
    CompanySettingsApi typed;
    try {
      typed = CompanySettingsApi.fromJsonLenient(raw);
    } catch (e, st) {
      _log.warning(
        'CompanySettingsApi.fromJson failed for companyId=${row.id}; '
        'falling back to empty typed view',
        e,
        st,
      );
      typed = const CompanySettingsApi();
    }
    final customFields = _decodeCustomFields(row.customFields);
    final documents = decodeDocumentsColumn(row.documents);
    TaxConfigApi? taxData;
    final taxDataJson = row.taxDataJson;
    if (taxDataJson != null && taxDataJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(taxDataJson);
        if (decoded is Map<String, dynamic>) {
          taxData = TaxConfigApi.fromJson(decoded);
        }
      } catch (e, st) {
        _log.warning(
          'TaxConfigApi.fromJson failed for companyId=${row.id}',
          e,
          st,
        );
      }
    }
    Map<String, dynamic>? eInvoice;
    final eInvoiceJson = row.eInvoiceJson;
    if (eInvoiceJson != null && eInvoiceJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(eInvoiceJson);
        if (decoded is Map<String, dynamic>) {
          eInvoice = decoded;
        }
      } catch (e, st) {
        _log.warning('e_invoice decode failed for companyId=${row.id}', e, st);
      }
    }
    return Company(
      id: row.id,
      name: row.name,
      displayName: row.displayName ?? '',
      sizeId: row.sizeId,
      industryId: row.industryId,
      firstMonthOfYear: row.firstMonthOfYear,
      firstDayOfWeek: row.firstDayOfWeek,
      useCommaAsDecimalPlace: row.useCommaAsDecimalPlace,
      legalEntityId: row.legalEntityId,
      hasEInvoiceCertificate: row.hasEInvoiceCertificate,
      eInvoiceCertificatePassphrase: row.eInvoiceCertificatePassphrase,
      hasEInvoiceCertificatePassphrase: row.hasEInvoiceCertificatePassphrase,
      enabledModules: row.enabledModules,
      googleAnalyticsKey: row.googleAnalyticsKey,
      matomoId: row.matomoId,
      matomoUrl: row.matomoUrl,
      sessionTimeout: row.sessionTimeout,
      defaultPasswordTimeout: row.defaultPasswordTimeout,
      oauthPasswordRequired: row.oauthPasswordRequired,
      isDisabled: row.isDisabled,
      markdownEnabled: row.markdownEnabled,
      markdownEmailEnabled: row.markdownEmailEnabled,
      reportIncludeDrafts: row.reportIncludeDrafts,
      reportIncludeDeleted: row.reportIncludeDeleted,
      enableApplyingPayments: row.enableApplyingPayments,
      convertPaymentCurrency: row.convertPaymentCurrency,
      quickbooks: _decodeQuickbooks(row.quickbooksJson),
      customFields: customFields,
      rawSettings: raw,
      settings: typed,
      enabledTaxRates: row.enabledTaxRates,
      enabledItemTaxRates: row.enabledItemTaxRates,
      enabledExpenseTaxRates: row.enabledExpenseTaxRates,
      calculateTaxes: row.calculateTaxes,
      taxData: taxData,
      eInvoice: eInvoice,
      customSurchargeTaxes1: row.customSurchargeTaxes1,
      customSurchargeTaxes2: row.customSurchargeTaxes2,
      customSurchargeTaxes3: row.customSurchargeTaxes3,
      customSurchargeTaxes4: row.customSurchargeTaxes4,
      trackInventory: row.trackInventory,
      stockNotification: row.stockNotification,
      inventoryNotificationThreshold: row.inventoryNotificationThreshold,
      enableProductDiscount: row.enableProductDiscount,
      enableProductCost: row.enableProductCost,
      enableProductQuantity: row.enableProductQuantity,
      defaultQuantity: row.defaultQuantity,
      showProductDetails: row.showProductDetails,
      fillProducts: row.fillProducts,
      updateProducts: row.updateProducts,
      convertProducts: row.convertProducts,
      convertRateToClient: row.convertRateToClient,
      stopOnUnpaidRecurring: row.stopOnUnpaidRecurring,
      useQuoteTermsOnConversion: row.useQuoteTermsOnConversion,
      autoStartTasks: row.autoStartTasks,
      showTaskEndDate: row.showTaskEndDate,
      showTasksTable: row.showTasksTable,
      invoiceTaskDatelog: row.invoiceTaskDatelog,
      invoiceTaskTimelog: row.invoiceTaskTimelog,
      invoiceTaskHours: row.invoiceTaskHours,
      invoiceTaskItemDescription: row.invoiceTaskItemDescription,
      invoiceTaskProject: row.invoiceTaskProject,
      invoiceTaskProjectHeader: row.invoiceTaskProjectHeader,
      invoiceTaskLock: row.invoiceTaskLock,
      invoiceTaskDocuments: row.invoiceTaskDocuments,
      markExpensesInvoiceable: row.markExpensesInvoiceable,
      markExpensesPaid: row.markExpensesPaid,
      convertExpenseCurrency: row.convertExpenseCurrency,
      invoiceExpenseDocuments: row.invoiceExpenseDocuments,
      notifyVendorWhenPaid: row.notifyVendorWhenPaid,
      calculateExpenseTaxByAmount: row.calculateExpenseTaxByAmount,
      expenseInclusiveTaxes: row.expenseInclusiveTaxes,
      expenseMailboxActive: row.expenseMailboxActive,
      expenseMailbox: row.expenseMailbox,
      inboundMailboxAllowCompanyUsers: row.inboundMailboxAllowCompanyUsers,
      inboundMailboxAllowVendors: row.inboundMailboxAllowVendors,
      inboundMailboxAllowClients: row.inboundMailboxAllowClients,
      inboundMailboxWhitelist: row.inboundMailboxWhitelist,
      inboundMailboxBlacklist: row.inboundMailboxBlacklist,
      inboundMailboxAllowUnknown: row.inboundMailboxAllowUnknown,
      smtpHost: row.smtpHost,
      smtpPort: row.smtpPort,
      smtpEncryption: row.smtpEncryption,
      smtpUsername: row.smtpUsername,
      smtpPassword: row.smtpPassword,
      smtpLocalDomain: row.smtpLocalDomain,
      smtpVerifyPeer: row.smtpVerifyPeer,
      subdomain: row.subdomain,
      portalDomain: row.portalDomain,
      portalMode: row.portalMode,
      clientCanRegister: row.clientCanRegister,
      companyKey: row.companyKey,
      clientRegistrationFields: _decodeRegistrationFields(
        row.clientRegistrationFields,
      ),
      documents: documents,
      updatedAt: row.updatedAt,
    );
  }

  /// Encode the typed list to a JSON-encoded string for the Drift column.
  /// Empty lists round-trip as `[]` so the column default backfills cleanly.
  String _encodeRegistrationFields(List<ClientRegistrationFieldApi> fields) =>
      jsonEncode(fields.map((f) => f.toJson()).toList());

  /// Decode the Drift `client_registration_fields` column back to the typed
  /// list. Malformed or empty input maps to an empty list — matches the
  /// server's "no fields set" default and keeps the UI's "render 20 hidden
  /// defaults" path single-branch.
  List<ClientRegistrationFieldApi> _decodeRegistrationFields(String raw) {
    if (raw.isEmpty) return const <ClientRegistrationFieldApi>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(ClientRegistrationFieldApi.fromJson)
            .toList(growable: false);
      }
    } catch (_) {}
    return const <ClientRegistrationFieldApi>[];
  }

  /// Decode the `quickbooks_json` Drift column back to the map shape the
  /// API + UI consume. Null / empty / malformed inputs all map to `null` so
  /// the UI's `quickbooks == null` "not connected" check stays a single
  /// branch.
  Map<String, dynamic>? _decodeQuickbooks(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _decodeSettingsMap(String raw) {
    if (raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Map<String, String> _decodeCustomFields(String raw) {
    if (raw.isEmpty) return const <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return {
          for (final e in decoded.entries) e.key: e.value?.toString() ?? '',
        };
      }
    } catch (_) {}
    return const <String, String>{};
  }

  int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// The server masks the stored SMTP credentials as `********` on every read
/// (`CompanyTransformer`), and the login/refresh envelope seeds that mask
/// straight into the local row — so a plain settings save would echo it back.
/// `UpdateCompanyRequest::prepareForValidation` unsets anything shorter than
/// two characters once `*` is stripped, so the echo is discarded server-side
/// today; dropping the keys here means we never rely on that, and never risk
/// writing the literal mask as someone's password.
bool _isMaskedSmtpCredential(String key, Object? value) =>
    (key == 'smtp_username' || key == 'smtp_password') && value == '********';
