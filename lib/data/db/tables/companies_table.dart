import 'package:drift/drift.dart';

/// Per-company envelope cached locally. The auth response (`LoginResponse`)
/// returns one of these per company the user has access to.
///
/// `settings` is the company settings blob; `permissions` is the per-company
/// permissions map; the rest is metadata shown in the company switcher.
@DataClassName('CompanyRow')
class Companies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get displayName => text().named('display_name').nullable()();
  // Logo URL persisted as its own column so the switcher doesn't depend on
  // the `settings` JSON round-tripping cleanly through codegen + SQLite +
  // jsonDecode. Populated at login from the API response.
  TextColumn get logoUrl => text().named('logo_url').nullable()();
  TextColumn get settings => text()();
  TextColumn get permissions => text()();
  TextColumn get accountId => text().named('account_id')();
  TextColumn get token => text()();
  // Top-level company fields that don't live inside `settings`. Stored so
  // the Company Details page can edit and round-trip them without a fresh
  // /auth/me. `custom_fields` is the `{ company1: "Label|type", ... }` map.
  TextColumn get customFields =>
      text().named('custom_fields').withDefault(const Constant('{}'))();
  TextColumn get sizeId =>
      text().named('size_id').withDefault(const Constant(''))();
  TextColumn get industryId =>
      text().named('industry_id').withDefault(const Constant(''))();
  // Settings → Localization "First Month of the Year" ('1'..'12'). Top-level
  // company field in the API (not inside `settings`), so — like size_id /
  // industry_id — it needs its own column or it's dropped on every
  // login/refresh and the dropdown renders blank.
  TextColumn get firstMonthOfYear =>
      text().named('first_month_of_year').withDefault(const Constant(''))();
  // Settings → Localization "First Day of the Week" ('0'=Sun..'6'=Sat). Like
  // first_month_of_year, a top-level company field (not inside `settings`), so
  // it needs its own column or it's dropped on every login/refresh. Drives the
  // week start for dashboard charts, report week grouping, and the date-range
  // calendar grid via `lib/utils/date_ranges.dart`.
  TextColumn get firstDayOfWeek =>
      text().named('first_day_of_week').withDefault(const Constant(''))();
  // Settings → Localization "Decimal Comma". Top-level company column (not
  // inside `settings`) — like first_month/first_day it needs its own column or
  // it's dropped on every login/refresh. The money formatter reads it via
  // `Services._buildFormatter`'s row overlay.
  BoolColumn get useCommaAsDecimalPlace => boolean()
      .named('use_comma_as_decimal_place')
      .withDefault(const Constant(false))();
  IntColumn get legalEntityId =>
      integer().named('legal_entity_id').withDefault(const Constant(0))();
  // E-Invoice certificate state. Edited by Settings → E-Invoice's
  // Certificate card. `passphrase` is locally editable + round-tripped
  // through the company PUT; the two `has*` flags are server-set (true
  // after upload, false after remove). The local `is_dirty` overlay in
  // `_fromRow` lets pending uploads show as "set" immediately instead of
  // waiting on the dispatcher drain — see § Strict rules in CLAUDE.md.
  // DocuNinja's "e-signatures are on" flag (`company.enable_modules`, not the
  // `enabled_modules` bitmask). Server-set and read-only (docs/docuninja.md);
  // rewritten from the login / refresh envelope like every other column.
  BoolColumn get enableModules =>
      boolean().named('enable_modules').withDefault(const Constant(false))();
  BoolColumn get hasEInvoiceCertificate => boolean()
      .named('has_e_invoice_certificate')
      .withDefault(const Constant(false))();
  TextColumn get eInvoiceCertificatePassphrase => text()
      .named('e_invoice_certificate_passphrase')
      .withDefault(const Constant(''))();
  BoolColumn get hasEInvoiceCertificatePassphrase => boolean()
      .named('has_e_invoice_certificate_passphrase')
      .withDefault(const Constant(false))();
  // Bitmask of modules enabled for this company. Driven by Settings →
  // Account Management → Enabled Modules; mirrors `CompanyApi.enabledModules`
  // (top-level, not inside the `settings` JSON). Default 0 backfills cleanly
  // on `addColumn`; real value lands on the next login / refresh.
  IntColumn get enabledModules =>
      integer().named('enabled_modules').withDefault(const Constant(0))();
  BoolColumn get isAdmin =>
      boolean().named('is_admin').withDefault(const Constant(false))();
  BoolColumn get isOwner =>
      boolean().named('is_owner').withDefault(const Constant(false))();
  // JSON-encoded list of attachments returned on the company response.
  // Nullable; the next `applyUpdateResponse` (or `/auth/me`) repopulates it.
  TextColumn get documents => text().nullable()();
  // Top-level tax configuration. Mirrors `CompanyApi.enabledTaxRates` /
  // `enabledItemTaxRates` / `enabledExpenseTaxRates` / `calculateTaxes` /
  // `taxData`. The Settings → Tax Settings UI edits these and round-trips
  // them through the outbox without touching the `settings` JSON.
  IntColumn get enabledTaxRates =>
      integer().named('enabled_tax_rates').withDefault(const Constant(0))();
  IntColumn get enabledItemTaxRates => integer()
      .named('enabled_item_tax_rates')
      .withDefault(const Constant(0))();
  IntColumn get enabledExpenseTaxRates => integer()
      .named('enabled_expense_tax_rates')
      .withDefault(const Constant(0))();
  BoolColumn get calculateTaxes =>
      boolean().named('calculate_taxes').withDefault(const Constant(false))();
  // `tax_data` JSON map. Nullable: older companies (and self-hosted
  // installs that haven't been touched recently) ship without it; the UI
  // treats null as "no regions provisioned yet".
  TextColumn get taxDataJson => text().named('tax_data_json').nullable()();
  // `e_invoice` JSON map (nested UBL-ish payment-means config). Nullable;
  // the Payment Means card seeds its fields from
  // `e_invoice.Invoice.PaymentMeans[0]`. Written on login/refresh; preserved
  // (not cleared) on a company PUT response that omits it.
  TextColumn get eInvoiceJson => text().named('e_invoice_json').nullable()();
  // Per-surcharge "charge taxes" toggles paired with the four surcharge
  // custom-field slots. Settings → Custom Fields → Invoices renders the
  // switch when `enabledTaxRates != 0`.
  BoolColumn get customSurchargeTaxes1 => boolean()
      .named('custom_surcharge_taxes1')
      .withDefault(const Constant(false))();
  BoolColumn get customSurchargeTaxes2 => boolean()
      .named('custom_surcharge_taxes2')
      .withDefault(const Constant(false))();
  BoolColumn get customSurchargeTaxes3 => boolean()
      .named('custom_surcharge_taxes3')
      .withDefault(const Constant(false))();
  BoolColumn get customSurchargeTaxes4 => boolean()
      .named('custom_surcharge_taxes4')
      .withDefault(const Constant(false))();
  // Top-level product configuration. Settings → Product Settings round-trips
  // these through the outbox without touching the `settings` JSON. Defaults
  // are false/0; real values land on first `applyUpdateResponse` / login.
  BoolColumn get trackInventory =>
      boolean().named('track_inventory').withDefault(const Constant(false))();
  BoolColumn get stockNotification => boolean()
      .named('stock_notification')
      .withDefault(const Constant(false))();
  IntColumn get inventoryNotificationThreshold => integer()
      .named('inventory_notification_threshold')
      .withDefault(const Constant(0))();
  BoolColumn get enableProductDiscount => boolean()
      .named('enable_product_discount')
      .withDefault(const Constant(false))();
  BoolColumn get enableProductCost => boolean()
      .named('enable_product_cost')
      .withDefault(const Constant(false))();
  BoolColumn get enableProductQuantity => boolean()
      .named('enable_product_quantity')
      .withDefault(const Constant(false))();
  BoolColumn get defaultQuantity =>
      boolean().named('default_quantity').withDefault(const Constant(false))();
  BoolColumn get showProductDetails => boolean()
      .named('show_product_details')
      .withDefault(const Constant(false))();
  BoolColumn get fillProducts =>
      boolean().named('fill_products').withDefault(const Constant(false))();
  BoolColumn get updateProducts =>
      boolean().named('update_products').withDefault(const Constant(false))();
  BoolColumn get convertProducts =>
      boolean().named('convert_products').withDefault(const Constant(false))();
  BoolColumn get convertRateToClient => boolean()
      .named('convert_rate_to_client')
      .withDefault(const Constant(false))();
  // Top-level workflow configuration. Edited by Settings → Workflow Settings;
  // the per-entity workflow toggles (auto_email_invoice, lock_invoices, etc.)
  // ride along in the `settings` JSON blob.
  BoolColumn get stopOnUnpaidRecurring => boolean()
      .named('stop_on_unpaid_recurring')
      .withDefault(const Constant(false))();
  BoolColumn get useQuoteTermsOnConversion => boolean()
      .named('use_quote_terms_on_conversion')
      .withDefault(const Constant(false))();
  // Top-level task configuration. Edited by Settings → Task Settings; the
  // per-entity task toggles (`default_task_rate`, `task_round_up`, …) ride
  // along in the `settings` JSON blob. Defaults are false so existing rows
  // backfill via `addColumn` without an explicit migration UPDATE.
  BoolColumn get autoStartTasks =>
      boolean().named('auto_start_tasks').withDefault(const Constant(false))();
  BoolColumn get showTaskEndDate => boolean()
      .named('show_task_end_date')
      .withDefault(const Constant(false))();
  BoolColumn get showTasksTable =>
      boolean().named('show_tasks_table').withDefault(const Constant(false))();
  BoolColumn get invoiceTaskDatelog => boolean()
      .named('invoice_task_datelog')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceTaskTimelog => boolean()
      .named('invoice_task_timelog')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceTaskHours => boolean()
      .named('invoice_task_hours')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceTaskItemDescription => boolean()
      .named('invoice_task_item_description')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceTaskProject => boolean()
      .named('invoice_task_project')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceTaskProjectHeader => boolean()
      .named('invoice_task_project_header')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceTaskLock =>
      boolean().named('invoice_task_lock').withDefault(const Constant(false))();
  BoolColumn get invoiceTaskDocuments => boolean()
      .named('invoice_task_documents')
      .withDefault(const Constant(false))();
  // Top-level expense configuration. Edited by Settings → Expense Settings.
  // Cascade `default_expense_payment_type_id` lives in the `settings` JSON
  // blob. The `inbound_mailbox_*` block is self-hosted only — gated client-
  // side by `session.isHosted == false`.
  BoolColumn get markExpensesInvoiceable => boolean()
      .named('mark_expenses_invoiceable')
      .withDefault(const Constant(false))();
  BoolColumn get markExpensesPaid => boolean()
      .named('mark_expenses_paid')
      .withDefault(const Constant(false))();
  BoolColumn get convertExpenseCurrency => boolean()
      .named('convert_expense_currency')
      .withDefault(const Constant(false))();
  BoolColumn get invoiceExpenseDocuments => boolean()
      .named('invoice_expense_documents')
      .withDefault(const Constant(false))();
  BoolColumn get notifyVendorWhenPaid => boolean()
      .named('notify_vendor_when_paid')
      .withDefault(const Constant(false))();
  BoolColumn get calculateExpenseTaxByAmount => boolean()
      .named('calculate_expense_tax_by_amount')
      .withDefault(const Constant(false))();
  BoolColumn get expenseInclusiveTaxes => boolean()
      .named('expense_inclusive_taxes')
      .withDefault(const Constant(false))();
  BoolColumn get expenseMailboxActive => boolean()
      .named('expense_mailbox_active')
      .withDefault(const Constant(false))();
  TextColumn get expenseMailbox =>
      text().named('expense_mailbox').withDefault(const Constant(''))();
  BoolColumn get inboundMailboxAllowCompanyUsers => boolean()
      .named('inbound_mailbox_allow_company_users')
      .withDefault(const Constant(false))();
  BoolColumn get inboundMailboxAllowVendors => boolean()
      .named('inbound_mailbox_allow_vendors')
      .withDefault(const Constant(false))();
  BoolColumn get inboundMailboxAllowClients => boolean()
      .named('inbound_mailbox_allow_clients')
      .withDefault(const Constant(false))();
  TextColumn get inboundMailboxWhitelist => text()
      .named('inbound_mailbox_whitelist')
      .withDefault(const Constant(''))();
  TextColumn get inboundMailboxBlacklist => text()
      .named('inbound_mailbox_blacklist')
      .withDefault(const Constant(''))();
  BoolColumn get inboundMailboxAllowUnknown => boolean()
      .named('inbound_mailbox_allow_unknown')
      .withDefault(const Constant(false))();
  // Top-level SMTP transport. Edited by Settings → Email Settings when the
  // `smtp` provider is selected. The cascade-aware email properties (sending
  // method, from name, signature, …) ride along in the `settings` JSON blob;
  // these seven live at company top-level only. `smtp_encryption` mirrors
  // admin-portal's `'TLS'` / `'STARTTLS'` vocabulary (default `'TLS'`);
  // `smtp_verify_peer` defaults to true to match the legacy fallback.
  TextColumn get smtpHost =>
      text().named('smtp_host').withDefault(const Constant(''))();
  IntColumn get smtpPort =>
      integer().named('smtp_port').withDefault(const Constant(0))();
  TextColumn get smtpEncryption =>
      text().named('smtp_encryption').withDefault(const Constant('TLS'))();
  TextColumn get smtpUsername =>
      text().named('smtp_username').withDefault(const Constant(''))();
  TextColumn get smtpPassword =>
      text().named('smtp_password').withDefault(const Constant(''))();
  TextColumn get smtpLocalDomain =>
      text().named('smtp_local_domain').withDefault(const Constant(''))();
  BoolColumn get smtpVerifyPeer =>
      boolean().named('smtp_verify_peer').withDefault(const Constant(true))();
  // Account Management → Integrations: top-level analytics keys. Empty
  // string defaults backfill in place; real values land on next login /
  // refresh / updateCompany.
  TextColumn get googleAnalyticsKey =>
      text().named('google_analytics_key').withDefault(const Constant(''))();
  TextColumn get matomoId =>
      text().named('matomo_id').withDefault(const Constant(''))();
  TextColumn get matomoUrl =>
      text().named('matomo_url').withDefault(const Constant(''))();
  // Account Management → Security Settings. Timeouts in milliseconds; 0 =
  // never time out. `oauth_password_required` defaults to false.
  IntColumn get sessionTimeout =>
      integer().named('session_timeout').withDefault(const Constant(0))();
  IntColumn get defaultPasswordTimeout => integer()
      .named('default_password_timeout')
      .withDefault(const Constant(0))();
  BoolColumn get oauthPasswordRequired => boolean()
      .named('oauth_password_required')
      .withDefault(const Constant(false))();
  // Account Management → Overview top-level toggles.
  BoolColumn get isDisabled =>
      boolean().named('is_disabled').withDefault(const Constant(false))();
  BoolColumn get markdownEnabled =>
      boolean().named('markdown_enabled').withDefault(const Constant(false))();
  BoolColumn get markdownEmailEnabled => boolean()
      .named('markdown_email_enabled')
      .withDefault(const Constant(false))();
  BoolColumn get reportIncludeDrafts => boolean()
      .named('report_include_drafts')
      .withDefault(const Constant(false))();
  BoolColumn get reportIncludeDeleted => boolean()
      .named('report_include_deleted')
      .withDefault(const Constant(false))();
  // Settings → Online Payments top-level toggles. Both live at company
  // top-level in the API (not inside the `settings` JSON), so — like
  // convert_expense_currency / first_month_of_year — they each need their own
  // column or they're dropped on every login/refresh and the toggle resets.
  // `enable_applying_payments` = "Admin Initiated Payments";
  // `convert_payment_currency` = "Convert Currency".
  BoolColumn get enableApplyingPayments => boolean()
      .named('enable_applying_payments')
      .withDefault(const Constant(false))();
  BoolColumn get convertPaymentCurrency => boolean()
      .named('convert_payment_currency')
      .withDefault(const Constant(false))();
  // QuickBooks integration blob. Null when not connected; otherwise carries
  // the nested `{accessTokenKey, refresh_token, realmID, settings:{...}}`
  // object the server stores on `company.quickbooks`. Persisted as JSON so
  // the QuickbooksScreen can read the connection state offline + after cold
  // restart.
  TextColumn get quickbooksJson => text().named('quickbooks_json').nullable()();
  // Top-level portal configuration. Edited by Settings → Client Portal.
  // `companyKey` doubles as the public id baked into self-hosted login URLs
  // and is otherwise read-only — but it has to round-trip through the
  // companies row anyway so offline screens can render the Login URL display.
  // `clientRegistrationFields` is the JSON-encoded list of
  // `{key, required, visible}` records driving the Registration tab
  // configurator; empty array = server's default (every field hidden).
  TextColumn get subdomain =>
      text().named('subdomain').withDefault(const Constant(''))();
  TextColumn get portalDomain =>
      text().named('portal_domain').withDefault(const Constant(''))();
  TextColumn get portalMode =>
      text().named('portal_mode').withDefault(const Constant(''))();
  BoolColumn get clientCanRegister => boolean()
      .named('client_can_register')
      .withDefault(const Constant(false))();
  TextColumn get companyKey =>
      text().named('company_key').withDefault(const Constant(''))();
  TextColumn get clientRegistrationFields => text()
      .named('client_registration_fields')
      .withDefault(const Constant('[]'))();
  IntColumn get updatedAt => integer().named('updated_at')();

  /// Per-company `/api/v1/refresh` high-water mark, in epoch ms — the
  /// wall-clock at the start of the last successful full/delta refresh for
  /// this company. The next refresh passes `updated_at=(this/1000)-buffer`
  /// so the server returns only records changed since then (v1's delta-sync
  /// model). `0` (the default, and what upgraders backfill to) forces one
  /// full refresh, after which deltas take over.
  IntColumn get lastSyncAt =>
      integer().named('last_sync_at').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Account-level info (one row per logged-in user). Stores hosted-vs-self
/// hosted, plan, trial info, feature flags, etc. — anything that's per-user
/// rather than per-company.
@DataClassName('AccountRow')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get plan => text()();
  IntColumn get numTrialDays => integer().named('num_trial_days')();
  BoolColumn get isHosted =>
      boolean().named('is_hosted').withDefault(const Constant(false))();
  TextColumn get defaultCompanyId =>
      text().named('default_company_id').nullable()();
  TextColumn get featuresJson => text().named('features_json').nullable()();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
