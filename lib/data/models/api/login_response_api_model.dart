import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/bank_account_api_model.dart';
import 'package:admin/data/models/api/client_registration_field_api_model.dart';
import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/data/models/api/group_setting_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/payment_term_api_model.dart';
import 'package:admin/data/models/api/schedule_api_model.dart';
import 'package:admin/data/models/api/subscription_api_model.dart';
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/data/models/api/tax_rate_api_model.dart';
import 'package:admin/data/models/api/token_api_model.dart';
import 'package:admin/data/models/api/transaction_rule_api_model.dart';
import 'package:admin/data/models/api/user_api_model.dart';
import 'package:admin/data/models/api/webhook_api_model.dart';

part 'login_response_api_model.freezed.dart';
part 'login_response_api_model.g.dart';

/// Shape of `/api/v1/login` and `/api/v1/refresh`.
///
/// Mirrors `admin-portal/lib/data/models/entities.dart:594` (LoginResponse).
/// `data` is the array of companies this user has access to. `static` is the
/// global reference-data blob (currencies, countries, etc.) — kept as a raw
/// map; `StaticsRepository` parses it lazily.
///
/// `data` and every bundled sub-list on [CompanyEnvelopeApi] parse through
/// `tolerantList` (per-row skip + WARNING log), matching the *ListApi
/// envelopes: this is the PRIMARY ingest path, and a single malformed row
/// here used to fail the whole login/refresh — locking the user out instead
/// of degrading one row. An all-rows-malformed `data` still fails loudly:
/// `_persistAndActivate` throws on an empty company list. Accepted
/// degradation: a skipped company vanishes from the session (and, on a full
/// sync, from the local cache) until the server sends it well-formed again —
/// its unsynced outbox rows still block logout/idle-wipe, because those
/// guards read `companiesWithActiveRows()` from the outbox, not the session.
/// That degradation is a genuine loss of function for the user, so keep the
/// per-row required-field surface as small as the data allows — every
/// `required` on [UserCompanyApi] is one more server-side null that silently
/// removes a company from the switcher (see the note on its `token` field).
@freezed
abstract class LoginResponseApi with _$LoginResponseApi {
  const factory LoginResponseApi({
    @JsonKey(fromJson: _userCompanyListData)
    @Default(<UserCompanyApi>[])
    List<UserCompanyApi> data,
    @JsonKey(name: 'static')
    @Default(<String, dynamic>{})
    Map<String, dynamic> staticData,
  }) = _LoginResponseApi;

  factory LoginResponseApi.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseApiFromJson(json);
}

/// One per company this user has access to. The token is per-company.
@freezed
abstract class UserCompanyApi with _$UserCompanyApi {
  const factory UserCompanyApi({
    @JsonKey(name: 'is_admin') @Default(false) bool isAdmin,
    @JsonKey(name: 'is_owner') @Default(false) bool isOwner,
    @Default('') String permissions,
    @JsonKey(name: 'permissions_updated_at')
    @Default(0)
    int permissionsUpdatedAt,
    required CompanyEnvelopeApi company,
    // NOT `required`: the server sends `"token": null` for a company that has
    // no `is_system` token for THIS user — `CompanyUserTransformer::includeToken`
    // filters on (company_id, user_id), while `/refresh`'s token backfill only
    // checks whether the *company* has one (BACKEND.md § `/refresh` mints the
    // `is_system` token per company). A required field made that a `TypeError`,
    // which `tolerantList` turned into a silently dropped company: gone from
    // the picker, wiped from Drift by the next full sync, and its token pruned
    // with it — the
    // user simply could no longer switch to it (issue #16). Defaulting to an
    // empty token keeps the company in the roster and lets the cached token
    // (merged at `_persistAndActivate`, which only overrides on non-empty) keep
    // working. `company` and `account` stay required — an entry missing either
    // is unusable, and `data.first.account` sources every account-level field.
    @Default(SessionTokenApi()) SessionTokenApi token,
    required AccountEnvelopeApi account,
    @Default(<String, dynamic>{}) Map<String, dynamic> settings,
    @JsonKey(name: 'user') @Default(UserSummaryApi()) UserSummaryApi user,
    // Pre-signed hosted-billing URL for this `(user, company)`. Surfaced by
    // Settings → Account Management → Plan as the "Manage Plan" CTA target;
    // the server bakes `account_key` and `product_id` into the URL so we
    // don't have to know them on the client.
    @JsonKey(name: 'ninja_portal_url') @Default('') String ninjaPortalUrl,
  }) = _UserCompanyApi;

