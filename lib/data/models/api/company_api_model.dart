import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/client_registration_field_api_model.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';

// `DocumentApi` moved out of this file when Client and Product also started
// carrying document arrays. Re-exported so existing call sites keep working
// with no import churn.
export 'package:admin/data/models/api/document_api_model.dart';

part 'company_api_model.freezed.dart';
part 'company_api_model.g.dart';

/// Wire shape of `/api/v1/companies/{id}` (also embedded in `/auth/me` via
/// `CompanyEnvelopeApi`).
///
/// `settings` stays as a raw map for the same reason it does on
/// [CompanyEnvelopeApi] — the typed model only covers ~200 of ~250 server
/// fields, and round-tripping through it would drop the others silently.
/// Callers build the typed view via `CompanySettingsApi.fromJson(settings)`
/// when they need to read individual fields.
@freezed
abstract class CompanyApi with _$CompanyApi {
  @JsonSerializable(includeIfNull: false)
  const factory CompanyApi({
    @Default('') String id,
    @JsonKey(name: 'display_name') @Default('') String displayName,
    @Default('') String name,
    @JsonKey(name: 'company_key') @Default('') String companyKey,
    @JsonKey(name: 'size_id') @Default('') String sizeId,
    @JsonKey(name: 'industry_id') @Default('') String industryId,
    @JsonKey(name: 'first_month_of_year') @Default('') String firstMonthOfYear,
    @JsonKey(name: 'first_day_of_week') @Default('') String firstDayOfWeek,
    // Settings → Localization "Decimal Comma". Top-level company column on the
    // API (never inside `settings`) — confirmed against the live server, React
    // (binds top-level), and admin-portal. The money formatter reads it via
    // `Services._buildFormatter`'s row overlay, same as the two fields above.
    @JsonKey(name: 'use_comma_as_decimal_place')
    @Default(false)
    bool useCommaAsDecimalPlace,
    @JsonKey(name: 'enabled_modules') @Default(0) int enabledModules,
    // `enable_modules` is DocuNinja's "e-signatures are on for this company"
    // flag (server `Company::docuninjaActive()`), not the `enabled_modules`
    // bitmask above. Set by the hosted admin service and not fillable, so it
    // is read-only: never sent back (docs/docuninja.md).
    @JsonKey(
      name: 'enable_modules',
      fromJson: jsonScalarToBool,
      includeToJson: false,
    )
    @Default(false)
    bool enableModules,
    @JsonKey(name: 'legal_entity_id') @Default(0) int legalEntityId,
    // ── E-Invoice certificate ───────────────────────────────────────────
    // Top-level company fields edited by Settings → E-Invoice's certificate
    // card. `eInvoiceCertificatePassphrase` is the only one the user edits
    // directly; the two `has*` flags are server-set — they flip to true when
    // a cert / passphrase is uploaded, and to false when the user clears
    // them. Default false / '' so a fresh CompanyApi doesn't invent state.
    @JsonKey(name: 'has_e_invoice_certificate')
    @Default(false)
    bool hasEInvoiceCertificate,
    @JsonKey(name: 'e_invoice_certificate_passphrase')
    @Default('')
    String eInvoiceCertificatePassphrase,
    @JsonKey(name: 'has_e_invoice_certificate_passphrase')
    @Default(false)
    bool hasEInvoiceCertificatePassphrase,
    @JsonKey(name: 'subdomain') @Default('') String subdomain,
    @JsonKey(name: 'portal_domain') @Default('') String portalDomain,
    @JsonKey(name: 'portal_mode') @Default('') String portalMode,
    @JsonKey(name: 'client_can_register')
    @Default(false)
    bool clientCanRegister,
    @JsonKey(name: 'client_registration_fields')
    @Default(<ClientRegistrationFieldApi>[])
    List<ClientRegistrationFieldApi> clientRegistrationFields,
    @JsonKey(name: 'custom_fields')
    @Default(<String, String>{})
    Map<String, String> customFields,
    @Default(<String, dynamic>{}) Map<String, dynamic> settings,
    @JsonKey(name: 'enable_applying_payments')
    @Default(false)
    bool enableApplyingPayments,
    @JsonKey(name: 'convert_payment_currency')
    @Default(false)
    bool convertPaymentCurrency,
    // ── Tax configuration ────────────────────────────────────────────────
    // The three count fields, `calculate_taxes` and `tax_data` live at
    // company top-level, not in settings — matching the server contract
    // and the legacy admin-portal / React clients.
    @JsonKey(name: 'enabled_tax_rates') @Default(0) int enabledTaxRates,
    @JsonKey(name: 'enabled_item_tax_rates')
    @Default(0)
    int enabledItemTaxRates,
    @JsonKey(name: 'enabled_expense_tax_rates')
    @Default(0)
    int enabledExpenseTaxRates,
    @JsonKey(name: 'calculate_taxes') @Default(false) bool calculateTaxes,
    @JsonKey(name: 'tax_data') TaxConfigApi? taxData,
    // Server's e-invoice config blob (nested UBL-ish map). Read-only as far as
    // the typed model is concerned — `includeIfNull: false` + the omission
    // from `Company.toApiJson` keep it out of the company PUT body, so a save
    // never clears the server's config. The Payment Means card seeds its
    // fields from `e_invoice.Invoice.PaymentMeans[0]` (matches React).
    @JsonKey(name: 'e_invoice', includeIfNull: false)
    Map<String, dynamic>? eInvoice,
    // Per-surcharge "charge taxes" toggles paired with the four surcharge
    // custom-field slots in `custom_fields.surcharge1..4`. Edited on
    // Settings → Custom Fields → Invoices.
    @JsonKey(name: 'custom_surcharge_taxes1')
    @Default(false)
    bool customSurchargeTaxes1,
    @JsonKey(name: 'custom_surcharge_taxes2')
    @Default(false)
    bool customSurchargeTaxes2,
    @JsonKey(name: 'custom_surcharge_taxes3')
    @Default(false)
    bool customSurchargeTaxes3,
    @JsonKey(name: 'custom_surcharge_taxes4')
    @Default(false)
    bool customSurchargeTaxes4,
    // ── Product configuration ───────────────────────────────────────────
    // Top-level company fields edited by Settings → Product Settings.
    // Defaults stay false/0 so a fresh CompanyApi constructor doesn't
    // invent values; `Company.fromApi` always overlays whatever the wire
    // sent.
    @JsonKey(name: 'track_inventory') @Default(false) bool trackInventory,
    @JsonKey(name: 'stock_notification') @Default(false) bool stockNotification,
    @JsonKey(name: 'inventory_notification_threshold')
    @Default(0)
    int inventoryNotificationThreshold,
    @JsonKey(name: 'enable_product_discount')
    @Default(false)
    bool enableProductDiscount,
    @JsonKey(name: 'enable_product_cost')
    @Default(false)
    bool enableProductCost,
    @JsonKey(name: 'enable_product_quantity')
    @Default(false)
    bool enableProductQuantity,
    @JsonKey(name: 'default_quantity') @Default(false) bool defaultQuantity,
    @JsonKey(name: 'show_product_details')
    @Default(false)
    bool showProductDetails,
    @JsonKey(name: 'fill_products') @Default(false) bool fillProducts,
    @JsonKey(name: 'update_products') @Default(false) bool updateProducts,
    @JsonKey(name: 'convert_products') @Default(false) bool convertProducts,
    @JsonKey(name: 'convert_rate_to_client')
    @Default(false)
    bool convertRateToClient,
    // ── Workflow ────────────────────────────────────────────────────────
    // Top-level company fields edited by Settings → Workflow Settings.
    // Only the company-scope rows on that page; the per-entity workflow
    // toggles live under `settings.*` (auto_email_invoice, lock_invoices,
    // etc.) on `CompanySettingsApi`.
    @JsonKey(name: 'stop_on_unpaid_recurring')
    @Default(false)
    bool stopOnUnpaidRecurring,
    @JsonKey(name: 'use_quote_terms_on_conversion')
    @Default(false)
    bool useQuoteTermsOnConversion,
    // ── Task configuration ──────────────────────────────────────────────
    // Top-level company fields edited by Settings → Task Settings. Per-entity
    // task toggles (`default_task_rate`, `task_round_up`, …) live on
    // `CompanySettingsApi`. `invoiceTaskProjectHeader`: false = service,
    // true = description (parity with legacy admin-portal).
    @JsonKey(name: 'auto_start_tasks') @Default(false) bool autoStartTasks,
    @JsonKey(name: 'show_task_end_date') @Default(false) bool showTaskEndDate,
    @JsonKey(name: 'show_tasks_table') @Default(false) bool showTasksTable,
    @JsonKey(name: 'invoice_task_datelog')
    @Default(false)
    bool invoiceTaskDatelog,
    @JsonKey(name: 'invoice_task_timelog')
    @Default(false)
    bool invoiceTaskTimelog,
    @JsonKey(name: 'invoice_task_hours') @Default(false) bool invoiceTaskHours,
    @JsonKey(name: 'invoice_task_item_description')
    @Default(false)
    bool invoiceTaskItemDescription,
    @JsonKey(name: 'invoice_task_project')
    @Default(false)
    bool invoiceTaskProject,
    @JsonKey(name: 'invoice_task_project_header')
    @Default(false)
    bool invoiceTaskProjectHeader,
    @JsonKey(name: 'invoice_task_lock') @Default(false) bool invoiceTaskLock,
    @JsonKey(name: 'invoice_task_documents')
    @Default(false)
    bool invoiceTaskDocuments,
    // ── Expense configuration ───────────────────────────────────────────
    // Top-level company fields edited by Settings → Expense Settings.
    // Cascade `default_expense_payment_type_id` lives on `CompanySettingsApi`.
    // The `inbound_mailbox_*` block is self-hosted only (gated by the
    // session's `isHosted == false`).
    @JsonKey(name: 'mark_expenses_invoiceable')
    @Default(false)
    bool markExpensesInvoiceable,
    @JsonKey(name: 'mark_expenses_paid') @Default(false) bool markExpensesPaid,
    @JsonKey(name: 'convert_expense_currency')
    @Default(false)
    bool convertExpenseCurrency,
    @JsonKey(name: 'invoice_expense_documents')
    @Default(false)
    bool invoiceExpenseDocuments,
    @JsonKey(name: 'notify_vendor_when_paid')
    @Default(false)
    bool notifyVendorWhenPaid,
    @JsonKey(name: 'calculate_expense_tax_by_amount')
    @Default(false)
    bool calculateExpenseTaxByAmount,
    @JsonKey(name: 'expense_inclusive_taxes')
    @Default(false)
    bool expenseInclusiveTaxes,
    @JsonKey(name: 'expense_mailbox_active')
    @Default(false)
    bool expenseMailboxActive,
    @JsonKey(name: 'expense_mailbox') @Default('') String expenseMailbox,
    @JsonKey(name: 'inbound_mailbox_allow_company_users')
    @Default(false)
    bool inboundMailboxAllowCompanyUsers,
    @JsonKey(name: 'inbound_mailbox_allow_vendors')
    @Default(false)
    bool inboundMailboxAllowVendors,
    @JsonKey(name: 'inbound_mailbox_allow_clients')
    @Default(false)
    bool inboundMailboxAllowClients,
    @JsonKey(name: 'inbound_mailbox_whitelist')
    @Default('')
    String inboundMailboxWhitelist,
    @JsonKey(name: 'inbound_mailbox_blacklist')
    @Default('')
    String inboundMailboxBlacklist,
    @JsonKey(name: 'inbound_mailbox_allow_unknown')
    @Default(false)
    bool inboundMailboxAllowUnknown,
    // ── Email / SMTP transport ──────────────────────────────────────────
    // Top-level company fields edited by Settings → Email Settings when the
    // `smtp` provider is selected. Cascade-aware email properties
    // (`emailSendingMethod`, `emailFromName`, …) live on `CompanySettingsApi`
    // — these seven are top-level only and never round-trip through the
    // `settings` JSON blob. `smtpEncryption` mirrors admin-portal's
    // `'TLS'` / `'STARTTLS'` vocabulary; `smtpVerifyPeer` defaults to true to
    // match the legacy clients' read-time fallback.
    @JsonKey(name: 'smtp_host') @Default('') String smtpHost,
    @JsonKey(name: 'smtp_port') @Default(0) int smtpPort,
    @JsonKey(name: 'smtp_encryption') @Default('TLS') String smtpEncryption,
    @JsonKey(name: 'smtp_username') @Default('') String smtpUsername,
    @JsonKey(name: 'smtp_password') @Default('') String smtpPassword,
    @JsonKey(name: 'smtp_local_domain') @Default('') String smtpLocalDomain,
    @JsonKey(name: 'smtp_verify_peer') @Default(true) bool smtpVerifyPeer,
    // ── Analytics integrations ──────────────────────────────────────────
    // Top-level company fields edited by Settings → Account Management →
    // Integrations. Empty strings are the "not configured" sentinel; the
    // server stores them verbatim.
    @JsonKey(name: 'google_analytics_key')
    @Default('')
    String googleAnalyticsKey,
    @JsonKey(name: 'matomo_id') @Default('') String matomoId,
    @JsonKey(name: 'matomo_url') @Default('') String matomoUrl,
    // ── Security ────────────────────────────────────────────────────────
    // Top-level company fields edited by Settings → Account Management →
    // Security Settings. Both timeouts are in milliseconds; 0 means
    // "never time out".
    @JsonKey(name: 'session_timeout') @Default(0) int sessionTimeout,
    @JsonKey(name: 'default_password_timeout')
    @Default(0)
    int defaultPasswordTimeout,
    @JsonKey(name: 'oauth_password_required')
    @Default(false)
    bool oauthPasswordRequired,
    // ── Overview-card top-level toggles ────────────────────────────────
    // Account Management → Overview edits these. `is_disabled` flips the
    // company off (server skips it for emails / recurring sends); the
    // remaining four are PDF / email markdown render flags and the report
    // include-drafts / include-deleted flags. All default false.
    @JsonKey(name: 'is_disabled') @Default(false) bool isDisabled,
    @JsonKey(name: 'markdown_enabled') @Default(false) bool markdownEnabled,
    @JsonKey(name: 'markdown_email_enabled')
    @Default(false)
    bool markdownEmailEnabled,
    @JsonKey(name: 'report_include_drafts')
    @Default(false)
    bool reportIncludeDrafts,
    @JsonKey(name: 'report_include_deleted')
    @Default(false)
    bool reportIncludeDeleted,
    // QuickBooks integration envelope. `null` (not the empty map) when
    // not connected — the server omits the key entirely; we preserve that
    // signal end-to-end so the UI's `isConnected` check is unambiguous.
    @JsonKey(name: 'quickbooks') Map<String, dynamic>? quickbooks,
    @Default(<DocumentApi>[]) List<DocumentApi> documents,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
  }) = _CompanyApi;

  factory CompanyApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyApiFromJson(json);
}

/// Envelope for `/api/v1/companies/{id}` item responses (`{ data: ... }`).
@freezed
abstract class CompanyItemApi with _$CompanyItemApi {
  const factory CompanyItemApi({required CompanyApi data}) = _CompanyItemApi;

  factory CompanyItemApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyItemApiFromJson(json);
}