  factory UserCompanyApi.fromJson(Map<String, dynamic> json) =>
      _$UserCompanyApiFromJson(json);
}

/// The authenticated user's record, decoded from `data[N].user` in the
/// `/api/v1/login` and `/api/v1/refresh` response. Carries everything the
/// Settings > User Details screen needs to render (and save through the
/// outbox), so the app never has to round-trip `/api/v1/users/{id}` — that
/// route is password-protected (412), and `/refresh` is not.
@freezed
abstract class UserSummaryApi with _$UserSummaryApi {
  const factory UserSummaryApi({
    @Default('') String id,
    @JsonKey(name: 'first_name') @Default('') String firstName,
    @JsonKey(name: 'last_name') @Default('') String lastName,
    @JsonKey(name: 'email') @Default('') String email,
    @JsonKey(name: 'phone') @Default('') String phone,
    @JsonKey(name: 'signature') @Default('') String signature,
    @JsonKey(name: 'language_id') @Default('') String languageId,
    @JsonKey(name: 'custom_value1') @Default('') String customValue1,
    @JsonKey(name: 'custom_value2') @Default('') String customValue2,
    @JsonKey(name: 'custom_value3') @Default('') String customValue3,
    @JsonKey(name: 'custom_value4') @Default('') String customValue4,
    @JsonKey(name: 'oauth_provider_id') @Default('') String oauthProviderId,
    // Server sends a truthy string ("true"/"1") OR a bool depending on the
    // endpoint, so the JSON converter normalizes to a plain bool.
    @JsonKey(name: 'google_2fa_secret', fromJson: _boolFromJson)
    @Default(false)
    bool google2faSecret,
    @JsonKey(name: 'verified_phone_number', fromJson: _boolFromJson)
    @Default(false)
    bool verifiedPhoneNumber,
    // Referral program — surfaced on Settings → Account Management →
    // Referral Program (hosted only). `referral_meta` is a `{plan: count}`
    // map of how many sign-ups each plan tier brought in.
    @JsonKey(name: 'referral_code') @Default('') String referralCode,
    @JsonKey(name: 'referral_meta', fromJson: _referralMetaFromJson)
    @Default(<String, int>{})
    Map<String, int> referralMeta,
  }) = _UserSummaryApi;

  factory UserSummaryApi.fromJson(Map<String, dynamic> json) =>
      _$UserSummaryApiFromJson(json);
}

bool _boolFromJson(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
}

/// `referral_meta` is the per-plan referral count map (`{free, pro,
/// enterprise}`). The server overloads the same column with unrelated nested
/// state — the live demo returns `calendar_connection: {status: ...}` alongside
/// the counts — so a plain `value as num` cast crashes login deserialization
/// for every session. Keep only the integer-valued entries (the counts the
/// Referral Program screen renders) and silently drop any nested object/list.
Map<String, int> _referralMetaFromJson(Object? value) {
  if (value is! Map) return const <String, int>{};
  final out = <String, int>{};
  value.forEach((key, v) {
    final k = key?.toString();
    if (k == null) return;
    if (v is num) {
      out[k] = v.toInt();
    } else if (v is String) {
      final n = num.tryParse(v);
      if (n != null) out[k] = n.toInt();
    }
  });
  return out;
}

/// The `data[N].company` object on `/login` and `/refresh`. The server builds
/// it with the same `CompanyTransformer` as `GET /companies/{id}`, so it
/// carries the full top-level column set.
///
/// **Every top-level `companies` column belongs here.** `_persistAndActivate`
/// re-writes the companies row from this envelope on each login/refresh, so a
/// column modelled on `CompanyApi` but missing here reverts to its Drift table
/// default — silently, and on every app launch. That's what lost users' SMTP
/// credentials in issue #29. Sole exception:
/// `e_invoice_certificate_passphrase`, a write-only secret the server never
/// returns (only the `has_…` flag comes back).
///
/// The bundled sub-lists (`users`, `designs`, `tax_rates`, …) are a separate
/// concern — see CLAUDE.md § Data loading — bundled vs per-entity.
@freezed
abstract class CompanyEnvelopeApi with _$CompanyEnvelopeApi {
  const factory CompanyEnvelopeApi({
    @Default('') String id,
    @JsonKey(name: 'display_name') @Default('') String displayName,
    @Default('') String name,
    @JsonKey(name: 'company_key') @Default('') String companyKey,
    // Server-side last-modified timestamp (Unix seconds). Persisted to the
    // companies table so the avatar's `cacheBustedLogoUrl` keys its `?v=` on a
    // real company change, not local wall-clock — otherwise every no-op
    // /refresh re-minted the logo URL and re-fetched an identical logo.
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    // Top-level portal configuration. Edited by Settings → Client Portal;
    // the login envelope persists them straight into the `companies` Drift
    // table so the page reads correct values offline before the first refresh.
    @JsonKey(name: 'subdomain') @Default('') String subdomain,
    @JsonKey(name: 'portal_domain') @Default('') String portalDomain,
    @JsonKey(name: 'portal_mode') @Default('') String portalMode,
    @JsonKey(name: 'client_can_register')
    @Default(false)
    bool clientCanRegister,
    @JsonKey(
      name: 'client_registration_fields',
      fromJson: _clientRegistrationFieldListData,
    )
    @Default(<ClientRegistrationFieldApi>[])
    List<ClientRegistrationFieldApi> clientRegistrationFields,
    @JsonKey(name: 'custom_fields')
    @Default(<String, String>{})
    Map<String, String> customFields,
    // Company file attachments. The server ships these on the login/refresh
    // envelope; persisting them straight into the `companies.documents` Drift
    // column keeps the Settings → Company Details → Documents tab populated
    // offline and before its own `GET /companies/{id}` lands. Without this the
    // `_persistAndActivate` wipe+upsert nulls the column on every refresh.
    @JsonKey(name: 'documents', fromJson: _companyDocumentListData)
    @Default(<DocumentApi>[])
    List<DocumentApi> documents,
    @JsonKey(name: 'size_id') @Default('') String sizeId,
    @JsonKey(name: 'industry_id') @Default('') String industryId,
    @JsonKey(name: 'first_month_of_year') @Default('') String firstMonthOfYear,
    @JsonKey(name: 'first_day_of_week') @Default('') String firstDayOfWeek,
    @JsonKey(name: 'use_comma_as_decimal_place')
    @Default(false)
    bool useCommaAsDecimalPlace,
    @JsonKey(name: 'legal_entity_id') @Default(0) int legalEntityId,
    @JsonKey(name: 'enabled_modules') @Default(0) int enabledModules,
    // `settings` stays as a raw map — every key the server sends is
    // preserved verbatim through the round-trip. Strong-typing here would
    // drop unknown keys at fromJson/toJson, silently corrupting fields
    // we haven't modeled yet. The repository builds the typed view on
    // demand via `CompanySettingsApi.fromJson`.
    @Default(<String, dynamic>{}) Map<String, dynamic> settings,
    // Bundled reference arrays. `/refresh?first_load=true` delivers these
    // alongside the company so the matching repos don't need a separate
    // round-trip on first paint. The pattern matches CLAUDE.md § Data
    // loading — bundled vs per-entity. Add new bundles here as more
    // settings screens come online (tax_rates, designs, …).
    // Full company roster (owner + members), embedded on `first_load` under
    // `company.users`. Persisted (upsert-only) by `UserRepository.applyBundle`
    // so assigned-user ids resolve to display names everywhere — without a
    // `GET /users/{id}` round-trip (that endpoint is 412 password-gated).
    @JsonKey(name: 'users', fromJson: _bundledUserListData)
    @Default(<UserApi>[])
    List<UserApi> users,
    @JsonKey(name: 'task_statuses', fromJson: _taskStatusListData)
    @Default(<TaskStatusApi>[])
    List<TaskStatusApi> taskStatuses,
    @JsonKey(name: 'company_gateways', fromJson: _companyGatewayListData)
    @Default(<CompanyGatewayApi>[])
    List<CompanyGatewayApi> companyGateways,
    @JsonKey(name: 'payment_terms', fromJson: _paymentTermListData)
    @Default(<PaymentTermApi>[])
    List<PaymentTermApi> paymentTerms,
    @JsonKey(name: 'tax_rates', fromJson: _taxRateListData)
    @Default(<TaxRateApi>[])
    List<TaxRateApi> taxRates,
    @JsonKey(name: 'expense_categories', fromJson: _expenseCategoryListData)
    @Default(<ExpenseCategoryApi>[])
    List<ExpenseCategoryApi> expenseCategories,
    // Client / permission groups. Tiny per-company list (typically a handful of
    // rows) the server returns on every `/refresh`. `GroupSettingRepository.applyBundle`
    // upserts into the local `group_settings` Drift table — the Settings →
    // Group Settings list reads from Drift and skips the first paged fetch.
    @JsonKey(name: 'groups', fromJson: _groupSettingListData)
    @Default(<GroupSettingApi>[])
    List<GroupSettingApi> groups,
    // Bank-transaction matching rules. Small settings-style list managed under
    // Banking → Rules; `TransactionRuleRepository.applyBundle` upserts into
    // the local `transaction_rules` table on every login/refresh.
    @JsonKey(name: 'bank_transaction_rules', fromJson: _transactionRuleListData)
    @Default(<TransactionRuleApi>[])
    List<TransactionRuleApi> bankTransactionRules,
    // Bank account integrations. Typically 1–10 rows per company.
    // `BankAccountRepository.applyBundle` upserts into the local
    // `bank_accounts` table on every login/refresh.
    @JsonKey(name: 'bank_integrations', fromJson: _bankIntegrationListData)
    @Default(<BankAccountApi>[])
    List<BankAccountApi> bankIntegrations,
    // API webhooks. Small settings-style list; `WebhookRepository.applyBundle`
    // upserts into the local `webhooks` table on every login/refresh.
    @JsonKey(name: 'webhooks', fromJson: _webhookListData)
    @Default(<WebhookApi>[])
    List<WebhookApi> webhooks,
    // API tokens. Small settings-style list; `TokenRepository.applyBundle`
    // upserts into the local `tokens` table on every login/refresh. The
    // server returns the `token` field MASKED in this array — the raw
    // bearer secret only appears on the `POST /tokens` create response.
    @JsonKey(name: 'tokens_hashed', fromJson: _tokenListData)
    @Default(<TokenApi>[])
    List<TokenApi> tokensHashed,
    // Task schedulers ("Schedules") — bundled settings entity. The server
    // ships every scheduler the user has configured (typically a handful);
    // `ScheduleRepository.applyBundle` upserts into the local `schedules`
    // table on every login/refresh.
    @JsonKey(name: 'task_schedulers', fromJson: _taskSchedulerListData)
    @Default(<ScheduleApi>[])
    List<ScheduleApi> taskSchedulers,
    // Subscriptions ("Payment Links") — same bundled-and-paginated
    // pattern as expense_categories. `SubscriptionRepository.applyBundle`
    // upserts into the `subscriptions` Drift table on every login/refresh.
    @JsonKey(name: 'subscriptions', fromJson: _subscriptionListData)
    @Default(<SubscriptionApi>[])
    List<SubscriptionApi> subscriptions,
    // Invoice Design template list. The server ships the 11 built-in
    // templates plus any custom designs the user has created, each with
    // the full `design.{body,header,footer,includes,product,task}` HTML
    // strings. `DesignRepository.applyBundle` upserts into the `designs`
    // table on every login/refresh.
    @JsonKey(name: 'designs', fromJson: _designListData)
    @Default(<DesignApi>[])
    List<DesignApi> designs,
    // Top-level tax fields on the envelope, mirroring `CompanyApi`. Settings
    // → Tax Settings writes these via `host.updateCompany(...)`.
    @JsonKey(name: 'enabled_tax_rates') @Default(0) int enabledTaxRates,
    @JsonKey(name: 'enabled_item_tax_rates')
    @Default(0)
    int enabledItemTaxRates,
    @JsonKey(name: 'enabled_expense_tax_rates')
    @Default(0)
    int enabledExpenseTaxRates,
    @JsonKey(name: 'calculate_taxes') @Default(false) bool calculateTaxes,
    @JsonKey(name: 'tax_data') TaxConfigApi? taxData,
    // Server's e-invoice config blob (nested UBL-ish map). Carried untyped so
    // the Payment Means card can seed from `e_invoice.Invoice.PaymentMeans[0]`
    // (matches React). Written straight to Drift on login/refresh; never
    // edited here. Writes flow through `/einvoice/configurations`.
    @JsonKey(name: 'e_invoice', includeIfNull: false)
    Map<String, dynamic>? eInvoice,
    // Per-custom-surcharge "charge taxes" toggles. Edited under Settings →
    // Custom Fields → Invoices; mirrored from `CompanyApi`.
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
    // Top-level product configuration on the envelope, mirroring `CompanyApi`.
    // Settings → Product Settings writes these via `vm.updateCompany(...)`;
    // the login envelope persists them straight into the `companies` Drift
    // table so they're available offline before the first refresh.
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
    // Top-level workflow configuration on the envelope, mirroring `CompanyApi`.
    // Settings → Workflow Settings edits these via `host.updateCompany(...)`;
    // the login envelope persists them straight into the `companies` Drift
    // table so the page reads correct values offline before the first refresh.
    @JsonKey(name: 'stop_on_unpaid_recurring')
    @Default(false)
    bool stopOnUnpaidRecurring,
    @JsonKey(name: 'use_quote_terms_on_conversion')
    @Default(false)
    bool useQuoteTermsOnConversion,
    // Analytics integrations. Edited by Settings → Account Management →
    // Integrations; persisted as top-level company fields.
    @JsonKey(name: 'google_analytics_key')
    @Default('')
    String googleAnalyticsKey,
    @JsonKey(name: 'matomo_id') @Default('') String matomoId,
    @JsonKey(name: 'matomo_url') @Default('') String matomoUrl,
    // Security settings — top-level company fields. Timeouts in
    // milliseconds; 0 = never.
    @JsonKey(name: 'session_timeout') @Default(0) int sessionTimeout,
    @JsonKey(name: 'default_password_timeout')
    @Default(0)
    int defaultPasswordTimeout,
    @JsonKey(name: 'oauth_password_required')
    @Default(false)
    bool oauthPasswordRequired,
    // Account Management → Overview top-level toggles.
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
    // QuickBooks integration envelope — see CompanyApi.quickbooks. Null
    // when not connected.
    @JsonKey(name: 'quickbooks') Map<String, dynamic>? quickbooks,
    // ── SMTP transport (Settings → Email Settings, `smtp` provider) ──────
    // The server returns these on every login/refresh (same CompanyTransformer
    // as GET /companies/{id}) with `smtp_username` / `smtp_password` masked as
    // `********`. They MUST be carried here: a full sync re-seeds the
    // companies row from this envelope, so a field missing here lands its
    // Drift default instead of the user's value — that's issue #29.
    @JsonKey(name: 'smtp_host') @Default('') String smtpHost,
    @JsonKey(name: 'smtp_port') @Default(0) int smtpPort,
    @JsonKey(name: 'smtp_encryption') @Default('TLS') String smtpEncryption,
    @JsonKey(name: 'smtp_username') @Default('') String smtpUsername,
    @JsonKey(name: 'smtp_password') @Default('') String smtpPassword,
    @JsonKey(name: 'smtp_local_domain') @Default('') String smtpLocalDomain,
    @JsonKey(name: 'smtp_verify_peer') @Default(true) bool smtpVerifyPeer,
    // ── Expense settings + inbound mailbox ───────────────────────────────
    @JsonKey(name: 'expense_mailbox') @Default('') String expenseMailbox,
    @JsonKey(name: 'expense_mailbox_active')
    @Default(false)
    bool expenseMailboxActive,
    @JsonKey(name: 'inbound_mailbox_allow_company_users')
    @Default(false)
    bool inboundMailboxAllowCompanyUsers,
    @JsonKey(name: 'inbound_mailbox_allow_vendors')
    @Default(false)
    bool inboundMailboxAllowVendors,
    @JsonKey(name: 'inbound_mailbox_allow_clients')
    @Default(false)
    bool inboundMailboxAllowClients,
    @JsonKey(name: 'inbound_mailbox_allow_unknown')
    @Default(false)
    bool inboundMailboxAllowUnknown,
    @JsonKey(name: 'inbound_mailbox_whitelist')
    @Default('')
    String inboundMailboxWhitelist,
    @JsonKey(name: 'inbound_mailbox_blacklist')
    @Default('')
    String inboundMailboxBlacklist,
    @JsonKey(name: 'expense_inclusive_taxes')
    @Default(false)
    bool expenseInclusiveTaxes,
    @JsonKey(name: 'calculate_expense_tax_by_amount')
    @Default(false)
    bool calculateExpenseTaxByAmount,
    // ── Task settings + task/expense invoicing ───────────────────────────
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
    @JsonKey(name: 'mark_expenses_invoiceable')
    @Default(false)
    bool markExpensesInvoiceable,
    @JsonKey(name: 'mark_expenses_paid') @Default(false) bool markExpensesPaid,
    @JsonKey(name: 'invoice_expense_documents')
    @Default(false)
    bool invoiceExpenseDocuments,
    @JsonKey(name: 'notify_vendor_when_paid')
    @Default(false)
    bool notifyVendorWhenPaid,
    // ── Online payments + expense currency conversion ────────────────────
    @JsonKey(name: 'enable_applying_payments')
    @Default(false)
    bool enableApplyingPayments,
    @JsonKey(name: 'convert_payment_currency')
    @Default(false)
    bool convertPaymentCurrency,
    @JsonKey(name: 'convert_expense_currency')
    @Default(false)
    bool convertExpenseCurrency,
    // ── E-invoice certificate presence flags ─────────────────────────────
    // Read-only "is one uploaded?" booleans. The passphrase itself
    // (`e_invoice_certificate_passphrase`) is write-only — the server never
    // returns it, so it deliberately stays off the envelope and keeps being
    // blanked locally by `applyUpdateResponse`.
    @JsonKey(name: 'has_e_invoice_certificate')
    @Default(false)
    bool hasEInvoiceCertificate,
    @JsonKey(name: 'has_e_invoice_certificate_passphrase')
    @Default(false)
    bool hasEInvoiceCertificatePassphrase,
  }) = _CompanyEnvelopeApi;

  factory CompanyEnvelopeApi.fromJson(Map<String, dynamic> json) =>
      _$CompanyEnvelopeApiFromJson(json);
}

/// Session bearer token returned by `/login` and `/refresh` under
/// `data[N].token`. Used to authenticate subsequent API requests for
/// the matching company. Distinct from the company-scoped API tokens
/// entity (`TokenApi` / `tokens_hashed`) — those are settings-area
/// rows the user manages.
@freezed
abstract class SessionTokenApi with _$SessionTokenApi {
  const factory SessionTokenApi({
    @Default('') String token,
    @Default('') String name,
  }) = _SessionTokenApi;

  factory SessionTokenApi.fromJson(Map<String, dynamic> json) =>
      _$SessionTokenApiFromJson(json);
}

@freezed
abstract class AccountEnvelopeApi with _$AccountEnvelopeApi {
  const factory AccountEnvelopeApi({
    @Default('') String id,
    @JsonKey(name: 'default_company_id') @Default('') String defaultCompanyId,
    @Default('') String plan,
    @JsonKey(name: 'plan_expires') @Default('') String planExpires,
    @JsonKey(name: 'trial_started') @Default('') String trialStarted,
    @JsonKey(name: 'trial_plan') @Default('') String trialPlan,
    @JsonKey(name: 'num_trial_days') @Default(0) int numTrialDays,
    // Server-authoritative trial countdown. Preferred over the client-clock
    // computation in `AuthSession.trialDaysRemaining` so a long-offline or
    // midnight-rollover session doesn't false-lock a trialing user. `-1`
    // means the server didn't send it (fall back to the client computation).
    @JsonKey(name: 'trial_days_left') @Default(-1) int trialDaysLeft,
    // True when this account's subscription is managed via an App Store /
    // Play in-app purchase. Drives routing IAP subscribers to store-managed
    // billing instead of the web portal. Mirrors admin-portal's
    // `account.has_iap_plan`.
    @JsonKey(name: 'has_iap_plan') @Default(false) bool hasIapPlan,
    @JsonKey(name: 'hosted_client_count') @Default(0) int hostedClientCount,
    @JsonKey(name: 'hosted_company_count') @Default(0) int hostedCompanyCount,
    @JsonKey(name: 'e_invoicing_token') @Default('') String eInvoicingToken,
    // Account opt-in for remote error reporting. Default false = opt-in
    // (privacy-safe; mirrors v1's "drop unless true" Sentry gate). Must be
    // a declared field so `toJson()` carries it into the persisted
    // `features_json` blob the session-build reads.
    @JsonKey(name: 'report_errors') @Default(false) bool reportErrors,
  }) = _AccountEnvelopeApi;

  factory AccountEnvelopeApi.fromJson(Map<String, dynamic> json) =>
      _$AccountEnvelopeApiFromJson(json);
}

// Tolerant per-row parsers for the login/refresh envelope (see the class doc
// on LoginResponseApi). Freezed can't reference the generic `tolerantList`
// directly from @JsonKey, so each list gets a concrete top-level wrapper —
// the same pattern as every *ListApi envelope.
List<UserCompanyApi> _userCompanyListData(Object? raw) =>
    tolerantList(raw, UserCompanyApi.fromJson, label: 'user_company');
List<ClientRegistrationFieldApi> _clientRegistrationFieldListData(
  Object? raw,
) => tolerantList(
  raw,
  ClientRegistrationFieldApi.fromJson,
  label: 'client_registration_field',
);
List<DocumentApi> _companyDocumentListData(Object? raw) =>
    tolerantList(raw, DocumentApi.fromJson, label: 'company_document');
List<UserApi> _bundledUserListData(Object? raw) =>
    tolerantList(raw, UserApi.fromJson, label: 'bundled_user');
List<TaskStatusApi> _taskStatusListData(Object? raw) =>
    tolerantList(raw, TaskStatusApi.fromJson, label: 'task_status');
List<CompanyGatewayApi> _companyGatewayListData(Object? raw) =>
    tolerantList(raw, CompanyGatewayApi.fromJson, label: 'company_gateway');
List<PaymentTermApi> _paymentTermListData(Object? raw) =>
    tolerantList(raw, PaymentTermApi.fromJson, label: 'payment_term');
List<TaxRateApi> _taxRateListData(Object? raw) =>
    tolerantList(raw, TaxRateApi.fromJson, label: 'tax_rate');
List<ExpenseCategoryApi> _expenseCategoryListData(Object? raw) =>
    tolerantList(raw, ExpenseCategoryApi.fromJson, label: 'expense_category');
List<GroupSettingApi> _groupSettingListData(Object? raw) =>
    tolerantList(raw, GroupSettingApi.fromJson, label: 'group_setting');
List<TransactionRuleApi> _transactionRuleListData(Object? raw) =>
    tolerantList(raw, TransactionRuleApi.fromJson, label: 'transaction_rule');
List<BankAccountApi> _bankIntegrationListData(Object? raw) =>
    tolerantList(raw, BankAccountApi.fromJson, label: 'bank_integration');
List<WebhookApi> _webhookListData(Object? raw) =>
    tolerantList(raw, WebhookApi.fromJson, label: 'webhook');
List<TokenApi> _tokenListData(Object? raw) =>
    tolerantList(raw, TokenApi.fromJson, label: 'token');
List<ScheduleApi> _taskSchedulerListData(Object? raw) =>
    tolerantList(raw, ScheduleApi.fromJson, label: 'task_scheduler');
List<SubscriptionApi> _subscriptionListData(Object? raw) =>
    tolerantList(raw, SubscriptionApi.fromJson, label: 'subscription');
List<DesignApi> _designListData(Object? raw) =>
    tolerantList(raw, DesignApi.fromJson, label: 'design');
